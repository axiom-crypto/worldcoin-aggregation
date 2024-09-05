# Batch WorldID proof verification with Axiom

This repo implements batch verification of [WorldID](https://worldcoin.org/world-id) proofs to enable cheaper batch claims of WLD grants.

It is implemented via two components:

- ZK circuits for batch WorldID proof verification using Axiom's ZK circuit libraries.
- Smart contracts implementing WLD grant claims based on batch-verified WorldID proof results.

In what follows, we describe two different flows for WLD grants using this integration.

**Note:** The work in this repo has not been audited and should not be deployed in production prior to additional security review.

## Worldcoin Grant Protocol

We implement two versions of WLD grants based on batch verification of WorldID proofs.

- `WorldcoinAggregationV1`: After proof verification, all the receivers in the batch immediately have their grant transferred to them.
- `WorldcoinAggregationV2`: After proof verification, the receivers (or someone on their behalf) can prove into a Merkle root and transfer the grant to the receiver.

We recommend **WLD Grant Protocol V1** for the best UX and cost for the grantee. We describe each variation below.

### WLD Grant Protocol V1

In the V1 design, the grant contract automatically transfers the grant amount to each of the users in the batch in the same transaction as the verification. This design means users do not need to make an additional on-chain transaction to receive the grant, but incurs additional calldata and transfer cost for each grantee.

The V1 grant contract supports at most `MAX_NUM_CLAIMS` at once, and receives as part of the claim transaction a ZK proof whose unique public output is a Keccak hash of the `3 + 3 * MAX_NUM_CLAIMS` ZK-verified quantities:

```
- vkeyHash - the Keccak hash of the flattened Groth16 vkey
- numClaims - the number of claims, which should satisfy 1 <= numClaims <= MAX_NUM_CLAIMS
- root - the WorldID root the proofs are relative to
- grantIds_i for i = 1, ..., MAX_NUM_CLAIMS
- receivers_i for i = 1, ..., MAX_NUM_CLAIMS
- nullifierHashes_i for i = 1, ..., MAX_NUM_CLAIMS
```

The ZK proof verifies in ZK that:

1. For `0 <= idx < numClaims`, there are valid WorldID proofs corresponding to `(root, claimedNullifierHashes[idx], receivers[idx], grantIds[idx])` with the given Groth16 `vkeyHash`.

The V1 grants contract then:

- checks the `vkeyHash` for the WorldID Groth16 proof is valid
- checks that `grantIds[idx]` is valid for `0 <= idx < numClaims`
- checks for each claiming grantee that the nullifier hash was not previously used
- sends `WLD` to fulfill the claim

To simplify re-execution in the case of insufficient `WLD` balance, claims are all-or-nothing -- if the contract has insufficient `WLD` to fulfill the entire batch, the entire claim transaction will be reverted.

### WLD Grant Protocol V2

In the V2 design, the grant contract implements a two-step process to distribute the grant. First, it verifies in ZK a Keccak Merkle root of a tree of eligible grant recipients with leaves given by `abi.encodePacked(grantId, receiver, nullifierHash)`. This Merkle root is stored on-chain, and grantees use ordinary Merkle proofs to prove eligibility and claim their grants.

The V2 grant contract supports at most `MAX_NUM_CLAIMS` at once, where `MAX_NUM_CLAIMS` must be a power of two. It verifies the following 3 ZK-verified quantities using a ZK proof:

```
- vkeyHash - the Keccak hash of the flattened Groth16 vkey
- root - the WorldID root the proofs are relative to
- claimsRoot - the Keccak Merkle root of the tree with `MAX_NUM_CLAIMS` leaves
```

The ZK proof verifies that

1. There is a value `1 <= numClaims <= MAX_NUM_CLAIMS` and arrays `grantIds`, `receivers` and `claimedNullifierHashes` so that for `0 <= idx < numClaims`, there are valid WorldID proofs corresponding to `(root, claimedNullifierHashes[idx], receivers[idx], grantIds[idx])`.
2. The hash `claimsRoot` is the Keccak Merkle root of the tree with `MAX_NUM_CLAIMS` leaves, where the first `numClaims` leaves are given by `abi.encodePacked(grantIds[idx], receivers[idx], claimedNullifierHashes[idx])` and the remaining leaves are `abi.encodePacked(uint256(0), address(0), byte32(0))`.

The V2 grants contract then:

- checks the `vkeyHash` for the WorldID Groth16 proof is valid
- stores `claimsRoot` for grantees to claim WLD against

Grantees can claim `WLD` rewards from the V2 grants contract by passing a Merkle proof into:

```solidity
    function claim(
        uint256 grantId,
        uint256 root,
        address receiver,
        bytes32 nullifierHash,
        bytes32[] calldata leaves,
        bytes32 isLeftBytes
    ) external {
        <...>
    }
```

Note that we use a Keccak Merkle tree **without** sorting of child hashes, meaning the parent hash is given by `parent = keccak256(abi.encodePacked(left, right))`. This means Merkle proof verification requires an indication of whether each proof hash is a left or right child, which we encode in `bytes32 isLeftBytes` so that **byte** `idx` of `isLeftBytes` is `1` if and only if `leaves[idx]` is a left child.

## Test Deployments and Benchmarks

To benchmark gas usage and off-chain costs, we deployed `WorldcoinAggregationV1` and `WorldcoinAggregationV2` for sizes `16, 32, 64, 128, 256 (v1 only) and 8192 (v2 only)` on Sepolia. Because the WLD token is not deployed on Sepolia, we mocked the WLD, RootValidator, and Grant contracts, as detailed below. After deployment, we initiated transactions for various batch sizes and measured amortized gas usage, calldata size and off-chain costs.

Test data was generated using [semaphore-rs](https://github.com/worldcoin/semaphore-rs) with the `depth_30` feature flag. Our profiling assumes that the grantees have a 0 balance for WLD. If the grantees are existing WLD holders, the WLD transfer will take 17.1K less gas, with the difference (20K - 2.9K) coming from the cost of the `SSTORE` opcode for updating grantee balances.

### WLD Grant Protocol V1

We deployed Grant Protocol V1 on Sepolia for different claim sizes and made sample fulfill transactions. We measure gas usage, calldata size and off-chain costs, displayed in the table below. We also compute gas attributed to proof verification, which excludes gas used for WLD token transfers and other business logic. **We recommend this configuration setting for the best cost and UX.**

In these benchmarks, onchain costs include L1 and L2 gas. Our onchain cost estimates assume an L2 gas cost of 0.06 gwei, L1 blob base fee of 1wei, and \$3000 ETH. Our offchain cost estimates are conservative benchmarks based on on-demand AWS compute instances (`m6a.4xlarge`).

| # Claims | Sepolia Address                                                                                                               | Fulfill Tx                                                                                                       | L2 Gas/Claim | Proof Gas/Claim | Calldata/Claim | Onchain \$/Claim | Offchain \$/Claim |
| -------- | ----------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ------------ | --------------- | -------------- | ---------------- | ----------------- |
| 16       | [0x3689d27A428543100E7CeB663F55616cdE896F07](https://sepolia.etherscan.io/address/0x3689d27A428543100E7CeB663F55616cdE896F07) | [Fulfill Tx](https://sepolia.etherscan.io/tx/0xe2ac0e66a91765656e8b88d21479b03506fe246ae7d2d8ccc8ad7ce2b9f626f2) | 75K          | 23K             | 232            | \$0.0139         | \$0.0208          |
| 32       | [0xF2EF0b7300BF2B0F0a7a310BABde640b3E74997B](https://sepolia.etherscan.io/address/0xF2EF0b7300BF2B0F0a7a310BABde640b3E74997B) | [Fulfill Tx](https://sepolia.etherscan.io/tx/0x80ccfd91b6121f5471f74c1f90dc10f3364478703be25c56f10683bcb8f4a163) | 64K          | 11K             | 164            | \$0.0118         | \$0.0181          |
| 64       | [0xe515583983388956147277Ec7a4347964D77bFbc](https://sepolia.etherscan.io/address/0xe515583983388956147277Ec7a4347964D77bFbc) | [Fulfill Tx](https://sepolia.etherscan.io/tx/0x69b7c8fc5d09e9c989960a271105b7adf0d291174b669042732342c98a2fcde2) | 58K          | 6K              | 130            | \$0.0107         | \$0.0170          |
| 128      | [0x0cd9558c9f3BB010F8A0ec3Fd301178e1fc925F8](https://sepolia.etherscan.io/address/0x0cd9558c9f3BB010F8A0ec3Fd301178e1fc925F8) | [Fulfill Tx](https://sepolia.etherscan.io/tx/0xc3af5876a5482edb2e348d0aa84546cf983afd6f1393954c4ce4dbc44b357e93) | 56K          | 3K              | 113            | \$0.0103         | \$0.0158          |
| 256      | [0xa5fac0910068B7a570B0De0c2411A4185A3c3b03](https://sepolia.etherscan.io/address/0xa5fac0910068B7a570B0De0c2411A4185A3c3b03) | [Fulfill Tx](https://sepolia.etherscan.io/tx/0x70927cab3b7bed3f01958261cdcb27ef5e495394e5989ce8c4eb8d9ed1c19ebd) | 54K          | 1.4K            | 105            | \$0.0100         | \$0.0156          |

### WLD Grant Protocol V2

We deployed Grant Protocol V2 on Sepolia for different sizes and made sample fulfill and claim transactions. We measured gas usage, calldata usage and off-chain costs, shown in the table below. We also show gas attributed to proof verification, which excludes gas used for WLD token transfers and other business logic.

In these benchmarks, onchain costs include L1 and L2 gas. Our onchain cost estimates assume an L2 gas cost of 0.06 gwei, L1 blob base fee of 1wei, and \$3000 ETH. Our offchain cost estimates are conservative benchmarks based on on-demand AWS compute instances (`m6a.4xlarge`).

| # Claims | Sepolia Address                                                                                                               | Fulfill/Claim Tx                                                                                                                                                                                                          | L2 Gas/Claim | Proof Gas/Claim | Calldata/Claim | Onchain \$/Claim | Offchain \$/Claim |
| -------- | ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | --------------- | -------------- | ---------------- | ----------------- |
| 16       | [0x0725a6d62f7d9eC34197c57Bbc34B6657e251bf9](https://sepolia.etherscan.io/address/0x0725a6d62f7d9eC34197c57Bbc34B6657e251bf9) | [Fulfill](https://sepolia.etherscan.io/tx/0x72ddab5605dfbc0277719f3920fff9ba3440a4cde0753451af85beb2b45e545f) [Claim](https://sepolia.etherscan.io/tx/0x6b04354dd7e48a32771390a481f460bfad023f0476ff397e979a810c6611c9c6) | 113K         | 23K             | 482            | \$0.0212         | \$0.0207          |
| 32       | [0xDbef001fF19867075F02bB6Ee3D490235885AABA](https://sepolia.etherscan.io/address/0xDbef001fF19867075F02bB6Ee3D490235885AABA) | [Fulfill](https://sepolia.etherscan.io/tx/0x3e95143a9a3e590da7817067a5901a525e4c67163f062c0a29e880996f4224d5) [Claim](https://sepolia.etherscan.io/tx/0x9d46d4b4d3310f43e3117d95aa22ea3a0cdf86e90b66f4545527f1d127eee1cb) | 103K         | 11K             | 451            | \$0.0193         | \$0.0225          |
| 64       | [0x15C11FA9f87819020ec63997e7f1FcDeb71E2420](https://sepolia.etherscan.io/address/0x15C11FA9f87819020ec63997e7f1FcDeb71E2420) | [Fulfill](https://sepolia.etherscan.io/tx/0x9363144513e4071cd542bc00bb5d9f777fe214a342ddc7d55a4eab57798ab03c) [Claim](https://sepolia.etherscan.io/tx/0x4ed1ef65afbd75e44b07655fb98aabf6c8a446b7d774a267423ba444bf0e9e39) | 98K          | 6K              | 452            | \$0.0185         | \$0.0218          |
| 128      | [0xE43aB117477b9976fE02198299D933fdaC80E319](https://sepolia.etherscan.io/address/0xE43aB117477b9976fE02198299D933fdaC80E319) | [Fulfill](https://sepolia.etherscan.io/tx/0xfe918e2ab6adc86e2ccc3c7ba4f92c822766327cda3bc0de6269f674d3967a3a) [Claim](https://sepolia.etherscan.io/tx/0x1f999dc716bedc93c9cfc117ae09928d9771e7f57614565e5d7d2739ac664fc2) | 96K          | 3K              | 468            | \$0.0182         | \$0.0217          |
| 8192     | [0x708151E55a73bf359A1E0cC87Ff7D88c87Db9859](https://sepolia.etherscan.io/address/0x708151E55a73bf359A1E0cC87Ff7D88c87Db9859) | [Fulfill](https://sepolia.etherscan.io/tx/0x752e89c1bc1788306aa70a5582415a9f91c76d2a0ef8b46c4ef68ab9700744de) [Claim](https://sepolia.etherscan.io/tx/0xf9c1ac7f899f2a5d3553d4e677aa91cdc805377ed649fd249191dbd3c9d6315f) | 97K          | 0.04K           | 644            | \$0.0188         | \$0.214           |

For a given batch size, V2 consumes more gas than V1 per claim due to the additional claim transaction. As the batch size increases, the calldata per claim mostly decreases, reaching its minimum when the batch size is 32. After that the calldata per claim starts to increase due to increased calldata usage from the claim transaction.

### External Contracts for Testing

We deployed the following other contracts to mock different aspects of the Worldcoin system on Sepolia and run the integration into Axiom.

| Name              | Sepolia Address                                                                                                               | Description                                                                                                     |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| WLDMock           | [0xe93D97b0Bd30bD61a9D02B0A471DbB329D5d1fd8](https://sepolia.etherscan.io/address/0xe93D97b0Bd30bD61a9D02B0A471DbB329D5d1fd8) | An ERC20 contract which mocks the WLD contract                                                                  |
| RootValidatorMock | [0x9c06c3F1deecb530857127009EBE7d112ecd0E3F](https://sepolia.etherscan.io/address/0x9c06c3F1deecb530857127009EBE7d112ecd0E3F) | A contract which implements the `IRootValidator` interface and never reverts on the the `requireValidRoot` call |
| GrantMock         | [0x5d1F6aDfff773A2146f1f3c947Ddad1945103DaC](https://sepolia.etherscan.io/address/0x5d1F6aDfff773A2146f1f3c947Ddad1945103DaC) | A contract which implements the `IGrant` interface and nver reverts on the `checkValidity` call                 |

## Development and Testing

### Repository Overview

- `circuit/`: Circuits and prover backend for standalone batch WorldID aggregation.
  - `README.md`: Documentation for the standalone WorldID aggregation circuits for WLD grants can be found in their own README.
- `src/`
  - `WorldcoinAggregationV1.sol`: The smart contract for the `WorldcoinAggregationV1` version.
  - `WorldcoinAggregationV2.sol`: The smart contract for the `WorldcoinAggregationV2` version.
  - `interfaces/`: Interfaces used throughout the aggregation contracts.
- `test/`: Full coverage testing over both the aggregation contracts. Includes end-to-end testing with a mocked witness generation over the circuit, unit testing, and fuzzes (where relevant).

### Getting Started

Clone this repository (and git submodule dependencies) with:

```bash
git clone --recursive git@github.com:axiom-crypto/worldcoin-aggregation.git
cd worldcoin-aggregation
cp .env.example .env
```

To run the tests, fill in `.env` with your `PROVIDER_URI_11155111`. This must be a Sepolia RPC.

Run the tests with

```bash
forge test
```
