import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner } from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + `/../.env` });
import {getSigner} from "../publish/";

const multiSigPackageId = process.env.MULTI_SIG_PACKAGE!;
const multiSigObj = process.env.MULTI_SIG_OBJ!;
const gamePackageId = process.env.GAME_PACKAGE!;
const gameConfig = process.env.GAME_CONFIG!;

async function setGameAddress() {
    let gameAddress = process.env.GAME_ADDRESS!;
    let txb = new TransactionBlock();

    txb.moveCall({
        target: `${gamePackageId}::game::set_game_address_request`,
        arguments: [
            txb.object(gameConfig),
            txb.object(multiSigObj),
            txb.pure(gameAddress),
        ]
    });

    const singer = await getSigner();
    let result = await singer.signAndExecuteTransactionBlock({
        transactionBlock: txb,
        requestType: "WaitForLocalExecution",
        options: {
            showEffects: true,
            showObjectChanges: true
        },
    });

    return result;

}

async function vote(id:number, approve: boolean) {
    let txb = new TransactionBlock();

    txb.moveCall({
        target: `${multiSigPackageId}::multisig::vote`,
        arguments: [
            txb.object(multiSigObj),
            txb.pure(id),
            txb.pure(approve),
        ]
    });

    const singer = await getSigner();

    let result = await singer.signAndExecuteTransactionBlock({
        transactionBlock: txb,
        requestType: "WaitForLocalExecution",
        options: {
            showEffects: true,
            showObjectChanges: true
        },
    });

    return result;
}

// public entry fun set_game_address_execute(
//     game_config:&mut GameConfig,
//     multi_signature : &mut MultiSignature,
//     proposal_id: u256,
//     is_approve: bool,
//     ctx: &mut TxContext)

async function setGameAddressExecute(id:number) {
    let txb = new TransactionBlock();

    txb.moveCall({
        target: `${gamePackageId}::game::set_game_address_execute`,
        arguments: [
            txb.object(gameConfig),
            txb.object(multiSigObj),
            txb.pure(id),
            txb.pure(true),
        ]
    });

    const singer = await getSigner();

    let result = await singer.signAndExecuteTransactionBlock({
        transactionBlock: txb,
        requestType: "WaitForLocalExecution",
        options: {
            showEffects: true,
            showObjectChanges: true
        },
    });

    return result;
}

async function setGameAddress2(id:number) {
    let gameAddress = process.env.GAME_ADDRESS!;
    let txb = new TransactionBlock();

    txb.moveCall({
        target: `${gamePackageId}::game::set_game_address_request`,
        arguments: [
            txb.object(gameConfig),
            txb.object(multiSigObj),
            txb.pure(gameAddress),
        ]
    });

    txb.moveCall({
        target: `${multiSigPackageId}::multisig::vote`,
        arguments: [
            txb.object(multiSigObj),
            txb.pure(id),
            txb.pure(true),
        ]
    });

    txb.moveCall({
        target: `${gamePackageId}::game::set_game_address_execute`,
        arguments: [
            txb.object(gameConfig),
            txb.object(multiSigObj),
            txb.pure(id),
            txb.pure(true),
        ]
    });

    const singer = await getSigner();
    let result = await singer.signAndExecuteTransactionBlock({
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

    let proposal_id = process.env.NEXT_PROPOSAL_ID!;

    let result = await setGameAddress2(parseInt(proposal_id));
    console.log(result);
    // let result = await setGameAddress();
    // console.log(result);
    // let result2 = await vote(parseInt(proposal_id), true);
    // console.log(result2);
    // let result3 = await setGameAddressExecute(parseInt(proposal_id));
    // console.log(result3);

}

main();

