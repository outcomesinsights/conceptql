#!/bin/bash

set -x

echo "${SEQUELIZER_URI}" | grep -i postgres || exit 0

curl -sSL "http://test_data_for_jigsaw.jsaw.io" | pigz -dc | psql postgres://postgres@localhost/postgres > /tmp/restore.log 2>&1 || cat /tmp/restore.log

bundle exec ruby test/all.rb
result=$?

set +x

exit ${result}
