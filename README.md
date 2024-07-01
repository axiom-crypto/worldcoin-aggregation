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

## Repository Overview

- `circuit/`
  - `README.md`: The client circuit documentation can be found in its own README.
- `src/`
  - `WorldcoinAggregationV1.sol`: The smart contract for the `WorldcoinAggregationV1` version.
  - `WorldcoinAggregationV2.sol`: The smart contract for the `WorldcoinAggregationV2` version.
  - `interfaces/`: Interfaces used throughout the aggregation contracts.
- `test/`: Full coverage testing over both the aggregation contracts. Includes end-to-end testing with a mocked witness generation over the circuit, unit testing, and fuzzes (where relevant).

## Development and Testing

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
