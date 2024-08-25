#!/bin/bash

intents=("3_128_20_21" "3_64_20_21" "3_32_20_21" "3_16_20_21" "2_8_19_20")

for intent in "${intents[@]}"; do
    echo "v1 keygen for ${intent}.yml" >> keygen.log
    mkdir -p circuit_data/v1_${intent}
    cargo run --release --features "keygen, v1" --bin keygen  --  --srs-dir ~/.axiom/srs/challenge_0085/ --intent configs/intents/${intent}.yml --tag v1_${intent}  --data-dir circuit_data/v1_${intent}  >> keygen.log
done

