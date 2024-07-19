# Batch WorldID proof verification with Axiom

This repo integrates [WorldID](https://worldcoin.org/world-id) proof verification into [Axiom](https://docs.axiom.xyz/) to enable:

- Cheaper batch claims of WLD grants by aggregating multiple WorldID proofs at once.
- Composition of WorldID proofs with facts about on-chain history enabled by Axiom.

These are implemented via two components:

- Axiom client circuits written using the [Axiom Rust SDK](https://docs.axiom.xyz/sdk/rust-sdk/axiom-rust) that make use of newly added Groth16 verification and ECDSA primitives.
- Smart contracts implementing WLD grant claims based on batch-verified WorldID proof results from Axiom.

In what follows, we describe two different flows for WLD grants using this integration.

## Worldcoin Grant Protocol

We implement two versions of WLD grants based on batch verification of WorldID proofs.

- `WorldcoinAggregationV1`: After proof verification, all the receivers in the batch immediately have their grant transferred to them.
- `WorldcoinAggregationV2`: After proof verification, the receivers (or someone on their behalf) can prove into a Merkle root and transfer the grant to the receiver.

These two versions trade off UX and cost to the grantee, and we will recommend a final design after benchmarking concrete costs.

### Grant Protocol V1

In the V1 design, the grant contract automatically transfers the grant amount to each of the users in the batch in the same transaction as the verification. This design means users do not need to make an additional on-chain transaction to receive the grant, but incurs additional calldata and transfer cost for each grantee.

The V1 grant contract supports at most `MAX_NUM_CLAIMS` at once, and receives the following `4 + 2 * MAX_NUM_CLAIMS` ZK-verified quantities in a callback from Axiom:

```
- axiomResults[0]: vkeyHash
- axiomResults[1]: grantId
- axiomResults[2]: root
- axiomResults[3]: numClaims
- axiomResults[idx] for idx in [4, 4 + numClaims): receivers
- axiomResults[idx] for idx in [4 + MAX_NUM_CLAIMS, 4 + MAX_NUM_CLAIMS + numClaims): claimedNullifierHashes
```

Axiom verifies in ZK that:

1. For `0 <= idx < numClaims`, there are valid WorldID proofs corresponding to `(grantId, receivers[idx], root, claimedNullifierHashes[idx])`.

The V1 grants contract then:

- checks the `vkeyHash` for the WorldID Groth16 proof is valid
- checks the `grantId` is valid
- checks for each claiming grantee that the nullifier hash was not previously used
- sends `WLD` to fulfill the claim

To simplify re-execution in the case of insufficient `WLD` balance, claims are all-or-nothing -- if the contract has insufficient `WLD` to fulfill the entire batch, the entire claim transaction will be reverted.

### Grant Protocol V2

In the V2 design, the grant contract implements a two-step process to distribute the grant. Axiom is used to verify a Keccak Merkle root of a tree of eligible grant recipients with leaves given by `abi.encodePacked(receiver, nullifierHash)`. This Merkle root is stored on-chain, and grantees use ordinary Merkle proofs to prove eligibility and claim their grants.

The V2 grant contract supports at most `MAX_NUM_CLAIMS` at once, where `MAX_NUM_CLAIMS` must be a power of two. It receives the following 4 ZK-verified quantities in a callback from Axiom:

```
- axiomResults[0]: vkeyHash
- axiomResults[1]: grantId
- axiomResults[2]: root
- axiomResults[3]: claimsRoot
```

Axiom verifies in ZK that:

1. There is a value `1 <= numClaims <= MAX_NUM_CLAIMS` and arrays `receivers` and `claimedNullifierHashes` so that for `0 <= idx < numClaims`, there are valid WorldID proofs corresponding to `(grantId, receivers[idx], root, claimedNullifierHashes[idx])`.
2. The hash `claimsRoot` is the Keccak Merkle root of the tree with `MAX_NUM_CLAIMS` leaves, where the first `numClaims` leaves are given by `abi.encodePacked(receiver[idx], claimedNullifierHashes[idx])` and the remaining leaves are `abi.encodePacked(address(0), byte32(0))`.

The V2 grants contract then:

- checks the `vkeyHash` for the WorldID Groth16 proof is valid
- checks `grantId` is valid
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
        <snip>
    }
```

Note that we use a Keccak Merkle tree **without** sorting of child hashes, meaning the parent hash is given by `parent = keccak256(abi.encodePacked(left, right))`. This means Merkle proof verification requires an indication of whether each proof hash is a left or right child, which we encode in `bytes32 isLeftBytes` so that **byte** `idx` of `isLeftBytes` is `1` if and only if `leaves[idx]` is a left child.

## Test Deployments and Gas Benchmarks

To benchmark gas usage and give an end-to-end demo, we deployed `WorldcoinAggregationV1` and `WorldcoinAggregationV2` for sizes `8, 16, 32, 64 and 128` on Sepolia. Because the WLD token is not deployed on Sepolia, we mocked the WLD, RootValidator, and Grant contracts, as detailed below. After deployment, we initiated transactions for various batch sizes and measured amortized gas usage and calldata size.

Test data was generated using [semaphore-rs](https://github.com/worldcoin/semaphore-rs) with `depth_30` feature flag. Our profiling assumes that the grantees have a 0 balance for WLD. If the grantees are existing WLD holders, the WLD transfer will take 17.1K less gas, with the difference (20K - 2.9K) coming from the cost of the `SSTORE` opcode for updating grantee balances.

### Grant Protocol V1

We deployed Grant Protocol V1 on Sepolia for different sizes at the addresses below and also made a [sample fulfill transaction](https://sepolia.etherscan.io/tx/0xc8fca0877cfad47e85e2c12541ad7f843e6c8dea852606d5bdedfa3a897ddee3).

| Batch Size | Sepolia Address                                                                                                               | Query Schema                                                       |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| 8          | [0x0Af226d96d3f149875bec102D71779BcF58e2800](https://sepolia.etherscan.io/address/0x0Af226d96d3f149875bec102D71779BcF58e2800) | 0x50746826a6dbc18722f1d29c9d7fed067c1f05e43f00a3db58e6ed5e44b3aaa2 |
| 16         | [0x27ff9334e2b75b838baeb78618d12ced843c075d](https://sepolia.etherscan.io/address/0x27ff9334e2b75b838baeb78618d12ced843c075d) | 0xa72441820512403e5a2328a333facfbcafb0fad2cfbeb48c3c1d18771d8651d4 |
| 32         | [0xE3C5d7441890048C472c52167453f349b1216b87](https://sepolia.etherscan.io/address/0xE3C5d7441890048C472c52167453f349b1216b87) | 0x90730514b68638c0fdeaa0617db9b9392e7cc6ddacdf49529eeb7528cebc6dbd |
| 64         | [0xF81a28F081d7Cd5Ba695E43D4c8aB0A991f17982](https://sepolia.etherscan.io/address/0xF81a28F081d7Cd5Ba695E43D4c8aB0A991f17982) | 0x32b63d6d49fca4274bc54fd67b6c56750d62a02c4621df02f171a6d474b73549 |
| 128        | [0x5F9c52B43Fc8E2080463e6246318203596FCB887](https://sepolia.etherscan.io/address/0x5F9c52B43Fc8E2080463e6246318203596FCB887) | 0xe056466be31c1e1da8069412acf2f2d3dbd1de30d5e6a28db14c3440e7312fd3 |

We measured gas and calldata usage, shown in the table below. We also show gas attributed to proof verification, which excludes gas used for WLD token transfers and other business logic. On-chain \$ includes L1 and L2 gas. Our dollar cost estimates are based on an L2 gas cost of 0.06 gwei, L1 blob base fee of 1wei, and \$3000 ETH.

| # Claims | L2 Gas/Claim | Proof Gas/Claim | Calldata/Claim | On-chain \$/Claim |
| -------- | ------------ | --------------- | -------------- | ----------------- |
| 1        | 418K         | -               | 388            | \$0.0760          |
| 8        | 108K         | 56K             | 540            | \$0.0205          |
| 16       | 79K          | 29K             | 302            | \$0.0148          |
| 32       | 65K          | 15K             | 182            | \$0.0121          |
| 64       | 58K          | 8K              | 123            | \$0.0107          |
| 128      | 54K          | 4K              | 96             | \$0.0099          |

### Grant Protocol V2

We deployed Grant Protocol V2 on Sepolia for different sizes at the addresses below and also made a [sample fulfill Transaction](https://sepolia.etherscan.io/tx/0x063c0731e7feda726ff08a662fbe7361be66a323e5f9dd62b620fd509847310a) and [sample claim transaction](https://sepolia.etherscan.io/tx/0x94e34370d657d8c081effdab0a074f74815178d28f15546ca10702deb3a79cc3).

| Batch Size | Sepolia Address                                                                                                               | Query Schema                                                       |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| 8          | [0x051e0aB85c4Dfb90270FD45c93628c7F0b7551e7](https://sepolia.etherscan.io/address/0x051e0aB85c4Dfb90270FD45c93628c7F0b7551e7) | 0x6fc97d2f5193f179ff1e389b4224bf9012f423d0c22b320e0e25dab7e873fc4a |
| 16         | [0x3f88b9dc416ceadc36092673097ba456ba878cfb](https://sepolia.etherscan.io/address/0x3f88b9dc416ceadc36092673097ba456ba878cfb) | 0x87752627efc44b2115fa241910c349c817e36dd52551b056a6d8fbe60acef88e |
| 32         | [0x18c98598e77dBF52e897966b3b1980EB9195D496](https://sepolia.etherscan.io/address/0x18c98598e77dBF52e897966b3b1980EB9195D496) | 0x3da7061d2821c48ceadae96bc3acee5f9a56ca5dab914ac2a28670fb2cd264c4 |
| 64         | [0x7400fA7E1da16D995EC5F8F717a61D974C02BfAc](https://sepolia.etherscan.io/address/0x7400fA7E1da16D995EC5F8F717a61D974C02BfAc) | 0xaff21322e9a3ea94f3320b7d07824ccda23daad366c162744717b52b40c16e2c |
| 128        | [0x0CBb51Fd7fbfc36A342C3D35316B814C825EA552](https://sepolia.etherscan.io/address/0x0CBb51Fd7fbfc36A342C3D35316B814C825EA552) | 0xef586869ec64df0b82cc308f2be3f0150e6ce544dfc1ccc9b4e3c3386e5c3110 |

We measured gas and calldata usage, shown in the table below. We also show gas attributed to proof verification, which excludes gas used for WLD token transfers and other business logic. On-chain \$ includes L1 and L2 gas. Our dollar cost estimates are based on an L2 gas cost of 0.06 gwei, L1 blob base fee of 1wei, and \$3000 ETH.

| # Claims | L2 Gas/Claim | Proof Gas/Claim | Calldata/Claim | On-chain \$/Claim |
| -------- | ------------ | --------------- | -------------- | ----------------- |
| 1        | 418K         | -               | 388            | \$0.0760          |
| 8        | 147K         | 59K             | 801            | \$0.0281          |
| 16       | 118K         | 29K             | 595            | \$0.0224          |
| 32       | 105K         | 15K             | 507            | \$0.0200          |
| 64       | 97K          | 7K              | 480            | \$0.0185          |
| 128      | 95K          | 4K              | 482            | \$0.0179          |

For a given batch size, V2 consumes more gas than V1 per claim due to the additional claim transaction. As the batch size increases, the calldata/claim mostly decreases, reaching its minimum when the batch size is 64. After that the calldata/claim starts to increase due to increased calldata usage from the claim transaction.

### External Contracts for Testing

We deployed the following other contracts to mock different aspects of the Worldcoin system on Sepolia and run the integration into Axiom.

| Name              | Sepolia Address                                                                                                               | Description                                                                                                                                                                           |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AxiomV2Query      | [0x9C9CF878f9Ba4422BDD73B55554F0A796411D5ed](https://sepolia.etherscan.io/address/0x9C9CF878f9Ba4422BDD73B55554F0A796411D5ed) | [AxiomV2Query](https://docs.axiom.xyz/protocol/protocol-design/axiom-query-protocol/) fulfills queries with on-chain ZK proof verification and triggers callbacks to target contracts |
| WLDMock           | [0xe93D97b0Bd30bD61a9D02B0A471DbB329D5d1fd8](https://sepolia.etherscan.io/address/0xe93D97b0Bd30bD61a9D02B0A471DbB329D5d1fd8) | An ERC20 contract which mocks the WLD contract                                                                                                                                        |
| RootValidatorMock | [0x9c06c3F1deecb530857127009EBE7d112ecd0E3F](https://sepolia.etherscan.io/address/0x9c06c3F1deecb530857127009EBE7d112ecd0E3F) | A contract which implements the `IRootValidator` interface and never reverts on the the `requireValidRoot` call                                                                       |
| GrantMock         | [0x5d1F6aDfff773A2146f1f3c947Ddad1945103DaC](https://sepolia.etherscan.io/address/0x5d1F6aDfff773A2146f1f3c947Ddad1945103DaC) | A contract which implements the `IGrant` interface and nver reverts on the `checkValidity` call                                                                                       |

## Development and Testing

### Repository Overview

- `circuit/`
  - `README.md`: The client circuit documentation can be found in its own README.
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
