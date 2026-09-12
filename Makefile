all: up

up:
	mkdir -p ./mariadb_data ./wp_data
	docker compose -f ./srcs/docker-compose.yml up -d

stop:
	docker compose -f ./srcs/docker-compose.yml stop

start:
	docker compose -f ./srcs/docker-compose.yml start

build:
	docker compose -f ./srcs/docker-compose.yml build --no-cache

status:
	docker ps

down:
	docker compose -f ./srcs/docker-compose.yml down

clean:
	docker compose -f ./srcs/docker-compose.yml down

fclean:
	docker compose -f ./srcs/docker-compose.yml down
	docker system prune -af --volumes
	rm -rf ./mariadb_data ./wp_data

re: fclean all

.PHONY: all up down start stop build status clean fclean re
