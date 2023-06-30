// exactly the same as upgrade but we are listening to PowerUpgradeReques event
import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner } from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + `/../.env` }); 

const mugenPrivKey: string = process.env.PRIVATE_KEY!;
const packageId = process.env.PACKAGE!;
const gameCap = process.env.GAME_CAP!;
const upgrader = process.env.UPGRADER!;

let keyPair = getKeyPair(mugenPrivKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);

/// helper to make keypair from private key that is in string format
function getKeyPair(privateKey: string): Ed25519Keypair{
  let privateKeyArray = Array.from(fromB64(privateKey));
  privateKeyArray.shift();
  return Ed25519Keypair.fromSecretKey(Uint8Array.from(privateKeyArray));
}

async function upgradeHero(playerAddress: string) {

  let txb = new TransactionBlock();

  let [hero, returnTicket] = txb.moveCall({
    target: `${packageId}::game::get_for_upgrade`,
    arguments: [
      txb.object(gameCap),
      txb.pure(playerAddress),
      txb.object(upgrader),
    ]
  });

  // upgrade growths
  txb.moveCall({
    target: `${packageId}::game::upgrade_growth`,
    arguments: [
      txb.object(gameCap),
      hero,
      txb.pure([50, 1, 1, 1, 1, 1, 1, 1]),
    ]
  });

  txb.moveCall({
    target: `${packageId}::game::return_upgraded_hero`,
    arguments: [
      hero,
      returnTicket,
    ]
  });

  const result = await mugen.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
      showObjectChanges: true
    },
  });

  console.log(result);
  return result;

}

// subscribe to power upgrade events and upgrade the hero once the event is emitted
async function subscribeToMakeoverEvents() {

    await provider.subscribeEvent({
      filter: { MoveEventType: `${packageId}::game::PowerUpgradeRequest`},
      onMessage(event) {
        console.log(event.parsedJson?.user)
        upgradeHero(event.parsedJson?.user);
        console.log("Hero upgraded!")
      },
    })
  }

async function main(){
  await subscribeToMakeoverEvents();

}

main();
