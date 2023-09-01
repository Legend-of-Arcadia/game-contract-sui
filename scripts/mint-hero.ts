import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner, Connection } from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config();

const privKey: string = process.env.PRIVATE_KEY as string;
const gameCapId = process.env.GAME_CAP as string;
const packageId = process.env.PACKAGE as string;
const objBurn = process.env.OBJBURN!;
// cli path is "sui"

/// helper to make keypair from private key that is in string format
function getKeyPair(privateKey: string): Ed25519Keypair{
  // let privateKeyArray = Array.from(fromB64(privateKey));
  // privateKeyArray.shift();
  //return Ed25519Keypair.fromSecretKey(Uint8Array.from(privateKeyArray));
  return Ed25519Keypair.fromSecretKey(Buffer.from(privateKey.slice(2), "hex"), { skipValidation: true });
}

const myConnection = new Connection({
  fullnode: 'https://sui-testnet.s.chainbase.online/v1/2Rs8715gJ07XaCoc6Y66jpCkZLV',
  faucet: 'https://faucet.testnet.sui.io/gas',
});
let keyPair = getKeyPair(privKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);

function getHeroId(mintResult: any) {
  let [hero]: any = mintResult.objectChanges?.filter((objectChange: any) => (objectChange.type === "created" && objectChange.objectType == `${packageId}::hero::Hero`));
  let heroId = hero.objectId;
  return heroId;
}
async function mintHero() {
  let baseValues = [1, 2, 3, 4, 5, 6];
  let skillValues = [200, 201, 202, 203];
  let appearenceValues = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111];
  let growthValues = [40, 0, 0, 0, 0, 0, 0, 0];
  //let otherValues = [34];
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
      txb.pure(growthValues),
      //txb.pure(otherValues),
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

async function mintGacha() {
  //    token_type: u64,
  //     collection: String,
  //     name: String,
  //     type: String,
  let token_type = 18888;
  let collection = "Boxes";
  let name = "test gacha";
  let type = "legend";
  let description = "Test gacha";
  //let otherValues = [34];
  let txb = new TransactionBlock();



  let hero = txb.moveCall({
    target: `${packageId}::game::mint_gacha`,
    arguments: [
      txb.object(gameCapId),
      txb.pure(token_type),
      txb.pure(collection),
      txb.pure(name),
      txb.pure(type),
      txb.pure(description),
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


async function mintItem() {
  let token_type = 9999;
  let collection = "item";
  let name = "test item";
  let type = "legend";
  let description = "Test Item";
  //let otherValues = [34];
  let txb = new TransactionBlock();



  let hero = txb.moveCall({
    target: `${packageId}::game::mint_item`,
    arguments: [
      txb.object(gameCapId),
      txb.pure(token_type),
      txb.pure(collection),
      txb.pure(name),
      txb.pure(type),
      txb.pure(description),
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

async function mintHeroAndCharge() {
  let result1 = await mintHero();
  let result2 = await mintHero();
  let result3 = await mintHero();

  let hero1Id = getHeroId(result1);
  let hero2Id = getHeroId(result2);
  let hero3Id = getHeroId(result3);

  let heroesIds = [hero1Id, hero2Id, hero3Id];

  let txb = new TransactionBlock();

  let heroes = txb.makeMoveVec( {objects: heroesIds.map((heroId) => txb.object(heroId))});

  txb.moveCall({
    target: `${packageId}::game::charge_hero`,
    arguments: [
      heroes,
      txb.pure(objBurn),
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

async function main() {

  // let result = await mintHero();
  // var fs = require('fs');
  // fs.writeFile(`./auto-results/mintHeroResult.json`, JSON.stringify(result, null, 2), function(err: any) {
  //   if (err) {
  //       console.log(err);
  //   }
  // });

  let mintGachaResult = await mintGacha();
  console.log(mintGachaResult)

  // let mintItemResult = await mintItem();
  // console.log(mintItemResult)

  // let chargeResult = await mintHeroAndCharge();
  // console.log(chargeResult)
}

main();

