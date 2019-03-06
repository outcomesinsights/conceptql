#!/bin/bash

# This was built locally by running: `docker build -t conceptql .`
# In the near future this will be put on your Docker Hub account and then it
# will be pulled from there without having to build anything locally.
readonly DOCKER_CONCEPTQL_IMAGE="conceptql:latest"

# This was built with the jigsaw_test_data preparation script.
readonly DOCKER_POSTGRES_IMAGE="jigsaw_test_data:latest"

# Where should state files be written to? State files will include container
# logs and CSV files that store results about the test run.
readonly STATE_ROOT_PATH="/tmp/ci"

# Which file name should be used to store the master CSV file?
readonly STATE_CSV_FILE="ci.csv"

# Which path and branch are we working on?
#
# In development you're not meant to set these. When unset, your current
# working directory and active branch will be used, and no state files will be
# created.
#
# On your CI server, these will be automatically set by the script that checks
# for repo updates. State files will be written.
readonly REPO_PATH="${1:-$(pwd)}"
readonly BRANCH="${2:-$(git symbolic-ref --short -q HEAD)}"
readonly ARG_COUNT="${#}"

# Set up a few variables that are used to name the Docker resources.
readonly REPO="$(basename "${REPO_PATH}")"
readonly COMMIT_SHA="$(git rev-parse --short HEAD)"
readonly TIMESTAMP="$(date +"%s")"
readonly DOCKER_NAMESPACE="${REPO}-${BRANCH}-${COMMIT_SHA}-${TIMESTAMP}"

# Remove a few resources Docker will create for the test run.
ci_cleanup() {
  local postgres_cid="${1}"
  local conceptql_cid="${2}"
  local namespace="${3}"
  local exit_code="${4}"

  docker container rm -f "${postgres_cid}" >/dev/null

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

# Set up and test scripts.
SCRIPT=$(cat <<-END
bundle install --gemfile .travis.gemfile
bundle exec --gemfile .travis.gemfile ruby test/all.rb
END
)

prepare_ci_environment () {
  if [ "${ARG_COUNT}" -ne 0 ]; then
    # Move into and checkout the branch for testing. This is really only meant
    # to run if you're running this script on your CI server, not dev box.
    cd "${REPO_PATH}" || exit
    git checkout "${BRANCH}" 
    echo ""

    # Where should the state files be created? 
    mkdir -p "${STATE_ROOT_PATH}"
  fi
}

wait_for_postgres () {
  local container_id="${1}"

  while sleep 1; do
    # Wait until psql can query the database.
    docker exec "${container_id}" psql -U postgres -c "\dt;" &>/dev/null

    # PostgreSQL is ready, time to bail.
    if [ "${?}" -eq 0 ]; then
      break
    fi
  done
}

run_postgres_test () {
  local namespace="${1}"

  # Start measuring how long this test will take.
  local time_wall_clock_start_time="${SECONDS}"

  # PostgreSQL and each conceptql container will belong to its own network.
  docker network create "${namespace}" >/dev/null

  # Start PostgreSQL and wait until PostgreSQL is ready for connections.
  local postgres_cid
  postgres_cid="$(docker run -d --rm --network-alias pg \
    --network "${namespace}" "${DOCKER_POSTGRES_IMAGE}" -c fsync=off)"
  wait_for_postgres "${postgres_cid}"

  # Start measuring conceptql's test suite in seconds.
  local time_conceptql_start_time="${SECONDS}"

  # Start the conceptql container and run its test suite.
  local conceptql_cid
  conceptql_cid="$(docker run -d -v "$(pwd)":/app \
    --network "${namespace}" --env-file "${file}" \
    "${DOCKER_CONCEPTQL_IMAGE}" bash -c "${SCRIPT}")"

  # Follow the container's logs and redirect both stdout and stderr to a new
  # file. Run it in the background and only do this in a CI environment.
  if [ "${ARG_COUNT}" -ne 0 ]; then
    docker container logs -f "${conceptql_cid}" \
      &> "${STATE_ROOT_PATH}/${namespace}.json" &
  fi

  # Wait until the container's tests are finished and get the exit code of
  # the container.
  local exit_code
  exit_code="$(docker container wait "${conceptql_cid}")"

  # Stop measuring conceptql's test suite in seconds.
  local time_conceptql="$(("${SECONDS}" - "${time_conceptql_start_time}"))"

  # Stop and remove any resources created for this test.
  ci_cleanup "${postgres_cid}" "${conceptql_cid}" "${namespace}" "${exit_code}"

  # Stop measuring how long this test took.
  local time_wall_clock="$(("${SECONDS}" - "${time_wall_clock_start_time}"))"

  # Record the results of how things went.
  local now
  now="$(date "+%F %H:%M:%S")"
  local results="${now},${namespace},${exit_code},${time_conceptql},${time_wall_clock}"
  
  if [ "${ARG_COUNT}" -ne 0 ]; then
    echo "${results}" > "${STATE_ROOT_PATH}/${namespace}.csv"
  else
    echo "${results}"
  fi
}

postgres_tests () {
  local test_file
  local namespace

  for file in .ci.env.postgres*; do
    [ -f "${file}" ] || break

    test_file="$(echo "${file}" | cut -d "." -f 4)"
    namespace="${DOCKER_NAMESPACE}-${test_file}"

    echo "Running tests for ${namespace}"
    run_postgres_test "${namespace}" &
  done
}

impala_tests () {
  local test_file
  local namespace

  for file in .ci.env.impala*; do
    [ -f "${file}" ] || break

    test_file="$(echo "${file}" | cut -d "." -f 4)"
    namespace="${DOCKER_NAMESPACE}-${test_file}"
  done
}

prepare_ci_environment
postgres_tests
impala_tests

write_log_and_report_errors() {
  local namespace="${1}"
  local csv_path="${STATE_ROOT_PATH}/${STATE_CSV_FILE}"
  local csv_pattern="${STATE_ROOT_PATH}/${namespace}"

  for file in "${csv_pattern}"*.csv; do
    cat "${file}" >> "${csv_path}"

    # Determine if this test had a failing test.
    cat "${file}" | cut -d"," -f3 | grep "1" >/dev/null

    # Exit code 0 means grep found a match.
    if [ "${?}" -eq 0 ]; then
      echo "This file had a failing test (error notification):"
      echo "  ${file}"
    fi

    rm "${file}"
  done
}

check_all_log_status_codes () {
  local namespace="${1}"
  local csv_path="${STATE_ROOT_PATH}/${STATE_CSV_FILE}"
  local exit_codes

  exit_codes="$(grep "${DOCKER_NAMESPACE}" "${csv_path}" | cut -d"," -f3)"

  # Grep reports an exit code of 0 if it finds a match but in the case of this
  # function, it's more natural to return 0 if all tests pass, so we swap the
  # exit codes by negating it.
  ! echo "${exit_codes}" | grep "1" >/dev/null

  echo "${?}"
}

build_and_publish_new_conceptql_image () {
  echo "All tests have passed, building new conceptql Docker image"
  docker build -t conceptql .

  # TODO: Push this to the Docker Hub.
}

# We're in development mode, so nothing else needs to run.
if [ "${ARG_COUNT}" -eq 0 ]; then exit 0; fi

write_log_and_report_errors "${DOCKER_NAMESPACE}"
all_tests_passed="$(check_all_log_status_codes "${DOCKER_NAMESPACE}")"

if [ "${all_tests_passed}" -eq 0 ]; then
  build_and_publish_new_conceptql_image
fi

exit 0
