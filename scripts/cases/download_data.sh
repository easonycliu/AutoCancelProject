#!/bin/bash

set -e

export AUTOCANCEL_HOME=$(git rev-parse --show-toplevel)

if [ ! -d "$AUTOCANCEL_HOME/scripts/data/elasticsearch" ]; then
    mkdir $AUTOCANCEL_HOME/scripts/data/elasticsearch
    pushd $AUTOCANCEL_HOME/scripts/data/elasticsearch
    gh release download --repo liuyc1515/AutocancelProject v1.0-es-data -p 'xaa'
    gh release download --repo liuyc1515/AutocancelProject v1.0-es-data -p 'xab'
    gh release download --repo liuyc1515/AutocancelProject v1.0-es-data -p 'xac'
    gh release download --repo liuyc1515/AutocancelProject v1.0-es-data -p 'xad'

    cat xa* > elasticsearch_doc.tar.gz
    tar -xzf elasticsearch_doc.tar.gz
    mv single_node/* .
    sudo chown -R 1000:1000 .
    popd
fi

if [ ! -d "$AUTOCANCEL_HOME/scripts/data/solr" ]; then
    mkdir $AUTOCANCEL_HOME/scripts/data/solr
    pushd $AUTOCANCEL_HOME/scripts/data/solr
    gh release download --repo liuyc1515/AutocancelProject v1.0-solr-data -p 'solr_exp.tar.gz'

    tar -xzf solr_exp.tar.gz
    mv single_node_v9.0/* .
    sudo chown -R 8983:8983 .
    popd
fi
