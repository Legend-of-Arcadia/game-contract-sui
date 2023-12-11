import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner } from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + `/../.env` });
import {getSigner} from "../publish/";

const multiSigPackageId = process.env.MULTI_SIG_PACKAGE!;
const multiSigObj = process.env.MULTI_SIG_OBJ!;

async function setMultiSig() {

    let participants = ["0xda19838be1a878912272bb994ba264cc490ddeabf8ce0b395220cbf2a6b98aa1", "0xbe225c0731573a1a41afb36dd363754d24585cfc790929252656ea4e77435d6e", "0xae88dcdcc6dde6f33711938fa2f5dd04722591e4d35eb3ebe19ec55e67482d96"];
    let participant_weights = [2, 1, 1];
    let participants_remove :any = [];
    let threshold = 2;
    let txb = new TransactionBlock();

    //    public entry fun create_multisig_setting_proposal(multi_signature: &mut MultiSignature, participants: vector<address>, participant_weights: vector<u64>, participants_remove: vector<address>, threshold: u64, _tx: &mut TxContext){
    //         onlyParticipant(multi_signature, _tx);
    txb.moveCall({
        target: `${multiSigPackageId}::multisig::create_multisig_setting_proposal`,
        arguments: [
            txb.object(multiSigObj),
            txb.pure(participants),
            txb.pure(participant_weights),
            txb.pure(participants_remove),
            txb.pure(threshold),
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

async function multisig_setting_execute(id:number) {
    let txb = new TransactionBlock();

    txb.moveCall({
        target: `${multiSigPackageId}::multisig::multisig_setting_execute`,
        arguments: [
            txb.object(multiSigObj),
            txb.pure(id),
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

    // let result = await setMultiSig();
    // let result = await vote(0, true);
    let result = await multisig_setting_execute(0);
    console.log(result);

}

main();

