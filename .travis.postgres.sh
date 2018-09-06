#!/bin/bash

set -x

echo "${SEQUELIZER_URI}" | grep -i postgres || exit 0

psql -c 'create database synpuf_250_20160815;' -U postgres
psql -c 'create schema scratch;' -U postgres -d synpuf_250_20160815
curl -sSL "http://synpuf250.omopv4_plus.data.jsaw.io" | gunzip -c | psql -U postgres -d synpuf_250_20160815 > /tmp/restore.log 2>&1 || cat /tmp/restore.log

bundle exec ruby test/all.rb
result=$?

set +x

exit ${result}
