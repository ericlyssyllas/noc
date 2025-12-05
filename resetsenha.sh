#!/bin/bash

# Recriação completa do banco Zabbix

DB_ROOT_PASS="ZabbixRoot123!"
NEW_ZABBIX_PASS="@Mudar666"

# 1. Remover usuário e banco existentes
mysql -uroot -p${DB_ROOT_PASS} -e "DROP USER IF EXISTS 'zabbix'@'localhost';"
mysql -uroot -p${DB_ROOT_PASS} -e "DROP DATABASE IF EXISTS zabbix;"

# 2. Criar do zero
mysql -uroot -p${DB_ROOT_PASS} -e "CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
mysql -uroot -p${DB_ROOT_PASS} -e "CREATE USER 'zabbix'@'localhost' IDENTIFIED BY '${NEW_ZABBIX_PASS}';"
mysql -uroot -p${DB_ROOT_PASS} -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
mysql -uroot -p${DB_ROOT_PASS} -e "FLUSH PRIVILEGES;"

# 3. Importar schema
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -p${NEW_ZABBIX_PASS} zabbix

# 4. Atualizar configuração
sed -i "s/^DBPassword=.*/DBPassword=${NEW_ZABBIX_PASS}/" /etc/zabbix/zabbix_server.conf

# 5. Reiniciar
systemctl restart zabbix-server

echo "Recriação completa feita!"
echo "Nova senha do usuário zabbix: ${NEW_ZABBIX_PASS}"
