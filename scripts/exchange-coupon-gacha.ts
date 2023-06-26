import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner} from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config();


const mugenPrivKey: string = process.env.PRIVATE_KEY!;
const playerPrivKey: string = process.env.PLAYER_PRIVATE_KEY!;
const packageId = process.env.PACKAGE!;
const gameCap = process.env.GAME_CAP!;
const config = process.env.CONFIG!;

/// helper to make keypair from private key that is in string format
function getKeyPair(privateKey: string): Ed25519Keypair{
  let privateKeyArray = Array.from(fromB64(privateKey));
  privateKeyArray.shift();
  return Ed25519Keypair.fromSecretKey(Uint8Array.from(privateKeyArray));
}

// helper to find coupon ID from transaction result
function getCouponIdGacha(result: any) {
  let [exchangeCoupon]: any = result.objectChanges?.filter((objectChange: any) => (objectChange.type === "created" && objectChange.objectType == `${packageId}::game::ExchangeCoupon<${packageId}::gacha::GachaBall>`));
  console.log(exchangeCoupon);
  let exchangeCouponId = exchangeCoupon.objectId;
  return exchangeCouponId;
}

let keyPair = getKeyPair(mugenPrivKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);
let playerKeyPair = getKeyPair(playerPrivKey);
let player = new RawSigner(playerKeyPair, provider);


// mint exchange coupon and transfer it to player
async function mintGachaExchangeCoupon(){

  let txb = new TransactionBlock();

  // mint a gacha ball
  let gachaBall = txb.moveCall({
    target: `${packageId}::game::mint_gacha`,
    arguments: [
      txb.object(gameCap),
      txb.pure("Haloween", "string"),
      txb.pure("Grandia", "string"),
      txb.pure("VIP"),
    ],
  });

  let exchangeCoupon = txb.moveCall({
    target: `${packageId}::game::mint_exchange_coupon`,
    arguments: [
      txb.object(gameCap),
      gachaBall,
    ],
    typeArguments: [`${packageId}::gacha::GachaBall`],
  });

  // transfer exchange coupon to player
  txb.transferObjects([exchangeCoupon], txb.pure(playerKeyPair.getPublicKey().toSuiAddress()));

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

async function claimExchangeCoupon(couponId: string){

  let txb = new TransactionBlock();

  let item = txb.moveCall({
    target: `${packageId}::game::claim_exchange_coupon`,
    arguments: [
      txb.object(couponId),
    ],
    typeArguments: [`${packageId}::gacha::GachaBall`],
  });

  // transfer item to player (self)
  txb.transferObjects([item], txb.pure(playerKeyPair.getPublicKey().toSuiAddress()));

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
  let result = await mintGachaExchangeCoupon();
  console.log(result);
  let couponId = getCouponIdGacha(result);

  let claimResult = await claimExchangeCoupon(couponId);
  console.log("claim result: ", claimResult);
}

main();
