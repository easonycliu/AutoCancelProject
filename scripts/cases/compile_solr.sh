#!/bin/bash

set -e

export AUTOCANCEL_HOME=$(git rev-parse --show-toplevel)

if [ -d "$AUTOCANCEL_HOME/solr/solr/packaging/build/solr-9.0.0-SNAPSHOT" ]; then
    sudo chown -R $(id -u):$(id -u) $AUTOCANCEL_HOME/solr/solr/packaging/build/solr-9.0.0-SNAPSHOT
fi

pushd $AUTOCANCEL_HOME/solr
./gradlew assemble
popd
sudo chown -R 8983:8983 $AUTOCANCEL_HOME/solr/solr/packaging/build/solr-9.0.0-SNAPSHOT
