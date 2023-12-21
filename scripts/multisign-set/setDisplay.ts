import { TransactionBlock } from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + `/../.env` });
import {getSigner} from "../publish/";


async function setDisplay(name: string,uri: string) {
    let disPlayObj = process.env.DISPLAY_OBJ!;
    let type = process.env.DISPLAY_TYPE!;
    let txb = new TransactionBlock();

    txb.moveCall({
        target: `0x2::display::edit`,
        typeArguments: [type],
        arguments: [
            txb.object(disPlayObj),
            txb.pure(name),
            txb.pure(uri),
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

    let displayKey = process.env.DISPLAY_KEY!;
    let displayValue = process.env.DISPLAY_VALUE!;

    let result = await setDisplay(displayKey, displayValue);
    console.log(result);
}

main();

