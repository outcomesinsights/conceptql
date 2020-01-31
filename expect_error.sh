
for old_name in ${*}; do
  old_statement_name="test/statements/${old_name}"
  old_result_name="test/results/gdm/${old_name}"
  new_name="${old_name/.json/_expect_sql_error.json}"
  new_statement_name="test/statements/${new_name}"
  new_result_name="test/results/gdm/${new_name}"

  set -x
  git mv "${old_statement_name}" "${new_statement_name}"
  git mv "${old_result_name}" "${new_result_name}"
  set +x
done
