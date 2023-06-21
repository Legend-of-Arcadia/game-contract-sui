// after the hero is put for upgrade by the player, mugen upgrades the hero
import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner} from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config();

const privKey: string = process.env.MY_PRIVATE_KEY!;
// const gameCapId = process.env.GAME_CAP_ID!;
// const packageId = process.env.PACKAGE_ID!;
const gameCapId = "0x704ed0b3e69bf59b4e16cf89550a0a4377d62dcc8128846886dc9199e8f6a082"
const packageId = "0x9e3ecb3a6958fc96bd9d848e15e40a232db7059660c1c2943ee2c5d543220310"
const upgraderId = "0xec59bd25fce6f835d647cd7c458844171700db7addc620903f902cfa2b564292"
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

async function upgradeHeroOfPlayer(playerAddress: String){

  let txb = new TransactionBlock();

  let [hero, returnTicket] = txb.moveCall({
    target: `${packageId}::game::get_for_upgrade`,
    arguments: [
      txb.object(gameCapId),
      txb.pure(playerAddress),
      txb.object(upgraderId),
    ]
  });

  let newAppearenceValues = [200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211];

  txb.moveCall({
    target: `${packageId}::game::upgrade_appearance`,
    arguments: [
      txb.object(gameCapId),
      hero,
      txb.pure(newAppearenceValues),
    ]
  });

  txb.moveCall({
    target: `${packageId}::game::return_upgraded_hero`,
    arguments: [
      hero,
      returnTicket,
    ]
  });

  let result = await mugen.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
      showObjectChanges: true,
    },
  });

  return result;

}



async function main() {

  let address = "0x6f2d5e80dd21cb2c87c80b227d662642c688090dc81adbd9c4ae1fe889dfaf71";
  let result = await upgradeHeroOfPlayer(address);
  console.log(result);
}

main();
