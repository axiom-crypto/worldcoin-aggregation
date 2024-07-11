import { JsonRpcProvider, ethers } from "ethers";
import * as fs from "fs";
import { abi } from "./abi";

const provider_uri = process.env.PROVIDER_URI;

const RECURRING_GRANT_DROP = "0x7b46ffbc976db2f94c3b3cdd9ebbe4ab50e3d77d";
const startBlock = 118371864;
const endBlock = 118372542;
const GRANT_ID = "30";
const ROOT =
  "12439333144543028190433995054436939846410560778857819700795779720142743070295";


async function getTransactionInput(maxProofs: number) {
  const provider = new JsonRpcProvider(provider_uri);
  const contract = new ethers.Contract(RECURRING_GRANT_DROP, abi, provider);

  const events = await contract.queryFilter(
    "GrantClaimed",
    startBlock,
    endBlock,
  );

  const claims: Claim[] = [];
  const seen_txs: String[] = [];
  const gasUsed: number[] = [];

  for (const event of events) {
    const txHash = event.transactionHash;
    if (txHash in seen_txs) {
      console.log(`${txHash} is seen before, skipping..`);
      continue;
    }
    seen_txs.push(txHash);
    const tx = await provider.getTransaction(txHash);
    if (tx?.to?.toLowerCase() !== RECURRING_GRANT_DROP.toLowerCase()) continue;

    const receipt = await provider.getTransactionReceipt(txHash);

    const data = tx?.data;

    const grantInterface = new ethers.Interface(abi);

    const decoded = grantInterface.parseTransaction({ data })?.args;

    if (!decoded) {
      throw new Error(`Fail to decode for tx ${txHash}`);
    }

    const [grant_id, receiver, root, nullifier_hash, proof] = decoded;

    if (grant_id.toString() !== GRANT_ID || root.toString() != ROOT) {
      continue;
    }

    console.log(`find one matching tx at block ${tx.blockNumber}`);

    const claim: Claim = {
      receiver,
      nullifier_hash: nullifier_hash.toString(),
      proof: proof.map((val: any) => val.toString()),
    };

    claims.push(claim);

    const gas = Number(receipt?.gasUsed);
    gasUsed.push(gas!);
    if (claims.length === maxProofs) break;
  }
  
  const request: WorldcoinRequest = {
    grant_id: GRANT_ID,
    root: ROOT,
    num_proofs: claims.length,
    max_proofs: maxProofs,
    claims,
  };

  const data_path = `../data/real_proofs_${maxProofs}.json`;
  const gas_report_path = `../data/gas_report_${maxProofs}.json`;

  fs.writeFileSync(data_path, JSON.stringify(request, null, 2), "utf8");
  const totalGas = gasUsed.reduce((accumulator, currentValue) => {
    return accumulator + currentValue;
  }, 0);
  const gasReport: GasReport = {
    gasUsed,
    totalGas,
    avgGas: totalGas / claims.length,
  };
  fs.writeFileSync(
    gas_report_path,
    JSON.stringify(gasReport, null, 2),
    "utf-8",
  );
}

const args = process.argv.slice(2);

const maxProofs = Number.parseInt(args[0]);

getTransactionInput(maxProofs);

interface WorldcoinRequest {
  root: string;
  grant_id: string;
  num_proofs: number;
  max_proofs: number;
  claims: Claim[];
}

interface Claim {
  receiver: string;
  nullifier_hash: string;
  proof: string[];
}

interface GasReport {
  gasUsed: number[];
  totalGas: number;
  avgGas: number;
}
