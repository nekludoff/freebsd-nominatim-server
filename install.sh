#!/bin/sh
cd /

echo "DEFAULT_VERSIONS+=llvm=16" >> /etc/make.conf
echo "DEFAULT_VERSIONS+=ssl=openssl" >> /etc/make.conf

zfs destroy -r zroot/pgdb
zfs create -o mountpoint=/pgdb zroot/pgdb
zfs create -o mountpoint=/pgdb/data zroot/pgdb/data
cd /pgdb/data
mkdir 16
zfs set recordsize=32k zroot/pgdb/data
zfs create -o mountpoint=/pgdb/wal zroot/pgdb/wal
cd /pgdb/wal
mkdir 16
zfs set recordsize=64k zroot/pgdb/wal
zfs set compression=lz4 zroot/pgdb
zfs set atime=off zroot/pgdb
zfs set xattr=sa zroot/pgdb
zfs set logbias=latency zroot/pgdb
zfs set redundant_metadata=most zroot/pgdb

pkg install -y portsnap
portsnap auto
pkg install -y git sudo wget npm nano
pkg install -y llvm16 lua54 
pkg install -y mc nano bash apache24 boost-all cairo ceph14 cmake coreutils curl freetype2 glib gmake harfbuzz icu iniparser libjpeg-turbo libmemcached png proj python39 sqlite3 tiff webp zlib-ng bzip
pkg install -y png tiff proj icu freetype2 cairomm pkgconf libtool libltdl py39-pip py39-python-dotenv py39-psutil py39-Jinja2
pkg install -y libosmium icu py39-pyicu icu-le-hb harfbuzz-icu py39-pycapsicum py39-datrie libdatrie autoconf

ln -s /usr/local/bin/python3.9 /usr/local/bin/python
ln -s /usr/local/bin/python3.9 /usr/local/bin/python3

pip install sqlalchemy

cd /root
git clone https://github.com/nekludoff/freebsd-osm-tile-server.git
cd freebsd-osm-tile-server/Postgresql-16

pkg install -y postgresql16-client-16.3.pkg
pkg install -y py39-psycopg-c-3.1.19.pkg
pkg install -y py39-psycopg-3.1.19.pkg
pkg install -y py39-psycopg2-2.9.9_1.pkg
pkg install -y py39-psycopg2cffi-2.9.0.pkg
pkg install -y postgresql16-contrib-16.3.pkg
pkg install -y sfcgal-1.5.1_1.pkg
pkg install -y gdal-3.9.0.pkg
pkg install -y osm2pgsql-1.11.0_1.pkg
pkg install -y postgresql16-server-16.3.pkg
pkg install -y postgis34-3.4.2_4.pkg
chown -R postgres:postgres /pgdb

sysrc postgresql_enable="YES"
cp -f postgresql /usr/local/etc/rc.d/postgresql
chmod 755 /usr/local/etc/rc.d/postgresql
/usr/local/etc/rc.d/postgresql initdb
mv -f /pgdb/data/16/pg_wal /pgdb/wal/16
ln -s /pgdb/wal/16/pg_wal /pgdb/data/16/pg_wal
cp -f pg_hba.conf /pgdb/data/16/pg_hba.conf
cp -f postgresql.conf /pgdb/data/16/postgresql.conf
service postgresql start
service postgresql restart

su - postgres -c "createuser nominatim"
su - postgres -c "psql -c 'ALTER ROLE nominatim WITH SUPERUSER;'"
su - postgres -c "createuser www-data"
su - postgres -c "dropdb nominatim"
cd /

pkg install -y nginx
pkg install -y php83 php83-bcmath php83-mbstring php83-bz2 php83-calendar php83-ctype php83-curl php83-dom php83-enchant
pkg install -y php83-exif php83-ffi php83-fileinfo php83-filter php83-ftp php83-gd php83-gettext php83-gmp php83-iconv
pkg install -y php83-intl php83-opcache php83-pcntl php83-pdo php83-pdo_sqlite php83-phar
pkg install -y php83-posix php83-pspell php83-readline php83-session php83-shmop php83-simplexml php83-sockets php83-sodium
pkg install -y php83-sqlite3 php83-sysvmsg php83-sysvsem php83-sysvshm php83-tidy php83-tokenizer php83-xml php83-xmlreader
pkg install -y php83-xmlwriter php83-xsl php83-zip php83-zlib php83-pecl-igbinary
pkg install -y autoconf

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
wget https://www.nominatim.org/release/Nominatim-4.4.0.tar.bz2
tar xvf Nominatim-4.4.0.tar.bz2
cd Nominatim-4.4.0
rm -r -f osm2pgsql
git clone https://github.com/openstreetmap/osm2pgsql.git
wget -O data/country_osm_grid.sql.gz https://www.nominatim.org/data/country_grid.sql.gz
wget -O data/central-fed-district-latest.osm.pbf http://download.geofabrik.de/russia/central-fed-district-latest.osm.pbf
mkdir /home/nominatim/build
cd /home/nominatim/build
cmake -DBUILD_OSM2PGSQL=off /home/nominatim/Nominatim-4.4.0
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

su - nominatim -c "cd /home/nominatim/nominatim-project; nominatim import --osm-file /home/nominatim/Nominatim-4.4.0/data/central-fed-district-latest.osm.pbf 2>&1 | tee setup.log"

mkdir /var/log/nginx
chown -R nominatim:nominatim /var/log/nginx

rm -r -f /usr/local/etc/nginx/*
cp -r -f /root/freebsd-nominatim-server/conf/nginx/* /usr/local/etc/nginx
rm -r -f /usr/local/etc/nginx/conf.d/nominatim.conf
chown -R nominatim:nominatim /usr/local/etc/nginx
service nginx start
service nginx restart

cp -r -f /root/freebsd-nominatim-server/conf/php/php.ini /usr/local/etc

rm -r -f /usr/local/etc/php-fpm.d/*
cp -r -f /root/freebsd-nominatim-server/conf/php-fpm/* /usr/local/etc/php-fpm.d/
chown -R nominatim:nominatim /usr/local/etc/php-fpm
service php-fpm start
service php-fpm restart
