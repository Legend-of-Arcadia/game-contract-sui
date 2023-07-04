import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner } from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + `/../.env` }); 

const mugenPrivKey: string = process.env.PRIVATE_KEY!;
const playerPrivKey: string = process.env.PLAYER_PRIVATE_KEY!;
const packageId = process.env.PACKAGE!;
const gameCap = process.env.GAME_CAP!;
const upgrader = process.env.UPGRADER!;
const objBurn = process.env.OBJBURN!;

/// helper to make keypair from private key that is in string format
function getKeyPair(privateKey: string): Ed25519Keypair{
  // let privateKeyArray = Array.from(fromB64(privateKey));
  // privateKeyArray.shift();
  //return Ed25519Keypair.fromSecretKey(Uint8Array.from(privateKeyArray));
  return Ed25519Keypair.fromSecretKey(Buffer.from(privateKey.slice(2), "hex"), { skipValidation: true });
}

// helper to find gacha ball ID from transaction result
function getGachaBallId(mintResult: any) {
  let [hero]: any = mintResult.objectChanges?.filter((objectChange: any) => (objectChange.type === "created" && objectChange.objectType == `${packageId}::gacha::GachaBall`));
  let heroId = hero.objectId;
  return heroId;
}

let keyPair = getKeyPair(mugenPrivKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);
let playerKeyPair = getKeyPair(playerPrivKey);
let player = new RawSigner(playerKeyPair, provider);
let playerAddress = playerKeyPair.getPublicKey().toSuiAddress();


// mint a gacha ball and send it to a player
async function mintGachaBall() {

  let txb = new TransactionBlock();

  let gachaBall = txb.moveCall({
    target: `${packageId}::game::mint_gacha`,
    arguments: [
      txb.object(gameCap),
      txb.pure(19999),
      txb.pure("Haloween", "string"),
      txb.pure("Grandia", "string"),
      txb.pure("VIP"),
    ],
  });

  txb.transferObjects([gachaBall], txb.pure(playerAddress));

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

// player opens the gacha ball
async function openGachaBall(gachaBallId: string) {

  let txb = new TransactionBlock();

  txb.moveCall({
    target: `${packageId}::game::open_gacha_ball`,
    arguments: [
      txb.object(gachaBallId),
      txb.object(objBurn),
    ],
  });

  let result = await player.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
      showObjectChanges: true
    },
  });

  return result;
}


async function main(){
  let result1 = await mintGachaBall();
  console.log(result1);
  let gachaBallId = getGachaBallId(result1);

  let result2 = await openGachaBall(gachaBallId);

  console.log(result2);
}

main();