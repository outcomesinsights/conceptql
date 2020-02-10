#!/bin/bash

set -x

echo "${SEQUELIZER_URI}" | grep -i sqlite || exit 0

psql -c "create database lexicon;" -U postgres
curl -sSL "http://chisel.lexicon.jsaw.io" | pigz -dc | psql postgres://postgres@localhost/lexicon > /tmp/restore.log 2>&1 || cat /tmp/restore.log
createdb test_data_for_chisel
time curl -sSL "http://chisel.test_data.jsaw.io" | pigz -dc | psql postgres://postgres@localhost/test_data_for_chisel > /tmp/restore.log 2>&1 || cat /tmp/restore.log

df -h

time bundle exec ruby test/all.rb
result=$?

set +x

exit ${result}
