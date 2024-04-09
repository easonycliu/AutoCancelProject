#!/bin/bash

set -e
set -m

export AUTOCANCEL_HOME=$(git rev-parse --show-toplevel)
export BASELINE=psandbox
export START_TIME=$(date +%Y_%m_%d_%H_%M_%S)
export START_DATE=$(date +%Y_%m_%d)

declare -A case_to_script_map
case_to_script_map["c1"]="elasticsearch_exp multiclient_request_cache_evict 8.00 16 5"
# case_to_script_map["c2"]="elasticsearch_exp multiclient_update_by_query 8.00 16 8"
case_to_script_map["c3"]="elasticsearch_exp multiclient_nested_aggs 8.00 8 8"
case_to_script_map["c4"]="elasticsearch_exp multiclient_complex_boolean 8.00 16 5"
case_to_script_map["c5"]="elasticsearch_exp multiclient_bulk_large_document 8.00 16 5"
case_to_script_map["c6"]="solr_exp complex_boolean_script 2.00 16 2"
case_to_script_map["c7"]="solr_exp stat_fields 4.00 16 8"

sudo sysctl -w vm.max_map_count=262144

if [ ! -d "$AUTOCANCEL_HOME/scripts/logs/$START_DATE" ]; then
    mkdir $AUTOCANCEL_HOME/scripts/logs/$START_DATE
fi

mkdir $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${BASELINE}_${START_TIME}

function run_once {
    local app_exp=$(echo ${case_to_script_map["$1"]} | awk '{print $1}')
    local case_name=$(echo ${case_to_script_map["$1"]} | awk '{print $2}')
    local core_num=$(echo ${case_to_script_map["$1"]} | awk '{print $3}')
    local heap_size=$(echo ${case_to_script_map["$1"]} | awk '{print $4}')
    local client_num=$(echo ${case_to_script_map["$1"]} | awk '{print $5}')

	env_args="USER_ID=$(id -u) GROUP_ID=$(id -g) AUTOCANCEL_LOG=$BASELINE AUTOCANCEL_START=false CORE_NUM=$core_num HEAP_SIZE=$heap_size"
	bash -c "$env_args docker compose -f $AUTOCANCEL_HOME/scripts/baseline/psandbox/${app_exp}_docker_config.yml down"
	
	docker stop single_node || true
	docker rm single_node || true
	
	bash -c "$env_args docker compose -f $AUTOCANCEL_HOME/scripts/baseline/psandbox/${app_exp}_docker_config.yml up &"
	sleep 60
	
	docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/$app_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/warmup.sh
	sleep 10

	docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/$app_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/$case_name.sh \
		$client_num ${BASELINE}_${START_TIME} $BASELINE $BASELINE:$(echo ${cgroup_names[@]} | tr " " ":")
	sleep 10

	mv $AUTOCANCEL_HOME/autocancel_exp/$app_exp/${BASELINE}_${START_TIME}_latency $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${BASELINE}_${START_TIME}/${BASELINE}_latency.csv
	mv $AUTOCANCEL_HOME/autocancel_exp/$app_exp/${BASELINE}_${START_TIME}_throughput $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${BASELINE}_${START_TIME}/${BASELINE}_throughput.csv
	
	bash -c "$env_args docker compose -f $AUTOCANCEL_HOME/scripts/baseline/psandbox/${app_exp}_docker_config.yml down"
}

if [[ "$1" =~ ^c[1-7]$ ]]; then
	run_once $1
fi

