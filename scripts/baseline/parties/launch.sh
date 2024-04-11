#!/bin/bash

set -e
set -m

export AUTOCANCEL_HOME=$(git rev-parse --show-toplevel)
export BASELINE=parties
export START_TIME=$(date +%Y_%m_%d_%H_%M_%S)
export START_DATE=$(date +%Y_%m_%d)

cgroup_num=$(cat config.txt | head -1)
cgroup_names=($(cat config.txt | tail -n $cgroup_num | awk '{print $1}'))

declare -A case_to_script_map
case_to_script_map["c1"]="elasticsearch_exp multiclient_request_cache_evict 8.00 16 5 c1_cache_evict"
# case_to_script_map["c2"]="elasticsearch_exp multiclient_update_by_query 8.00 16 8 c2_byquery"
case_to_script_map["c3"]="elasticsearch_exp multiclient_nested_aggs 8.00 4 8 c3_nest_agg"
case_to_script_map["c4"]="elasticsearch_exp multiclient_complex_boolean 12.00 16 5 c4_complex_boolean"
case_to_script_map["c5"]="elasticsearch_exp multiclient_bulk_large_document 8.00 16 5 c5_bulk_document"
case_to_script_map["c6"]="solr_exp complex_boolean_script 2.00 16 2 c6_complex_request"
case_to_script_map["c7"]="solr_exp stat_fields 4.00 16 8 c7_stat_fields"

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
    local case_dir=$(echo ${case_to_script_map["$1"]} | awk '{print $6}')

	env_args="USER_ID=$(id -u) GROUP_ID=$(id -g) AUTOCANCEL_LOG=$BASELINE CORE_NUM=$core_num HEAP_SIZE=$heap_size CASE_DIR=$case_dir"
	bash -c "$env_args docker compose -f $AUTOCANCEL_HOME/scripts/baseline/parties/${app_exp}_docker_config.yml down"
	
	docker stop single_node || true
	docker rm single_node || true
	
	bash -c "$env_args docker compose -f $AUTOCANCEL_HOME/scripts/baseline/parties/${app_exp}_docker_config.yml up &"
	sleep 60
	
	docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/$app_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/warmup.sh
	sleep 10

	# Set up cgroup for PARTIES
	for cgroup_name in ${cgroup_names[@]}; do
		sudo cgdelete -g cpuset:$cgroup_name || true
		sudo cgcreate -g cpuset:$cgroup_name
		sudo cgset -r cpuset.mems=0 /$cgroup_name
		sudo cgset -r cpuset.cpus=0-$(( `nproc` - 1 )) /$cgroup_name
	done
	
	target_pid=$(ps -aux | grep "autocancel.log" | head -1 | awk '{print $2}')
	target_threads=($(ps -o spid= -T $target_pid))
	target_threads_num=$(echo ${target_threads[@]} | wc -w)
	for index in $(seq 0 1 $(( target_threads_num - 1 ))); do
		echo ${target_threads[$index]} | sudo tee /sys/fs/cgroup/cpuset/${cgroup_names[$(( index % cgroup_num ))]}/tasks > /dev/null
	done
	# Finish set up cgroup for PARTIES
	
	# Launch PARTIES
	./parties.py $AUTOCANCEL_HOME/scripts/baseline/parties/config.txt `nproc` 10000 > /dev/null &
	# Finish launch PARTIES
	
	docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/$app_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/$case_name.sh \
		$client_num ${BASELINE}_${START_TIME} $BASELINE $BASELINE:$(echo ${cgroup_names[@]} | tr " " ":")
	sleep 10
	
	kill -2 $(ps | grep parties.py | awk '{print $1}')
	
	mv $AUTOCANCEL_HOME/autocancel_exp/$app_exp/${BASELINE}_${START_TIME}_latency $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${BASELINE}_${START_TIME}/${BASELINE}_${1}_latency.csv
	mv $AUTOCANCEL_HOME/autocancel_exp/$app_exp/${BASELINE}_${START_TIME}_throughput $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${BASELINE}_${START_TIME}/${BASELINE}_${1}_throughput.csv
	
	bash -c "$env_args docker compose -f $AUTOCANCEL_HOME/scripts/baseline/parties/${app_exp}_docker_config.yml down"
}

run_once c1
run_once c3
run_once c4
run_once c5
run_once c6
run_once c7
