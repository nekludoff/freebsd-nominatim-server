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

pkg install -y git sudo wget npm nano
pkg install -y llvm15 lua54 
pkg install -y mc nano bash apache24 boost-all cairo ceph14 cmake coreutils curl freetype2 glib gmake harfbuzz icu iniparser libjpeg-turbo libmemcached png proj python39 sqlite3 tiff webp zlib-ng bzip
pkg install -y png tiff proj icu freetype2 cairomm pkgconf libtool libltdl py39-pip py39-python-dotenv py39-psutil py39-Jinja2
pkg install -y libosmium icu py39-pyicu icu-le-hb harfbuzz-icu py39-pycapsicum py39-datrie libdatrie autoconf
ln -s /usr/local/bin/python3.9 /usr/local/bin/python
ln -s /usr/local/bin/python3.9 /usr/local/bin/python3

pip install sqlalchemy

cd /root
git clone https://github.com/nekludoff/freebsd-osm-tile-server.git
cd freebsd-osm-tile-server/Postgresql-16

pkg install -y postgresql16-client-16.0.pkg
pkg install -y py39-psycopg-c-3.1.10.pkg
pkg install -y py39-psycopg-3.1.10.pkg
pkg install -y py39-psycopg2-2.9.7.pkg
pkg install -y py39-psycopg2cffi-2.9.0.pkg
pkg install -y postgresql16-contrib-16.0.pkg
pkg install -y sfcgal-1.4.1_4.pkg
pkg install -y gdal-3.7.2.pkg
pkg install -y osm2pgsql-1.9.2.pkg
pkg install -y postgresql16-server-16.0.pkg
pkg install -y postgis33-3.3.4.pkg
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
pkg install -y php81 php81-bcmath php81-mbstring php81-bz2 php81-calendar php81-ctype php81-curl php81-dom php81-enchant
pkg install -y php81-exif php81-ffi php81-fileinfo php81-filter php81-ftp php81-gd php81-gettext php81-gmp php81-iconv
pkg install -y php81-intl php81-opcache php81-pcntl php81-pdo php81-pdo_sqlite php81-phar
pkg install -y php81-posix php81-pspell php81-readline php81-session php81-shmop php81-simplexml php81-sockets php81-sodium
pkg install -y php81-sqlite3 php81-sysvmsg php81-sysvsem php81-sysvshm php81-tidy php81-tokenizer php81-xml php81-xmlreader
pkg install -y php81-xmlwriter php81-xsl php81-zip php81-zlib php81-pecl-igbinary
pkg install -y autoconf

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
wget https://nominatim.org/release/Nominatim-4.2.3.tar.bz2
tar xf Nominatim-4.2.3.tar.bz2
cd Nominatim-4.2.3
rm -r -f osm2pgsql
git clone https://github.com/openstreetmap/osm2pgsql.git
wget -O data/country_osm_grid.sql.gz https://www.nominatim.org/data/country_grid.sql.gz
#wget -O data/central-fed-district-latest.osm.pbf http://download.geofabrik.de/russia/central-fed-district-latest.osm.pbf
wget -O data/andorra-latest.osm.pbf https://download.geofabrik.de/europe/andorra-latest.osm.pbf
mkdir /home/nominatim/build
cd /home/nominatim/build
cmake /home/nominatim/Nominatim-4.2.3
gmake
gmake install

cd /root
git clone https://github.com/nekludoff/freebsd-nominatim-server.git
cp -r -f /root/freebsd-nominatim-server/conf/nominatim/.env /usr/local/etc/nominatim/.env

mkdir /home/nominatim/flatnode
mkdir /home/nominatim/nominatim-project
cd /home/nominatim/nominatim-project
chown -R nominatim:nominatim /home/nominatim

#su - nominatim -c "cd /home/nominatim/nominatim-project; nominatim import --osm-file /home/nominatim/Nominatim-4.2.3/data/central-fed-district-latest.osm.pbf 2>&1 | tee setup.log"
su - nominatim -c "cd /home/nominatim/nominatim-project; nominatim import --osm-file /home/nominatim/Nominatim-4.2.3/data/andorra-latest.osm.pbf 2>&1 | tee setup.log"

mkdir /var/log/nginx
chown -R nominatim:nominatim /var/log/nginx

sysrc nginx_enable="YES"
sysrc php_fpm_enable="YES"

rm -r -f /usr/local/etc/nginx/*
cp -r -f /root/freebsd-nominatim-server/conf/nginx/* /usr/local/etc/nginx
rm -r -f /usr/local/etc/nginx/conf.d/nominatim-on-osm.conf
chown -R nominatim:nominatim /usr/local/etc/nginx
service nginx start
service nginx restart

rm -r -f /usr/local/etc/php-fpm.d/*
cp -r -f /root/freebsd-nominatim-server/conf/php-fpm/* /usr/local/etc/php-fpm.d/
chown -R nominatim:nominatim /usr/local/etc/php-fpm
service php-fpm start
service php-fpm restart
