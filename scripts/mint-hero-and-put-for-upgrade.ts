import { fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner, testnetConnection} from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config();

const privKey: string = process.env.PRIVATE_KEY as string;
const gameCapId = process.env.GAME_CAP as string;
const packageId = process.env.PACKAGE as string;
const upgraderId = process.env.UPGRADER as string;
// cli path is "sui"

/// helper to make keypair from private key that is in string format
function getKeyPair(privateKey: string): Ed25519Keypair{
  // let privateKeyArray = Array.from(fromB64(privateKey));
  // privateKeyArray.shift();
  //return Ed25519Keypair.fromSecretKey(Uint8Array.from(privateKeyArray));
  return Ed25519Keypair.fromSecretKey(Buffer.from(privateKey.slice(2), "hex"), { skipValidation: true });
}

// helper to find hero ID from transaction result
function getHeroId(mintResult: any) {
  let [hero]: any = mintResult.objectChanges?.filter((objectChange: any) => (objectChange.type === "created" && objectChange.objectType == `${packageId}::hero::Hero`));
  let heroId = hero.objectId;
  return heroId;
}

let keyPair = getKeyPair(privKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);

async function mintHero() {
  let txb = new TransactionBlock();

  let baseValues = [1, 2, 3, 4, 5, 6];
  let skillValues = [200, 201, 202, 203];
  let appearenceValues = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111];
  let statValues = [40, 0, 0, 0, 0, 0, 0, 0];
  let otherValues = [34];

  let [hero] = txb.moveCall({
    target: `${packageId}::game::mint_hero`,
    arguments: [
      txb.object(gameCapId),
      txb.pure("Wo Long", "string"),
      txb.pure("Assassin", "string"),
      txb.pure("Flamexecuter", "string"),
      txb.pure("R", "string"),
      txb.pure(baseValues),
      txb.pure(skillValues),
      txb.pure(appearenceValues),
      txb.pure(statValues),
      txb.pure(otherValues),
      txb.pure("1337", "string"),
    ]
  });

  // hero is sent to mugen, it should be sent to the player
  txb.transferObjects([hero], txb.pure(keyPair.getPublicKey().toSuiAddress()));

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

// calls upgrade_hero to put main hero for upgrade
// this should be called by the player, here it is called by mugen for demo
async function upgradeHero(mainHeroId: string, heroIds: string[]){

  let txb = new TransactionBlock();

  let heroes = heroIds.map((heroId) => txb.object(heroId));
  let hero = txb.object(mainHeroId);

  txb.moveCall({
    target: `${packageId}::game::upgrade_hero`,
    arguments: [
      hero,
      txb.makeMoveVec({ objects: heroes }),
      txb.object(upgraderId)
    ]
  });

  let result = await mugen.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
      showObjectChanges: true,
      showEvents: true
    },
  });

  return result;
 
}

const perofmUpgrade = async (playerAddress: string) => {
  const new_stats = [
    500, //5%
    234, // 2.24%
    0,
    0,
    300, // 3%
    0,
    0,
    0
  ]
  const txb = new TransactionBlock();

  const callResult = txb.moveCall({
    target: `${packageId}::game::get_for_upgrade`,
    arguments: [txb.object(gameCapId), txb.pure(playerAddress), txb.object(upgraderId)],
    typeArguments: []
  });
  
  txb.moveCall({
    target: `${packageId}::game::upgrade_stat`,
    arguments: [txb.object(gameCapId), callResult[0], txb.pure(new_stats)]
  })

  txb.moveCall({
    target: `${packageId}::game::return_upgraded_hero`,
    arguments: [callResult[0], callResult[1]]
  });

  txb.setGasBudget(100000000);
  let result = mugen.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true
    }
  });

  return result;

}

async function main() {

  let mintResult1 = await mintHero();
  await sleep(5);
  let mintResult2 = await mintHero();
  await sleep(5);
  let mintResult3 = await mintHero();
  await sleep(5);

  let mainHeroId = getHeroId(mintResult1);

  let hero1Id = getHeroId(mintResult2);
  let hero2Id = getHeroId(mintResult3);

  let heroIds = [hero1Id, hero2Id];

  let requestUpgradeResult = await upgradeHero(mainHeroId, heroIds);
  console.log(JSON.stringify(requestUpgradeResult));

  // address
  const address = "0xbe225c0731573a1a41afb36dd363754d24585cfc790929252656ea4e77435d6e";
  let result = await perofmUpgrade(address);
  var fs = require('fs');
  fs.writeFile(`./auto-results/mintHeroAndPutForUpgradeResult.json`, JSON.stringify(result, null, 2), function(err: any) {
    if (err) {
        console.log(err);
    }
  });
}

function sleep(seconds:number) {
  const milliseconds = seconds * 1000;
  return new Promise(resolve => setTimeout(resolve, milliseconds));
};

main();
