import { Ed25519Keypair, fromB64, testnetConnection, JsonRpcProvider, TransactionBlock, RawSigner } from "@mysten/sui.js";
const { execSync } = require('child_process');
import * as dotenv from "dotenv";
dotenv.config();

const privKey: string = process.env.MY_PRIVATE_KEY!;
const packagePath: string = process.env.PACKAGE_PATH!;
const cliPath: string = process.env.CLI_PATH!;

/// helper to make keypair from private key that is in string format
function getKeyPair(privateKey: string): Ed25519Keypair{
  let privateKeyArray = Array.from(fromB64(privateKey));
  privateKeyArray.shift();
  return Ed25519Keypair.fromSecretKey(Uint8Array.from(privateKeyArray));
}

let keyPair = getKeyPair(privKey);
let mugenAddress = keyPair.getPublicKey().toSuiAddress();
// console.log(mugenAddress);

const provider = new JsonRpcProvider(testnetConnection);
const signer = new RawSigner(keyPair, provider);
const { modules, dependencies } = JSON.parse(
	execSync(`${cliPath} move build --dump-bytecode-as-base64 --path ${packagePath}`, {
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
  const result = await signer.signAndExecuteTransactionBlock({
    transactionBlock: tx,
  });
  var fs = require('fs');
  fs.writeFile(`./auto-results/publishResult.json`, JSON.stringify(result, null, 2), function(err: any) {
    if (err) {
        console.log(err);
    }
  });
  console.log(result);
}

publish();