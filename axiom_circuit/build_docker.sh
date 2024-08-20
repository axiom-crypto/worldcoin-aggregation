#!bin/bash

REPO_ROOT=$(git rev-parse --show-toplevel)
WORKDIR=$REPO_ROOT/circuit
export CARGO_HOME=$WORKDIR/.cargo
cd $WORKDIR

cargo clean
cargo update
cargo fetch

docker build -t worldcoin_server .
