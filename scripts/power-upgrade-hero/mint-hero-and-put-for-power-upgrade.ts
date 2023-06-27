import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner, SUI_FRAMEWORK_ADDRESS} from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + `/../.env` }); 


const mugenPrivKey: string = process.env.PRIVATE_KEY!;
const playerPrivKey: string = process.env.PLAYER_PRIVATE_KEY!;
const packageId = process.env.PACKAGE!;
const gameCap = process.env.GAME_CAP!;
const TreasuryCap = process.env.TREASURY_CAP!;
const upgrader = process.env.UPGRADER!;

/// helper to make keypair from private key that is in string format
function getKeyPair(privateKey: string): Ed25519Keypair{
  let privateKeyArray = Array.from(fromB64(privateKey));
  privateKeyArray.shift();
  return Ed25519Keypair.fromSecretKey(Uint8Array.from(privateKeyArray));
}

// helper to arca coin ID from transaction result
function getArcaCoinId(result: any) {
  let [hero]: any = result.objectChanges?.filter((objectChange: any) => (objectChange.type === "created" && objectChange.objectType == `${SUI_FRAMEWORK_ADDRESS}::coin::Coin<${packageId}::arca::ARCA>`));
  let heroId = hero.objectId;
  return heroId;
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

// mint a hero and send it to the player
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

// mint exact amount of ARCA needed, send them to the player
// hero we mint has rarity "R", we will burn 2 heroes, so we need 6_666_000_000 ARCA
async function mintAndTransferArca() {

  let txb = new TransactionBlock();

  txb.moveCall({
    target: `${SUI_FRAMEWORK_ADDRESS}::coin::mint_and_transfer`,
    arguments: [ 
      txb.object(TreasuryCap),
      // 6_666_000_000
      txb.pure("6666000000", "u64"),
      txb.pure(playerAddress, "address")
    ],
    typeArguments: [`${packageId}::arca::ARCA`]
  });

  txb.setGasBudget(100000000);

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

async function putForPowerUpgrade(heroId: string, heroesIds: string[], arcaCoinId: string) {

  let txb = new TransactionBlock();

  let heroes = txb.makeMoveVec( { objects: heroesIds.map((heroId) => txb.object(heroId))});

  txb.moveCall({
    target: `${packageId}::game::power_upgrade_hero`,
    arguments: [
      txb.object(heroId),
      heroes,
      txb.object(arcaCoinId),
      txb.object(upgrader),
    ]
  });

  txb.setGasBudget(100000000);

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
  let mintResult1 = await mintHero();
  let mintResult2 = await mintHero();
  let mintResult3 = await mintHero();

  let mainHeroId = getHeroId(mintResult1);
  let heroId1 = getHeroId(mintResult2);
  let heroId2 = getHeroId(mintResult3);

  let heroes = [heroId1, heroId2];

  let arcaResult = await mintAndTransferArca();
  let arcaCoinId = getArcaCoinId(arcaResult);

  let result = await putForPowerUpgrade(mainHeroId, heroes, arcaCoinId);
  console.log(result);
}

main();