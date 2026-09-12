FROM debian:bookworm

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      wget \
      php8.2 \
      php8.2-fpm \
      php8.2-mysql \
      mariadb-client \
      curl \
      ca-certificates \
      bash && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/php /var/www/html

# RUN chown -R root:root /var/www/wordpress
RUN chown -R www-data:www-data /var/www/html

RUN sed -i 's|^listen = .*|listen = 9000|' /etc/php/*/fpm/pool.d/www.conf

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

#RUN wp core download --allow-root

COPY conf/auto_config.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /var/www/html

ENTRYPOINT ["bash", "/entrypoint.sh"]
