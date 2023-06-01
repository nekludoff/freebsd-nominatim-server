#!/bin/sh
cd /

echo "DEFAULT_VERSIONS+=llvm=15" >> /etc/make.conf
echo "DEFAULT_VERSIONS+=ssl=openssl" >> /etc/make.conf

zfs destroy -r zroot/pgdb
zfs create -o mountpoint=/pgdb zroot/pgdb
zfs create -o mountpoint=/pgdb/data zroot/pgdb/data
cd /pgdb/data
mkdir 15
zfs set recordsize=32k zroot/pgdb/data
zfs create -o mountpoint=/pgdb/wal zroot/pgdb/wal
cd /pgdb/wal
mkdir 15
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

cd /root
git clone https://github.com/nekludoff/freebsd-osm-tile-server.git
cd freebsd-osm-tile-server/Postgresql-15

pkg install -y postgresql15-client-15.3.pkg
pkg install -y py39-psycopg-c-3.1.9.pkg
pkg install -y py39-psycopg-3.1.9.pkg
pkg install -y py39-psycopg2-2.9.6.pkg
pkg install -y py39-psycopg2cffi-2.9.0.pkg
pkg install -y postgresql15-contrib-15.3.pkg
pkg install -y sfcgal-1.4.1_4.pkg
pkg install -y gdal-3.6.4_1.pkg
pkg install -y osm2pgsql-1.8.1_2.pkg
pkg install -y postgresql15-server-15.3.pkg
pkg install -y postgis33-3.3.2_4.pkg
chown -R postgres:postgres /pgdb

sysrc postgresql_enable="YES"
cp -f postgresql /usr/local/etc/rc.d/postgresql
chmod 755 /usr/local/etc/rc.d/postgresql
/usr/local/etc/rc.d/postgresql initdb
mv -f /pgdb/data/15/pg_wal /pgdb/wal/15
ln -s /pgdb/wal/15/pg_wal /pgdb/data/15/pg_wal
cp -f pg_hba.conf /pgdb/data/15/pg_hba.conf
cp -f postgresql.conf /pgdb/data/15/postgresql.conf
service postgresql start
service postgresql restart

su - postgres -c "createuser nominatim"
su - postgres -c "psql -c 'ALTER ROLE nominatim WITH SUPERUSER;'"
su - postgres -c "createuser www-data"
su - postgres -c "dropdb nominatim"
cd /

pkg install -y nginx
pkg install -y php80 php80-bcmath php80-mbstring php80-bz2 php80-calendar php80-ctype php80-curl php80-dom php80-enchant
pkg install -y php80-exif php80-ffi php80-fileinfo php80-filter php80-ftp php80-gd php80-gettext php80-gmp php80-iconv
pkg install -y php80-intl php80-opcache php80-pcntl php80-pdo php80-pdo_sqlite php80-phar
pkg install -y php80-posix php80-pspell php80-readline php80-session php80-shmop php80-simplexml php80-sockets php80-sodium
pkg install -y php80-sqlite3 php80-sysvmsg php80-sysvsem php80-sysvshm php80-tidy php80-tokenizer php80-xml php80-xmlreader
pkg install -y php80-xmlwriter php80-xsl php80-zip php80-zlib php80-pecl-igbinary
pkg install -y autoconf

cd /usr/ports/databases/php80-pdo_pgsql
make reinstall clean
cd /usr/ports/databases/php80-pgsql
make reinstall clean
cd /

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
cmake -DBUILD_OSM2PGSQL=off /home/nominatim/Nominatim-4.2.3
gmake
gmake install
ln -s /usr/local/bin/osm2pgsql /usr/local/lib/nominatim/osm2pgsql

cd /root
git clone https://github.com/nekludoff/freebsd-nominatim-server.git
cp -r -f /root/freebsd-nominatim-server/conf/nominatim/ /usr/local/etc/nominatim/

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
chown -R nominatim:nominatim /usr/local/etc/nginx
service nginx start
service nginx restart

rm -r -f /usr/local/etc/php-fpm.d/*
cp -r -f /root/freebsd-nominatim-server/conf/php-fpm/* /usr/local/etc/php-fpm.d/
chown -R nominatim:nominatim /usr/local/etc/php-fpm
service php-fpm start
service php-fpm restart
