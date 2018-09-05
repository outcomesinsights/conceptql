#!/bin/bash

set -x

echo "${SEQUELIZER_URI}" | grep -i postgres || exit 0

find /var/ramfs/postgresql/9.{2,3,4,5} -maxdepth 0 -print | sudo xargs rm -rf
df -h
sudo service postgresql stop 9.6
sudo bash -c "echo \"data_directory = '/etc/postgresql/9.6/main/data'\" >> /etc/postgresql/9.6/main/postgresql.conf"
tail /etc/postgresql/9.6/main/postgresql.conf
sudo -u postgres /usr/lib/postgresql/9.6/bin/initdb /etc/postgresql/9.6/main/data
sudo service postgresql start 9.6
curl -sSL "http://test_data_for_jigsaw.jsaw.io" | pigz -dc | psql postgres://postgres@localhost/postgres > /tmp/restore.log 2>&1 || cat /tmp/restore.log
df -h

bundle exec ruby test/all.rb
result=$?

set +x

exit $?
