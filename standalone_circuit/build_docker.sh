#!bin/bash

# usage: bash build_docker.sh <version - v1 or v2>
REPO_ROOT=$(git rev-parse --show-toplevel)
WORKDIR=$REPO_ROOT/standalone_circuit
export CARGO_HOME=$WORKDIR/.cargo
cd $WORKDIR

VERSION=${1:-v1}

cargo clean
cargo update
cargo fetch

docker build --build-arg VERSION=${VERSION} -t server .
