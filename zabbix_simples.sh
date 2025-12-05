#!/bin/bash

# Instalação rápida do Zabbix Server - Ubuntu Server

# Configurações
DB_ROOT_PASS="SuaSenhaRoot123!"
DB_ZABBIX_PASS="SenhaZabbixDB123!"

# Atualizar sistema
apt update && apt upgrade -y

# Instalar MySQL
apt install -y mysql-server
systemctl start mysql
systemctl enable mysql

# Configurar MySQL
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_ROOT_PASS}';"
mysql -uroot -p${DB_ROOT_PASS} -e "CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
mysql -uroot -p${DB_ROOT_PASS} -e "CREATE USER 'zabbix'@'localhost' IDENTIFIED BY '${DB_ZABBIX_PASS}';"
mysql -uroot -p${DB_ROOT_PASS} -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
mysql -uroot -p${DB_ROOT_PASS} -e "FLUSH PRIVILEGES;"

# Instalar Zabbix
apt install -y \
    zabbix-server-mysql \
    zabbix-frontend-php \
    zabbix-apache-conf \
    zabbix-sql-scripts \
    zabbix-agent

# Importar banco de dados
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -p${DB_ZABBIX_PASS} zabbix

# Configurar Zabbix
sed -i "s/^# DBPassword=$/DBPassword=${DB_ZABBIX_PASS}/" /etc/zabbix/zabbix_server.conf
sed -i "s/^Hostname=Zabbix server/Hostname=$(hostname)/" /etc/zabbix/zabbix_agentd.conf

# Configurar PHP
sed -i "s/^;date.timezone =/date.timezone = America\/Sao_Paulo/" /etc/php/*/apache2/php.ini

# Reiniciar serviços
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2

echo "Instalação concluída!"
echo "Acesse: http://$(hostname -I | awk '{print $1}')/zabbix"
echo "Usuário: Admin"
echo "Senha: zabbix"
