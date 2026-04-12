FROM nginx:stable-alpine

# Copy custom nginx config (use COPY, not ADD)
# Remove default site config and clear default html, combining into one layer
RUN rm -f /etc/nginx/conf.d/default.conf && \
	rm -f /etc/nginx/nginx.conf && \
	rm -rf /usr/share/nginx/html/*
RUN mkdir -p /var/cache/nginx/client_temp && \
        mkdir -p /var/cache/nginx/proxy_temp && \
        mkdir -p /var/cache/nginx/fastcgi_temp && \
        mkdir -p /var/cache/nginx/uwsgi_temp && \
        mkdir -p /var/cache/nginx/scgi_temp && \
        chown -R nginx:nginx /var/cache/nginx && \
        chown -R nginx:nginx /etc/nginx/ && \
        chmod -R 755 /etc/nginx/ && \
        chown -R nginx:nginx /var/log/nginx
RUN mkdir -p /etc/nginx/ssl/ && \
    chown -R nginx:nginx /etc/nginx/ssl/ && \
    chmod -R 755 /etc/nginx/ssl/
RUN touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid /run/nginx.pid
ADD nginx.conf /etc/nginx/nginx.conf
ADD static /usr/share/nginx/html/
# Copy static files; set ownership to nginx user to avoid permission issues

EXPOSE 80
USER nginx
CMD ["nginx", "-g", "daemon off;"]
