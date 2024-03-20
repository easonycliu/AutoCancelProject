#!/bin/bash

set -e
set -m

export AUTOCANCEL_HOME=$(git rev-parse --show-toplevel)
export MICROBENCHMARK=solr_bench
export START_TIME=$(date +%Y_%m_%d_%H_%M_%S)
export START_DATE=$(date +%Y_%m_%d)

client_num_list=(1 16 32 64 128)
test_times=10

sudo sysctl -w vm.max_map_count=262144

if [ ! -d "$AUTOCANCEL_HOME/scripts/data/solr_bench" ]; then
    mkdir $AUTOCANCEL_HOME/scripts/data/solr_bench
fi

if [ ! -d "$AUTOCANCEL_HOME/scripts/logs/$START_DATE" ]; then
    mkdir $AUTOCANCEL_HOME/scripts/logs/$START_DATE
fi

mkdir $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}

function run_once {
    USER_ID=$(id -u) GROUP_ID=$(id -g) DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 AUTOCANCEL_START=$5 \
		docker compose -f $AUTOCANCEL_HOME/scripts/microbenchmark/solr_bench/docker_config.yml down

    USER_ID=$(id -u) GROUP_ID=$(id -g) DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 AUTOCANCEL_START=$5 \
		docker compose -f $AUTOCANCEL_HOME/scripts/microbenchmark/solr_bench/docker_config.yml up &
    sleep 90

    for j in $(seq 1 1 $test_times); do
        BENCHMARK_START_TIME=$(date +%Y_%m_%d_%H_%M_%S)
		docker run --rm --net=host -v $AUTOCANCEL_HOME/scripts/data/solr_bench_home:/solr-bench/suites solr_bench_exp:v1.0

        sleep 10
    done

    USER_ID=$(id -u) GROUP_ID=$(id -g) DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 AUTOCANCEL_START=$5 \
		docker compose -f $AUTOCANCEL_HOME/scripts/microbenchmark/solr_bench/docker_config.yml down
}

run_once multi_objective_policy true false normal true
sleep 10
run_once multi_objective_policy true false normal false
sleep 10

# for client_num in ${client_num_list[*]}; do
#     run_once multi_objective_policy true false normal true $client_num
#     sleep 10
#     run_once multi_objective_policy true false normal false $client_num
#     sleep 10
# done
