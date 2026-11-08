const instana = require('@instana/collector');

// Initialize tracing before loading other modules
instana({
    tracing: {
        enabled: true
    }
});

const redis = require('redis');
const request = require('request');
const bodyParser = require('body-parser');
const express = require('express');
const pino = require('pino');
const expPino = require('express-pino-logger');
const promClient = require('prom-client');

// Prometheus metrics
const Registry = promClient.Registry;
const register = new Registry();

const counter = new promClient.Counter({
    name: 'items_added',
    help: 'running count of items added to cart',
    registers: [register]
});

// Application configuration
var redisConnected = false;
var redisHost = process.env.REDIS_HOST || 'redis';
var redisPort = parseInt(process.env.REDIS_PORT || '6379', 10);
var catalogueHost = process.env.CATALOGUE_HOST || 'catalogue';
var cataloguePort = process.env.CATALOGUE_PORT || '8080';

const logger = pino({
    level: 'info',
    prettyPrint: false,
    useLevelLabels: true
});

const expLogger = expPino({
    logger: logger
});

const app = express();

app.use(expLogger);

app.use((req, res, next) => {
    res.set('Timing-Allow-Origin', '*');
    res.set('Access-Control-Allow-Origin', '*');
    next();
});

app.use((req, res, next) => {
    const dcs = [
        'asia-northeast2',
        'asia-south1',
        'europe-west3',
        'us-east1',
        'us-west1'
    ];

    const span = instana.currentSpan();

    if (span) {
        span.annotate(
            'custom.sdk.tags.datacenter',
            dcs[Math.floor(Math.random() * dcs.length)]
        );
    }

    next();
});

app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());

// Redis client for redis@2.8.x
// Connection starts automatically when createClient() is called.
const redisClient = redis.createClient({
    host: redisHost,
    port: redisPort
});

// Redis connection lifecycle events
redisClient.on('connect', () => {
    logger.info('Redis CONNECT: TCP connection established');
});

redisClient.on('ready', () => {
    redisConnected = true;
    logger.info('Redis READY: client is ready to accept commands');
});

redisClient.on('reconnecting', (params) => {
    redisConnected = false;
    logger.warn({ reconnect: params }, 'Redis RECONNECTING');
});

redisClient.on('end', () => {
    redisConnected = false;
    logger.error('Redis END: connection has been closed');
});

redisClient.on('error', (err) => {
    logger.error({ err: err }, 'Redis ERROR');
});

// Check Redis readiness before executing Redis-dependent requests
function requireRedis(req, res, next) {
    if (!redisConnected) {
        return res.status(503).json({
            error: 'Redis is not ready',
            message: 'Cart service cannot process this request until Redis reconnects'
        });
    }

    next();
}

// Health endpoint
app.get('/health', (req, res) => {
    res.json({
        app: 'OK',
        redis: redisConnected
    });
});

// Prometheus metrics endpoint
app.get('/metrics', (req, res) => {
    res.set('Content-Type', register.contentType);
    res.send(register.metrics());
});

// Get cart
app.get('/cart/:id', requireRedis, (req, res) => {
    redisClient.get(req.params.id, (err, data) => {
        if (err) {
            req.log.error({ err: err }, 'Unable to get cart from Redis');
            return res.status(500).send(err.message || err);
        }

        if (data == null) {
            return res.status(404).send('cart not found');
        }

        res.set('Content-Type', 'application/json');
        res.send(data);
    });
});

// Delete cart
app.delete('/cart/:id', requireRedis, (req, res) => {
    redisClient.del(req.params.id, (err, data) => {
        if (err) {
            req.log.error({ err: err }, 'Unable to delete cart from Redis');
            return res.status(500).send(err.message || err);
        }

        if (data === 1) {
            return res.send('OK');
        }

        res.status(404).send('cart not found');
    });
});

// Rename cart
app.get('/rename/:from/:to', requireRedis, (req, res) => {
    redisClient.get(req.params.from, (err, data) => {
        if (err) {
            req.log.error({ err: err }, 'Unable to read cart for rename');
            return res.status(500).send(err.message || err);
        }

        if (data == null) {
            return res.status(404).send('cart not found');
        }

        let cart;

        try {
            cart = JSON.parse(data);
        } catch (parseError) {
            req.log.error({ err: parseError }, 'Stored cart contains invalid JSON');
            return res.status(500).send('stored cart data is invalid');
        }

        saveCart(req.params.to, cart)
            .then(() => res.json(cart))
            .catch((saveError) => {
                req.log.error({ err: saveError }, 'Unable to save renamed cart');
                res.status(500).send(saveError.message || saveError);
            });
    });
});

// Add product to cart
app.get('/add/:id/:sku/:qty', requireRedis, (req, res) => {
    const qty = parseInt(req.params.qty, 10);

    if (isNaN(qty)) {
        req.log.warn('quantity not a number');
        return res.status(400).send('quantity must be a number');
    }

    if (qty < 1) {
        req.log.warn('quantity less than one');
        return res.status(400).send('quantity has to be greater than zero');
    }

    getProduct(req.params.sku)
        .then((product) => {
            req.log.info({ product: product }, 'Catalogue product lookup completed');

            if (!product) {
                return res.status(404).send('product not found');
            }

            if (product.instock === 0) {
                return res.status(404).send('out of stock');
            }

            redisClient.get(req.params.id, (err, data) => {
                if (err) {
                    req.log.error({ err: err }, 'Unable to get cart from Redis');
                    return res.status(500).send(err.message || err);
                }

                let cart;

                if (data == null) {
                    cart = {
                        total: 0,
                        tax: 0,
                        items: []
                    };
                } else {
                    try {
                        cart = JSON.parse(data);
                    } catch (parseError) {
                        req.log.error({ err: parseError }, 'Stored cart contains invalid JSON');
                        return res.status(500).send('stored cart data is invalid');
                    }
                }

                const item = {
                    qty: qty,
                    sku: req.params.sku,
                    name: product.name,
                    price: product.price,
                    subtotal: qty * product.price
                };

                cart.items = mergeList(cart.items, item, qty);
                cart.total = calcTotal(cart.items);
                cart.tax = calcTax(cart.total);

                saveCart(req.params.id, cart)
                    .then(() => {
                        counter.inc(qty);
                        res.json(cart);
                    })
                    .catch((saveError) => {
                        req.log.error({ err: saveError }, 'Unable to save cart to Redis');
                        res.status(500).send(saveError.message || saveError);
                    });
            });
        })
        .catch((productError) => {
            req.log.error({ err: productError }, 'Catalogue request failed');
            res.status(500).send(productError.message || productError);
        });
});

// Update cart quantity
app.get('/update/:id/:sku/:qty', requireRedis, (req, res) => {
    const qty = parseInt(req.params.qty, 10);

    if (isNaN(qty)) {
        req.log.warn('quantity not a number');
        return res.status(400).send('quantity must be a number');
    }

    if (qty < 0) {
        req.log.warn('quantity less than zero');
        return res.status(400).send('negative quantity not allowed');
    }

    redisClient.get(req.params.id, (err, data) => {
        if (err) {
            req.log.error({ err: err }, 'Unable to get cart from Redis');
            return res.status(500).send(err.message || err);
        }

        if (data == null) {
            return res.status(404).send('cart not found');
        }

        let cart;

        try {
            cart = JSON.parse(data);
        } catch (parseError) {
            req.log.error({ err: parseError }, 'Stored cart contains invalid JSON');
            return res.status(500).send('stored cart data is invalid');
        }

        const idx = cart.items.findIndex(
            (item) => item.sku === req.params.sku
        );

        if (idx === -1) {
            return res.status(404).send('not in cart');
        }

        if (qty === 0) {
            cart.items.splice(idx, 1);
        } else {
            cart.items[idx].qty = qty;
            cart.items[idx].subtotal = cart.items[idx].price * qty;
        }

        cart.total = calcTotal(cart.items);
        cart.tax = calcTax(cart.total);

        saveCart(req.params.id, cart)
            .then(() => res.json(cart))
            .catch((saveError) => {
                req.log.error({ err: saveError }, 'Unable to save updated cart');
                res.status(500).send(saveError.message || saveError);
            });
    });
});

// Add shipping
app.post('/shipping/:id', requireRedis, (req, res) => {
    const shipping = req.body;

    if (
        shipping.distance === undefined ||
        shipping.cost === undefined ||
        shipping.location === undefined
    ) {
        req.log.warn({ shipping: shipping }, 'shipping data missing');
        return res.status(400).send('shipping data missing');
    }

    redisClient.get(req.params.id, (err, data) => {
        if (err) {
            req.log.error({ err: err }, 'Unable to get cart from Redis');
            return res.status(500).send(err.message || err);
        }

        if (data == null) {
            req.log.info({ id: req.params.id }, 'no cart for user');
            return res.status(404).send('cart not found');
        }

        let cart;

        try {
            cart = JSON.parse(data);
        } catch (parseError) {
            req.log.error({ err: parseError }, 'Stored cart contains invalid JSON');
            return res.status(500).send('stored cart data is invalid');
        }

        const item = {
            qty: 1,
            sku: 'SHIP',
            name: 'shipping to ' + shipping.location,
            price: shipping.cost,
            subtotal: shipping.cost
        };

        const idx = cart.items.findIndex(
            (existingItem) => existingItem.sku === item.sku
        );

        if (idx === -1) {
            cart.items.push(item);
        } else {
            cart.items[idx] = item;
        }

        cart.total = calcTotal(cart.items);
        cart.tax = calcTax(cart.total);

        saveCart(req.params.id, cart)
            .then(() => res.json(cart))
            .catch((saveError) => {
                req.log.error({ err: saveError }, 'Unable to save cart with shipping');
                res.status(500).send(saveError.message || saveError);
            });
    });
});

// Merge cart items
function mergeList(list, product, qty) {
    const existingIndex = list.findIndex(
        (item) => item.sku === product.sku
    );

    if (existingIndex !== -1) {
        list[existingIndex].qty += qty;
        list[existingIndex].subtotal =
            list[existingIndex].price * list[existingIndex].qty;
    } else {
        list.push(product);
    }

    return list;
}

// Calculate cart total
function calcTotal(list) {
    return list.reduce(
        (total, item) => total + item.subtotal,
        0
    );
}

// Calculate tax
function calcTax(total) {
    return total - (total / 1.2);
}

// Fetch product details from Catalogue
function getProduct(sku) {
    return new Promise((resolve, reject) => {
        const url =
            'http://' + catalogueHost + ':' +
            cataloguePort + '/product/' +
            encodeURIComponent(sku);

        request(url, (err, response, body) => {
            if (err) {
                return reject(err);
            }

            if (!response || response.statusCode !== 200) {
                return resolve(null);
            }

            try {
                resolve(JSON.parse(body));
            } catch (parseError) {
                reject(parseError);
            }
        });
    });
}

// Save cart to Redis
function saveCart(id, cart) {
    logger.info({ id: id, cart: cart }, 'Saving cart');

    return new Promise((resolve, reject) => {
        redisClient.setex(
            id,
            3600,
            JSON.stringify(cart),
            (err, data) => {
                if (err) {
                    return reject(err);
                }

                resolve(data);
            }
        );
    });
}

// Start HTTP server
const port = process.env.CART_SERVER_PORT || '8080';

const server = app.listen(port, () => {
    logger.info({ port: port }, 'Cart service started');
});

// Graceful shutdown
function shutdown(signal) {
    logger.info({ signal: signal }, 'Shutting down Cart service');

    redisConnected = false;

    server.close(() => {
        redisClient.quit(() => {
            process.exit(0);
        });
    });

    setTimeout(() => process.exit(1), 10000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));