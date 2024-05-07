import {
  add,
  sub,
  mul,
  div,
  checkLessThan,
  addToCallback,
  CircuitValue,
  CircuitValue256,
  constant,
  witness,
  getAccount,
} from "@axiom-crypto/client";

// For type safety, define the input types to your circuit here.
// These should be the _variable_ inputs to your circuit. Constants can be hard-coded into the circuit itself.
export interface CircuitInputs {
  grantId: CircuitValue256;
  root: CircuitValue256;
  receivers: CircuitValue[];
  claimedNullifierHashes: CircuitValue256[];
}

// Default inputs to use for compiling the circuit. These values should be different than the inputs fed into
// the circuit at proving time.
export const defaultInputs = {
  "grantId": "0xfd3a1e9736c12a5d4a31f26362b577ccafbd523d358daf40cdc04d90e17f77",
  "root": "0x1d0372864732dfcd91c18414fd4126e1e38293be237aad4315a026bf23d02717",
  "receivers": ["0x0000000000000000000000000000000000787878"],
  "claimedNullifierHashes": ["0x4b7790813c37c910b41236334ce9b1841d430e3b4874e89778e1afd0fd3a7b6"]
};

export const circuit = async (inputs: CircuitInputs) => {
  const numClaims = 1;

  // Validate that the block number is greater than the number of samples times the spacing
  if (inputs.receivers.length != numClaims || inputs.claimedNullifierHashes.length != numClaims) {
    throw new Error("Incorrect input lengths");
  }

  // TODO: We make the circuit a pure pass-through for now.

  addToCallback(inputs.grantId);
  addToCallback(inputs.root);
  for (const receiver of inputs.receivers) {
    addToCallback(receiver);
  }
  for (const claimedNullifierHash of inputs.claimedNullifierHashes) {
    addToCallback(claimedNullifierHash);
  }
};