#!/bin/bash
if [ ! -f /var/www/html/moodle/config.php ]; then
  #mysql has to be started this way as it doesn't work to call from /etc/init.d
  /usr/bin/mysqld_safe & 
  sleep 10s
  # Here we generate random passwords (thank you pwgen!). The first two are for mysql users, the last batch for random keys in wp-config.php
  MOODLE_DB="moodle"
  MYSQL_PASSWORD=`pwgen -c -n -1 12`
  MOODLE_PASSWORD=`pwgen -c -n -1 12`
  SSH_PASSWORD=`pwgen -c -n -1 12`
  #This is so the passwords show up in logs. 
  echo mysql root password: $MYSQL_PASSWORD
  echo moodle password: $MOODLE_PASSWORD
  echo ssh root password: $SSH_PASSWORD
  echo root:$SSH_PASSWORD | chpasswd
  echo $MYSQL_PASSWORD > /mysql-root-pw.txt
  echo $MOODLE_PASSWORD > /moodle-db-pw.txt
  echo $SSH_PASSWORD > /ssh-pw.txt

  sed -e "s/pgsql/mysqli/
  s/username/moodle/
  s/password/$MOODLE_PASSWORD/
# s/example.com/$VIRTUAL_HOST/
  s/\/home\/example\/moodledata/\/var\/moodledata/" /var/www/html/moodle/config-dist.php > /var/www/html/moodle/config.php
 
  
  sed -i 's/PermitRootLogin without-password/PermitRootLogin Yes/' /etc/ssh/sshd_config

  chown www-data:www-data /var/www/html/moodle/config.php
  # add 3 DB tenants 
  mysqladmin -u root password $MYSQL_PASSWORD
  mysql -uroot -p$MYSQL_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
  mysql -uroot -p$MYSQL_PASSWORD -e "CREATE DATABASE moodle0; GRANT ALL PRIVILEGES ON moodle0.* TO 'moodle'@'localhost' IDENTIFIED BY '$MOODLE_PASSWORD'; FLUSH PRIVILEGES;"
  mysql -uroot -p$MYSQL_PASSWORD -e "CREATE DATABASE moodle1; GRANT ALL PRIVILEGES ON moodle1.* TO 'moodle'@'localhost' IDENTIFIED BY '$MOODLE_PASSWORD'; FLUSH PRIVILEGES;"
  mysql -uroot -p$MYSQL_PASSWORD -e "CREATE DATABASE moodle2; GRANT ALL PRIVILEGES ON moodle2.* TO 'moodle'@'localhost' IDENTIFIED BY '$MOODLE_PASSWORD'; FLUSH PRIVILEGES;"
  killall mysqld

  # add redis tenancy section to config.php
  sed -i 's/\$CFG->dbname/# \$CFG->dbname/' /var/www/html/moodle/config.php
  sed -i 's/\$CFG->dataroot/# \$CFG->dataroot/' /var/www/html/moodle/config.php
  sed -i 's/\$CFG->wwwroot/# \$CFG->wwwroot/' /var/www/html/moodle/config.php
  sed -i 's/require_once/# require_once/' /var/www/html/moodle/config.php

cat <<'EOF' >>/var/www/html/moodle/config.php
### TENANCY MANAGEMENT  ########################
$myhost = "";
$proxy = 'false';
foreach (getallheaders() as $name => $value) {
    if ($name == "X-Forwarded-Host") {
      $myhost = $value;
      $proxy = 'true';
    }
}
if ( $myhost == "" ) {
    foreach (getallheaders() as $name => $value) {
	if ($name == "Host") {
    	    $myhost = $value;
	}
    }
}
if($proxy=='true'){
    $CFG->reverseproxy='true';
}
### REDIS ARRAY ##################################
### 0     DB user
### 1     DB

$redis = new Redis();
$redis->connect('10.72.216.243', 6379);
$minstancearray = $redis->lGetRange($myhost,0,1);
$CFG->dbname="moodle$minstancearray[0]";
$CFG->dataroot="/var/moodledata$minstancearray[0]";
$CFG->wwwroot="http://$myhost";
require_once(dirname(__FILE__) . '/lib/setup.php');
EOF

###########################################################
### add vhosts to Apache2 sites-available 0-2

cat <<'EOF' >>/etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
 ServerName moodle0.domain.com
 DocumentRoot "/var/www/html/moodle"
</VirtualHost>
<VirtualHost *:80>
 ServerName moodle1.domain.com
 DocumentRoot "/var/www/html/moodle"
</VirtualHost>
<VirtualHost *:80>
 ServerName moodle2.domain.com
 DocumentRoot "/var/www/html/moodle"
</VirtualHost>
EOF

fi
# start all the services
/usr/local/bin/supervisord -n
