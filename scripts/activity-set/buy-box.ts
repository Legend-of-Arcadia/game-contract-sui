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


async function buyBox() {

    let configId = "0xc0b96c0d7da9461eaee8f5489d059b9a2dc9c1ad7428b10eeb5b0ab771780847"
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

async function main() {

    //let result = await setConfig();
    let result = await buyBox();
    console.log(result);

}

main();

