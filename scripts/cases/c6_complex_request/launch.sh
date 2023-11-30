#!/bin/bash

set -e
set -m

export AUTOCANCEL_HOME=$(git rev-parse --show-toplevel)
export CASE=c6
export START_TIME=$(date +%Y_%m_%d_%H_%M_%S)
export START_DATE=$(date +%Y_%m_%d)

client_num=2

sudo sysctl -w vm.max_map_count=262144

if [ ! -d "$AUTOCANCEL_HOME/scripts/logs/$START_DATE" ]; then
    sudo mkdir $AUTOCANCEL_HOME/scripts/logs/$START_DATE
fi

sudo mkdir $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${CASE}_${START_TIME}
sudo chown -R 8983:8983 $AUTOCANCEL_HOME/scripts/logs

if [ ! -f "$AUTOCANCEL_HOME/autocancel_exp/solr_exp/query/boolean_search_1.json" ]; then
    docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/solr_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/performance_issues/complex_boolean_operations.py 80000 boolean_search_1.json
fi
if [ ! -f "$AUTOCANCEL_HOME/autocancel_exp/solr_exp/query/boolean_search_2.json" ]; then
    docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/solr_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/performance_issues/complex_boolean_operations.py 50000 boolean_search_2.json
fi

function run_once {
    DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 docker compose -f $AUTOCANCEL_HOME/scripts/cases/c6_complex_request/docker_config.yml down

    docker stop single_node || true
    docker rm single_node || true

    DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 docker compose -f $AUTOCANCEL_HOME/scripts/cases/c6_complex_request/docker_config.yml up &
    sleep 60

    docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/solr_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/complex_boolean_script.sh $5 ${4}_${START_TIME} $4
    sleep 10

    sudo mv $AUTOCANCEL_HOME/autocancel_exp/solr_exp/${4}_${START_TIME}_latency $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${CASE}_${START_TIME}/${4}_latency.csv
    sudo mv $AUTOCANCEL_HOME/autocancel_exp/solr_exp/${4}_${START_TIME}_throughput $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${CASE}_${START_TIME}/${4}_throughput.csv

    DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 docker compose -f $AUTOCANCEL_HOME/scripts/cases/c6_complex_request/docker_config.yml down
}

# run_once base_policy false true base_wo_predict $client_num
# sleep 10

# run_once base_policy true true base_w_predict $client_num
# sleep 10

# run_once multi_objective_policy false true moo_wo_predict $client_num
# sleep 10

run_once multi_objective_policy true true moo_w_predict $client_num
sleep 10

# run_once multi_objective_policy true false wo_cancel $client_num
# sleep 10

# run_once multi_objective_policy true false normal $client_num
# sleep 10
