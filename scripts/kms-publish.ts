import { Secp256k1PublicKey, mainnetConnection, testnetConnection, JsonRpcProvider, TransactionBlock, RawSigner } from "@mysten/sui.js";
const { execSync } = require('child_process');
import * as dotenv from "dotenv";
import { getProvider } from "./publish/index";
dotenv.config();

const packagePath: string = process.env.PACKAGE_PATH!;
const cliPath: string = process.env.CLI_PATH!;

const base64pk = process.env.KMS_BASE64PK!;
const keyId = process.env.KMS_KEY_ID!;
const pk = new Secp256k1PublicKey(Buffer.from(base64pk, 'base64').slice(1))
const mugenAddress = pk.toSuiAddress();

const provider = getProvider();
const { modules, dependencies } = JSON.parse(
    execSync(`${cliPath} move build --dump-bytecode-as-base64 --with-unpublished-dependencies --path ${packagePath}`, {
        encoding: 'utf-8',
    }),
);

async function publish() {
    const tx = new TransactionBlock();
    const [upgradeCap] = tx.publish({
        modules,
        dependencies,
    });
    tx.transferObjects([upgradeCap], tx.pure(mugenAddress));

    tx.setSender(mugenAddress);

    const tx_bytes = await tx.build({provider: provider})

    const tx_data = Buffer.from(tx_bytes).toString('base64')
    const { serializedSigBase64 } = JSON.parse(
        execSync(`${cliPath} keytool sign-kms --data ${tx_data} --keyid ${keyId} --base64pk ${base64pk} --json`),
    );

    const result = await provider.executeTransactionBlock({
        transactionBlock: tx_data,
        signature:serializedSigBase64,
        options: {
            showEffects: true,
            showObjectChanges: true
        },
    })
    console.log(result)
    var fs = require('fs');
    // unfortunately when I published, I forgot to ask for all the data needed in the response, so for now I have to go to the explorer manually
    fs.writeFile(`./auto-results/publishResult.json`, JSON.stringify(result, null, 2), function(err: any) {
        if (err) {
            console.log(err);
        }
    });
}

publish();