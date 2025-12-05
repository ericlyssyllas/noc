#!/bin/bash

echo "=== INSTALAÇÃO ZABBIX SERVER ==="

apt-get update
apt-get upgrade -y

echo "1. Instalando MySQL..."
apt-get install -y mysql-server
systemctl start mysql
systemctl enable mysql

echo "2. Configurando MySQL..."
mysql -u root << EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'zabbix';
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'zabbix';
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

echo "3. Instalando Apache e PHP..."
apt-get install -y apache2 php libapache2-mod-php php-mysql php-gd php-xml php-mbstring

echo "4. Instalando Zabbix..."
wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-5+ubuntu$(lsb_release -rs)_all.deb
dpkg -i zabbix-release_*.deb
apt-get update
rm -f zabbix-release_*.deb

apt-get install -y \
    zabbix-server-mysql \
    zabbix-frontend-php \
    zabbix-apache-conf \
    zabbix-sql-scripts \
    zabbix-agent \
    zabbix-js

echo "5. Importando banco de dados..."
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -pzabbix zabbix

echo "6. Configurando Zabbix..."
sed -i 's/^# DBPassword=/DBPassword=zabbix/' /etc/zabbix/zabbix_server.conf
sed -i 's/^# DBHost=localhost/DBHost=localhost/' /etc/zabbix/zabbix_server.conf
sed -i "s/^Hostname=Zabbix server/Hostname=$(hostname)/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^;date.timezone =/date.timezone = America\/Sao_Paulo/" /etc/php/*/apache2/php.ini

echo "7. Instalando phpMyAdmin..."
apt-get install -y phpmyadmin
ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
a2enconf phpmyadmin

echo "8. Configurando Apache..."
a2enmod ssl rewrite
a2ensite zabbix.conf
systemctl restart apache2

echo "9. Iniciando serviços..."
systemctl restart mysql
systemctl restart zabbix-server
systemctl restart zabbix-agent

systemctl enable mysql zabbix-server zabbix-agent apache2

echo "=== INSTALAÇÃO CONCLUÍDA ==="
echo ""
echo "Zabbix:     http://$(hostname -I | awk '{print $1}')/zabbix"
echo "phpMyAdmin: http://$(hostname -I | awk '{print $1}')/phpmyadmin"
echo ""
echo "Credenciais:"
echo "  MySQL Root:  usuário: root   senha: zabbix"
echo "  MySQL Zabbix: usuário: zabbix senha: zabbix"
echo "  Zabbix Web:  usuário: Admin  senha: zabbix"
