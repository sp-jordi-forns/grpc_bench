#!/bin/bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

## The list of benchmarks to run
BENCHMARKS_TO_RUN="${@}"
##  ...or use all the *_bench dirs by default
BENCHMARKS_TO_RUN="${BENCHMARKS_TO_RUN:-$(find . -maxdepth 1 -name '*_bench' -type d | sort)}"

RESULTS_DIR="results/$(date '+%y%m%dT%H%M%S')"
export GRPC_BENCHMARK_DURATION=${GRPC_BENCHMARK_DURATION:-"20s"}
export GRPC_BENCHMARK_WARMUP=${GRPC_BENCHMARK_WARMUP:-"5s"}
export GRPC_CLIENT_CONNECTIONS=${GRPC_CLIENT_CONNECTIONS:-"50"}
export GRPC_CLIENT_CONCURRENCY=${GRPC_CLIENT_CONCURRENCY:-"1000"}
export GRPC_CLIENT_QPS=${GRPC_CLIENT_QPS:-"0"}
export GRPC_CLIENT_QPS=$(( GRPC_CLIENT_QPS / GRPC_CLIENT_CONCURRENCY ))
export GRPC_CLIENT_CPUS=${GRPC_CLIENT_CPUS:-"1"}
export GRPC_REQUEST_SCENARIO=${GRPC_REQUEST_SCENARIO:-"complex_proto"}
export GRPC_SERVER_ENDPOINT=${GRPC_SERVER_ENDPOINT:-"localhost"}
export GRPC_SERVER_PORT=${GRPC_SERVER_PORT:-"8889"}

# Let containers know how many CPUs they will be running on
# Additionally export other vars for further analysis script.
# export GRPC_SERVER_CPUS
# export GRPC_CLIENT_CPUS
# export GRPC_BENCHMARK_DURATION
# export GRPC_BENCHMARK_WARMUP
# export GRPC_CLIENT_CONNECTIONS
# export GRPC_CLIENT_CONCURRENCY
# export GRPC_CLIENT_QPS

# Loop over benchs
for benchmark in ${BENCHMARKS_TO_RUN}; do
	NAME="${benchmark##*/}"
	echo "==> Running benchmark for ${NAME}..."

	mkdir -p "${RESULTS_DIR}"

	# Setup the chosen scenario
#    if ! sh setup_scenario.sh $GRPC_REQUEST_SCENARIO true; then
#  		echo "Scenario setup fiascoed."
#  		exit 1
#	fi

  # Login
  echo -n "Logging in... "
  SESSION_ID=$(grpcurl -allow-unknown-fields -plaintext -protoset ~/Dev/emerald-sparta-protobuf/emeraldsparta.protoset -d @ <<< '
  {
    "user_id": "131313",
    "security_token": "12311111111111111",
    "link_type": 0,
    "client_app_id": "8775b657-30ab-4151-ba14-165591546c55",
    "client_version": "2.1.0",
    "client_build": "1",
    "client_language": "es",
    "platform": "ios",
    "device": "Hello",
    "device_uid": "5155a6e5-2a0a-4a30-92e6-dfcfab030d1a",
    "device_os": "Hello",
    "device_language": "Hello",
    "device_ad_id": "48bb5fe1-9bab-405a-9bbb-5b49636472d0",
    "device_ad_id_enabled": true,
    "device_rooted": true,
    "device_vendor_id": "108b89c1-c9ea-4ba2-b242-e2a7e33b3883",
    "network_connection": "Hello",
    "marketing_ids": {
      "appsflyer": "Hello"
    }
  }' "${GRPC_SERVER_ENDPOINT}:${GRPC_SERVER_PORT}" sp.rpc.emerald.UserService/Login| jq '.genericData.user.sessionId' -r)
  echo "🎉 got sessionId ID: ${SESSION_ID}"

	# Warm up the service
    if [[ "${GRPC_BENCHMARK_WARMUP}" != "0s" ]]; then
      echo -n "Warming up the service for ${GRPC_BENCHMARK_WARMUP}... "
    	ghz \
    		--cpus $GRPC_CLIENT_CPUS \
        --protoset=/Users/jordiforns/Dev/emerald-sparta-protobuf/emeraldsparta.protoset \
        --call=sp.rpc.usersync.UserSyncService/SyncUserState \
        --disable-template-functions \
        --disable-template-data \
        --insecure \
        --concurrency="${GRPC_CLIENT_CONCURRENCY}" \
        --connections="${GRPC_CLIENT_CONNECTIONS}" \
        --rps="${GRPC_CLIENT_QPS}" \
        --duration="${GRPC_BENCHMARK_WARMUP}" \
        --data-file="${PWD}/scenarios/${NAME}/data.json" \
        --metadata="{\"x-user-id\": \"131313\", \"x-session-id\": \"${SESSION_ID}\"}" \
    		"${GRPC_SERVER_ENDPOINT}:${GRPC_SERVER_PORT}" > /dev/null

    	echo "done."
    else
        echo "gRPC Server Warmup skipped."
    fi

	# Actual benchmark
	echo -n "Benchmarking now... "

	# Start collecting stats
	#./collect_stats.sh "${NAME}" "${RESULTS_DIR}" &

	# Start the gRPC Client
  ghz \
    --cpus $GRPC_CLIENT_CPUS \
    --protoset=/Users/jordiforns/Dev/emerald-sparta-protobuf/emeraldsparta.protoset \
    --call=sp.rpc.usersync.UserSyncService/SyncUserState \
    --disable-template-functions \
    --disable-template-data \
    --insecure \
    --concurrency="${GRPC_CLIENT_CONCURRENCY}" \
    --connections="${GRPC_CLIENT_CONNECTIONS}" \
    --rps="${GRPC_CLIENT_QPS}" \
    --duration="${GRPC_BENCHMARK_DURATION}" \
    --data-file="${PWD}/scenarios/${NAME}/data.json" \
    --metadata="{\"x-user-id\": \"131313\", \"x-session-id\": \"${SESSION_ID}\"}" \
    "${GRPC_SERVER_ENDPOINT}:${GRPC_SERVER_PORT}" > "${RESULTS_DIR}/${NAME}".report

	# Show quick summary (reqs/sec)
#	cat << EOF
#		done.
#		Results:
#		$(cat "${RESULTS_DIR}/${NAME}".report | grep "Requests/sec" | sed -E 's/^ +/    /')
#EOF
  echo "🤩 done!"

  cat "${RESULTS_DIR}/${NAME}".report

#	kill -INT %1 2>/dev/null
done

#if sh analyze.sh $RESULTS_DIR; then
#  cat ${RESULTS_DIR}/bench.params
#  echo "All done."
#else
#  echo "Analysis fiascoed."
#  ls -lha $RESULTS_DIR
#  for f in $RESULTS_DIR/*; do
#  	echo
#  	echo
#  	echo "$f"
#	  cat "$f"
#  done
#  exit 1
#fi
