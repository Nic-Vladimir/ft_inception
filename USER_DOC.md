# User documentation

This document explains how to operate the Inception stack. All commands are run
from the root of the repository, where the `Makefile` is located.

## 1. Services provided by the stack

| Service     | Description                                                                                     | Reachable from the host |
| ----------- | ----------------------------------------------------------------------------------------------- | ----------------------- |
| `nginx`     | Web server and TLS termination. Serves the static files and forwards PHP requests to WordPress. | `https://vnicoles.42.fr` (port 443) |
| `wordpress` | The WordPress site itself, executed by php-fpm.                                                  | No, internal only       |
| `mariadb`   | Database server storing the WordPress content, accounts and settings.                            | No, internal only       |

Port 443 is the only port published on the host. The two other services are only
reachable from inside the `inception_network` Docker network.

The website content and the database are stored outside the containers, in
`/home/vnicoles/data`. Stopping or rebuilding the stack does not delete them.

## 2. Starting and stopping the project

Build the images and start everything, first launch included:

```bash
make
```

The first start takes a few minutes: the images are built, the database is
initialised and WordPress is installed. Subsequent starts take a few seconds.

| Action                                          | Command      |
| ----------------------------------------------- | ------------ |
| Start the containers                            | `make up`    |
| Stop and remove the containers, keeping the data | `make down`  |
| Rebuild the images and start again               | `make`       |
| Delete everything, including the website data    | `make fclean` |
| Full reset, then rebuild from scratch            | `make re`    |

`make fclean` removes the containers, the images, the volumes and the content of
`/home/vnicoles/data`. The website and the database are lost, and the next start
performs a fresh installation.

## 3. Accessing the website and the administration panel

- Website: <https://vnicoles.42.fr>
- Administration panel: <https://vnicoles.42.fr/wp-admin>

The certificate is self-signed, so the browser displays a security warning on
the first visit. Accept it to continue; this is expected for a local
installation.

`https://` is mandatory. The stack does not listen on port 80 and does not
redirect from it.

The domain name must resolve to the local machine. `make` takes care of this by
adding the following line to `/etc/hosts` if it is missing:

```
127.0.0.1	vnicoles.42.fr
```

Two accounts are created at installation:

| Account       | Role          | Purpose                                        |
| ------------- | ------------- | ---------------------------------------------- |
| `vnicoles42`  | administrator | Full administration of the site                |
| `vnicoles`    | author        | Regular account, may write and publish posts   |

## 4. Locating and managing credentials

Passwords are not in the repository and not in the environment. They are stored
in three files in the `secrets/` directory, which is ignored by git and mounted
read-only inside the containers as Docker secrets:

| File                           | Content                                                        |
| ------------------------------ | -------------------------------------------------------------- |
| `secrets/db_root_password.txt` | Password of the MariaDB `root` account                          |
| `secrets/db_password.txt`      | Password of the MariaDB user owning the WordPress database      |
| `secrets/credentials.txt`      | `WP_ADMIN_PASSWORD` and `WP_USER_PASSWORD`, the two site logins |

Read the password of the administration panel:

```bash
cat secrets/credentials.txt
```

Non-sensitive settings, such as the domain name, the database name and the two
WordPress logins, are defined in `srcs/.env`.

Changing a password:

- **WordPress accounts:** change them from the administration panel, under
  *Users*, and update `secrets/credentials.txt` accordingly.
- **Database passwords:** editing the files is only sufficient before the first
  start. Once the database exists, the password is also stored inside MariaDB and
  in `wp-config.php`, so it must either be changed in the database as well, or
  the stack must be reset with `make fclean` followed by `make`.

Keep the files readable by their owner only:

```bash
chmod 600 secrets/*.txt
```

## 5. Checking that the services run correctly

The three containers must be listed as `Up`:

```bash
make status
```

Expected output, one line per service, with `nginx` publishing port 443:

```
CONTAINER ID   IMAGE           STATUS         PORTS                    NAMES
...            nginx:1.0       Up 2 minutes   0.0.0.0:443->443/tcp     nginx
...            wordpress:1.0   Up 2 minutes                            wordpress
...            mariadb:1.0     Up 2 minutes                            mariadb
```

Read the logs, all services at once or one at a time:

```bash
make logs
make logs-nginx
make logs-wordpress
make logs-mariadb
```

Check that the site answers over HTTPS:

```bash
curl -Ik https://vnicoles.42.fr
```

`HTTP/1.1 200 OK` means NGINX, php-fpm and MariaDB all work, since the home page
is a PHP page reading the database.

Check that only TLSv1.2 and TLSv1.3 are accepted:

```bash
openssl s_client -connect vnicoles.42.fr:443 -tls1_2 </dev/null   # succeeds
openssl s_client -connect vnicoles.42.fr:443 -tls1_1 </dev/null   # fails
```

Check that the database is populated:

```bash
docker exec -it mariadb mariadb \
  -u root -p"$(cat secrets/db_root_password.txt)" \
  -e "SHOW DATABASES;"
```

Check the WordPress accounts:

```bash
docker exec -it wordpress wp user list --allow-root --path=/var/www/html
```

If a container is missing or keeps restarting, its logs give the reason. A
missing `srcs/.env` or a missing file in `secrets/` is the most common cause: the
entrypoints stop immediately with an explicit message in that case.
