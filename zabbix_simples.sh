#!/bin/bash

# Script corrigido para instalação do Zabbix Server no Ubuntu Server

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configurações
DB_ROOT_PASS="ZabbixRoot123!"
DB_ZABBIX_PASS="ZabbixDB123!"
ZABBIX_HOSTNAME=$(hostname)
SERVER_IP=$(hostname -I | awk '{print $1}')

print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Verificar root
if [[ $EUID -ne 0 ]]; then
    print_error "Execute como root: sudo bash $0"
    exit 1
fi

# Menu de configuração
echo "========================================"
echo "  INSTALAÇÃO ZABBIX SERVER - UBUNTU    "
echo "========================================"
echo ""
echo "Configurações padrão:"
echo "1. Senha root MySQL: ${DB_ROOT_PASS}"
echo "2. Senha Zabbix DB: ${DB_ZABBIX_PASS}"
echo "3. Hostname: ${ZABBIX_HOSTNAME}"
echo "4. IP do Servidor: ${SERVER_IP}"
echo ""
read -p "Usar configurações padrão? (s/n): " -r usar_padrao

if [[ "$usar_padrao" =~ ^[Nn]$ ]]; then
    read -p "Nova senha root MySQL: " DB_ROOT_PASS
    read -p "Nova senha Zabbix DB: " DB_ZABBIX_PASS
fi

# Atualizar sistema
print_message "Atualizando sistema..."
apt-get update
apt-get upgrade -y

# Instalar MySQL/MariaDB
print_message "Instalando MariaDB..."
apt-get install -y mariadb-server mariadb-client

# Configurar MySQL
print_message "Configurando MySQL..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';"
systemctl restart mysql

# Criar banco de dados Zabbix
print_message "Criando banco de dados Zabbix..."
mysql -uroot -p${DB_ROOT_PASS} -e "DROP DATABASE IF EXISTS zabbix;"
mysql -uroot -p${DB_ROOT_PASS} -e "CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
mysql -uroot -p${DB_ROOT_PASS} -e "CREATE USER 'zabbix'@'localhost' IDENTIFIED BY '${DB_ZABBIX_PASS}';"
mysql -uroot -p${DB_ROOT_PASS} -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
mysql -uroot -p${DB_ROOT_PASS} -e "FLUSH PRIVILEGES;"

# Instalar Zabbix
print_message "Instalando pacotes Zabbix..."
apt-get install -y \
    zabbix-server-mysql \
    zabbix-frontend-php \
    zabbix-apache-conf \
    zabbix-sql-scripts \
    zabbix-agent \
    zabbix-js

# Importar schema do banco
print_message "Importando schema do banco de dados..."
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -p${DB_ZABBIX_PASS} zabbix

# CORREÇÃO DO ERRO 404 - Configurar Apache corretamente
print_message "Configurando Apache para evitar erro 404..."

# 1. Verificar se os arquivos do Zabbix existem
if [ ! -d "/usr/share/zabbix" ]; then
    print_error "Diretório /usr/share/zabbix não encontrado!"
    exit 1
fi

# 2. Configurar permissões corretamente
chown -R www-data:www-data /usr/share/zabbix/
chmod -R 755 /usr/share/zabbix/

# 3. Criar configuração do VirtualHost corretamente
cat > /etc/apache2/sites-available/zabbix.conf << EOF
<VirtualHost *:80>
    ServerName ${ZABBIX_HOSTNAME}
    ServerAlias ${SERVER_IP}
    DocumentRoot /usr/share/zabbix
    
    <Directory /usr/share/zabbix>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
        
        <IfModule mod_php7.c>
            php_value max_execution_time 300
            php_value memory_limit 128M
            php_value post_max_size 16M
            php_value upload_max_filesize 2M
            php_value max_input_time 300
            php_value always_populate_raw_post_data -1
            php_value date.timezone America/Sao_Paulo
        </IfModule>
        <IfModule mod_php.c>
            php_value max_execution_time 300
            php_value memory_limit 128M
            php_value post_max_size 16M
            php_value upload_max_filesize 2M
            php_value max_input_time 300
            php_value always_populate_raw_post_data -1
            php_value date.timezone America/Sao_Paulo
        </IfModule>
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/zabbix_error.log
    CustomLog \${APACHE_LOG_DIR}/zabbix_access.log combined
</VirtualHost>
EOF

# 4. Configurar arquivo de configuração do Zabbix
cat > /etc/apache2/conf-available/zabbix.conf << EOF
# Configuração do Zabbix para Apache
Alias /zabbix /usr/share/zabbix

<Directory "/usr/share/zabbix">
    Options FollowSymLinks
    AllowOverride None
    Order allow,deny
    Allow from all
    
    <IfModule mod_php7.c>
        php_value max_execution_time 300
        php_value memory_limit 128M
        php_value post_max_size 16M
        php_value upload_max_filesize 2M
        php_value max_input_time 300
        php_value always_populate_raw_post_data -1
        php_value date.timezone America/Sao_Paulo
    </IfModule>
    <IfModule mod_php.c>
        php_value max_execution_time 300
        php_value memory_limit 128M
        php_value post_max_size 16M
        php_value upload_max_filesize 2M
        php_value max_input_time 300
        php_value always_populate_raw_post_data -1
        php_value date.timezone America/Sao_Paulo
    </IfModule>
</Directory>

<Directory "/usr/share/zabbix/conf">
    Order deny,allow
    Deny from all
    <files *.php>
        Order deny,allow
        Deny from all
    </files>
</Directory>

<Directory "/usr/share/zabbix/app">
    Order deny,allow
    Deny from all
    <files *.php>
        Order deny,allow
        Deny from all
    </files>
</Directory>

<Directory "/usr/share/zabbix/include">
    Order deny,allow
    Deny from all
    <files *.php>
        Order deny,allow
        Deny from all
    </files>
</Directory>

<Directory "/usr/share/zabbix/local">
    Order deny,allow
    Deny from all
    <files *.php>
        Order deny,allow
        Deny from all
    </files>
</Directory>
EOF

# 5. Configurar arquivo do Zabbix Server
ZABBIX_SERVER_CONF="/etc/zabbix/zabbix_server.conf"
cp ${ZABBIX_SERVER_CONF} ${ZABBIX_SERVER_CONF}.backup

cat > ${ZABBIX_SERVER_CONF} << EOF
# Zabbix Server Configuration File

### GENERAL PARAMETERS ###
LogType=file
LogFile=/var/log/zabbix/zabbix_server.log
LogFileSize=0
DebugLevel=3
PidFile=/run/zabbix/zabbix_server.pid
SocketDir=/run/zabbix
DBHost=localhost
DBName=zabbix
DBUser=zabbix
DBPassword=${DB_ZABBIX_PASS}
DBPort=3306

### ADVANCED PARAMETERS ###
StartPollers=5
StartPollersUnreachable=1
StartTrappers=5
StartPingers=1
StartDiscoverers=1
StartHTTPPollers=1
StartAlerters=3
StartTimers=1
StartEscalators=1
CacheSize=32M
HistoryCacheSize=16M
HistoryIndexCacheSize=4M
TrendCacheSize=4M
ValueCacheSize=8M
Timeout=4
TrapperTimeout=300
UnreachablePeriod=45
UnavailableDelay=60
UnreachableDelay=15

### JAVAGATEWAY ###
JavaGateway=
JavaGatewayPort=10052
StartJavaPollers=0
EOF

# 6. Configurar arquivo do Zabbix Agent
ZABBIX_AGENT_CONF="/etc/zabbix/zabbix_agentd.conf"
cp ${ZABBIX_AGENT_CONF} ${ZABBIX_AGENT_CONF}.backup

cat > ${ZABBIX_AGENT_CONF} << EOF
# Zabbix Agent Configuration File

PidFile=/run/zabbix/zabbix_agentd.pid
LogType=file
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=0
DebugLevel=3
Server=127.0.0.1
ServerActive=127.0.0.1
Hostname=${ZABBIX_HOSTNAME}
ListenPort=10050
ListenIP=0.0.0.0
StartAgents=3
Timeout=3
Include=/etc/zabbix/zabbix_agentd.d/*.conf
EnableRemoteCommands=1
LogRemoteCommands=1
EOF

# 7. Configurar PHP
print_message "Configurando PHP..."
PHP_INI=$(find /etc/php -name "php.ini" | grep apache | head -1)

if [ -n "$PHP_INI" ]; then
    cp ${PHP_INI} ${PHP_INI}.backup
    sed -i "s/^;date.timezone =/date.timezone = America\/Sao_Paulo/" ${PHP_INI}
    sed -i "s/^max_execution_time = .*/max_execution_time = 300/" ${PHP_INI}
    sed -i "s/^max_input_time = .*/max_input_time = 300/" ${PHP_INI}
    sed -i "s/^post_max_size = .*/post_max_size = 32M/" ${PHP_INI}
    sed -i "s/^upload_max_filesize = .*/upload_max_filesize = 16M/" ${PHP_INI}
    sed -i "s/^memory_limit = .*/memory_limit = 256M/" ${PHP_INI}
else
    print_warning "Arquivo php.ini do Apache não encontrado"
fi

# 8. Configurar módulos Apache
print_message "Configurando Apache..."
a2enmod rewrite
a2enmod ssl
a2enmod headers
a2dissite 000-default.conf 2>/dev/null
a2ensite zabbix.conf
a2enconf zabbix.conf

# 9. Criar arquivo de configuração do Zabbix Frontend
cat > /usr/share/zabbix/conf/zabbix.conf.php << EOF
<?php
// Zabbix GUI configuration file.
global \$DB;

\$DB['TYPE']     = 'MYSQL';
\$DB['SERVER']   = 'localhost';
\$DB['PORT']     = '0';
\$DB['DATABASE'] = 'zabbix';
\$DB['USER']     = 'zabbix';
\$DB['PASSWORD'] = '${DB_ZABBIX_PASS}';

// Schema name. Used for IBM DB2 and PostgreSQL.
\$DB['SCHEMA'] = '';

\$ZBX_SERVER      = 'localhost';
\$ZBX_SERVER_PORT = '10051';
\$ZBX_SERVER_NAME = 'Zabbix Server';

\$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
EOF

chown www-data:www-data /usr/share/zabbix/conf/zabbix.conf.php
chmod 644 /usr/share/zabbix/conf/zabbix.conf.php

# 10. Iniciar serviços
print_message "Iniciando serviços..."
systemctl restart mysql
systemctl restart zabbix-server
systemctl restart zabbix-agent
systemctl restart apache2

systemctl enable mysql
systemctl enable zabbix-server
systemctl enable zabbix-agent
systemctl enable apache2

# 11. Configurar firewall
if command -v ufw > /dev/null; then
    if ufw status | grep -q "active"; then
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 10050/tcp
        ufw allow 10051/tcp
        ufw reload
    fi
fi

# 12. Testar configuração
print_message "Testando configuração..."
sleep 5

# Verificar se serviços estão rodando
echo ""
echo "========================================"
echo "       VERIFICAÇÃO DE SERVIÇOS         "
echo "========================================"
echo ""

services=("mysql" "zabbix-server" "zabbix-agent" "apache2")
for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo -e "${GREEN}✓ $service está rodando${NC}"
    else
        echo -e "${RED}✗ $service NÃO está rodando${NC}"
        systemctl status $service --no-pager | head -10
    fi
done

echo ""
echo "========================================"
echo "       VERIFICAÇÃO DE ARQUIVOS         "
echo "========================================"
echo ""

# Verificar arquivos importantes
files=(
    "/usr/share/zabbix"
    "/usr/share/zabbix/index.php"
    "/etc/apache2/sites-enabled/zabbix.conf"
    "/etc/zabbix/zabbix_server.conf"
)

for file in "${files[@]}"; do
    if [ -e "$file" ]; then
        echo -e "${GREEN}✓ $file existe${NC}"
    else
        echo -e "${RED}✗ $file NÃO existe${NC}"
    fi
done

echo ""
echo "========================================"
echo "        INFORMAÇÕES DE ACESSO          "
echo "========================================"
echo ""
echo -e "${GREEN}ZABBIX INSTALADO COM SUCESSO!${NC}"
echo ""
echo "URLs de acesso:"
echo "1. http://${SERVER_IP}/zabbix"
echo "2. http://${ZABBIX_HOSTNAME}/zabbix"
echo "3. http://localhost/zabbix"
echo ""
echo "Credenciais padrão:"
echo "Usuário: Admin"
echo "Senha: zabbix"
echo ""
echo "Informações do banco de dados:"
echo "Host: localhost"
echo "Banco: zabbix"
echo "Usuário: zabbix"
echo ""
echo "Arquivos de log:"
echo "/var/log/zabbix/zabbix_server.log"
echo "/var/log/zabbix/zabbix_agentd.log"
echo "/var/log/apache2/zabbix_error.log"
echo ""
echo "========================================"
echo ""
echo "Se ainda tiver erro 404, execute:"
echo "sudo systemctl restart apache2"
echo "sudo tail -f /var/log/apache2/error.log"
echo ""
