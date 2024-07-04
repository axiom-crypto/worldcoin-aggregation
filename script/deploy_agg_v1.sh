source .env

forge script script/DeployAggregationV1.s.sol:DeployAggregationV1  --private-key $PRIVATE_KEY --rpc-url $RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY  --chain-id 11155111 --broadcast --verify  -vvvv --slow