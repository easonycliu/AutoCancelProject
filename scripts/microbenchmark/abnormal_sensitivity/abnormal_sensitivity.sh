#!/bin/bash

set -e
set -m

export AUTOCANCEL_HOME=$(git rev-parse --show-toplevel)
export MICROBENCHMARK=abnormal_sensitivity
export START_TIME=$(date +%Y_%m_%d_%H_%M_%S)
export START_DATE=$(date +%Y_%m_%d)

declare -A case_to_script_map
case_to_script_map["c1"]="elasticsearch_exp multiclient_request_cache_evict"
# case_to_script_map["c2"]="elasticsearch_exp multiclient_update_by_query"
case_to_script_map["c3"]="elasticsearch_exp multiclient_nested_aggs"
case_to_script_map["c4"]="elasticsearch_exp multiclient_complex_boolean"
case_to_script_map["c5"]="elasticsearch_exp multiclient_bulk_large_document"
# case_to_script_map["c6"]="solr_exp complex_boolean_script"
case_to_script_map["c7"]="solr_exp stat_fields"

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
    local app_exp=$(echo ${case_to_script_map["$6"]} | awk '{print $1}')
    local case_name=$(echo ${case_to_script_map["$6"]} | awk '{print $2}')

    DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 ABNORMAL_PORTION=$7 ABNORMAL_ABSOLUTE=$8 docker compose -f $AUTOCANCEL_HOME/scripts/microbenchmark/abnormal_sensitivity/${app_exp}_docker_config.yml down

    DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 ABNORMAL_PORTION=$7 ABNORMAL_ABSOLUTE=$8 docker compose -f $AUTOCANCEL_HOME/scripts/microbenchmark/abnormal_sensitivity/${app_exp}_docker_config.yml up &
    sleep 60

    docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/$app_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/warmup.sh
    sleep 10

    docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/$app_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/$case_name.sh $5 ${4}_${START_TIME} $4
    sleep 10

    sudo mv $AUTOCANCEL_HOME/autocancel_exp/$app_exp/${4}_${START_TIME}_latency $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${4}_latency.csv
    sudo mv $AUTOCANCEL_HOME/autocancel_exp/$app_exp/${4}_${START_TIME}_throughput $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${4}_throughput.csv

    sudo mv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${4}.csv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${6}_${4}_${7}_${8}.csv
    sudo mv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${4}_latency.csv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${6}_${4}_${7}_${8}_latency.csv
    sudo mv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${4}_throughput.csv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${6}_${4}_${7}_${8}_throughput.csv

    DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 ABNORMAL_PORTION=$7 ABNORMAL_ABSOLUTE=$8 docker compose -f $AUTOCANCEL_HOME/scripts/microbenchmark/abnormal_sensitivity/${app_exp}_docker_config.yml down
}

function run_case {
    run_once base_policy false true base_wo_predict $client_num $1 $2 $3
    sleep 10

    run_once base_policy true true base_w_predict $client_num $1 $2 $3
    sleep 10

    run_once multi_objective_policy false true moo_wo_predict $client_num $1 $2 $3
    sleep 10

    run_once multi_objective_policy true true moo_w_predict $client_num $1 $2 $3
    sleep 10

    run_once multi_objective_policy true false wo_cancel $client_num $1 $2 $3
    sleep 10

    run_once multi_objective_policy true false normal $client_num $1 $2 $3
    sleep 10
}

function run_round {
    # run_case $1 0.1 40
    # sleep 10
    # run_case $1 0.25 100
    # sleep 10
    run_case $1 0.5 200
    sleep 10
    run_case $1 0.75 300
    sleep 10
}

# run_round c1
# sleep 10
# run_round c2
# sleep 10
# run_round c3
# sleep 10
# run_round c4
# sleep 10
run_round c5
sleep 10
# run_round c6
# sleep 10
run_round c7
sleep 10
