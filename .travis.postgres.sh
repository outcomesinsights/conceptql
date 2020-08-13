#!/bin/bash

set -x

echo "${SEQUELIZER_URI}" | grep -i postgres || exit 0

psql -c "create database test_data_for_chisel;" -U postgres
time curl -sSL "http://chisel.test_data.jsaw.io" | pigz -dc | psql postgres://postgres@localhost/test_data_for_chisel > /tmp/restore.log 2>&1 || cat /tmp/restore.log

# Spot check OMOPv4+
#for table in person condition_occurrence procedure_occurrence observation observation period; do
#  echo "select count(1) from omopv4_plus_250.${table}"
#  echo "select count(1) from omopv4_plus_250.${table}" | psql postgres://postgres@localhost/test_data_for_jigsaw
#done

# Spot check GDM
#for table in patients clinical_codes information_periods; do
#  echo "select count(1) from gdm_250.${table}"
#  echo "select count(1) from gdm_250.${table}" | psql postgres://postgres@localhost/test_data_for_jigsaw
#done

df -h

time bundle exec ruby test/all.rb
result=$?

set +x

exit ${result}
