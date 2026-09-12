FROM debian:bookworm

RUN apt update -y && \
    apt install mariadb-server -y && \
    rm -rf /var/lib/apt/lists/*

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

RUN mkdir -p /run/mysqld && \
    chown -R mysql:mysql /run/mysqld

COPY tools/setup_mariadb.sh /tmp/setup_mariadb.sh

RUN chmod +x /tmp/setup_mariadb.sh

ENTRYPOINT [ "bash", "/tmp/setup_mariadb.sh" ]
