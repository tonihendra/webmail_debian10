#!/bin/bash
# Welcome message
echo "+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+"
echo "TKJ Manusa The First and the future of Technology"
echo "+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+"
# Memastikan script dijalankan sebagai root
if [ "$(id -u)" != "0" ]; then
   echo "Script ini harus dijalankan sebagai root" 1>&2
   exit 1
fi

# Meminta inputan dari pengguna
read -p "Masukkan nama domain/IP Lokal (misalnya: contoh.com): " DOMAIN
read -p "Masukkan password untuk database MySQL (root): " MYSQL_ROOT_PASSWORD
read -p "Masukkan nama database untuk Roundcube: " ROUNDCUBE_DB
read -p "Masukkan username database untuk Roundcube: " ROUNDCUBE_USER
read -p "Masukkan password untuk pengguna database Roundcube: " ROUNDCUBE_PASSWORD

# Memperbarui dan menginstal paket yang diperlukan
apt update
apt upgrade -y
apt install -y apache2 mariadb-server mariadb-client php php-mysql php-intl php-mbstring php-xml php-common php-curl php-zip php-pear php-net-socket php-imap wget unzip

# Mengonfigurasi MariaDB
mysql -u root -p$MYSQL_ROOT_PASSWORD <<EOF
CREATE DATABASE $ROUNDCUBE_DB;
CREATE USER '$ROUNDCUBE_USER'@'localhost' IDENTIFIED BY '$ROUNDCUBE_PASSWORD';
GRANT ALL PRIVILEGES ON $ROUNDCUBE_DB.* TO '$ROUNDCUBE_USER'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

# Mengunduh dan memasang Roundcube
cd /var/www/html
wget https://github.com/roundcube/roundcubemail/releases/download/1.6.0/roundcubemail-1.6.0-complete.tar.gz
tar -xzf roundcubemail-1.6.0-complete.tar.gz
mv roundcubemail-1.6.0 roundcube
chown -R www-data:www-data /var/www/html/roundcube
chmod -R 755 /var/www/html/roundcube

# Konfigurasi Apache untuk Roundcube
cat > /etc/apache2/sites-available/roundcube.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot /var/www/html/roundcube

    <Directory /var/www/html/roundcube/>
        Options +FollowSymLinks
        AllowOverride All
        <IfModule mod_dav.c>
            Dav off
        </IfModule>
        SetEnv HOME /var/www/html/roundcube
        SetEnv HTTP_HOME /var/www/html/roundcube
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/roundcube_error.log
    CustomLog ${APACHE_LOG_DIR}/roundcube_access.log combined

</VirtualHost>
EOF

# Mengaktifkan situs dan modifikasi Apache
a2ensite roundcube.conf
a2enmod rewrite
systemctl restart apache2

# Menyelesaikan pengaturan Roundcube
cd /var/www/html/roundcube
cp config/config.inc.php.sample config/config.inc.php

# Menambahkan konfigurasi database ke config.inc.php
sed -i "s#'sql' => '',#'sql' => 'mysql://$ROUNDCUBE_USER:$ROUNDCUBE_PASSWORD@localhost/$ROUNDCUBE_DB',#" config/config.inc.php

# Menyelesaikan instalasi Roundcube melalui CLI
php ./bin/installto.sh /var/www/html/roundcube

echo "Instalasi dan konfigurasi Roundcube selesai."
echo "Silakan akses Webmail di http://$DOMAIN/roundcube"
