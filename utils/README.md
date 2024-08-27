## Onchain Testing Utilities
### Generate Merkle SisterNodes Info
```
npm/pnpm/yarn install
npx ts-node src/merkleSisterNodes.ts {input_path} {claim_index}
```
This command will create a file named `claim.json` which can be used to create a claim transaction for the `WorldcoinAggregationV2`.

### Crawl real claims data for testing
```
export PROVIDER_URI={$OP_PROVIDER_URI}
npm/pnpm/yarn install
npx ts-node src/crawlProofData.ts {max_proofs}
```
This command will crawl up to `max_proofs` for a certain `grantId` and `root`, generating a file named `real_proofs_{max_proofs}.json`.