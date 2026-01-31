FROM nginx:alpine
RUN apk add --no-cache curl
COPY default.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
