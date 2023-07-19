import { testnetConnection, fromB64, TransactionBlock, Ed25519Keypair, JsonRpcProvider, RawSigner, devnetConnection} from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config();

const privKey: string = process.env.PRIVATE_KEY as string;
const playerPrivKey: string = process.env.PLAYER_PRIVATE_KEY!;
const gameCapId = process.env.GAME_CAP as string;
const packageId = process.env.PACKAGE as string;
const upgraderId = process.env.UPGRADER as string;
const gameConfigId = process.env.GAME_CONFIG as string;
// cli path is "sui"

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

let keyPair = getKeyPair(privKey);
let provider = new JsonRpcProvider(testnetConnection);
let mugen = new RawSigner(keyPair, provider);

async function addGameCap() {
    let txb = new TransactionBlock();

    //let capId = "0x4a7fcc8ad88afc291bf52b8bf794ade682c03c50dd3ea2b7879347e0e6adf7e7"

    let gameCap = txb.moveCall({
        target: `${packageId}::game::create_game_cap_by_admin`,
        arguments: [
            txb.object(gameConfigId),
        ]
    });
    txb.transferObjects([gameCap], txb.pure(keyPair.getPublicKey().toSuiAddress()));
    let result = await mugen.signAndExecuteTransactionBlock({
        transactionBlock: txb,
        requestType: "WaitForLocalExecution",
        options: {
            showEffects: true,
            showObjectChanges: true,
        },
    });

    return result;

}

async function main() {
    //let addresses = ['0x0421a66d58e4acd151ec50a2c5aa6219ca3c13d18df816c6e93b0b7838e26f65', '0x9e4edd0140d46f36d58772b8ba62f7c11c5d15cddaf7bcb3f9bef6fdcb4f8a86', '0x5fc4018050c3f30499bcd7e18b028596bd5f25557080725f1fd586a6d5def2b1', '0x611ae9aba751de462aa8347a0d4428584193a64373bb717e389f17c8df21a52b'];

    let result = await addGameCap();
    console.log(result);
}

main();
