#!/bin/bash

######### SETUP POSTGRES
cp /var/lib/postgresql/10/main/postgresql.auto.conf /var/lib/postgresql/10/main/postgresql.conf
echo "local all all trust
host all all ::1/128 trust
host all all 127.0.0.1/32 trust" >> /var/lib/postgresql/10/main/pg_hba.conf
echo "listen_addresses='*'" >> /var/lib/postgresql/10/main/postgresql.conf
chown postgres:postgres /var/lib/postgresql/10/main/postgresql.conf
su postgres -c "/usr/lib/postgresql/10/bin/pg_ctl -D /var/lib/postgresql/10/main -l /tmp/pg_log start" &
sleep 2
cat /tmp/pg_log

psql -h localhost -U postgres postgres < schema.sql

cd /usr/src/postgraphile
export PORT=3000
exec node main.js
