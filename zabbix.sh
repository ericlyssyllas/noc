#!/bin/bash

# ============================================
# INSTALADOR ZABBIX + phpMyAdmin - TUDO zabbix
# ============================================

echo "========================================"
echo "  INSTALANDO ZABBIX + phpMyAdmin       "
echo "========================================"
echo "Todas as senhas serão: zabbix"
echo ""

# 1. ATUALIZAR SISTEMA
echo "[1/10] Atualizando sistema..."
sudo apt-get update
sudo apt-get upgrade -y

# 2. INSTALAR MYSQL
echo "[2/10] Instalando MySQL..."
sudo apt-get install -y mysql-server

# Configurar MySQL
echo "Configurando MySQL..."
sudo systemctl start mysql
sudo systemctl enable mysql

# Definir senha do root como 'zabbix'
sudo mysql << EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'zabbix';
FLUSH PRIVILEGES;
EXIT;
EOF

# 3. INSTALAR APACHE
echo "[3/10] Instalando Apache..."
sudo apt-get install -y apache2

# 4. INSTALAR PHP
echo "[4/10] Instalando PHP..."
sudo apt-get install -y php libapache2-mod-php php-mysql php-gd php-xml php-mbstring php-bcmath

# 5. INSTALAR phpMyAdmin
echo "[5/10] Instalando phpMyAdmin..."
sudo apt-get install -y phpmyadmin

# Durante a instalação, selecione automaticamente:
# - Servidor web: apache2
# - Configurar com dbconfig-common: Sim

# Configurar phpMyAdmin
sudo ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
sudo a2enconf phpmyadmin

# 6. INSTALAR ZABBIX
echo "[6/10] Adicionando repositório do Zabbix..."
wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-5+ubuntu$(lsb_release -rs)_all.deb
sudo dpkg -i zabbix-release_*.deb
sudo apt-get update
rm -f zabbix-release_*.deb

echo "[7/10] Instalando Zabbix..."
sudo apt-get install -y \
    zabbix-server-mysql \
    zabbix-frontend-php \
    zabbix-apache-conf \
    zabbix-sql-scripts \
    zabbix-agent \
    zabbix-js

# 7. CONFIGURAR BANCO DE DADOS
echo "[8/10] Configurando banco de dados..."
sudo mysql -uroot -pzabbix << EOF
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'zabbix';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

# Importar estrutura do banco
echo "Importando banco do Zabbix..."
sudo zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -pzabbix zabbix

# 8. CONFIGURAR ZABBIX
echo "[9/10] Configurando Zabbix..."
# Arquivo do Zabbix Server
sudo sed -i 's/^# DBPassword=/DBPassword=zabbix/' /etc/zabbix/zabbix_server.conf
sudo sed -i 's/^# DBHost=localhost/DBHost=localhost/' /etc/zabbix/zabbix_server.conf

# Arquivo do Zabbix Agent
sudo sed -i 's/^Server=127.0.0.1/Server=127.0.0.1/' /etc/zabbix/zabbix_agentd.conf
sudo sed -i 's/^ServerActive=127.0.0.1/ServerActive=127.0.0.1/' /etc/zabbix/zabbix_agentd.conf
sudo sed -i "s/^Hostname=Zabbix server/Hostname=$(hostname)/" /etc/zabbix/zabbix_agentd.conf

# Configurar PHP
sudo sed -i "s/^;date.timezone =/date.timezone = America\/Sao_Paulo/" /etc/php/*/apache2/php.ini

# 9. CONFIGURAR APACHE
echo "[10/10] Configurando Apache..."
sudo a2enmod ssl rewrite headers
sudo a2ensite zabbix.conf
sudo systemctl restart apache2

# 10. INICIAR SERVIÇOS
echo "Iniciando serviços..."
sudo systemctl restart mysql
sudo systemctl restart zabbix-server
sudo systemctl restart zabbix-agent
sudo systemctl restart apache2

sudo systemctl enable mysql zabbix-server zabbix-agent apache2

# 11. INFORMAÇÕES FINAIS
clear
echo "========================================"
echo "    INSTALAÇÃO CONCLUÍDA COM SUCESSO!   "
echo "========================================"
echo ""
echo "✅ TODAS AS SENHAS SÃO: zabbix"
echo ""
echo "🌐 URLS DE ACESSO:"
echo "   Zabbix:      http://$(hostname -I | awk '{print $1}')/zabbix"
echo "   phpMyAdmin:  http://$(hostname -I | awk '{print $1}')/phpmyadmin"
echo ""
echo "🔑 CREDENCIAIS:"
echo "   MySQL Root:      usuário: root       senha: zabbix"
echo "   MySQL Zabbix:    usuário: zabbix     senha: zabbix"
echo "   Zabbix Web:      usuário: Admin      senha: zabbix"
echo "   phpMyAdmin:      usuário: root       senha: zabbix"
echo ""
echo "🛠️  COMANDOS ÚTEIS:"
echo "   Ver status:      sudo systemctl status zabbix-server"
echo "   Ver logs:        sudo tail -f /var/log/zabbix/zabbix_server.log"
echo "   Reiniciar:       sudo systemctl restart zabbix-server mysql apache2"
echo ""
echo "========================================"
