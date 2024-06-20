# Worldcoin Aggregation

This repo contains the implementation of smart contracts and client circuits designed to aggregate multiple Worldcoin grant WorldID proofs into a single, succinct proof. The circuits are developed in Rust using Halo2. The smart contracts are designed to be called back by AxiomV2Query after it has verified the proofs.

The proof aggregation enables a more cost-effective distribution of the grant.

There are two versions of the smart contracts/circuits:

- `WorldcoinAggregationV1`: After proof verification, all the receivers in the batch immediately have their grant transferred to them.
- `WorldcoinAggregationV2`: After proof verification, the receivers (or someone on their behalf) can prove into a Merkle root and transfer the grant to the receiver.

## Repository Overview

- `client-circuit/`
  - README.md: The client circuit documentation can be found in its own README.
- `src/`
  - `WorldcoinAggregationV1.sol`: The smart contract for the `WorldcoinAggregationV1` version.
  - `WorldcoinAggregationV2.sol`: The smart contract for the `WorldcoinAggregationV2` version.
  - `interfaces/`: Interfaces used throughout the aggregation contracts.
- `test/`: Full coverage testing over both the aggregation contracts. Includes end-to-end testing with a mocked witness generation over the circuit, unit testing, and fuzzes (where relevant).

## Contract Documentation

#### `MAX_PROOFS`

The `MAX_PROOFS` constant is used in both circuits and indicates the maximum number of Worldcoin WorldID proofs that can be aggregated into a single run of the circuit.

### `WorldcoinAggregationV1.sol`

V1 of the aggregation contract automatically transfers the grant amount to each of the users in the batch in the same tx as the verification. From a UX perspective, this requires no action on the part of the user to receive the grant.

The Axiom callback provides the contract with the public outputs of the SNARK verification through `axiomResults`.

```solidity
function _axiomV2Callback(
        uint64, // sourceChainId,
        address, // caller,
        bytes32, // querySchema,
        uint256, // queryId,
        bytes32[] calldata axiomResults,
        bytes calldata // extraData
    ) internal override
```

The contract has a constant `MAX_NUM_CLAIMS` which is always equal to `MAX_PROOFS`.

The `axiomResults` array must have `4 + 2 * MAX_NUM_CLAIMS` items. The expected results to be returned from the Axiom query are:

```
- axiomResults[0]: vkeyHash
- axiomResults[1]: grantId
- axiomResults[2]: root
- axiomResults[3]: numClaims
- axiomResults[idx] for idx in [4, 4 + numClaims): receivers
- axiomResults[idx] for idx in [4 + MAX_NUM_CLAIMS, 4 + MAX_NUM_CLAIMS + numClaims): claimedNullifierHashes
```

The SNARK verification proves two statements in zk:

1. The `receiver`s and associated `claimedNullifierHashes` have valid WorldID proofs for the grant (Axiom subquery).
2. The `vkeyHash`, `grantId`, and `root` are associated with the `receiver`'s specific proof (client circuit).

#### Insufficient `WLD` Balance on Batch Claims

If during a batch claim, the contract does not contain sufficient `WLD` to service the entire batch, the tx will be reverted. This was done for the simplicity of a re-execution after a balance top-off (instead of reconstructing a new proof for the unprocessed subset of the batch).

### `WorldcoinAggregationV2.sol`

V2 of the aggregation contract implements a two-step process to distribute the grant. The SNARK verification callback will only commit a root for the receivers to prove against. This root is of a tree with leaves `abi.encodePacked(address(receiver), bytes32(nullifierHash))`. Once the commitment is complete, the burden is on the receiver (or someone their behalf) to prove into the root and transfer the grant to the receiver.

The Axiom callback provides the contract with the public outputs of the SNARK verification through `axiomResults`.

```solidity
function _axiomV2Callback(
        uint64, // sourceChainId,
        address, // caller,
        bytes32, // querySchema,
        uint256, // queryId,
        bytes32[] calldata axiomResults,
        bytes calldata // extraData
    ) internal override
```

The `axiomResults` array must have 4 items. The expected results to be returned from the Axiom query are:

```
- axiomResults[0]: vkeyHash
- axiomResults[1]: grantId
- axiomResults[2]: root
- axiomResults[3]: claimsRoot
```

The SNARK verification proves two statements in zk:

1. There is a set of `receiver`s and associated `nullifierHash`es. The `vkeyHash`, `grantId`, and `root` are associated with all the `receiver`s' specific proofs. Additionally, the `claimsRoot` is the Keccak Merkle root of `abi.encodePacked(address(receiver), bytes32(nullifierHash))` (client circuit).
2. The `receiver`s and associated `nullifierHash`es that the `claimsRoot` commits to have valid WorldID proofs for the grant (Axiom subquery).

#### Merkle Proof Data Packing

The `claim()` function requires passing a Merkle proof:

```solidity
    function claim(
        uint256 grantId,
        uint256 root,
        address receiver,
        bytes32 nullifierHash,
        bytes32[] calldata leaves,
        bytes32 isLeftBytes
    ) external {
      ... snip ...
    }
```

_The tree generated by the circuit does not sort its leaves._

On a Merkle tree with unsorted leaves, verification requires the leaves and boolean value for each leaf indicating whether it is a right or left child. While the boolean values could have been encoded in a `bool[] calldata isLeft`, for improved calldata usage, the boolean values are packed into a `bytes32`.

Each byte (not bit!) maps to a leaf's `isLeft` flag. Note that this means proofs of size larger than 32 cannot be supported here, but a Merkle tree of size 2 \*\* 32 is more than sufficient.

Index 0 in the `leaves` array will map the most significant byte of the `bytes32 isLeftBytes` word.

### Unsafe Calldata Array Access

Because of explicit length checks the aggregation contracts make on calldata arrays, accessing calldata arrays without bounds checks can be performed safely. For improved gas-efficiency, calldata arrays are accessed through assembly, skipping the bounds checks inlined by Solidity.

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
