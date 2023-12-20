import {TransactionBlock} from "@mysten/sui.js";
import * as dotenv from "dotenv";
import {getKmsSigner} from "./aws-kms/aws-kms-by-env";

const {execSync} = require('child_process');

dotenv.config();

const packagePath: string = process.env.PACKAGE_PATH!;
const cliPath: string = process.env.CLI_PATH!;


const {modules, dependencies} = JSON.parse(
    execSync(`${cliPath} move build --dump-bytecode-as-base64  --path ${packagePath}`, {
        encoding: 'utf-8',
    }),
);

async function publish() {
    const signer = await getKmsSigner();
    const mugenAddress = await signer.getAddress();

    const txb = new TransactionBlock();
    const [upgradeCap] = txb.publish({
        modules,
        dependencies,
    });
    txb.transferObjects([upgradeCap], txb.pure(mugenAddress));

    const result = await signer.signAndExecuteTransactionBlock({
        transactionBlock: txb,
        options: {
            showEffects: true,
            showObjectChanges: true
        },
    })
    console.log(result)
    const fs = require('fs');
    // unfortunately when I published, I forgot to ask for all the data needed in the response, so for now I have to go to the explorer manually
    fs.writeFile(`./auto-results/publishResult.json`, JSON.stringify(result, null, 2), function (err: any) {
        if (err) {
            console.log(err);
        }
    });
}

publish().then(r => console.log(r));