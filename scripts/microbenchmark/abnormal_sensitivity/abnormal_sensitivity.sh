#!/bin/bash

set -e
set -m

export AUTOCANCEL_HOME=$(git rev-parse --show-toplevel)
export MICROBENCHMARK=abnormal_sensitivity
export START_TIME=$(date +%Y_%m_%d_%H_%M_%S)
export START_DATE=$(date +%Y_%m_%d)

declare -A case_to_script_map
case_to_script_map["c1"]="elasticsearch_exp multiclient_request_cache_evict 8.00 16"
# case_to_script_map["c2"]="elasticsearch_exp multiclient_update_by_query 8.00 16"
case_to_script_map["c3"]="elasticsearch_exp multiclient_nested_aggs 8.00 8"
case_to_script_map["c4"]="elasticsearch_exp multiclient_complex_boolean 8.00 16"
case_to_script_map["c5"]="elasticsearch_exp multiclient_bulk_large_document 8.00 16"
# case_to_script_map["c6"]="solr_exp complex_boolean_script 2.00 16"
case_to_script_map["c7"]="solr_exp stat_fields 4.00 16"

client_num=5

sudo sysctl -w vm.max_map_count=262144

if [ $(docker images | grep "solr_exp" | wc -l) -eq 0 ]; then
    docker build --build-arg SOLR_ID=$(id -u) -t solr_exp:v1.0-9.0.0 .
fi

if [ ! -d "$AUTOCANCEL_HOME/scripts/logs/$START_DATE" ]; then
    mkdir $AUTOCANCEL_HOME/scripts/logs/$START_DATE
fi

mkdir $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}

if [ ! -f "$AUTOCANCEL_HOME/autocancel_exp/elasticsearch_exp/query/boolean_search.json" ]; then
    docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/elasticsearch_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/performance_issues/complex_boolean_operations.py 2000 boolean_search.json
fi

function run_once {
    local app_exp=$(echo ${case_to_script_map["$6"]} | awk '{print $1}')
    local case_name=$(echo ${case_to_script_map["$6"]} | awk '{print $2}')
    local core_num=$(echo ${case_to_script_map["$6"]} | awk '{print $3}')
    local heap_size=$(echo ${case_to_script_map["$6"]} | awk '{print $4}')

	local env_args="USER_ID=$(id -u) GROUP_ID=$(id -g) DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 ABNORMAL_PORTION=$7 ABNORMAL_ABSOLUTE=$8 CORE_NUM=$core_num HEAP_SIZE=$heap_size"

	bash -c "$env_args docker compose -f $AUTOCANCEL_HOME/scripts/microbenchmark/abnormal_sensitivity/${app_exp}_docker_config.yml down"

	bash -c "$env_args docker compose -f $AUTOCANCEL_HOME/scripts/microbenchmark/abnormal_sensitivity/${app_exp}_docker_config.yml up &"
    sleep 60

    docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/$app_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/warmup.sh
    sleep 10

    docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/$app_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/$case_name.sh $5 ${4}_${START_TIME} $4
    sleep 10

    mv $AUTOCANCEL_HOME/autocancel_exp/$app_exp/${4}_${START_TIME}_latency $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${4}_latency.csv
    mv $AUTOCANCEL_HOME/autocancel_exp/$app_exp/${4}_${START_TIME}_throughput $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${4}_throughput.csv

    mv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${4}.csv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${6}_${4}_${7}_${8}.csv
    mv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${4}_latency.csv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${6}_${4}_${7}_${8}_latency.csv
    mv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${4}_throughput.csv $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${MICROBENCHMARK}_${START_TIME}/${6}_${4}_${7}_${8}_throughput.csv

	bash -c "$env_args docker compose -f $AUTOCANCEL_HOME/scripts/microbenchmark/abnormal_sensitivity/${app_exp}_docker_config.yml down"
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
    run_case $1 0.1 80
    sleep 10
    run_case $1 0.25 200
    sleep 10
    run_case $1 0.5 400
    sleep 10
    run_case $1 0.75 600
    sleep 10
}

if [[ "$1" =~ ^c[1-7]$ ]]; then
	run_round $1
fi

