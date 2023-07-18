import { Ed25519Keypair, fromB64, testnetConnection, JsonRpcProvider, TransactionBlock, RawSigner, UpgradePolicy } from "@mysten/sui.js";
const { execSync } = require('child_process');
import * as dotenv from "dotenv";
dotenv.config();

const privKey: string = process.env.PRIVATE_KEY!;
const packagePath: string = process.env.PACKAGE_PATH!;
const cliPath: string = process.env.CLI_PATH!;
const packageId: string = process.env.PACKAGE!;
const upgradeCapId:string = process.env.UPGRADE_CAP!;

/// helper to make keypair from private key that is in string format
function getKeyPair(privateKey: string): Ed25519Keypair{
    // let privateKeyArray = Array.from(fromB64(privateKey));
    // privateKeyArray.shift();
    //return Ed25519Keypair.fromSecretKey(Uint8Array.from(privateKeyArray));
    return Ed25519Keypair.fromSecretKey(Buffer.from(privateKey.slice(2), "hex"), { skipValidation: true });
}

let keyPair = getKeyPair(privKey);
let mugenAddress = keyPair.getPublicKey().toSuiAddress();

const provider = new JsonRpcProvider(testnetConnection);
const signer = new RawSigner(keyPair, provider);
const { modules, dependencies, digest  } = JSON.parse(
    execSync(`${cliPath} move build --dump-bytecode-as-base64 --path ${packagePath}`, {
        encoding: 'utf-8',
    }),
);

async function publish() {
    const tx = new TransactionBlock();

    const cap = tx.object(upgradeCapId);
    const ticket = tx.moveCall({
        target: "0x2::package::authorize_upgrade",
        arguments: [cap, tx.pure(UpgradePolicy.COMPATIBLE), tx.pure(digest)],
    });

    const receipt = tx.upgrade({
        modules,
        dependencies,
        packageId,
        ticket,
    });

    tx.moveCall({
        target: "0x2::package::commit_upgrade",
        arguments: [cap, receipt],
    });

    const result = await signer.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        options: {
            showEffects: true,
            showObjectChanges: true,
        },
    });
    var fs = require('fs');
    // unfortunately when I published, I forgot to ask for all the data needed in the response, so for now I have to go to the explorer manually
    fs.writeFile(`./auto-results/upgradeResult.json`, JSON.stringify(result, null, 2), function(err: any) {
        if (err) {
            console.log(err);
        }
    });
}

publish();