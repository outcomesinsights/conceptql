#!/bin/bash

cleanup_postgres_test () {
  local namespace="${1}"
  local jigsaw_test_data_cid
  local jigsaw_lexicon_data_cid

  jigsaw_test_data_cid=$(get_cid "test_data_${namespace}")
  jigsaw_lexicon_data_cid=$(get_cid "lexicon_data_${namespace}")

  remove_cid "test_data_${namespace}"
  remove_cid "lexicon_data_${namespace}"

  docker container rm -f "${jigsaw_test_data_cid}" >/dev/null
  docker container rm -f "${jigsaw_lexicon_data_cid}" >/dev/null

}

# Remove a few resources Docker will create for the test run.
ci_cleanup() {
  local rdbms="${1}"
  local conceptql_cid="${2}"
  local namespace="${3}"
  local exit_code="${4}"

  "cleanup_${rdbms}_test" "${namespace}"

  if [ "${ARG_COUNT}" -ne 0 ]; then
    # If there's arguments, then it's a CI run, so we can safely remove the
    # container which will delete its logs but those logs have been safely
    # stored in a different location.
    docker container rm -f "${conceptql_cid}" >/dev/null
  else
    # But in development, we don't want to always remove the container's logs.
    if [ "${exit_code}" -eq 0 ]; then
      docker container rm -f "${conceptql_cid}" >/dev/null
    else
      echo ""
      echo "${namespace} had failing tests, see why by copy / pasting this:"
      echo "  docker container logs ${conceptql_cid:0:4}"
    fi
  fi

  docker network rm "${namespace}" >/dev/null
}

pull_or_build_image () {
  local image="${1}"

  if ! docker pull "${image}" &>/dev/null; then
    debug_msg "Building initial ${image} image..."

    docker build -t "${image}" .
  fi
}

prepare_ci_environment () {
  if [ -n "${ARG_REPO_PATH}" ]; then
    # Move into and checkout the branch for testing. This is really only meant
    # to run if you're running this script on your CI server, not dev box.
    cd "${REPO_PATH}" || exit
    git checkout "${BRANCH}"
    echo ""
  fi

  # Create preparation directories.
  mkdir -p "${CI_LOG_PATH}"
  mkdir -p "${CI_CID_PATH}"
}

wait_for_database () {
  local container_id="${1}"
  local container_type="${2}"
  local pg_user="${3}"

  # Wait until psql can query the database.
  while sleep 1; do
    # Make sure the container itself is capable of starting up.
    if ! docker exec "${container_id}" /bin/true; then
      echo "Jigsaw ${container_type} data container ${container_id:0:4} unexpectedly failed to start"
      echo "  docker container logs ${container_id:0:4}"
      exit 1
    fi

    debug_msg "Waiting on Jigsaw ${container_type} data container ${container_id:0:4} to be ready..."

    # Jigsaw test data is ready, time to bail.
    if docker exec "${container_id}" psql --username="${pg_user}" --dbname=postgres --command="\dt;" &>/dev/null; then
      debug_msg "Jigsaw ${container_type} data container ${container_id:0:4} is ready!"
      break
    fi
  done
}

record_cid () {
  local name="${1}"
  local cid="${2}"

  echo "${cid}" > "${CI_CID_PATH}/${name}"
}

get_cid () {
  local name="${1}"
  cat "${CI_CID_PATH}/${name}"
}

remove_cid () {
  local name="${1}"
  cat "${CI_CID_PATH}/${name}"
}

prep_postgres_test() {
  local namespace="${1}"
  local env_file="${2}"

  # Start Jigsaw test data and wait until PostgreSQL is ready for connections.
  local jigsaw_test_data_cid
  jigsaw_test_data_cid="$(docker run --detach --rm --network-alias pg \
    --network "${namespace}" "${DOCKER_JIGSAW_TEST_DATA_IMAGE}" -c fsync=off)"

  record_cid "test_data_${namespace}" "${jigsaw_test_data_cid}"

  debug_msg "Starting Jigsaw test data container ${jigsaw_test_data_cid:0:4}"

  # Start Jigsaw Lexicon data and wait until PostgreSQL is ready for connections.
  local jigsaw_lexicon_data_cid
  jigsaw_lexicon_data_cid="$(docker run \
    --detach \
    --rm \
    --env-file "${env_file}" \
    --network-alias lexicon \
    --network "${namespace}" "${DOCKER_JIGSAW_LEXICON_DATA_IMAGE}" -c fsync=off)"

  record_cid "lexicon_data_${namespace}" "${jigsaw_lexicon_data_cid}"

  debug_msg "Starting Jigsaw lexicon data container ${jigsaw_lexicon_data_cid:0:4}"

  wait_for_database "${jigsaw_test_data_cid}" "test" "postgres"
  wait_for_database "${jigsaw_lexicon_data_cid}" "lexicon" "ryan"
}

run_test () {
  local rdbms="${1}"
  local namespace="${2}"
  local env_file="${3}"
  local the_script
  local prep_script_name="${rdbms}_prep_script"
  local kdir=.ci/kerberos
  local kconf="${kdir}/krb5.conf"
  local keytab="${kdir}/test.keytab"
  local impala_prep_script

  # shellcheck disable=SC2034
  impala_prep_script=$(cat <<-END
if [ -e "${kconf}" ]; then
  cp "${kconf}" /etc/
  echo "Copied ${kconf}..."
else
  echo "No ${kconf}...skipping"
fi
if [ -e "${keytab}" ]; then
  kinit -k -t "${keytab}" "\${KERBEROS_USER}"
  klist
else
  echo "No ${keytab}...skipping"
fi
END
)

# Set up and test scripts.
the_script=$(cat <<-END
${!prep_script_name}
bundle install --gemfile .ci.Gemfile
bundle exec --gemfile .ci.Gemfile ruby test/all.rb
END
)
  debug_msg "${the_script}"

  # Start measuring how long this test will take.
  local time_wall_clock_start_time="${SECONDS}"

  # PostgreSQL and each conceptql container will belong to its own network.
  docker network create "${namespace}" >/dev/null

  debug_msg "Created network ${namespace}"

  "prep_${rdbms}_test" "${namespace}" "${env_file}"

  # Start measuring conceptql's test suite in seconds.
  local time_conceptql_start_time="${SECONDS}"

  # Start the conceptql container and run its test suite.
  local conceptql_cid
  conceptql_cid="$(docker run -d -v "$(pwd)":/app \
    --network "${namespace}" --env-file "${env_file}" \
    "${DOCKER_CONCEPTQL_IMAGE}" bash -c "${the_script}")"

  debug_msg "Running tests for conceptql container ${conceptql_cid:0:4}..."

  # Follow the container's logs and redirect both stdout and stderr to a new
  # file. Run it in the background and only do this in a CI environment.
  docker container logs -f "${conceptql_cid}" \
    &> "${CI_LOG_PATH}/${namespace}.log" &

  # Wait until the container's tests are finished and get the exit code of
  # the container.
  local exit_code
  exit_code="$(docker container wait "${conceptql_cid}")"

  # Stop measuring conceptql's test suite in seconds.
  local time_conceptql
  time_conceptql="$(echo "${SECONDS} - ${time_conceptql_start_time}" | bc)"

  # Stop and remove any resources created for this test.
  ci_cleanup "${rdbms}" "${conceptql_cid}" "${namespace}" "${exit_code}"

  # Stop measuring how long this test took.
  local time_wall_clock
  time_wall_clock="$(echo "${SECONDS} - ${time_wall_clock_start_time}" | bc)"

  # Record the results of how things went.
  local now
  now="$(date "+%F %H:%M:%S")"
  local results="${now},${exit_code},${namespace},${time_conceptql},${time_wall_clock}"

  echo "${results}" > "${CI_LOG_PATH}/${namespace}.csv"
  echo "${results}"
}

debug_msg () {
  local msg="${1}"
  if [ -n "${DEBUG}" ]; then
    echo "${msg}"
  fi
}

prep_impala_test () {
  echo
}

cleanup_impala_test () {
  echo
}

run_tests () {
  local rdbms="${1}"
  local test_file
  local namespace
  local env_files

  debug_msg "Running tests for ${rdbms}..."

  if [ -n "${EXPRS}" ]; then
    # shellcheck disable=SC2010
    env_files=$(ls -1 .ci/.ci.env."${rdbms}"* | grep -e "\(${EXPRS}\)")
  else
    env_files=$(ls -1 .ci/.ci.env."${rdbms}"*)
  fi

  debug_msg "Looking for ${env_files}"
  for env_file in ${env_files}; do
    debug_msg "Checking for ${env_file}"
    [ -f "${env_file}" ] || break

    test_file="$(echo "${env_file}" | cut -d "." -f 5)"
    namespace="${DOCKER_NAMESPACE}-${test_file}"
    echo "Running tests for ${namespace}"
    run_test "${rdbms}" "${namespace}" "${env_file}" &
  done
}

write_log_and_report_errors() {
  local namespace="${1}"
  local csv_path="${CI_LOG_PATH}/all.csv"
  local csv_pattern="${CI_LOG_PATH}/${namespace}"

  for file in "${csv_pattern}"*.csv; do
    cat "${file}" >> "${csv_path}"

    # Exit code 0 means grep found a match.
    if cut -d"," -f2 "${file}" | grep "1" >/dev/null; then
      echo "The test listed below failed, see why by copy / pasting this:"
      csv_pattern=$(cut -d"," -f3 "${file}")
      echo "  cat ${CI_LOG_PATH}/${csv_pattern}.log"
    fi

    rm "${file}"
  done
}

check_all_log_status_codes () {
  local namespace="${1}"
  local csv_path="${CI_LOG_PATH}/all.csv"
  local exit_codes

  exit_codes="$(grep "${DOCKER_NAMESPACE}" "${csv_path}" | cut -d"," -f2)"

  # Grep reports an exit code of 0 if it finds a match but in the case of this
  # function, it's more natural to return 0 if all tests pass, so we swap the
  # exit codes by negating it.
  ! echo "${exit_codes}" | grep "1" >/dev/null

  echo "${?}"
}

while (( "$#" )); do
  case "$1" in
    -e|--expr)
      EXPRS="$2|${EXPRS}"
      shift 2
      ;;
    -p|--path)
      ARG_REPO_PATH="$2"
      shift 2
      ;;
    -b|--branch)
      ARG_BRANCH="$2"
      shift 2
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    --*=|-*) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

# Which path and branch are we working on?
#
# In development you're not meant to set these. When unset, your current
# working directory and active branch will be used, and no state files will be
# created.
#
# On your CI server, these will be automatically set by the script that checks
# for repo updates. State files will be written.
readonly REPO_PATH="${ARG_REPO_PATH:-$(pwd)}"
readonly BRANCH="${ARG_BRANCH:-$(git symbolic-ref --short -q HEAD)}"
readonly ARG_COUNT="${#}"

# Set up a few variables that are used to name the Docker resources.
readonly REPO="$(basename "${REPO_PATH}")"
readonly COMMIT_SHA="$(git rev-parse --short HEAD)"
readonly TIMESTAMP="$(date "+%Y%m%d%H%M%S")"
readonly DOCKER_NAMESPACE="${REPO}-${BRANCH}-${COMMIT_SHA}-${TIMESTAMP}"

# This was built locally by running: `docker build -t conceptql .`
# In the near future this will be put on your Docker Hub account and then it
# will be pulled from there without having to build anything locally.
readonly DOCKER_CONCEPTQL_IMAGE="conceptql:latest"

# This was built with the jigsaw_test_data preparation script.
readonly DOCKER_JIGSAW_TEST_DATA_IMAGE="jigsaw_test_data:${BRANCH}.latest"

# This was built with the jigsaw_test_data preparation script.
readonly DOCKER_JIGSAW_LEXICON_DATA_IMAGE="outcomesinsights/lexicon:${BRANCH}.latest"
#readonly DOCKER_JIGSAW_LEXICON_DATA_IMAGE="lexicon:broom2.latest"

# Where should the log files be written to? This will include both container
# logs as well as the master CSV log file to track all CI runs.
readonly CI_LOG_PATH="${CI_LOG_PATH:-.ci/logs}"

# State files for container ids. They are used temporarily during the CI run.
readonly CI_CID_PATH="${CI_CID_PATH:-.ci/cids}"

if [ -n "${EXPRS}" ]; then
  EXPRS="${EXPRS%?}"
fi

# set positional arguments in their proper place
eval set -- "${PARAMS}"

prepare_ci_environment
pull_or_build_image "${DOCKER_CONCEPTQL_IMAGE}"

run_tests "postgres"
run_tests "impala"

# Wait until everything is done before finishing up.
echo "Waiting until all tests are complete before moving on..."
wait

# Log everything and finish the run.
write_log_and_report_errors "${DOCKER_NAMESPACE}"
all_tests_passed="$(check_all_log_status_codes "${DOCKER_NAMESPACE}")"

exit "${all_tests_passed}"
