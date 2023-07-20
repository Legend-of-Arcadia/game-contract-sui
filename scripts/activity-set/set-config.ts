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
    let end_time = 1691200800000 // 2023-08-05 10:00:00
    let max_supply = 1000
    let finance_address = "0xbe225c0731573a1a41afb36dd363754d24585cfc790929252656ea4e77435d6e"
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
            txb.pure(finance_address),
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

    let configId = "0x3e15a9f680f6137aa4f20b38e07f62def7a72f67a19a28f035e0325531f31bca"
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

async function main() {

    //let result = await setConfig();
    let result = await setArcaPrice();
    console.log(result);

}

main();

