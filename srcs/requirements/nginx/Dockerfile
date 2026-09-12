FROM debian:bookworm

# update and install all the depedencies
RUN apt update && apt install nginx -y  \
            openssl -y \
            curl   -y \
            vim  -y && \
            rm -rf /var/lib/apt/lists/*

#creater the ssl folder
RUN mkdir -p /etc/nginx/ssl

#generate the certificate and stores it 
RUN openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/inception.key \
  -out /etc/nginx/ssl/inception.crt \
  -subj "/C=CZ/ST=Prague/L=Prague/O=42/OU=42/CN=vnicoles.42.fr/UID=vnicoles"

#create folder to store nginx config files
RUN mkdir -p /var/run/nginx

#Replace the nginx file with the one stored in conf
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/default.conf /etc/nginx/conf.d/default.conf

#Add rights to files
RUN chmod 755 /var/www/html
RUN chown -R www-data:www-data /var/www/html

#Documentation (port open in commpose)
EXPOSE 443

#launch this and says to docker to keep it in foreground
CMD ["nginx", "-g", "daemon off;"]
