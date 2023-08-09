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
const gacha_config_tb = process.env.GACHACONFIG as string;

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


async function withdrawGacha() {

    //     public fun withdraw_gacha(
    //     gacha_config: &GachaConfigTable,
    //     token_type: u64,
    //     amount: u64,
    //     expire_at: u64,
    //     salt: u64,
    //     chain_id: u64,
    //     package_address: address,
    //     signed_message: vector<u8>,
    //     seen_messages: &mut SeenMessages,
    //     clock: & Clock,
    //     ctx: &mut TxContext,
    //   )
    let txb = new TransactionBlock();
    let token_type = 188881
    let amount = 10;
    let expire_at = 169149259959;
    let salt = 1;
    let chain_id = 99;
    let package_address = "0xc69c87d31fc58cb07373997c285fffb113f513fedc26355e0fa036449f4573f3";
    let signed_message =  [
            126, 197, 159,  25,  52, 102, 181,  99, 109,  31, 233,
            3, 242,  74,  37, 143,  41, 106, 168, 170, 127, 100,
            248,  77,  23, 183, 127, 111, 135, 165,  93, 143,  67,
            8, 166, 154, 115, 152, 145, 206, 186, 179, 223, 145,
            45, 127, 244, 104, 226, 225, 226, 165,   3, 157, 229,
            128, 143, 130, 118, 117, 145, 137,   5,  88
        ];
    let clock = "0x6"

    txb.moveCall({
        target: `${packageId}::game::withdraw_gacha`,
        arguments: [
            txb.object(gacha_config_tb),
            txb.pure(token_type),
            txb.pure(amount),
            txb.pure(expire_at),
            txb.pure(salt),
            txb.pure(chain_id),
            txb.pure(package_address),
            txb.pure(signed_message),
            txb.object(seenMessagesId),
            txb.object(clock)
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
        target: `${packageId}::game::set_mugen_pk`,
        arguments: [
            txb.object(gameCap),
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

// helper to arca coin ID from transaction result
async function setGachaConfig() {
    //  public fun add_gacha_config(
    //     _: &GameCap, gacha_config_tb: &mut GachaConfigTable, token_type:u64, gacha_token_type: vector<u64>,
    //     gacha_name: vector<String>, gacha_type: vector<String>, gacha_collction: vector<String>,
    //     gacha_description: vector<String>, start_time: u64, end_time: u64)
    let txb = new TransactionBlock();
    let token_type = 188881
    let gacha_token_type = [19999]
    let gacha_token_amount = [1]
    // let gacha_name = ["test"]
    // let gacha_type = ["test"]
    // let gacha_collction = ["test"]
    // let gacha_description = ["test"]
    let start_time = 0;
    let end_time = 0;

    txb.moveCall({
        target: `${packageId}::game::add_gacha_config`,
        arguments: [
            txb.object(gameCap),
            txb.object(gacha_config_tb),
            txb.pure(token_type),
            txb.pure(gacha_token_type),
            txb.pure(gacha_token_amount),
            txb.pure(start_time),
            txb.pure(end_time),
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

// helper to arca coin ID from transaction result
async function setGachaInfo() {
    //  public fun add_gacha_config(
    //     _: &GameCap, gacha_config_tb: &mut GachaConfigTable, token_type:u64, gacha_token_type: vector<u64>,
    //     gacha_name: vector<String>, gacha_type: vector<String>, gacha_collction: vector<String>,
    //     gacha_description: vector<String>, start_time: u64, end_time: u64)
    let txb = new TransactionBlock();
    let token_type = 188881
    let gacha_name = "test"
    let gacha_type = "test"
    let gacha_collction = "test"
    let gacha_description = "test"

    txb.moveCall({
        target: `${packageId}::game::add_gacha_info`,
        arguments: [
            txb.object(gameCap),
            txb.object(gacha_config_tb),
            txb.pure(token_type),
            txb.pure(gacha_name),
            txb.pure(gacha_type),
            txb.pure(gacha_collction),
            txb.pure(gacha_description),
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
    //let result = await setGachaConfig();
    //let result = await setGachaInfo();
    let result = await withdrawGacha();
    console.log(result);

}

main();

