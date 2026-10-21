#!/bin/sh
# Opt-in HTTP contract for Data-LoyaltyCard and Data-Profile.
#
# WARNING: reset wipes local data. POST /v1/test/reset truncates users,
# loyalty_cards, and points_transactions, including any seed data loaded
# for local development.
#
# minit-api must already be listening on 127.0.0.1:8080 with MINIT_ENV=test.
# The API process needs FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099. Start
# that process with the variable set. The API reads it and exits 1 when it
# is blank. Exporting it from this script does not apply it to an API that
# is already running. This script does not start a process on 127.0.0.1:9099
# and it does not start the API.
#
# The classes skip unless MINIT_HTTP_CONTRACT is 1. xcodebuild forwards an
# environment variable named TEST_RUNNER_MINIT_HTTP_CONTRACT to the test
# runner with the prefix removed. A build setting of that name does not.
# A normal test run does not set it.
#
# The two packages share that database, so they run one after the other.
# Parallel testing stays off so two resets cannot overlap.
#
# DESTINATION is an xcodebuild destination, for example:
#   DESTINATION='platform=iOS Simulator,id=<UDID>' scripts/run-http-contract-tests.sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
destination=${DESTINATION:-}

if [ -z "$destination" ]; then
  echo "Set DESTINATION to an iOS Simulator destination." >&2
  echo "Example: DESTINATION='platform=iOS Simulator,id=<UDID>' $0" >&2
  exit 1
fi

export TEST_RUNNER_MINIT_HTTP_CONTRACT=1

if ! curl --silent --show-error --fail --max-time 5 "http://127.0.0.1:8080/healthz" >/dev/null; then
  echo "minit-api is not healthy at http://127.0.0.1:8080/healthz." >&2
  exit 1
fi

echo "WARNING: reset wipes local data. POST /v1/test/reset truncates users, loyalty_cards, and points_transactions."

status=0

run_package() {
  package_dir=$1
  scheme=$2
  echo "HTTP contract: $scheme"
  (
    cd "$package_dir"
    perl -e 'alarm 1500; exec @ARGV' \
      xcodebuild test \
        -scheme "$scheme" \
        -destination "$destination" \
        -parallel-testing-enabled NO
  )
}

run_package "$root/Data-LoyaltyCard" Data-LoyaltyCard || status=$?
run_package "$root/Data-Profile" Data-Profile || status=$?

exit "$status"
