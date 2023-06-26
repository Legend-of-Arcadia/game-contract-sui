import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner } from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + `/../.env` }); 

const mugenPrivKey: string = process.env.PRIVATE_KEY!;
const playerPrivKey: string = process.env.PLAYER_PRIVATE_KEY!;
const packageId = process.env.PACKAGE!;
const gameCap = process.env.GAME_CAP!;
const upgrader = process.env.UPGRADER!;

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

let keyPair = getKeyPair(mugenPrivKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);
let playerKeyPair = getKeyPair(playerPrivKey);
let player = new RawSigner(playerKeyPair, provider);
let playerAddress = playerKeyPair.getPublicKey().toSuiAddress();

// mint a hero and send it to a player
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
      txb.object(gameCap),
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

  txb.transferObjects([hero], txb.pure(playerAddress));

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

// player puts their hero to makeover
async function putHeroToUpgrade(mainHeroId: string, heroesIds: string[]) {

  let txb = new TransactionBlock();

  let heroes = txb.makeMoveVec( {objects: heroesIds.map((heroId) => txb.object(heroId))});

  txb.moveCall({
    target: `${packageId}::game::upgrade_hero`,
    arguments: [
      txb.object(mainHeroId),
      heroes,
      txb.pure(upgrader),
    ]
  });

  txb.setGasBudget(10000000);

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


async function main() {

  let mintResult1 = await mintHero();
  let mintResult2 = await mintHero();
  let mintResult3 = await mintHero();

  let mainHeroId = getHeroId(mintResult1);
  let hero1Id = getHeroId(mintResult2);
  let hero2Id = getHeroId(mintResult3);

  let heroesIds = [hero1Id, hero2Id];
  
  let result = await putHeroToUpgrade(mainHeroId, heroesIds);
  console.log(result);
}

main();

