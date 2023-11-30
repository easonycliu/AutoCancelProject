#!/bin/bash

set -e
set -m

export AUTOCANCEL_HOME=$(git rev-parse --show-toplevel)
export MICROBENCHMARK=abnormal_sensitivity
export START_TIME=$(date +%Y_%m_%d_%H_%M_%S)
export START_DATE=$(date +%Y_%m_%d)

client_num=5

sudo sysctl -w vm.max_map_count=262144

if [ ! -d "$AUTOCANCEL_HOME/scripts/logs/$START_DATE" ]; then
    sudo mkdir $AUTOCANCEL_HOME/scripts/logs/$START_DATE
fi

sudo mkdir $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}
sudo chown -R 1000:1000 $AUTOCANCEL_HOME/scripts/logs

if [ ! -f "$AUTOCANCEL_HOME/autocancel_exp/elasticsearch_exp/query/boolean_search.json" ]; then
    docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/elasticsearch_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/performance_issues/complex_boolean_operations.py 2000 boolean_search.json
fi

function run_once {
    DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 ABNORMAL_PORTION=$5 ABNORMAL_ABSOLUTE=$6 docker compose -f $AUTOCANCEL_HOME/scripts/microbenchmark/abnormal_sensitivity/docker_config.yml down

    DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 ABNORMAL_PORTION=$5 ABNORMAL_ABSOLUTE=$6 docker compose -f $AUTOCANCEL_HOME/scripts/microbenchmark/abnormal_sensitivity/docker_config.yml up &
    sleep 60

    docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/elasticsearch_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/warmup.sh
    sleep 10

    docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/elasticsearch_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/multiclient_complex_boolean.sh $7 ${4}_${START_TIME} $4
    sleep 10

    sudo mv $AUTOCANCEL_HOME/autocancel_exp/elasticsearch_exp/${4}_${START_TIME}_latency $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${CASE}_${START_TIME}/${4}_latency.csv
    sudo mv $AUTOCANCEL_HOME/autocancel_exp/elasticsearch_exp/${4}_${START_TIME}_throughput $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${CASE}_${START_TIME}/${4}_throughput.csv

    sudo mv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${4}.csv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${4}_${5}_${6}.csv
    sudo mv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${4}_latency.csv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${4}_${5}_${6}_latency.csv

    DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 ABNORMAL_PORTION=$5 ABNORMAL_ABSOLUTE=$6 docker compose -f $AUTOCANCEL_HOME/scripts/microbenchmark/abnormal_sensitivity/docker_config.yml down
}

run_once multi_objective_policy true false normal 0.25 100 $client_num
sleep 10
run_once multi_objective_policy true false normal 0.5 200 $client_num
sleep 10
run_once multi_objective_policy true false normal 0.75 300 $client_num
sleep 10
run_once multi_objective_policy true false normal 0.9 360 $client_num
sleep 10