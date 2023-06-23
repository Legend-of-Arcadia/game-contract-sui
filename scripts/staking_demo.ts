import {
  JsonRpcProvider,
  testnetConnection,
  TransactionBlock,
  RawSigner,
  fromB64,
  Ed25519Keypair,
  toB64,
} from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config();

const privKey: string = process.env.PRIVATE_KEY as string;
const gameCapId = process.env.GAME_CAP as string;
const packageId = process.env.PACKAGE_ID as string;
const TreasuryCap = process.env.TREASURY_CAP as string;
const Clock = process.env.CLOCK as string;
const StakingPool = process.env.STAKING_POOL_ID as string;
const ArcaCoin = process.env.ARCA_COIN_ID as string;
const veARCAId = process.env.VEARCA_ID as string;

function getKeyPair(privateKey: string): Ed25519Keypair{
  let privateKeyArray = Array.from(fromB64(privateKey));
  privateKeyArray.shift();
  return Ed25519Keypair.fromSecretKey(Uint8Array.from(privateKeyArray));
}

let keyPair = getKeyPair(privKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);
let mugenAddress = keyPair.getPublicKey().toSuiAddress();

async function mintARCA() {
  let txb = new TransactionBlock();

  txb.moveCall({
    target: `0x0000000000000000000000000000000000000000000000000000000000000002::coin::mint_and_transfer`,
    arguments: [ 
      txb.object(TreasuryCap),
      // 50_000_000_000_000_000
      txb.pure("500000000000", "u64"),
      txb.pure(mugenAddress, "address")
    ],
    typeArguments: [`0x1f2d091d955717a2f81a7bc3216af57311e9cce9a691e71800a71785aa1e3d3d::arca::ARCA`]
  });

  txb.setGasBudget(100000000);

  let response = await mugen.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
    },
  });

  return response;
}

async function createStakingPool() {
  let txb = new TransactionBlock();

  txb.moveCall({
    target: `${packageId}::staking::create_pool`,
    arguments: [
      txb.object(gameCapId),
      txb.object(Clock),
    ]
  });

  txb.setGasBudget(100000000);

  let response = await mugen.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
    },
  });

  return response;
}

// TODO: take the object with the respective sdk function

async function stake() {
  let txb = new TransactionBlock();

  txb.moveCall({
    target: `${packageId}::staking::stake`,
    arguments: [
      txb.object(StakingPool),
      txb.object(ArcaCoin),
      txb.object(Clock),
      txb.pure("1w", "string"),
    ]
  });

  // console.log(signer);
  // console.log(address);
  txb.setGasBudget(100000000);


  let response = await mugen.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
    },
  });

  return response;
}

async function unstake() {
  let txb = new TransactionBlock();

  let coin = txb.moveCall({
    target: `${packageId}::staking::unstake`,
    arguments: [
      txb.object(veARCAId),
      txb.object(StakingPool),
      txb.object(Clock)
    ]
  });

  txb.transferObjects([coin], txb.pure(mugenAddress));

  txb.setGasBudget(100000000);

  let response = await mugen.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
    },
  });

  return response;
}

async function main() {
  
  let response = await mintARCA();
  // let response = await createStakingPool();
  // let response = await stake();
  // let response = await unstake();
  console.log(response);
}

main();