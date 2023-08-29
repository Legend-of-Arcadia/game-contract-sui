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
const packageId = process.env.PACKAGE as string;
const TreasuryCap = process.env.TREASURY_CAP as string;
const Clock = process.env.CLOCK as string;
const StakingPool = process.env.STAKING_POOL_ID as string;
const ArcaCoin = process.env.ARCA_COIN_ID as string;
const ArcaCoin2 = process.env.ARCA_COIN_ID2 as string;
const ArcaCoin3 = process.env.ARCA_COIN_ID3 as string;
const veARCAId = process.env.VEARCA_ID as string;
const Sui = process.env.SUI as string;
const sp = process.env.SP as string;

export function getKeyPair(privateKey: string): Ed25519Keypair{
  // let privateKeyArray = Array.from(fromB64(privateKey));
  // privateKeyArray.shift();
  return Ed25519Keypair.fromSecretKey(Buffer.from(privateKey.slice(2), "hex"), { skipValidation: true });
}

let keyPair = getKeyPair(privKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);
let mugenAddress = keyPair.getPublicKey().toSuiAddress();

export async function mintARCA() {
  let txb = new TransactionBlock();

  txb.moveCall({
    target: `${Sui}::coin::mint_and_transfer`,
    arguments: [ 
      txb.object(TreasuryCap),
      // 50_000_000_000_000_000
      txb.pure("30000000000", "u64"),
      txb.pure(mugenAddress, "address")
    ],
    typeArguments: [`${packageId}::arca::ARCA`]
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

export async function createStakingPool() {
  let txb = new TransactionBlock();

  txb.moveCall({
    target: `${packageId}::staking::create_pool`,
    arguments: [
      txb.object(TreasuryCap),
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

export async function stake() {
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

async function append() {
  let txb = new TransactionBlock();

  txb.moveCall({
    target: `${packageId}::staking::append`,
    arguments: [
      txb.object(StakingPool),
      txb.object(veARCAId),
      txb.object(ArcaCoin2),
      txb.object(Clock)
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

async function distribute_rewards() {
  let txb = new TransactionBlock();

  txb.moveCall({
    target: `${packageId}::staking::distribute_rewards`,
    arguments: [
      txb.object(TreasuryCap),
      txb.object(StakingPool),
      txb.object(Clock)
    ]
  });

  txb.setGasBudget(100000000);

  let response = await mugen.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
    }
  });

  return response;

}


async function append_rewards() {
  let txb = new TransactionBlock();

  let balance = txb.moveCall({
    target: `0x2::coin::into_balance`,
    typeArguments: [`${packageId}::arca::ARCA`],
    arguments: [
      txb.object("0x51e46ad1211eef18939ed2e56d0466653d49d2c60e914f02dea2d85b66fa8410"),
    ]
  });

  txb.moveCall({
    target: `${packageId}::staking::append_rewards`,
    arguments: [
      txb.object(gameCapId),
      txb.object(sp),
      balance,
    ]
  });

  //txb.setGasBudget(100000000);

  let response = await mugen.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
    }
  });

  return response;

}
async function main() {
  
  // let response = await mintARCA();
  // let response = await createStakingPool();
  // let response = await stake();
  // let response = await unstake();
  // let response = await append();
  let response = await append_rewards();
  console.log(response);
}

main();