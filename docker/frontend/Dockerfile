FROM nginx
RUN rm /etc/nginx/conf.d/default.conf
RUN rm -rf /etc/nginx/nginx.conf
RUN rm -rf /usr/share/nginx/html/*
ADD nginx.conf /etc/nginx/nginx.conf
ADD static /usr/share/nginx/html/