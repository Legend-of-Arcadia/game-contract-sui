import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner} from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config();


const mugenPrivKey: string = process.env.PRIVATE_KEY!;
const playerPrivKey: string = process.env.PLAYER_PRIVATE_KEY!;
const packageId = process.env.PACKAGE!;
const gameCap = process.env.GAME_CAP!;
const config = process.env.GAME_CONFIG!;

/// helper to make keypair from private key that is in string format
function getKeyPair(privateKey: string): Ed25519Keypair{
  // let privateKeyArray = Array.from(fromB64(privateKey));
  // privateKeyArray.shift();
  //return Ed25519Keypair.fromSecretKey(Uint8Array.from(privateKeyArray));
  return Ed25519Keypair.fromSecretKey(Buffer.from(privateKey.slice(2), "hex"), { skipValidation: true });
}

let keyPair = getKeyPair(mugenPrivKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);
console.log("mugen address: ", keyPair.getPublicKey().toSuiAddress());
let playerKeyPair = getKeyPair(playerPrivKey);
let player = new RawSigner(playerKeyPair, provider);
console.log("player address: ", playerKeyPair.getPublicKey().toSuiAddress());


// address of whitelisted player
const playerAddress = playerKeyPair.getPublicKey().toSuiAddress();

// mint two heroes and one gacha ball
// here the two heroes have the same attributes, this can be changed
async function mintForWhitelistedPlayer(playerAddress: string){

  let baseValues = [1, 2, 3, 4, 5, 6];
  let skillValues = [200, 201, 202, 203];
  let appearenceValues = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111];
  let growthValues = [40, 0, 0, 0, 0, 0, 0, 0];
  //let otherValues = [34];
  let txb = new TransactionBlock();

  

  let hero1 = txb.moveCall({
    target: `${packageId}::game::mint_hero`,
    arguments: [
      txb.object(gameCap),
      txb.pure("Wo Long", "string"),
      txb.pure("Assassin", "string"),
      txb.pure("Flamexecuter"),
      txb.pure("R"),
      txb.pure(baseValues),
      txb.pure(skillValues),
      txb.pure(appearenceValues),
      txb.pure(growthValues),
      //txb.pure(otherValues),
      txb.pure("1337", "string"),
    ]
  });

  let hero2 = txb.moveCall({
    target: `${packageId}::game::mint_hero`,
    arguments: [
      txb.object(gameCap),
      txb.pure("Wo Long", "string"),
      txb.pure("Assassin", "string"),
      txb.pure("Flamexecuter"),
      txb.pure("R"),
      txb.pure(baseValues),
      txb.pure(skillValues),
      txb.pure(appearenceValues),
      txb.pure(growthValues),
      //txb.pure(otherValues),
      txb.pure("1337", "string"),
    ]
  });

  let heroes = txb.makeMoveVec({ objects: [hero1, hero2]});

  let gacha_id = 19999
  let gachaBall = txb.moveCall({
    target: `${packageId}::game::mint_gacha`,
    arguments: [
      txb.object(gameCap),
      txb.pure(gacha_id),
      txb.pure("Haloween collection", "string"),
      txb.pure("Grandia", "string"),
      txb.pure("elite"),
    ]
  });

  let gachaBalls = txb.makeMoveVec({ objects: [gachaBall]});

  txb.moveCall({
    target: `${packageId}::game::whitelist_add`,
    arguments: [
      txb.object(gameCap),
      txb.pure(playerAddress, "address"),
      heroes,
      gachaBalls,
      txb.object(config),
    ]
  });

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

async function claimWhitelistRewards(playerAddress: string){

  let txb = new TransactionBlock();

  txb.moveCall({
    target: `${packageId}::game::whitelist_claim`,
    arguments: [
      txb.object(config),
    ]
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
  // let mintForWhitelistedResult = await mintForWhitelistedPlayer(playerAddress);
  var fs = require('fs');
  // fs.writeFile(`./auto-results/mintForWhitelistedResult.json`, JSON.stringify(mintForWhitelistedResult, null, 2), function(err: any) {
  //   if (err) {
  //       console.log(err);
  //   }
  // });

  let claimWhitelistRewardsResult = await claimWhitelistRewards(playerAddress);
  fs.writeFile(`./auto-results/claimWhitelistRewardsResult.json`, JSON.stringify(claimWhitelistRewardsResult, null, 2), function(err: any) {
    if (err) {
        console.log(err);
    }
  });

  }

main();