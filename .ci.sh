#!/bin/bash

# This was built locally by running: `docker build -t conceptql .`
# In the near future this will be put on your Docker Hub account and then it
# will be pulled from there without having to build anything locally.
readonly DOCKER_CONCEPTQL_IMAGE="conceptql:latest"

# This was built with the jigsaw_test_data preparation script.
readonly DOCKER_POSTGRES_IMAGE="jigsaw_test_data:latest"

# Where should state files be written to? State files will include container
# logs and CSV files that store results about the test run.
readonly STATE_ROOT_PATH="${STATE_ROOT_PATH:-./.ci}"

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
readonly TIMESTAMP="$(date "+%Y%m%d%H%M%S")"
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

pull_or_build_image () {
  local image="${1}"

  if docker pull "${image}" &>/dev/null; then
    if ! docker image ls | grep "${image}" /dev/null; then
      docker build -t "${image}" .
    fi
  fi
}

prepare_ci_environment () {
  if [ "${ARG_COUNT}" -ne 0 ]; then
    # Move into and checkout the branch for testing. This is really only meant
    # to run if you're running this script on your CI server, not dev box.
    cd "${REPO_PATH}" || exit
    git checkout "${BRANCH}" 
    echo ""
  fi

  # Create state directory and supporting directories.
  mkdir -p "${STATE_ROOT_PATH}"
  mkdir -p "${STATE_ROOT_PATH}/logs"
}

wait_for_postgres () {
  local container_id="${1}"

  # Wait until psql can query the database.
  while sleep 1; do
    # Make sure the container itself is capable of starting up.
    if ! docker exec "${container_id}" /bin/true; then
      echo "PostgreSQL container ${container_id:0:4} unexpectedly failed to start"
      echo "  docker container logs ${container_id:0:4}"
      exit 1
    fi

    if [ -n "${DEBUG}" ]; then
      echo "Waiting on PostgreSQL container ${container_id:0:4} to be ready..."
    fi

    # PostgreSQL is ready, time to bail.
    if docker exec "${container_id}" psql -U postgres -c "\dt;" &>/dev/null; then
      if [ -n "${DEBUG}" ]; then
        echo "PostgreSQL container ${container_id:0:4} is ready!"
      fi
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

  if [ -n "${DEBUG}" ]; then
    echo "Created network ${namespace}"
  fi

  # Start PostgreSQL and wait until PostgreSQL is ready for connections.
  local postgres_cid
  postgres_cid="$(docker run -d --rm --network-alias pg \
    --network "${namespace}" "${DOCKER_POSTGRES_IMAGE}" -c fsync=off)"

  if [ -n "${DEBUG}" ]; then
    echo "Starting PostgreSQL container ${postgres_cid:0:4}"
  fi

  wait_for_postgres "${postgres_cid}"

  # Start measuring conceptql's test suite in seconds.
  local time_conceptql_start_time="${SECONDS}"

  # Start the conceptql container and run its test suite.
  local conceptql_cid
  conceptql_cid="$(docker run -d -v "$(pwd)":/app \
    --network "${namespace}" --env-file "${file}" \
    "${DOCKER_CONCEPTQL_IMAGE}" bash -c "${SCRIPT}")"

  if [ -n "${DEBUG}" ]; then
    echo "Running tests for conceptql container ${conceptql_cid:0:4}..."
  fi

  # Follow the container's logs and redirect both stdout and stderr to a new
  # file. Run it in the background and only do this in a CI environment.
  docker container logs -f "${conceptql_cid}" \
    &> "${STATE_ROOT_PATH}/logs/${namespace}.log" &

  # Wait until the container's tests are finished and get the exit code of
  # the container.
  local exit_code
  exit_code="$(docker container wait "${conceptql_cid}")"

  # Stop measuring conceptql's test suite in seconds.
  local time_conceptql
  time_conceptql="$(echo "${SECONDS} - ${time_conceptql_start_time}" | bc)"

  # Stop and remove any resources created for this test.
  ci_cleanup "${postgres_cid}" "${conceptql_cid}" "${namespace}" "${exit_code}"

  # Stop measuring how long this test took.
  local time_wall_clock
  time_wall_clock="$(echo "${SECONDS} - ${time_wall_clock_start_time}" | bc)"

  # Record the results of how things went.
  local now
  now="$(date "+%F %H:%M:%S")"
  local results="${now},${exit_code},${namespace},${time_conceptql},${time_wall_clock}"

  echo "${results}" > "${STATE_ROOT_PATH}/logs/${namespace}.csv"
  echo "${results}"
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
pull_or_build_image "${DOCKER_CONCEPTQL_IMAGE}"

postgres_tests
impala_tests

write_log_and_report_errors() {
  local namespace="${1}"
  local csv_path="${STATE_ROOT_PATH}/logs/${STATE_CSV_FILE}"
  local csv_pattern="${STATE_ROOT_PATH}/logs/${namespace}"

  for file in "${csv_pattern}"*.csv; do
    cat "${file}" >> "${csv_path}"

    # Determine if this test had a failing test.
    cat "${file}" | cut -d"," -f2 | grep "1" >/dev/null

    # Exit code 0 means grep found a match.
    if [ "${?}" -eq 0 ]; then
      echo "The test listed below failed, see why by copy / pasting this:"
      echo "  cat ${file}"
    fi

    rm "${file}"
  done
}

check_all_log_status_codes () {
  local namespace="${1}"
  local csv_path="${STATE_ROOT_PATH}/logs/${STATE_CSV_FILE}"
  local exit_codes

  exit_codes="$(grep "${DOCKER_NAMESPACE}" "${csv_path}" | cut -d"," -f2)"

  # Grep reports an exit code of 0 if it finds a match but in the case of this
  # function, it's more natural to return 0 if all tests pass, so we swap the
  # exit codes by negating it.
  ! echo "${exit_codes}" | grep "1" >/dev/null

  echo "${?}"
}

# Wait until everything is done before finishing up.
echo "Waiting until all tests are complete before moving on..."
wait

# Log everything and finish the run.
write_log_and_report_errors "${DOCKER_NAMESPACE}"
all_tests_passed="$(check_all_log_status_codes "${DOCKER_NAMESPACE}")"

exit "${all_tests_passed}"
