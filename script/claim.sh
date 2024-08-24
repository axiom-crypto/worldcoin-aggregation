source .env

# This command reads claim.json under config and submit it on-chain.
forge script script/ClaimScript.s.sol:ClaimScript --private-key $PRIVATE_KEY --rpc-url $RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY --chain-id 11155111 --broadcast -vvvv
