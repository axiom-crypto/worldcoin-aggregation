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
  vkeyHash: CircuitValue256;
  grantId: CircuitValue256;
  root: CircuitValue256;
  claimsRoot: CircuitValue256;
}

// Default inputs to use for compiling the circuit. These values should be different than the inputs fed into
// the circuit at proving time.
export const defaultInputs = {
  "vkeyHash": "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
  "grantId": "0xfd3a1e9736c12a5d4a31f26362b577ccafbd523d358daf40cdc04d90e17f77",
  "root": "0x1d0372864732dfcd91c18414fd4126e1e38293be237aad4315a026bf23d02717",
  "claimsRoot": "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
};

export const circuit = async (inputs: CircuitInputs) => {
  const logMaxNumClaims = 1;

  // TODO: We make the circuit a pure pass-through for now.

  addToCallback(inputs.vkeyHash);
  addToCallback(inputs.grantId);
  addToCallback(inputs.root);
  addToCallback(inputs.claimsRoot);
};