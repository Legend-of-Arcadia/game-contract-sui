import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner } from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + `/../.env` }); 

const mugenPrivKey: string = process.env.PRIVATE_KEY!;
const playerPrivKey: string = process.env.PLAYER_PRIVATE_KEY!;
const packageId = process.env.PACKAGE!;
const gameCap = process.env.GAME_CAP!;
const upgrader = process.env.UPGRADER!;

let keyPair = getKeyPair(mugenPrivKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);

/// helper to make keypair from private key that is in string format
function getKeyPair(privateKey: string): Ed25519Keypair{
  // let privateKeyArray = Array.from(fromB64(privateKey));
  // privateKeyArray.shift();
  //return Ed25519Keypair.fromSecretKey(Uint8Array.from(privateKeyArray));
  return Ed25519Keypair.fromSecretKey(Buffer.from(privateKey.slice(2), "hex"), { skipValidation: true });
}

async function upgradeAppearance(playerAddress: string) {

  let txb = new TransactionBlock();

  let [hero, returnTicket] = txb.moveCall({
    target: `${packageId}::game::get_for_upgrade`,
    arguments: [
      txb.object(gameCap),
      txb.pure(playerAddress),
      txb.object(upgrader),
    ]
  });

  txb.moveCall({
    target: `${packageId}::game::upgrade_appearance`,
    arguments: [
      txb.object(gameCap),
      hero,
      txb.pure([200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211]),
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

// subscribe to makeover events and makeover the hero once the event is emitted
async function subscribeToMakeoverEvents() {

    await provider.subscribeEvent({
      filter: { MoveEventType: `${packageId}::game::MakeoverRequest` },
      onMessage(event) {
        console.log(event.parsedJson?.player_address)
        upgradeAppearance(event.parsedJson?.player_address);
      },
    })
  }

async function main(){
  // await subscribeToMakeoverEvents();
  await upgradeAppearance("0x0421a66d58e4acd151ec50a2c5aa6219ca3c13d18df816c6e93b0b7838e26f65");
}

main();
