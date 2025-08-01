#!/bin/bash

set -e

export AUTOCANCEL_HOME=$(git rev-parse --show-toplevel)

gh auth login -p https --with-token <<< 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

if [ ! -d "$AUTOCANCEL_HOME/scripts/data/elasticsearch" ]; then
    mkdir $AUTOCANCEL_HOME/scripts/data/elasticsearch
    pushd $AUTOCANCEL_HOME/scripts/data/elasticsearch
    gh release download --repo liuyc1515/AutoCancelProject v1.0-es-data -p 'xaa'
    gh release download --repo liuyc1515/AutoCancelProject v1.0-es-data -p 'xab'
    gh release download --repo liuyc1515/AutoCancelProject v1.0-es-data -p 'xac'
    gh release download --repo liuyc1515/AutoCancelProject v1.0-es-data -p 'xad'

    cat xa* > elasticsearch_doc.tar.gz
    tar -xzf elasticsearch_doc.tar.gz
    mv single_node/* .
    popd
fi

if [ ! -d "$AUTOCANCEL_HOME/scripts/data/solr" ]; then
    mkdir $AUTOCANCEL_HOME/scripts/data/solr
    pushd $AUTOCANCEL_HOME/scripts/data/solr
    gh release download --repo liuyc1515/AutoCancelProject v1.0-solr-data -p 'solr_exp.tar.gz'

    tar -xzf solr_exp.tar.gz
    mv single_node_v9.0/* .
    popd
fi

if [ ! -d "$AUTOCANCEL_HOME/scripts/data/solr_bench_home" ]; then
    mkdir $AUTOCANCEL_HOME/scripts/data/solr_bench_home
    pushd $AUTOCANCEL_HOME/scripts/data/solr_bench_home
    gh release download --repo liuyc1515/AutoCancelProject v1.0-solr-bench-data -p 'xaa'
    gh release download --repo liuyc1515/AutoCancelProject v1.0-solr-bench-data -p 'xab'
    gh release download --repo liuyc1515/AutoCancelProject v1.0-solr-bench-data -p 'xac'
    gh release download --repo liuyc1515/AutoCancelProject v1.0-solr-bench-data -p 'xad'
    gh release download --repo liuyc1515/AutoCancelProject v1.0-solr-bench-data -p 'xae'
    gh release download --repo liuyc1515/AutoCancelProject v1.0-solr-bench-data -p 'xaf'

    cat xa* > solr_bench.tar.gz
    tar -xzf solr_bench.tar.gz
    mv suites/* .
	mv stress-facets-local-autocancel.json stress-facets-local-autocancel-base.json
    popd
fi

