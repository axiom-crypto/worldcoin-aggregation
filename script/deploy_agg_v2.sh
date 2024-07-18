source .env

# usage bash script/deploy_agg_v1.sh logMaxNumClaims
forge script script/DeployAggregationV2.s.sol:DeployAggregationV2 --sig "run(uint256)" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY  --chain-id 11155111 --broadcast --verify  -vvvv --slow $1