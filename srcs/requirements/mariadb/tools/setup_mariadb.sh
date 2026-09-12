#!/bin/bash
set -euo pipefail

# Passwords come from Docker secrets, never from the environment.
read_secret() {
  if [ ! -r "$1" ]; then
    echo "❌ Missing Docker secret: $1" >&2
    exit 1
  fi
  tr -d '\r\n' <"$1"
}

MARIADB_PASSWORD="$(read_secret /run/secrets/db_password)"
MARIADB_ROOT_PASSWORD="$(read_secret /run/secrets/db_root_password)"

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

# First-ever MariaDB initialization
if [ ! -d "/var/lib/mysql/mysql" ]; then

  echo "🆕 First initialization detected — setting up MariaDB..."

  mysql_install_db --user=mysql --ldata=/var/lib/mysql

  echo "Starting temporary MariaDB server..."
  mysqld --user=mysql --skip-networking --socket=/run/mysqld/mysqld.sock &
  temp_pid=$!

  echo "Waiting for MariaDB to be ready..."

  for i in {30..0}; do
    if mysqladmin --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  if ! mysqladmin --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; then
    echo "❌ MariaDB did not start properly — aborting setup."
    kill "$temp_pid" 2>/dev/null || true
    exit 1
  fi

  echo "✅ MariaDB is ready, configuring initial users..."

  mysql --socket=/run/mysqld/mysqld.sock -u root <<-EOSQL
        CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;
        CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
        GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
        FLUSH PRIVILEGES;
EOSQL

  echo "Shutting down temporary MariaDB..."

  mysqladmin \
    --socket=/run/mysqld/mysqld.sock \
    -u root \
    -p"${MARIADB_ROOT_PASSWORD}" \
    shutdown

  wait "$temp_pid" 2>/dev/null || true

  echo "✅ MariaDB initial setup complete."

else

  echo "🔁 Existing MariaDB data found."

  # Check whether our WordPress database exists
  if mysql \
    -u root \
    -p"${MARIADB_ROOT_PASSWORD}" \
    -e "USE \`${MARIADB_DATABASE}\`;" >/dev/null 2>&1; then
    echo "✅ Database '${MARIADB_DATABASE}' already exists."
  else
    echo "⚠️ Database '${MARIADB_DATABASE}' is missing."
    echo "Creating database and user..."

    # Start temporary server
    mysqld --user=mysql --skip-networking --socket=/run/mysqld/mysqld.sock &
    temp_pid=$!

    for i in {30..0}; do
      if mysqladmin --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done

    mysql \
      --socket=/run/mysqld/mysqld.sock \
      -u root \
      -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL
            CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;
            CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
            ALTER USER '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
            GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
            FLUSH PRIVILEGES;
EOSQL

    mysqladmin \
      --socket=/run/mysqld/mysqld.sock \
      -u root \
      -p"${MARIADB_ROOT_PASSWORD}" \
      shutdown

    wait "$temp_pid" 2>/dev/null || true

    echo "✅ Database and user created."
  fi
fi

echo "🚀 Starting MariaDB in foreground..."
exec mysqld --user=mysql --console
