#!/usr/bin/env bash

db_root_pass="password"
db_radius_pass="radiuspassword"

yum install -y epel-release wget unzip yum-utils

cat <<< '
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.5/centos7-amd64/
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1 ' > /etc/yum.repos.d/mariadb.repo

yum makecache fast
yum install -y mariadb-server MariaDB-client nano unzip http://rpms.remirepo.net/enterprise/remi-release-7.rpm
yum-config-manager --enable remi-php73
yum install -y php php-common php-opcache php-mcrypt php-cli php-gd php-curl php-mysqlnd php-pear php-pear-DB
yum install -y httpd
yum install -y freeradius freeradius-utils freeradius-mysql freeradius-perl

systemctl start mariadb
systemctl enable mariadb

mysql_secure_installation <<EOF

y
$db_root_pass
$db_root_pass
y
y
y
y
EOF

cat > create_radius_user.sql << EOF
CREATE DATABASE radius;
GRANT ALL ON radius.* TO radius@localhost IDENTIFIED BY "$db_radius_pass";
FLUSH PRIVILEGES;
EOF

mysql -uroot -p${db_root_pass} < create_radius_user.sql

mysql -u root -p${db_root_pass} radius < /etc/raddb/mods-config/sql/main/mysql/schema.sql

ln -s /etc/raddb/mods-available/sql /etc/raddb/mods-enabled/sql

cat > /etc/raddb/mods-available/sql << EOF
sql {
driver = "rlm_sql_mysql"
dialect = "mysql"
# Connection info:
server = "localhost"
port = 3306
login = "radius"
password = "${db_radius_pass}"
# Database table configuration
radius_db = "radius"
}
read_clients = yes
client_table = "nas"
EOF

cat <<< '
client localhost {
    ipaddr = 127.0.0.1
    secret = testing123
    require_message_authenticator = no
    shortname = localhost
    nas_type = other
} ' > /etc/raddb/clients.conf

wget https://github.com/lirantal/daloradius/archive/master.zip
unzip master.zip
mv daloradius-master/ daloradius
cd daloradius

mysql -u root -p${db_root_pass} radius < contrib/db/fr2-mysql-daloradius-and-freeradius.sql
mysql -u root -p${db_root_pass} radius < contrib/db/mysql-daloradius.sql

# Update table radacct for radius3. Because original template for daloradius freeradius2.
cat > radacct.sql << EOF
DROP TABLE radacct;
CREATE TABLE radacct (
radacctid bigint(21) NOT NULL auto_increment,
acctsessionid varchar(64) NOT NULL default '',
acctuniqueid varchar(32) NOT NULL default '',
username varchar(64) NOT NULL default '',
groupname varchar(64) NOT NULL default '',
realm varchar(64) default '',
nasipaddress varchar(15) NOT NULL default '',
nasportid varchar(15) default NULL,
nasporttype varchar(32) default NULL,
acctstarttime datetime NULL default NULL,
acctupdatetime datetime NULL default NULL,
acctstoptime datetime NULL default NULL,
acctinterval int(12) default NULL,
acctsessiontime int(12) unsigned default NULL,
acctauthentic varchar(32) default NULL,
connectinfo_start varchar(50) default NULL,
connectinfo_stop varchar(50) default NULL,
acctinputoctets bigint(20) default NULL,
acctoutputoctets bigint(20) default NULL,
calledstationid varchar(50) NOT NULL default '',
callingstationid varchar(50) NOT NULL default '',
acctterminatecause varchar(32) NOT NULL default '',
servicetype varchar(32) default NULL,
framedprotocol varchar(32) default NULL,
framedipaddress varchar(15) NOT NULL default '',
PRIMARY KEY (radacctid),
UNIQUE KEY acctuniqueid (acctuniqueid),
KEY username (username),
KEY framedipaddress (framedipaddress),
KEY acctsessionid (acctsessionid),
KEY acctsessiontime (acctsessiontime),
KEY acctstarttime (acctstarttime),
KEY acctinterval (acctinterval),
KEY acctstoptime (acctstoptime),
KEY nasipaddress (nasipaddress)
) ENGINE = INNODB;
EOF

mysql -u root -p${db_root_pass} radius < radacct.sql

cd ..
mv daloradius /var/www/html/

chown -R apache:apache /var/www/html/daloradius/
chmod 664 /var/www/html/daloradius/library/daloradius.conf.php
restorecon -R /var/www/html/daloradius/

# nano /var/www/html/daloradius/library/daloradius.conf.php
# $configValues['CONFIG_DB_USER'] = 'radius';
# $configValues['CONFIG_DB_PASS'] = 'radiuspassword';
# $configValues['CONFIG_DB_NAME'] = 'radius';

# Replace configuration daloradius.conf.php
# Replace 'root' to 'radius' in string "$configValues['CONFIG_DB_USER'] = 'root';"
sed -i "/CONFIG_DB_USER/ s/'root'/'radius'/" /var/www/html/daloradius/library/daloradius.conf.php
sed -i "/CONFIG_DB_PASS/ s/''/'${db_radius_pass}'/" /var/www/html/daloradius/library/daloradius.conf.php

systemctl start radiusd.service
systemctl restart mariadb.service
systemctl restart httpd
systemctl enable radiusd.service
systemctl enable mariadb.service
systemctl enable httpd

# http://localhost/daloradius/login.php
# default username and password of dolaRadius is:
# Username: administrator
# Password: radius

