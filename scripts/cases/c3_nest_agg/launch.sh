#!/bin/bash

set -e
set -m

export AUTOCANCEL_HOME=$(realpath ../../..)
export CASE=c1
export START_TIME=$(date +%Y_%m_%d_%H_%M_%S)

sudo mkdir $AUTOCANCEL_HOME/scripts/logs/${CASE}_${START_TIME}
sudo chown -R 1000:1000 $AUTOCANCEL_HOME/scripts/logs

function run_once {
    DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 docker compose -f $AUTOCANCEL_HOME/scripts/cases/c3_nest_agg/docker_config.yml down

    DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 docker compose -f $AUTOCANCEL_HOME/scripts/cases/c3_nest_agg/docker_config.yml up &
    sleep 60

    docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/elasticsearch_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/warmup.sh
    sleep 10

    docker run --rm --net=host -v $AUTOCANCEL_HOME/autocancel_exp/elasticsearch_exp:/root -w /root easonliu12138/es_py_env:v1.1 /root/scripts/multiclient_nested_aggs.sh $4
    sleep 10

    DEFAULT_POLICY=$1 PREDICT_PROGRESS=$2 CANCEL_ENABLE=$3 AUTOCANCEL_LOG=$4 docker compose -f $AUTOCANCEL_HOME/scripts/cases/c3_nest_agg/docker_config.yml down
}

run_once base_policy false true base_wo_predict
sleep 10

run_once base_policy true true base_w_predict
sleep 10

run_once multi_objective_policy false true moo_wo_predict
sleep 10

run_once multi_objective_policy true true moo_w_predict
sleep 10

run_once multi_objective_policy true false wo_cancel
sleep 10

run_once multi_objective_policy true false normal
sleep 10
