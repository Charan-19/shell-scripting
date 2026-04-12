FROM nginx:stable-alpine

# Copy custom nginx config (use COPY, not ADD)
# Remove default site config and clear default html, combining into one layer
RUN rm -f /etc/nginx/conf.d/default.conf && \
	rm -f /etc/nginx/nginx.conf && \
	rm -rf /usr/share/nginx/html/*
ADD nginx.conf /etc/nginx/nginx.conf
ADD static /usr/share/nginx/html/
# Copy static files; set ownership to nginx user to avoid permission issues

EXPOSE 80
USER nginx
CMD ["nginx", "-g", "daemon off;"]
