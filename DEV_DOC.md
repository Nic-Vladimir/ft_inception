# Developer documentation

This document describes how to set up, build and maintain the Inception stack.

## 1. Setting up the environment from scratch

### 1.1 Prerequisites

| Requirement            | Purpose                                       |
| ---------------------- | --------------------------------------------- |
| Docker Engine          | Building the images and running the containers |
| Docker Compose plugin  | Orchestration, invoked as `docker compose`     |
| `make`                 | Entrypoint of every operation                  |
| `sudo` rights          | Adding the domain to `/etc/hosts`, deleting the data owned by the containers |
| An outgoing connection | Debian packages, WP-CLI and WordPress are downloaded at build and first start |

The project is meant to run in a virtual machine. The user account running it
must be a member of the `docker` group.

### 1.2 Repository layout

```
Makefile                  all targets, calls docker compose
README.md                 presentation of the project
USER_DOC.md               user and administrator documentation
DEV_DOC.md                this file
secrets/                  passwords, ignored by git
srcs/.env                 non-sensitive configuration, ignored by git
srcs/docker-compose.yml   services, network, volumes, secrets
srcs/requirements/<service>/Dockerfile
srcs/requirements/<service>/conf/    configuration files copied into the image
srcs/requirements/<service>/tools/   entrypoint scripts
```

### 1.3 Configuration file: `srcs/.env`

Ignored by git and therefore absent from a fresh clone. It must be created before
the first build and must contain no password.

```ini
DOMAIN_NAME=vnicoles.42.fr

MARIADB_DATABASE=wordpress_db
MARIADB_USER=wpuser
MARIADB_HOST=mariadb

WP_PATH=https://vnicoles.42.fr
WP_TITLE=Vnicoles' Containers
WP_ADMIN_USER=vnicoles42
WP_ADMIN_EMAIL=vnicoles@42.fr

WP_USER=vnicoles
WP_USER_EMAIL=vladimir@42.fr
```

| Variable                             | Used by     | Purpose                                          |
| ------------------------------------ | ----------- | ------------------------------------------------ |
| `DOMAIN_NAME`                        | both        | Domain of the site                               |
| `MARIADB_DATABASE`, `MARIADB_USER`   | mariadb, wordpress | Database and its owner                    |
| `MARIADB_HOST`                       | wordpress   | Host name of the database, i.e. the service name |
| `WP_PATH`, `WP_TITLE`                | wordpress   | Site URL and title                               |
| `WP_ADMIN_USER`, `WP_ADMIN_EMAIL`    | wordpress   | Administrator account. The login must contain neither `admin` nor `administrator` |
| `WP_USER`, `WP_USER_EMAIL`           | wordpress   | Second account, created with the `author` role   |

### 1.4 Secrets

The four passwords live in `secrets/`, which is ignored by git. Compose mounts
them read-only inside the containers under `/run/secrets/`.

| File in `secrets/`       | Secret name         | Mounted in          | Format                     |
| ------------------------ | ------------------- | ------------------- | -------------------------- |
| `db_root_password.txt`   | `db_root_password`  | mariadb             | the password, one line     |
| `db_password.txt`        | `db_password`       | mariadb, wordpress  | the password, one line     |
| `credentials.txt`        | `credentials`       | wordpress           | `KEY=value` lines          |

Creating them:

```bash
mkdir -p secrets
printf 'supersecure'      > secrets/db_root_password.txt
printf 'supersecure'  > secrets/db_password.txt
cat > secrets/credentials.txt <<'EOF'
WP_ADMIN_PASSWORD=supersecure
WP_USER_PASSWORD=supersecure
EOF
chmod 600 secrets/*.txt
```

The single-line files are read with `tr -d '\r\n'`, so a trailing newline is
harmless. `credentials.txt` is parsed line by line: the two keys must be spelled
exactly `WP_ADMIN_PASSWORD` and `WP_USER_PASSWORD`. Both entrypoints exit with an
explicit error if a secret is missing or incomplete.

### 1.5 Domain name and data directory

`make build` performs the two remaining host-side steps:

- it appends `127.0.0.1 vnicoles.42.fr` to `/etc/hosts` if the entry is missing,
  which requires `sudo`;
- it creates `/home/vnicoles/data/mariadb_data` and
  `/home/vnicoles/data/wp_data`, since Docker does not create the target
  directory of a volume by itself.

That path appears in two places, `volumes.*.driver_opts.device` in
`srcs/docker-compose.yml` and the `mkdir`/`rm` lines of the `Makefile`. Both must
be kept in sync and must match the home directory of the user running the stack.

## 2. Building and launching

`make` is the only entrypoint; it always calls `docker compose` with
`-f ./srcs/docker-compose.yml`.

| Target      | Effect                                                                    |
| ----------- | ------------------------------------------------------------------------- |
| `all`       | `build` then `up`, the default target                                     |
| `hosts`     | Adds the domain to `/etc/hosts` if needed                                 |
| `build`     | `hosts`, then builds the three images with `--no-cache`, then creates the data directories |
| `up`        | Starts the containers in the background                                   |
| `down`      | Stops and removes the containers and the network                          |
| `status`    | `docker ps`                                                               |
| `logs`      | Follows the logs of the three services                                    |
| `logs-nginx`, `logs-wordpress`, `logs-mariadb` | Follows the logs of one service          |
| `clean`     | Same as `down`                                                            |
| `fclean`    | `down` with `--rmi all --volumes --remove-orphans`, then deletes the data directories with `sudo` |
| `re`        | `fclean` then `all`                                                       |

First launch:

```bash
make
```

Build order is imposed by `depends_on`: `mariadb`, then `wordpress`, then
`nginx`. Dependencies only guarantee the start order, not readiness, so
`auto_config.sh` waits in a loop until the database answers before installing
WordPress.

What happens on the first start:

1. `mariadb` finds an empty data directory, runs `mysql_install_db`, starts a
   temporary server, creates the database and its user, sets the `root` password
   from the secrets, then execs `mysqld`.
2. `wordpress` waits for the database, downloads WordPress 6.0 with WP-CLI,
   writes `wp-config.php`, installs the site, creates the two accounts, then
   execs `php-fpm8.2 -F`.
3. `nginx` starts and serves the volume shared with `wordpress`.

On the following starts both scripts detect the existing installation and go
straight to their final process.

Rebuilding a single service:

```bash
docker compose -f ./srcs/docker-compose.yml build --no-cache nginx
docker compose -f ./srcs/docker-compose.yml up -d nginx
```

## 3. Managing containers and volumes

Containers:

```bash
docker compose -f ./srcs/docker-compose.yml ps          # state of the services
docker compose -f ./srcs/docker-compose.yml restart nginx
docker compose -f ./srcs/docker-compose.yml logs -f mariadb
docker exec -it wordpress bash                          # shell in a container
docker inspect nginx --format '{{.State.Status}} {{.HostConfig.RestartPolicy.Name}}'
```

Useful checks inside the containers:

```bash
docker exec nginx nginx -T                    # effective NGINX configuration
docker exec nginx cat /proc/1/cmdline         # PID 1 of the container
docker exec mariadb ls -l /run/secrets/       # secrets actually mounted
docker exec wordpress wp core version --allow-root --path=/var/www/html
```

Images and network:

```bash
docker images | grep -E 'nginx|wordpress|mariadb'
docker network inspect srcs_inception_network
```

Volumes:

```bash
docker volume ls                              # srcs_wordpress_data, srcs_mariadb_data
docker volume inspect srcs_mariadb_data       # driver options and mountpoint
```

A volume in use cannot be removed: stop the containers first with `make down`,
then remove it with `docker volume rm`, or use `make fclean` which does both.

Compose prefixes the objects it creates with the name of the directory holding
the compose file, hence `srcs_wordpress_data`, `srcs_mariadb_data` and
`srcs_inception_network`. The containers themselves keep a fixed name thanks to
`container_name`.

Validating the compose file without starting anything:

```bash
docker compose -f ./srcs/docker-compose.yml config
```

## 4. Where the data is stored and how it persists

Two named volumes are declared in `srcs/docker-compose.yml`:

| Volume            | Mounted in                           | Content                          |
| ----------------- | ------------------------------------ | -------------------------------- |
| `mariadb_data`    | `mariadb:/var/lib/mysql`             | Database files                   |
| `wordpress_data`  | `wordpress:/var/www/html` and `nginx:/var/www/html` | WordPress core, themes, plugins, uploads |

Both use the `local` driver with mount options pointing at
`/home/vnicoles/data`, so the data physically lives on the host:

```
/home/vnicoles/data/mariadb_data   database files
/home/vnicoles/data/wp_data        WordPress files
```

The services never reference a host path; they mount the volumes by name only.

The web root volume is shared by two containers: `wordpress` writes the PHP
files, `nginx` reads the static files from the same directory. This is why NGINX
needs no copy of the site.

Consequences for persistence:

- `make down` and `make up` keep everything. The entrypoints detect the existing
  installation and skip initialisation.
- Rebuilding the images changes nothing in the data, since no site content is
  baked into an image.
- `make fclean` removes the volumes and their directories, so the next start
  reinstalls a blank site with a new database.

The files under `/home/vnicoles/data` are owned by the users of the containers,
`mysql` for the database and `www-data` for the website, which is why `fclean`
deletes them with `sudo`.

Backing up and restoring the site:

```bash
# Backup
docker exec mariadb mariadb-dump \
  -u root -p"$(cat secrets/db_root_password.txt)" \
  --all-databases > backup.sql
sudo tar czf wp_files.tar.gz -C /home/vnicoles/data wp_data

# Restore, stack running and database present
docker exec -i mariadb mariadb \
  -u root -p"$(cat secrets/db_root_password.txt)" < backup.sql
```
