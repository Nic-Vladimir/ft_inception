HOSTS_ENTRY = "127.0.0.1	vnicoles.42.fr"

# ==Rules==
all: build up

hosts:
	@if ! grep -q "vnicoles.42.fr" /etc/hosts; then \
		echo $(HOSTS_ENTRY) | sudo tee -a /etc/hosts > /dev/null; \
	fi

up:
	docker compose -f ./srcs/docker-compose.yml up -d

down:
	docker compose -f ./srcs/docker-compose.yml down

build: hosts
	docker compose -f ./srcs/docker-compose.yml build --no-cache
	mkdir -p /home/vladimir/data/mariadb_data /home/vladimir/data/wp_data

status:
	docker ps

logs:
	docker compose -f ./srcs/docker-compose.yml logs -f --tail=100

logs-nginx:
	docker compose -f ./srcs/docker-compose.yml logs -f --tail=100 nginx

logs-wordpress:
	docker compose -f ./srcs/docker-compose.yml logs -f --tail=100 wordpress

logs-mariadb:
	docker compose -f ./srcs/docker-compose.yml logs -f --tail=100 mariadb

clean:
	docker compose -f ./srcs/docker-compose.yml down

fclean:
	docker compose -f ./srcs/docker-compose.yml down --rmi all --volumes --remove-orphans
	sudo rm -rf ~/data/mariadb_data ~/data/wp_data

re: fclean all

.PHONY: all up down build status logs logs-nginx logs-wordpress logs-mariadb clean fclean re
