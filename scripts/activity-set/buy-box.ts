import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner, SUI_FRAMEWORK_ADDRESS } from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + `/../.env` });

const mugenPrivKey: string = process.env.PRIVATE_KEY!;
const playerPrivKey: string = process.env.PLAYER_PRIVATE_KEY!;
const packageId = process.env.PACKAGE!;
const gameCap = process.env.GAME_CAP!;
const upgrader = process.env.UPGRADER!;
const objBurn = process.env.OBJBURN!;
const gameConfig = process.env.GAME_CONFIG!;
const TreasuryCap = process.env.TREASURY_CAP as string;
const ActivityConfig = process.env.ACTIVITYPROFITS!;

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


async function buyBox() {

    let configId = "0x30a7bcc4e06c948fd46c76a91abeeeebb01aa3998a7a361f84894894b1c5ec47"
    let txb = new TransactionBlock();
    let amount = 5;
    const coinType = "0x2::sui::SUI";
    const paid = txb.splitCoins(txb.gas, [txb.pure(5000)]);
    const clock = "0x6";

    txb.moveCall({
        target: `${packageId}::activity::buy`,
        typeArguments: [coinType],
        arguments: [
            txb.object(configId),
            paid,
            txb.pure(amount),
            txb.object(clock),
            txb.object(ActivityConfig),
        ]
    });

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


async function buyBoxByArca() {

    let arcaResult = await mintAndTransferArca();
    let arcaCoinId = getArcaCoinId(arcaResult);
    let configId = "0xcda3da3c1daca742473c1971d5a0490818e41583b662fd26a4224b29796e1f9d"
    let txb = new TransactionBlock();
    let amount = 5;
    const coinType = `${packageId}::arca::ARCA`;
    //const paid = txb.splitCoins(txb.gas, [txb.pure(5000)]);
    const clock = "0x6";

    txb.moveCall({
        target: `${packageId}::activity::buy`,
        typeArguments: [coinType],
        arguments: [
            txb.object(configId),
            txb.object(arcaCoinId),
            txb.pure(amount),
            txb.object(clock),
        ]
    });

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

async function mintAndTransferArca() {

    let txb = new TransactionBlock();

    txb.moveCall({
        target: `${SUI_FRAMEWORK_ADDRESS}::coin::mint_and_transfer`,
        arguments: [
            txb.object(TreasuryCap),
            // 6_666_000_000
            txb.pure("5000", "u64"),
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

async function main() {

    //let result = await setConfig();
    let result = await buyBox();
    console.log(result);

}

main();

