#!/bin/sh
cd /

echo "DEFAULT_VERSIONS+=llvm=16" >> /etc/make.conf
echo "DEFAULT_VERSIONS+=php=8.3" >> /etc/make.conf
echo "DEFAULT_VERSIONS+=ssl=openssl" >> /etc/make.conf

pkg install -y portsnap
portsnap auto
pkg install -y py311-pip py311-python-dotenv py311-psutil py311-Jinja2
pkg install -y libosmium icu py311-pyicu icu-le-hb harfbuzz-icu py311-pycapsicum py311-datrie libdatrie autoconf

su - postgres -c "createuser nominatim"
su - postgres -c "psql -c 'ALTER ROLE nominatim WITH SUPERUSER;'"
su - postgres -c "createuser www-data"
su - postgres -c "dropdb nominatim"

pkg install -y nginx
pkg install -y php83 php83-bcmath php83-mbstring php83-bz2 php83-calendar php83-ctype php83-curl php83-dom php83-enchant
pkg install -y php83-exif php83-ffi php83-fileinfo php83-filter php83-ftp php83-gd php83-gettext php83-gmp php83-iconv
pkg install -y php83-intl php83-opcache php83-pcntl php83-pdo php83-pdo_sqlite php83-phar
pkg install -y php83-posix php83-pspell php83-readline php83-session php83-shmop php83-simplexml php83-sockets php83-sodium
pkg install -y php83-sqlite3 php83-sysvmsg php83-sysvsem php83-sysvshm php83-tidy php83-tokenizer php83-xml php83-xmlreader
pkg install -y php83-xmlwriter php83-xsl php83-zip php83-zlib php83-pecl-igbinary
pkg install -y autoconf

pip install sqlalchemy

cd /usr/ports/databases/php83-pdo_pgsql
make reinstall clean
cd /usr/ports/databases/php83-pgsql
make reinstall clean
cd /

sysrc nginx_enable="YES"
service nginx start
sysrc php_fpm_enable="YES"
service php-fpm start

mkdir /home
mkdir /home/nominatim
pw groupadd nominatim
pw useradd nominatim -g nominatim -s /usr/local/bin/bash
chown -R nominatim:nominatim /home/nominatim

cd /home/nominatim
wget https://www.nominatim.org/release/Nominatim-4.5.0.tar.bz2
tar xvf Nominatim-4.5.0.tar.bz2
cd Nominatim-4.5.0
rm -r -f osm2pgsql
git clone https://github.com/openstreetmap/osm2pgsql.git
wget -O data/country_osm_grid.sql.gz https://www.nominatim.org/data/country_grid.sql.gz
wget -O data/central-fed-district-latest.osm.pbf http://download.geofabrik.de/russia/central-fed-district-latest.osm.pbf
mkdir /home/nominatim/build
cd /home/nominatim/build
cmake -DBUILD_OSM2PGSQL=off /home/nominatim/Nominatim-4.5.0
gmake
gmake install
ln -s /usr/local/bin/osm2pgsql /usr/local/lib/nominatim/osm2pgsql

cd /root
git clone https://github.com/nekludoff/freebsd-nominatim-server.git
cp -r -f /root/freebsd-nominatim-server/conf/nominatim/.env /usr/local/etc/nominatim/.env

mkdir /home/nominatim/flatnode
mkdir /home/nominatim/nominatim-project
cd /home/nominatim/nominatim-project
chown -R nominatim:nominatim /home/nominatim

su - nominatim -c "cd /home/nominatim/nominatim-project; nominatim import --osm-file /home/nominatim/Nominatim-4.5.0/data/central-fed-district-latest.osm.pbf 2>&1 | tee setup.log"

mkdir /var/log/nginx
chown -R nominatim:nominatim /var/log/nginx

rm -r -f /usr/local/etc/nginx/*
cp -r -f /root/freebsd-nominatim-server/conf/nginx/* /usr/local/etc/nginx
rm -r -f /usr/local/etc/nginx/conf.d/nominatim.conf
chown -R nominatim:nominatim /usr/local/etc/nginx
service nginx start
service nginx restart

rm -f /usr/local/etc/php.ini
cp -r -f /root/freebsd-nominatim-server/conf/php/php.ini /usr/local/etc

rm -r -f /usr/local/etc/php-fpm.d/*
cp -r -f /root/freebsd-nominatim-server/conf/php-fpm/* /usr/local/etc/php-fpm.d/
chown -R nominatim:nominatim /usr/local/etc/php-fpm
service php-fpm start
service php-fpm restart
