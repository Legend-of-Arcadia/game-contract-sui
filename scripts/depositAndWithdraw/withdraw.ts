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
const seenMessagesId = process.env.SEENMESSAGES as string;

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


async function withdraw() {

    //    public fun withdraw(
    //         arca_counter: &mut ArcaCounter,
    //         amount: u64,
    //         expire_at: u64,
    //         salt: u64,
    //         fee: u64,
    //         chain_id: u64,
    //         package_address: address,
    //         signed_message: vector<u8>,
    //         seen_messages: &mut SeenMessages,
    //         clock: & Clock,
    //         ctx: &mut TxContext,
    //     )
    let txb = new TransactionBlock();
    let amount = 1000;
    let expire_at = 1692519168;
    let salt = 1;
    let fee =0;
    let chain_id = 99;
    let package_address = "";
    let signed_message = [
            42, 137,  50, 246,  80, 254, 171, 176, 213, 138, 181,
            199,  68, 107, 156, 172, 110, 198, 174, 254,  91,  60,
            254, 213, 244, 199, 207,  42, 160,  91, 159,  37,   3,
            39, 162, 161,  60, 104, 121, 176, 194, 237,  51, 222,
            231, 112,  90, 239, 230,  31, 125,   2, 104,  26, 124,
            38, 103, 175, 133, 195, 163,  53, 250,  39
        ];
    let clock = "0x6"

    let arca = txb.moveCall({
        target: `${packageId}::arca::withdraw`,
        arguments: [
            txb.object(arcaCounter),
            txb.pure(amount),
            txb.pure(expire_at),
            txb.pure(salt),
            txb.pure(fee),
            txb.pure(chain_id),
            txb.pure(packageId),
            txb.pure(signed_message),
            txb.object(seenMessagesId),
            txb.object(clock)
        ]
    });
    txb.transferObjects([arca], txb.pure(playerAddress));

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
            txb.object(seenMessagesId)
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
async function setPk() {
    //public fun set_mugen_pk(_: &TreasuryCap<ARCA>, mugen_pk: vector<u8>, seen_messages: &mut SeenMessages)
    let txb = new TransactionBlock();

    let pk:number[] =[
        2, 103,  79,  79, 204,  13, 202, 247,
        197,  59,  99,  89, 191,  68, 208, 197,
        53,  13, 102, 206, 105, 188,  11, 224,
        201, 218, 204, 245,  28, 251, 215,  86,
        126
    ]

    txb.moveCall({
        target: `${packageId}::arca::set_mugen_pk`,
        arguments: [
            txb.object(TreasuryCap),
            // 6_666_000_000
            txb.pure(pk),
            txb.object(seenMessagesId),
        ],
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

async function main() {

    //let result = await setPk();
    let result = await withdraw();
    console.log(result);

}

main();

