import {
    JsonRpcProvider,
    testnetConnection,
    TransactionBlock,
    RawSigner,
    fromB64,
    Ed25519Keypair,
    toB64,
} from "@mysten/sui.js";
import {
    getKeyPair,
    mintARCA,
    createStakingPool,
    stake,
} from "./staking_demo";
import {
    BCS,
    getSuiMoveConfig
} from "@mysten/bcs";
import * as dotenv from "dotenv";
dotenv.config();

const privKey: string = process.env.PRIVATE_KEY as string;
const gameCapId = process.env.GAME_CAP as string;
const packageId = process.env.PACKAGE_ID as string;
const TreasuryCap = process.env.TREASURY_CAP as string;
const Clock = process.env.CLOCK as string;
const StakingPool = process.env.STAKING_POOL_ID as string;
const ArcaCoin = process.env.ARCA_COIN_ID as string;
const ArcaCoin2 = process.env.ARCA_COIN_ID2 as string;
const ArcaCoin3 = process.env.ARCA_COIN_ID3 as string;
const veARCAId = process.env.VEARCA_ID as string;
const marketplaceId = process.env.MARKETPLACE as string;
const hero = process.env.HERO_ID as string;
const Sui = process.env.SUI as string;

const bcs = new BCS(getSuiMoveConfig());

let keyPair = getKeyPair(privKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);
let mugenAddress = keyPair.getPublicKey().toSuiAddress();


async function list_primary_arca() {
    let txb = new TransactionBlock();

    txb.moveCall({
        target: `${packageId}::marketplace::list_primary_arca`,
        arguments: [
            txb.object(gameCapId),
            txb.object(marketplaceId),
            txb.object(hero),
            txb.pure("30000000000", "u64")
        ],
        typeArguments: [`${packageId}::hero::Hero`]
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

async function buy_primary_arca() {
    let txb = new TransactionBlock();

    let hero = txb.moveCall({
        target: `${packageId}::marketplace::buy_primary_arca`,
        arguments: [
            txb.object(ArcaCoin),
            txb.object(marketplaceId),
            txb.pure("1", "u64")
        ],
        typeArguments: [`${packageId}::hero::Hero`]
    });

    txb.transferObjects([hero], txb.pure(mugenAddress));

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

async function list_secondary_arca() {
    let txb = new TransactionBlock();

    txb.moveCall({
        target: `${packageId}::marketplace::list_secondary_arca`,
        arguments: [
            txb.object(marketplaceId),
            txb.object(hero),
            txb.pure("30000000000", "u64")
        ],
        typeArguments: [`${packageId}::hero::Hero`]
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

bcs.registerEnumType(['Option', 'T'], {
    None: null,
    Some: "T",
});

let serialized = bcs.ser('Option<address>', {Some: mugenAddress}).toString('hex');
let deSerialized = bcs.de('Option<address>', serialized, 'hex');

let serEmpty = bcs.ser('Option<address>', {None: true}).toString('hex');
let deSerEmpty = bcs.de('Option<address>', serEmpty, 'hex');

async function buy_secondary_arca() {
    let txb = new TransactionBlock();

    let hero = txb.moveCall({
        target: `${packageId}::marketplace::buy_secondary_arca`,
        arguments: [
            txb.object(ArcaCoin2),
            txb.pure("1", "u64"),
            txb.pure(deSerEmpty, "Option<address>"),
            txb.object(marketplaceId),
            txb.object(StakingPool)
        ],
        typeArguments: [`${packageId}::hero::Hero`, `${Sui}::coin::Coin<${packageId}::arca::ARCA>`]
    });

    txb.transferObjects([hero], txb.pure(mugenAddress));

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
    
    // let response = await buy_primary_arca(); 
    // let response = await list_secondary_arca(); 
    let response = await buy_secondary_arca(); 
    console.log(response);
}

main();
