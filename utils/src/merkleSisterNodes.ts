import { ZeroAddress, ethers } from "ethers";
import * as fs from "fs";

class MerkleTree {
  private leaves: string[];
  private layers: string[][];

  constructor(leaves: string[]) {
    this.leaves = leaves;
    this.layers = [this.leaves];
    this.buildTree();
  }

  private buildTree() {
    let currentLayer = this.leaves;
    while (currentLayer.length > 1) {
      const nextLayer: string[] = [];
      for (let i = 0; i < currentLayer.length; i += 2) {
        const packed = ethers.solidityPacked(
          ["bytes32", "bytes32"],
          [currentLayer[i], currentLayer[i + 1]],
        );

        nextLayer.push(ethers.keccak256(packed));
      }
      this.layers.push(nextLayer);
      currentLayer = nextLayer;
    }
  }

  public getRoot(): string {
    return this.layers[this.layers.length - 1][0];
  }

  public getSisterNodesPath(index: number): {
    sisterNodes: string[];
    isLeftBytes: boolean[];
  } {
    let sisterNodes: string[] = [];
    let isLeftBytes: boolean[] = [];
    let layerIndex = 0;

    while (layerIndex < this.layers.length - 1) {
      const layer = this.layers[layerIndex];
      const isLeftNode = index % 2 != 1;
      const siblingIndex = isLeftNode ? index + 1 : index - 1;

      if (siblingIndex < layer.length) {
        sisterNodes.push(layer[siblingIndex]);
        // isLeftBytes indicates whether the sibling is on the left side
        isLeftBytes.push(!isLeftNode);
      }

      index = Math.floor(index / 2);
      layerIndex++;
    }

    return { sisterNodes, isLeftBytes };
  }
}

function getKeccakHash(
  grantId: string,
  receiver: string,
  nullfilerHash: string,
) {
  const nullifierHashHex =
    "0x" + BigInt(nullfilerHash).toString(16).padStart(64, "0");

  const packed = ethers.solidityPacked(
    ["uint256", "address", "bytes32"],
    [BigInt(grantId), receiver, nullifierHashHex],
  );

  return ethers.keccak256(packed);
}

function boolArrayToByte32(boolArray: boolean[]): String {
  if (boolArray.length > 32) {
    throw new Error("Input array must have fewer than 32 boolean elements.");
  }

  const byteArray = new Uint8Array(32);

  for (let i = 0; i < boolArray.length; i++) {
    byteArray[i] = boolArray[i] ? 1 : 0;
  }

  return Array.from(byteArray)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function parseInput(inputPath: string): {
  leaves: string[];
  grantIds: string[];
  receivers: string[];
  nullifierHashes: string[];
  root: string;
  grantId: string;
} {
  const leaves: string[] = [];
  const grantIds: string[] = [];
  const receivers: string[] = [];
  const nullifierHashes: string[] = [];

  const fileContent = fs.readFileSync(inputPath, "utf8");

  const input = JSON.parse(fileContent);

  const claims = input.claims;
  for (const claim of claims) {
    leaves.push(
      getKeccakHash(claim.grant_id, claim.receiver, claim.nullifier_hash),
    );
    
    grantIds.push(claim.grant_id);
    receivers.push(claim.receiver);
    nullifierHashes.push(claim.nullifier_hash);
  }

  const num_proofs = input.num_proofs;
  const max_proofs = input.max_proofs;

  const padLeave = getKeccakHash("0", ZeroAddress.toString(), "0");
  for (let i = num_proofs; i < max_proofs; i++) {
    leaves.push(padLeave);
  }
  return {
    leaves,
    grantIds,
    receivers,
    nullifierHashes,
    root: input.root,
    grantId: input.grant_id,
  };
}

function main() {
  if (process.argv.length !== 4) {
    console.log(
      `Usage: npx ts-node merkleSisterNodes.ts {inputFilePath} {claimIndex}`,
    );
    process.exit(0);
  }
  const { leaves, grantIds, receivers, nullifierHashes, root } = parseInput(
    process.argv[2],
  );
  const claimIdx = parseInt(process.argv[3]);
  console.log("Claim Batch Root:", root);

  const tree = new MerkleTree(leaves);
  console.log("Merkle Root:", tree.getRoot());
  console.log(
    `Sister Nodes Path for index ${claimIdx} ${receivers[claimIdx]} with nullifierHash 0x${BigInt(nullifierHashes[claimIdx]).toString(16)} is:`,
  );
  let { sisterNodes, isLeftBytes } = tree.getSisterNodesPath(claimIdx);
  console.log(sisterNodes);
  console.log(`isLeftBytes is: ${boolArrayToByte32(isLeftBytes)}`);

  const claim = {
    grantId: `0x${BigInt(grantIds[claimIdx]).toString(16)}`,
    isLeftBytes: `${boolArrayToByte32(isLeftBytes)}`,
    nullifierHash: `0x${BigInt(nullifierHashes[claimIdx]).toString(16)}`,
    receiver: receivers[claimIdx],
    root,
    sisterNodes,
  };
  const json = JSON.stringify(claim, null, 2);

  fs.writeFileSync("claim.json", json);
}

main();
