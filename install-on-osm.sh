#!/bin/sh
cd /

echo "DEFAULT_VERSIONS+=llvm=16" >> /etc/make.conf
echo "DEFAULT_VERSIONS+=php=8.1" >> /etc/make.conf
echo "DEFAULT_VERSIONS+=ssl=openssl" >> /etc/make.conf

pkg install -y py39-pip py39-python-dotenv py39-psutil py39-Jinja2
pkg install -y libosmium icu py39-pyicu icu-le-hb harfbuzz-icu py39-pycapsicum py39-datrie libdatrie autoconf

su - postgres -c "createuser nominatim"
su - postgres -c "psql -c 'ALTER ROLE nominatim WITH SUPERUSER;'"
su - postgres -c "createuser www-data"
su - postgres -c "dropdb nominatim"

pkg install -y nginx
pkg install -y php81 php81-bcmath php81-mbstring php81-bz2 php81-calendar php81-ctype php81-curl php81-dom php81-enchant
pkg install -y php81-exif php81-ffi php81-fileinfo php81-filter php81-ftp php81-gd php81-gettext php81-gmp php81-iconv
pkg install -y php81-intl php81-opcache php81-pcntl php81-pdo php81-pdo_sqlite php81-phar
pkg install -y php81-posix php81-pspell php81-readline php81-session php81-shmop php81-simplexml php81-sockets php81-sodium
pkg install -y php81-sqlite3 php81-sysvmsg php81-sysvsem php81-sysvshm php81-tidy php81-tokenizer php81-xml php81-xmlreader
pkg install -y php81-xmlwriter php81-xsl php81-zip php81-zlib php81-pecl-igbinary
pkg install -y autoconf

pip install sqlalchemy

cd /usr/ports/databases/php81-pdo_pgsql
make reinstall clean
cd /usr/ports/databases/php81-pgsql
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
wget https://www.nominatim.org/release/Nominatim-4.3.0.tar.bz2
tar xf Nominatim-4.3.0.tar.bz2
cd Nominatim-4.3.0
rm -r -f osm2pgsql
git clone https://github.com/openstreetmap/osm2pgsql.git
wget -O data/country_osm_grid.sql.gz https://www.nominatim.org/data/country_grid.sql.gz
wget -O data/central-fed-district-latest.osm.pbf http://download.geofabrik.de/russia/central-fed-district-latest.osm.pbf
mkdir /home/nominatim/build
cd /home/nominatim/build
cmake -DBUILD_OSM2PGSQL=off /home/nominatim/Nominatim-4.3.0
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

su - nominatim -c "cd /home/nominatim/nominatim-project; nominatim import --osm-file /home/nominatim/Nominatim-4.3.0/data/central-fed-district-latest.osm.pbf 2>&1 | tee setup.log"

mkdir /var/log/nginx
chown -R nominatim:nominatim /var/log/nginx

rm -r -f /usr/local/etc/nginx/*
cp -r -f /root/freebsd-nominatim-server/conf/nginx/* /usr/local/etc/nginx
rm -r -f /usr/local/etc/nginx/conf.d/nominatim.conf
chown -R nominatim:nominatim /usr/local/etc/nginx
service nginx start
service nginx restart

rm -r -f /usr/local/etc/php-fpm.d/*
cp -r -f /root/freebsd-nominatim-server/conf/php-fpm/* /usr/local/etc/php-fpm.d/
chown -R nominatim:nominatim /usr/local/etc/php-fpm
service php-fpm start
service php-fpm restart
