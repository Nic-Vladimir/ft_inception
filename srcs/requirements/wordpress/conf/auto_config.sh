#!/bin/bash
set -e

echo "⏳ Waiting for MariaDB to be ready..."
while ! mariadb \
  -h"${MARIADB_HOST}" \
  -u"${MARIADB_USER}" \
  -p"${MARIADB_PASSWORD}" \
  -e "SELECT 1;" >/dev/null 2>&1; do
  sleep 2
done
echo "✅ Database is ready!"

cd /var/www/html

if [ ! -f "wp-load.php" ]; then
  echo "⬇️ Downloading WordPress 6.0..."
  wp core download \
    --version=6.0 \
    --allow-root
else
  echo "🔁 WordPress files already exist."
fi

if [ ! -f "wp-config.php" ]; then
  echo "⚙️ Creating wp-config.php..."

  wp config create \
    --allow-root \
    --dbname="${MARIADB_DATABASE}" \
    --dbuser="${MARIADB_USER}" \
    --dbpass="${MARIADB_PASSWORD}" \
    --dbhost="${MARIADB_HOST}"
else
  echo "🔁 wp-config.php already exists."
fi

if ! wp core is-installed --allow-root >/dev/null 2>&1; then
  echo "🛠 Installing WordPress..."

  wp core install \
    --allow-root \
    --url="${WP_PATH}" \
    --title="${WP_TITLE}" \
    --admin_user="${WP_ADMIN_USER}" \
    --admin_password="${WP_ADMIN_PASS}" \
    --admin_email="${WP_ADMIN_EMAIL}"

  echo "✅ WordPress installed."
else
  echo "🔁 WordPress is already installed."
fi

if ! wp user get "${WP_ADMIN_USER}" --allow-root >/dev/null 2>&1; then
  echo "👤 Creating admin user..."

  wp user create \
    "${WP_ADMIN_USER}" \
    "${WP_ADMIN_EMAIL}" \
    --role=administrator \
    --user_pass="${WP_ADMIN_PASS}" \
    --allow-root

  echo "✅ Admin user created."
else
  echo "🔁 Admin user '${WP_ADMIN_USER}' already exists."
fi

if ! wp user get "${WP_USER}" --allow-root >/dev/null 2>&1; then
  echo "👤 Creating secondary user..."

  wp user create \
    "${WP_USER}" \
    "${WP_USER_EMAIL}" \
    --role=author \
    --user_pass="${WP_USER_PWD}" \
    --allow-root

  echo "✅ Secondary user created."
else
  echo "🔁 Secondary user '${WP_USER}' already exists."
fi

echo "🔐 Fixing permissions..."
chown -R www-data:www-data /var/www/html

echo "🚀 Starting PHP-FPM..."
exec /usr/sbin/php-fpm8.2 -F
