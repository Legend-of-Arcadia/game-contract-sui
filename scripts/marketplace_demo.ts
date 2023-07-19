import {
    JsonRpcProvider,
    testnetConnection,
    TransactionBlock,
    RawSigner,
    fromB64,
    Ed25519Keypair,
    toB64,
    SUI_FRAMEWORK_ADDRESS
} from "@mysten/sui.js";
import {
    BCS,
    getSuiMoveConfig
} from "@mysten/bcs";
import * as dotenv from "dotenv";
dotenv.config();

const privKey: string = process.env.PRIVATE_KEY as string;
const playerPrivKey: string = process.env.PLAYER_PRIVATE_KEY!;
const gameCapId = process.env.GAME_CAP as string;
const packageId = process.env.PACKAGE as string;
const TreasuryCap = process.env.TREASURY_CAP as string;
const marketplaceId = process.env.MARKETPLACE as string;
const Sui ="0x2";

const bcs = new BCS(getSuiMoveConfig());

function getKeyPair(privateKey: string): Ed25519Keypair{
    // let privateKeyArray = Array.from(fromB64(privateKey));
    // privateKeyArray.shift();
    //return Ed25519Keypair.fromSecretKey(Uint8Array.from(privateKeyArray));
    return Ed25519Keypair.fromSecretKey(Buffer.from(privateKey.slice(2), "hex"), { skipValidation: true });
}
let keyPair = getKeyPair(privKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);
let mugenAddress = keyPair.getPublicKey().toSuiAddress();

let playerKeyPair = getKeyPair(playerPrivKey);
let player = new RawSigner(playerKeyPair, provider);
let playerAddress = playerKeyPair.getPublicKey().toSuiAddress();

async function list_secondary() {
    let txb = new TransactionBlock();

    //    public fun list_secondary<Item: key+store, COIN>(
    //         marketplace: &mut Marketplace,
    //         item: Item,
    //         price: u64,
    //         ctx: &mut TxContext
    //     )
    const hero = "0x90b5c8b7e9e79b86e7fe986e97b79bfb87cc2c80c242b969e339b078dd9ac353";
    txb.moveCall({
        target: `${packageId}::marketplace::list_secondary`,
        arguments: [
            txb.object(marketplaceId),
            txb.object(hero),
            txb.pure("1000", "u64")
        ],
        typeArguments: [`${packageId}::hero::Hero`, `${packageId}::arca::ARCA`]
    });

    console.log(packageId)
    console.log(hero)
    console.log(`${packageId}::hero::Hero`)
    console.log(`${Sui}::sui::SUI`)
    //txb.setGasBudget(100000000);

    let response = await mugen.signAndExecuteTransactionBlock({
        transactionBlock: txb,
        requestType: "WaitForLocalExecution",
        options: {
            showEffects: true,
        },
    });

    return response;
}


async function buy_secondary() {
    let arcaResult = await mintAndTransferArca();
    let arcaCoinId = getArcaCoinId(arcaResult);

    await sleep(1)
    console.log(arcaCoinId)
    let txb = new TransactionBlock();

    //    public fun buy_secondary<Item: key+store, COIN>(
    //         payment: Coin<COIN>,
    //         listing_number: u64,
    //         marketplace: &mut Marketplace,
    //         ctx: &mut TxContext
    //     ): Item
    //const paid = txb.splitCoins(txb.gas, [txb.pure(1000)]);
    let hero = txb.moveCall({
        target: `${packageId}::marketplace::buy_secondary`,
        typeArguments: [`${packageId}::hero::Hero`, `${packageId}::arca::ARCA`],
        arguments: [
            txb.object(arcaCoinId),
            txb.pure("5", "u64"),
            txb.object(marketplaceId)
        ],

    });

    console.log(`${packageId}::hero::Hero`)
    console.log(`${Sui}::coin::Coin<${packageId}::arca::ARCA>`)
    txb.transferObjects([hero], txb.pure(playerAddress));

    //txb.setGasBudget(100000000);

    let response = await player.signAndExecuteTransactionBlock({
        transactionBlock: txb,
        requestType: "WaitForLocalExecution",
        options: {
            showEffects: true,
        },
    });

    return response;
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
            txb.pure("1000", "u64"),
            txb.pure(playerAddress, "address")
        ],
        typeArguments: [`${packageId}::arca::ARCA`]
    });

    //txb.setGasBudget(100000000);

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

// helper to arca coin ID from transaction result
function getArcaCoinId(result: any) {
    let [hero]: any = result.objectChanges?.filter((objectChange: any) => (objectChange.type === "created" && objectChange.objectType == `${SUI_FRAMEWORK_ADDRESS}::coin::Coin<${packageId}::arca::ARCA>`));
    let heroId = hero.objectId;
    return heroId;
}

function sleep(seconds: number) {
    const milliseconds = seconds * 1000;
    return new Promise(resolve => setTimeout(resolve, milliseconds));
};

async function main() {
    // let response = await list_secondary();
    let response = await buy_secondary();
            // let response = await list_secondary_arca();
            //let response = await buy_secondary_arca();
    console.log(response);


    // var fs = require('fs');
    // // unfortunately when I published, I forgot to ask for all the data needed in the response, so for now I have to go to the explorer manually
    // fs.writeFile(`./auto-results/marketTest.json`, JSON.stringify(response, null, 2), function(err: any) {
    //     if (err) {
    //         console.log(err);
    //     }
    // });
}

main();
