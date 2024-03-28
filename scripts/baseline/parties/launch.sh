#!/bin/bash

set -e
set -m

export AUTOCANCEL_HOME=$(git rev-parse --show-toplevel)
export BASELINE=parties
export START_TIME=$(date +%Y_%m_%d_%H_%M_%S)
export START_DATE=$(date +%Y_%m_%d)

client_num=2

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

# Set up cgroup for PARTIES
# Finish set up cgroup for PARTIES

# Launch PARTIES
# Finish launch PARTIES

docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/solr_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/complex_boolean_script.sh $client_num ${BASELINE}_${START_TIME} $BASELINE
sleep 10

mv $AUTOCANCEL_HOME/autocancel_exp/solr_exp/${BASELINE}_${START_TIME}_latency $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${BASELINE}_${START_TIME}/${BASELINE}_latency.csv
mv $AUTOCANCEL_HOME/autocancel_exp/solr_exp/${BASELINE}_${START_TIME}_throughput $AUTOCANCEL_HOME/scripts/logs/$START_DATE/${BASELINE}_${START_TIME}/${BASELINE}_throughput.csv

bash -c "$env_args docker compose -f $AUTOCANCEL_HOME/scripts/cases/c6_complex_request/docker_config.yml down"

