#!/bin/bash

# Prompt for database details
read -p "Enter the database name: " dbname
read -p "Enter the database user: " dbuser
read -sp "Enter the database password: " dbpass
echo

# Update and upgrade the system
apt update -y && apt upgrade -y

# Install necessary packages
apt install -y apache2 mariadb-server mariadb-client php php-mysql php-pear php-intl php-mbstring php-xml unzip wget

# Secure MariaDB installation
mysql_secure_installation

# Login to MariaDB and create the database and user
mysql -u root -p <<MYSQL_SCRIPT
CREATE DATABASE ${dbname};
CREATE USER '${dbuser}'@'localhost' IDENTIFIED BY '${dbpass}';
GRANT ALL PRIVILEGES ON ${dbname}.* TO '${dbuser}'@'localhost';
FLUSH PRIVILEGES;
EXIT;
MYSQL_SCRIPT

# Download and extract Roundcube
cd /var/www/html
wget https://github.com/roundcube/roundcubemail/releases/download/1.6.0/roundcubemail-1.6.0-complete.tar.gz
tar xvf roundcubemail-1.6.0-complete.tar.gz
mv roundcubemail-1.6.0 roundcube
cd roundcube
composer install --no-dev

# Set the correct permissions
chown -R www-data:www-data /var/www/html/roundcube
chmod -R 755 /var/www/html/roundcube

# Configure Roundcube
cp /var/www/html/roundcube/config/config.inc.php.sample /var/www/html/roundcube/config/config.inc.php

# Update the database configuration in Roundcube
sed -i "s/\(\$config\['db_dsnw'\] = \).*/\1'mysql:\/\/${dbuser}:${dbpass}@localhost\/${dbname}';/" /var/www/html/roundcube/config/config.inc.php

# Create a new virtual host for Roundcube
cat <<EOF > /etc/apache2/sites-available/roundcube.conf
<VirtualHost *:80>
    ServerAdmin admin@yourdomain.com
    DocumentRoot /var/www/html/roundcube/
    ServerName yourdomain.com

    <Directory /var/www/html/roundcube/>
        Options +FollowSymlinks
        AllowOverride All
        <IfModule mod_php7.c>
            php_value upload_max_filesize 10M
            php_value post_max_size 12M
            php_value memory_limit 64M
            php_value max_execution_time 3600
            php_value max_input_time 3600
        </IfModule>
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/roundcube_error.log
    CustomLog ${APACHE_LOG_DIR}/roundcube_access.log combined
</VirtualHost>
EOF

# Enable the site and necessary Apache modules
a2ensite roundcube.conf
a2enmod rewrite
systemctl restart apache2

echo "Installation and configuration of Roundcube Webmail completed!"
