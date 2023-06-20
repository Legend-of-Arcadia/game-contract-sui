import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner} from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config();

const privKey: string = process.env.MY_PRIVATE_KEY!;
// const gameCapId = process.env.GAME_CAP_ID!;
// const packageId = process.env.PACKAGE_ID!;
const gameCapId = "0x704ed0b3e69bf59b4e16cf89550a0a4377d62dcc8128846886dc9199e8f6a082"
const packageId = "0x9e3ecb3a6958fc96bd9d848e15e40a232db7059660c1c2943ee2c5d543220310"
// cli path is "sui"

/// helper to make keypair from private key that is in string format
function getKeyPair(privateKey: string): Ed25519Keypair{
  let privateKeyArray = Array.from(fromB64(privateKey));
  privateKeyArray.shift();
  return Ed25519Keypair.fromSecretKey(Uint8Array.from(privateKeyArray));
}

let keyPair = getKeyPair(privKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);

async function mintHero() {
  let txb = new TransactionBlock();

  let baseValues = [1, 2, 3, 4, 5, 6];
  let skillValues = [200, 201, 202, 203];
  let appearenceValues = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111];
  let statValues = [40, 0, 0, 0, 0, 0, 0, 0];
  let otherValues = [34];

  let [hero] = txb.moveCall({
    target: `${packageId}::game::mint_hero`,
    arguments: [
      txb.object(gameCapId),
      txb.pure("Wo Long"),
      txb.pure("Assassin"),
      txb.pure("Flamexecuter"),
      txb.pure("R"),
      txb.pure(baseValues),
      txb.pure(skillValues),
      txb.pure(appearenceValues),
      txb.pure(statValues),
      txb.pure(otherValues),
      txb.pure("1337"),
    ]
  });

  txb.transferObjects([hero], txb.pure(keyPair.getPublicKey().toSuiAddress()));

  let result = await mugen.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
    },
  });

  return result;

}

async function main() {

  let result = await mintHero();
  console.log(result);
}

main();

