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

// helper to find hero ID from transaction result
function getHeroId(mintResult: any) {
  let [hero]: any = mintResult.objectChanges?.filter((objectChange: any) => (objectChange.type === "created" && objectChange.objectType == `${packageId}::hero::Hero`));
  let heroId = hero.objectId;
  return heroId;
}

let keyPair = getKeyPair(privKey);
let provider = new JsonRpcProvider(devnetConnection);
let mugen = new RawSigner(keyPair, provider);

async function airdrop(addresses: string[]) {
  let txb = new TransactionBlock();

  let baseValues = [1, 2, 3, 4, 5, 6];
  let skillValues = [200, 201, 202, 203];
  let appearenceValues = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111];
  let statValues = [40, 0, 0, 0, 0, 0, 0, 0];
  let otherValues = [34];

  let total = addresses.length;
  let count = 0;
  
  for (let i = 0; i < total; i++) {
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

    txb.transferObjects([hero], txb.pure(addresses[i]));
  }

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
  let addresses = ['0x0ba6a2ea5e021ba771c882b65dccccd37131b2e68816de2d39f90a20864ab413', '0x1378f860144a2ab2e34622009e4a11b9228d245e444b0caf6289096206cbd496', '0x5fc4018050c3f30499bcd7e18b028596bd5f25557080725f1fd586a6d5def2b1', '0x611ae9aba751de462aa8347a0d4428584193a64373bb717e389f17c8df21a52b'];

  let result = await airdrop(addresses);
  console.log(result);
}

main();
