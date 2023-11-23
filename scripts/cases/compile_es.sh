#!/bin/bash

set -e

export AUTOCANCEL_HOME=$(realpath ../..)

sudo chown -R $(id -u):$(id -u) $AUTOCANCEL_HOME/elasticsearch/build/distribution/local/elasticsearch-8.9.0-SNAPSHOT
pushd $AUTOCANCEL_HOME/elasticsearch
./gradlew localDistro
popd
sudo chown -R 1000:1000 $AUTOCANCEL_HOME/elasticsearch/build/distribution/local/elasticsearch-8.9.0-SNAPSHOT