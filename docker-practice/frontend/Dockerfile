FROM nginx
RUN rm /usr/share/nginx/html/index.html
RUN rm /etc/nginx/nginx.conf
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY static /usr/share/nginx/html
