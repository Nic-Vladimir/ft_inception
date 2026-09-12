*This project has been created as part of the 42 curriculum by vnicoles.*

# Inception

## Description

Inception is a system administration project whose goal is to build a small web
infrastructure with Docker, where every service runs in its own container built
from a Dockerfile written from scratch.

The stack serves a WordPress website over HTTPS and is composed of three
services orchestrated by Docker Compose:

| Service     | Image           | Role                                                        |
| ----------- | --------------- | ----------------------------------------------------------- |
| `nginx`     | `nginx:1.0`     | TLS termination and the only entrypoint, port 443           |
| `wordpress` | `wordpress:1.0` | WordPress 6.0 served by php-fpm 8.2, listening on port 9000 |
| `mariadb`   | `mariadb:1.0`   | MariaDB server holding the WordPress database               |

The three containers communicate over a dedicated bridge network. The database
and the website files are stored in two Docker named volumes so that the site
survives the destruction and recreation of the containers. The site is reachable
at `https://vnicoles.42.fr`.

## Project description

### Use of Docker

Each service is described by its own Dockerfile, built from `debian:bookworm`
(the penultimate stable Debian release). No pre-built application image is
pulled: the images are built locally by Docker Compose, which is itself invoked
from the `Makefile`. Every image carries the name of its service and an explicit
version tag, so `latest` is never used.

Each container runs a single foreground process, which becomes PID 1:

- `nginx` runs `nginx -g "daemon off;"`,
- `wordpress` runs `php-fpm8.2 -F`,
- `mariadb` runs `mysqld --user=mysql --console`.

No container is kept alive artificially, and all three declare
`restart: always` so they come back automatically after a crash.

### Sources included in the project

```
.
├── Makefile                     entrypoint for building and running the stack
├── README.md                    this file
├── USER_DOC.md                  user and administrator documentation
├── DEV_DOC.md                   developer documentation
├── secrets/                     passwords, ignored by git
│   ├── credentials.txt
│   ├── db_password.txt
│   └── db_root_password.txt
└── srcs/
    ├── .env                     non-sensitive configuration, ignored by git
    ├── docker-compose.yml       services, network, volumes and secrets
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/50-server.cnf          server configuration
        │   └── tools/setup_mariadb.sh      database bootstrap, then mysqld
        ├── nginx/
        │   ├── Dockerfile
        │   └── conf/
        │       ├── nginx.conf              global configuration, TLS policy
        │       └── default.conf            virtual host on port 443
        └── wordpress/
            ├── Dockerfile
            └── conf/auto_config.sh         WordPress install, then php-fpm
```

### Main design choices

- **NGINX is the only published port.** Only `443:443` is mapped to the host.
  The Debian default virtual host, which listens on port 80, is not included in
  `nginx.conf`. `ssl_protocols TLSv1.2 TLSv1.3` is set both globally and in the
  virtual host, so no older protocol can be negotiated. The certificate is
  self-signed and generated at build time for `vnicoles.42.fr`.
- **No application code in the images.** WordPress is downloaded and configured
  at first start by `auto_config.sh` using WP-CLI, directly inside the volume.
  The image therefore stays generic and the site content lives only in the
  volume.
- **Idempotent entrypoints.** Both `setup_mariadb.sh` and `auto_config.sh`
  detect an existing installation and skip initialisation, so restarting the
  stack never overwrites existing data.
- **php-fpm over TCP.** php-fpm listens on `9000` and NGINX reaches it through
  the Docker network at `wordpress:9000`, which keeps the two services in
  separate containers while sharing the same web root volume.
- **Two WordPress accounts** are created at installation: an administrator whose
  login contains neither `admin` nor `administrator`, and a second account with
  the `author` role.

### Virtual Machines vs Docker

A virtual machine emulates a complete machine: the hypervisor provides virtual
hardware and the guest boots its own kernel, with its own init system and its
own memory and disk allocation. Isolation is therefore very strong, but each
instance costs gigabytes of disk and hundreds of megabytes of RAM, and takes
minutes to provision.

A container is only a group of processes running on the host kernel, isolated by
namespaces (PID, network, mount, user) and limited by cgroups. There is no guest
kernel and no emulated hardware, so a container starts in milliseconds and its
image only contains the files the service needs. The price is a weaker isolation
boundary, since all containers share the host kernel, and the loss of the
ability to run another operating system.

For this project containers are the right tool: three cooperating services must
be started, destroyed and rebuilt constantly, and each one only needs a
filesystem and a process. The project is nevertheless run inside a virtual
machine, which shows how the two technologies complement each other rather than
compete.

### Secrets vs Environment Variables

Environment variables configure a container: they are declared in `srcs/.env`,
injected with `env_file`, and readable by any process in the container as well
as by anyone running `docker inspect` or `docker compose config`. They are
convenient for non-sensitive values such as the domain name, the database name
or an account login.

Docker secrets are files mounted read-only inside the container under
`/run/secrets/`. They are not part of the image, not part of the container
configuration, and not exposed to child processes through the environment. This
project keeps the four passwords in `secrets/db_password.txt`,
`secrets/db_root_password.txt` and `secrets/credentials.txt`; the entrypoint
scripts read them from `/run/secrets/` at start-up. The `secrets/` directory is
ignored by git, so no credential ever reaches the repository, and no password
appears in a Dockerfile or in `.env`.

### Docker Network vs Host Network

With the host network the container shares the host network namespace: it uses
the host interfaces and ports directly, there is no port mapping and no
isolation, and two services wanting the same port collide.

A user-defined bridge network, as used here with `inception_network`, gives the
containers their own namespace and their own subnet. Docker provides an internal
DNS server, so a container is reached by its service name: NGINX connects to
`wordpress:9000` and WordPress to `mariadb:3306` without knowing any IP address.
Only the ports explicitly published are reachable from outside, which is what
makes `443` the single entrypoint while MariaDB and php-fpm remain unreachable
from the host. This is why the subject forbids `network: host` and `links:`.

### Docker Volumes vs Bind Mounts

A bind mount attaches an arbitrary host directory into a container. It is
practical during development because both sides see the same files immediately,
but the container then depends on the host layout, on host permissions and on
the presence of that directory; nothing in Docker describes or manages it.

A named volume is an object managed by Docker: it is declared, listed with
`docker volume ls`, inspected, and removed independently of the containers using
it. Its lifecycle is bound to the project rather than to a path on the host,
which is why the subject requires named volumes for the database and for the
website files.

This project declares both storages as named volumes in the `volumes:` section
of `docker-compose.yml`, and the local driver is given mount options so that the
volume data is stored under `/home/vnicoles/data`, as required. The services
never reference a host path themselves: they only mount the volumes by name.

## Instructions

There is nothing to compile. The infrastructure is built and launched from the
`Makefile` at the root of the repository.

Prerequisites: Docker Engine, the Docker Compose plugin, `make`, and `sudo`
rights (used once to add the domain to `/etc/hosts`).

Before the first launch, two files must exist. They are ignored by git and
therefore not part of the repository:

1. `srcs/.env`, containing the non-sensitive configuration.
2. `secrets/db_password.txt`, `secrets/db_root_password.txt` and
   `secrets/credentials.txt`, containing the passwords.

Their exact content is described in `DEV_DOC.md`.

Build the images and start the stack:

```bash
make
```

The site is then served at `https://vnicoles.42.fr`. The certificate is
self-signed, so the browser asks for a confirmation on the first visit.

Other targets:

```bash
make up        # start the containers
make down      # stop and remove the containers
make status    # list the running containers
make logs      # follow the logs of the three services
make clean     # stop and remove the containers
make fclean    # also remove the images, the volumes and their data
make re        # fclean, then rebuild and restart
```

`USER_DOC.md` describes day-to-day usage, `DEV_DOC.md` the development
environment.

## Resources

Documentation used while writing the project:

- Inception subject, 42 School.
- Docker documentation: [Dockerfile
  reference](https://docs.docker.com/reference/dockerfile/), [Best practices for
  writing Dockerfiles](https://docs.docker.com/build/building/best-practices/),
  [Compose file
  reference](https://docs.docker.com/reference/compose-file/), [Volumes](https://docs.docker.com/engine/storage/volumes/),
  [Networking](https://docs.docker.com/engine/network/), [Secrets in
  Compose](https://docs.docker.com/compose/how-tos/use-secrets/).
- NGINX documentation:
  [ngx_http_ssl_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html),
  [ngx_http_fastcgi_module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html).
- MariaDB Knowledge Base:
  [mysql_install_db](https://mariadb.com/kb/en/mysql_install_db/), [Configuring
  MariaDB with option files](https://mariadb.com/kb/en/configuring-mariadb-with-option-files/).
- PHP documentation: [FastCGI Process
  Manager](https://www.php.net/manual/en/install.fpm.php).
- WP-CLI handbook: [Commands](https://developer.wordpress.org/cli/commands/).
- WordPress documentation: [Editing
  wp-config.php](https://developer.wordpress.org/advanced-administration/wordpress/wp-config/).

### Use of AI

An AI coding assistant was used on this project for the following tasks:

- **Compliance review.** Auditing the repository before peer review
- **Various questions.** Occasional use for checking commands or config structure.
- **Documentation.** Drafting `README.md`, `USER_DOC.md` and `DEV_DOC.md` from
  the actual content of the repository.

The design of the infrastructure, the Dockerfiles, the entrypoint scripts and
the final verification of every change were done by hand.
