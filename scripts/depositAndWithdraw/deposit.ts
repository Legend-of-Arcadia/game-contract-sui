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
const arcaCounter = process.env.ARCACOUNTER as string;

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


async function deposit() {

    //public fun deposit(payment: Coin<ARCA>, arca_counter: &mut ArcaCounter, ctx: &mut TxContext)
    let txb = new TransactionBlock();
    let arcaResult = await mintAndTransferArca();
    let arcaCoinId = getArcaCoinId(arcaResult);

    txb.moveCall({
        target: `${packageId}::arca::deposit`,
        arguments: [
            txb.object(arcaCoinId),
            txb.object(arcaCounter),
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

async function main() {

    //let result = await setConfig();
    let result = await deposit();
    console.log(result);

}

main();

