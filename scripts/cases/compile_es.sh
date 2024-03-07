#!/bin/bash

set -e

export AUTOCANCEL_HOME=$(git rev-parse --show-toplevel)

if [ -d "$AUTOCANCEL_HOME/elasticsearch/build/distribution/local/elasticsearch-8.9.0-SNAPSHOT" ]; then
    sudo chown -R $(id -u):$(id -u) $AUTOCANCEL_HOME/elasticsearch/build/distribution/local/elasticsearch-8.9.0-SNAPSHOT
fi

pushd $AUTOCANCEL_HOME/elasticsearch
./gradlew localDistro
popd
