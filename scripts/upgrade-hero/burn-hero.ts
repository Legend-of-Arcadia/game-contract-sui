import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner } from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + `/../.env` });

const mugenPrivKey: string = process.env.PRIVATE_KEY!;
const playerPrivKey: string = process.env.PLAYER_PRIVATE_KEY!;
const packageId = process.env.PACKAGE!;
const gameCap = process.env.GAME_CAP!;
const upgrader = process.env.UPGRADER!;
const objBurn = process.env.OBJBURN!;

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
async function burnHero(burnHeroId: string[]) {

    let txb = new TransactionBlock();

    for (let i = 0; i < burnHeroId.length; i++) {
        let x = txb.moveCall({
            target: `${packageId}::game::get_hero_and_burn`,
            arguments: [
                txb.pure(gameCap),
                txb.pure(burnHeroId[i]),
                txb.pure(objBurn),
            ]
        });

        console.log(burnHeroId[i])
    }
    // txb.setGasBudget(100000000)
    // txb.setGasPrice(1000);
    console.log(txb.blockData.transactions[0])
    console.log(txb.blockData.transactions[1])

    let result = await mugen.signAndExecuteTransactionBlock({
        transactionBlock: txb,
        requestType: "WaitForEffectsCert",
        options: {
            showEffects: false,
            showObjectChanges: false
        },
    });

    return result;

}

// player puts their hero to makeover
async function batchBurnHero(burnHeroIds: string[]) {

    let txb = new TransactionBlock();

    const burnHero = txb.pure(burnHeroIds, 'vector<address>');
    let x = txb.moveCall({
        target: `${packageId}::game::batch_burn_hero`,
        arguments: [
            txb.pure(gameCap),
            burnHero,
            txb.pure(objBurn),
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

    let result = await batchBurnHero(["0x675e1d75e262dbdfbdc17b2353b66878234ad568250253c1c05af2e8d32c68f3", "0x017eac5c9dca4f957ddc396f6712808dace50e7650d21f2b79e908ea847ced0e"]);
    console.log(result);

    // let result = await test(["0xbef5f977f3ca30f079fabd9513e4b06a6e9063d42ab89480b1f16855c5fe45be", "0x9b92dce784819d711a4d62f299999a868958a1c139da6f706e272c80b49ab6b5"]);
    // console.log(result);
}

main();

