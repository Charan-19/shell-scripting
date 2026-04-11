FROM nginx:stable-alpine

# Copy custom nginx config (use COPY, not ADD)
# Remove default site config and clear default html, combining into one layer
RUN rm -f /etc/nginx/conf.d/default.conf && \
	rm -rf /usr/share/nginx/html/*
ADD nginx.conf /etc/nginx/nginx.conf
# Copy static files; set ownership to nginx user to avoid permission issues
COPY --chown=nginx:nginx static/ /usr/share/nginx/html/

EXPOSE 80
USER nginx
CMD ["nginx", "-g", "daemon off;"]
