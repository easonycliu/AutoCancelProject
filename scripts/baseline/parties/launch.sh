#!/bin/bash

set -e
set -m

export AUTOCANCEL_HOME=$(git rev-parse --show-toplevel)
export BASELINE=parties
export START_TIME=$(date +%Y_%m_%d_%H_%M_%S)
export START_DATE=$(date +%Y_%m_%d)

client_num=2

cgroup_num=$(cat config.txt | head -1)
cgroup_names=($(cat config.txt | tail -n $cgroup_num | awk '{print $1}'))

sudo sysctl -w vm.max_map_count=262144

if [ $(docker images | grep "solr_exp" | wc -l) -eq 0 ]; then
    docker build --build-arg SOLR_ID=$(id -u) -t solr_exp:v1.0-9.0.0 .
fi

if [ ! -d "$AUTOCANCEL_HOME/scripts/logs/$START_DATE" ]; then
    mkdir $AUTOCANCEL_HOME/scripts/logs/$START_DATE
fi

mkdir $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${BASELINE}_${START_TIME}

if [ ! -f "$AUTOCANCEL_HOME/autocancel_exp/solr_exp/query/boolean_search_1.json" ]; then
    docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/solr_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/performance_issues/complex_boolean_operations.py 80000 boolean_search_1.json
fi
if [ ! -f "$AUTOCANCEL_HOME/autocancel_exp/solr_exp/query/boolean_search_2.json" ]; then
    docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/solr_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/performance_issues/complex_boolean_operations.py 50000 boolean_search_2.json
fi

env_args="AUTOCANCEL_LOG=$BASELINE"
bash -c "$env_args docker compose -f $AUTOCANCEL_HOME/scripts/cases/c6_complex_request/docker_config.yml down"

docker stop single_node || true
docker rm single_node || true

bash -c "$env_args docker compose -f $AUTOCANCEL_HOME/scripts/cases/c6_complex_request/docker_config.yml up &"
sleep 60

docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/elasticsearch_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/warmup.sh
sleep 10

# Set up cgroup for PARTIES
for cgroup_name in ${cgroup_names[@]}; do
	sudo cgdelete -g cpuset:$cgroup_name
	sudo cgcreate -g cpuset:$cgroup_name
	sudo cgset -r cpuset.mems=0 /$cgroup_name
	sudo cgset -r cpuset.cpus=0-$(( `nproc` - 1 )) /$cgroup_name

	sudo cgdelete -g cpu:$cgroup_name
	sudo dgcreate -g cpu:$cgroup_name
	sudo cgset -r cpu.cfs_period_us=10000 /$cgroup_name
	sudo cgset -r cpu.cfs_quota_us=-1 /$cgroup_name
done

target_pid=$(ps -aux | grep "autocancel.log" | head -1 | awk '{print $2}')
target_threads=($(ps -o spid= -T $target_pid))
target_threads_num=$(echo ${target_threads[@]} | wc -w)
for index in $(seq 0 1 $(( target_threads_num - 1 ))); do
	echo ${target_threads[$index]} | sudo tee /sys/fs/cgroup/cpuset/${cgroup_names[$(( index % cgroup_num ))]}/tasks > /dev/null
done
# Finish set up cgroup for PARTIES

# Launch PARTIES
./parties.py $AUTOCANCEL_HOME/scripts/baseline/parties/config.txt `nproc` 10000
# Finish launch PARTIES

docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/solr_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/complex_boolean_script.sh $client_num ${BASELINE}_${START_TIME} $BASELINE
sleep 10

kill -2 $(ps | grep parties.py | awk '{print $1}')

mv $AUTOCANCEL_HOME/autocancel_exp/solr_exp/${BASELINE}_${START_TIME}_latency $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${BASELINE}_${START_TIME}/${BASELINE}_latency.csv
mv $AUTOCANCEL_HOME/autocancel_exp/solr_exp/${BASELINE}_${START_TIME}_throughput $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${BASELINE}_${START_TIME}/${BASELINE}_throughput.csv

bash -c "$env_args docker compose -f $AUTOCANCEL_HOME/scripts/cases/c6_complex_request/docker_config.yml down"

