#!/bin/bash

echo "=== ZABBIX 7.4 - UBUNTU 24.04 ==="

apt update
apt upgrade -y

echo "1. MySQL..."
apt install -y mysql-server
systemctl start mysql
systemctl enable mysql

mysql -u root << EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'zabbix';
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'zabbix';
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

echo "2. Apache e PHP..."
apt install -y apache2 php8.3 php8.3-mysql php8.3-gd php8.3-xml php8.3-mbstring php8.3-bcmath libapache2-mod-php8.3

echo "3. Zabbix 7.4..."
wget -q https://repo.zabbix.com/zabbix/7.4/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.4+ubuntu24.04_all.deb
dpkg -i zabbix-release_latest_7.4+ubuntu24.04_all.deb
apt update

apt install -y \
    zabbix-server-mysql \
    zabbix-frontend-php \
    zabbix-apache-conf \
    zabbix-sql-scripts \
    zabbix-agent2 \
    zabbix-js

echo "4. Banco de dados..."
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -pzabbix zabbix

echo "5. Configurando..."
sed -i 's/^# DBPassword=/DBPassword=zabbix/' /etc/zabbix/zabbix_server.conf
sed -i 's/^# DBHost=localhost/DBHost=localhost/' /etc/zabbix/zabbix_server.conf
sed -i "s/^Hostname=Zabbix server/Hostname=$(hostname)/" /etc/zabbix/zabbix_agent2.conf
sed -i "s/^;date.timezone =/date.timezone = America\/Sao_Paulo/" /etc/php/8.3/apache2/php.ini

echo "6. phpMyAdmin..."
apt install -y phpmyadmin
ln -sf /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
a2enconf phpmyadmin

echo "7. Apache..."
a2enmod ssl rewrite
a2ensite zabbix.conf
systemctl restart apache2

echo "8. Serviços..."
systemctl restart mysql
systemctl restart zabbix-server
systemctl restart zabbix-agent2

systemctl enable mysql zabbix-server zabbix-agent2 apache2

echo "=== CONCLUÍDO ==="
echo ""
echo "Zabbix 7.4: http://$(hostname -I | awk '{print $1}')/zabbix"
echo "phpMyAdmin: http://$(hostname -I | awk '{print $1}')/phpmyadmin"
echo ""
echo "Credenciais:"
echo "  MySQL:    root/zabbix"
echo "  Zabbix DB: zabbix/zabbix"
echo "  Zabbix Web: Admin/zabbix"
