import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner} from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config();

const privKey: string = process.env.PRIVATE_KEY!;
const gameCapId = process.env.GAME_CAP!;
const packageId = process.env.PACKAGE!;

/// helper to make keypair from private key that is in string format
function getKeyPair(privateKey: string): Ed25519Keypair{
  // let privateKeyArray = Array.from(fromB64(privateKey));
  // privateKeyArray.shift();
  //return Ed25519Keypair.fromSecretKey(Uint8Array.from(privateKeyArray));
  return Ed25519Keypair.fromSecretKey(Buffer.from(privateKey.slice(2), "hex"), { skipValidation: true });
}

let keyPair = getKeyPair(privKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);

console.log(keyPair.getPublicKey().toSuiAddress());


async function mintNFT() {
  let txb = new TransactionBlock();

  let [gacha] = txb.moveCall({
    target: `${packageId}::game::mint_gacha`,
    arguments: [
      txb.object(gameCapId),
      txb.pure("19999", "u64"),
      txb.pure("initial collection", "string"),
      txb.pure("blue gacha", "string"),
      txb.pure("rare", "string"),
    ]
  });

  txb.transferObjects([gacha], txb.pure(keyPair.getPublicKey().toSuiAddress()));

  let response = await mugen.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
    },
  });

  return response;

}

async function main() {

  let response = await mintNFT();
  console.log(response);
}

main();

