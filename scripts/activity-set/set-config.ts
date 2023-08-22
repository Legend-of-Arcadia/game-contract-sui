import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner } from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + `/../.env` });

const mugenPrivKey: string = process.env.PRIVATE_KEY!;
const playerPrivKey: string = process.env.PLAYER_PRIVATE_KEY!;
const packageId = process.env.PACKAGE!;
const gameCap = process.env.GAME_CAP!;
const upgrader = process.env.UPGRADER!;
const objBurn = process.env.OBJBURN!;
const gameConfig = process.env.GAME_CONFIG!;

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

let keyPair = getKeyPair(mugenPrivKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);
let playerKeyPair = getKeyPair(playerPrivKey);
let player = new RawSigner(playerKeyPair, provider);
let playerAddress = playerKeyPair.getPublicKey().toSuiAddress();


// player puts their hero to makeover
async function setConfig() {
    let start_time = 1688522400000 // 2023-07-05 10:00:00
    let end_time = 1791200800000 // 2023-08-05 10:00:00
    let max_supply = 1000
    let token_type = 19999
    let name = "blue gacha"
    let type = "legend"
    let collection = "gacha"
    let description = "Test gacha";
    let txb = new TransactionBlock();

    txb.moveCall({
        target: `${packageId}::activity::create_config`,
        arguments: [
            txb.object(gameCap),
            txb.pure(start_time),
            txb.pure(end_time),
            txb.pure(max_supply),
            txb.pure(token_type),
            txb.pure(name),
            txb.pure(type),
            txb.pure(collection),
            txb.pure(description)
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

// player puts their hero to makeover
async function setPrice() {

    let configId = "0x38bb56b3d30706f2c174603c7383940eeea1d7a927fe34d51e48ee9951ae5680"
    let txb = new TransactionBlock();
    let price = 1000;
    const coinType = "0x2::sui::SUI";

    txb.moveCall({
        target: `${packageId}::activity::set_price`,
        typeArguments: [coinType],
        arguments: [
            txb.object(gameCap),
            txb.object(configId),
            txb.pure(price),
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

async function setArcaPrice() {

    let configId = "0xcda3da3c1daca742473c1971d5a0490818e41583b662fd26a4224b29796e1f9d"
    let txb = new TransactionBlock();
    let price = 1000;
    const coinType = `${packageId}::arca::ARCA`;
    console.log(coinType)

    txb.moveCall({
        target: `${packageId}::activity::set_price`,
        typeArguments: [coinType],
        arguments: [
            txb.object(gameCap),
            txb.object(configId),
            txb.pure(price),
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

async function removeConfig() {

    let configId = "0x30a7bcc4e06c948fd46c76a91abeeeebb01aa3998a7a361f84894894b1c5ec47"
    let txb = new TransactionBlock();

    txb.moveCall({
        target: `${packageId}::activity::remove_config`,
        arguments: [
            txb.object(gameCap),
            txb.object(configId),
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

    //let result = await setConfig();
    let result = await setPrice();
    console.log(result);

}

main();

