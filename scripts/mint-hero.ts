import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner, devnetConnection} from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config();

const privKey: string = process.env.PRIVATE_KEY as string;
const gameCapId = process.env.GAME_CAP as string;
const packageId = process.env.PACKAGE as string;
const upgraderId = process.env.UPGRADER as string;
// cli path is "sui"

/// helper to make keypair from private key that is in string format
function getKeyPair(privateKey: string): Ed25519Keypair{
  let privateKeyArray = Array.from(fromB64(privateKey));
  privateKeyArray.shift();
  return Ed25519Keypair.fromSecretKey(Uint8Array.from(privateKeyArray));
}

let keyPair = getKeyPair(privKey);
let provider = new JsonRpcProvider(devnetConnection);
let mugen = new RawSigner(keyPair, provider);

async function mintHero() {
  let baseValues = [1, 2, 3, 4, 5, 6];
  let skillValues = [200, 201, 202, 203];
  let appearenceValues = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111];
  let statValues = [40, 0, 0, 0, 0, 0, 0, 0];
  let otherValues = [34];
  let txb = new TransactionBlock();

  

  let hero = txb.moveCall({
    target: `${packageId}::game::mint_hero`,
    arguments: [
      txb.object(gameCapId),
      txb.pure("Wo Long", "string"),
      txb.pure("Assassin", "string"),
      txb.pure("Flamexecuter"),
      txb.pure("R"),
      txb.pure(baseValues),
      txb.pure(skillValues),
      txb.pure(appearenceValues),
      txb.pure(statValues),
      txb.pure(otherValues),
      txb.pure("1337", "string"),
    ]
  });

  txb.transferObjects([hero], txb.pure(keyPair.getPublicKey().toSuiAddress()));

  let result = await mugen.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
      showObjectChanges: true
    },
  });

  return result;

}

async function main() {

  let result = await mintHero();
  console.log(JSON.stringify(result));
}

main();

