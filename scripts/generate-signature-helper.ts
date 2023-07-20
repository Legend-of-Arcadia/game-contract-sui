/// script for generating input for `mint_from_signature`
import { Secp256k1Keypair, Ed25519Keypair } from "@mysten/sui.js";
import { BCS, getSuiMoveConfig } from "@mysten/bcs"
import * as dotenv from "dotenv";
dotenv.config();

const privKeyStr: string = process.env.PRIVATE_KEY!;


function constructMessageToSign(
    userAddress: string,
    amount: number,
    expire_at: number,
    salt: number,
    fee: number,
    chain_id: number,
    packageAddress: string
){
    let msgToSign: Array<Uint8Array> = [];
    let bcs = new BCS(getSuiMoveConfig());

    const addressBytes: Uint8Array = new Uint8Array(Buffer.from(userAddress.slice(2), 'hex'));

    const amountBytes = bcs.ser(["u64", BCS.U64], amount).toString("base64");
    const expire_atBytes = bcs.ser(["u64", BCS.U64], expire_at).toString("base64");
    const saltBytes = bcs.ser(["u64", BCS.U64], salt).toString("base64");
    const feeBytes = bcs.ser(["u64", BCS.U64], fee).toString("base64");
    const chain_idBytes = bcs.ser(["u64", BCS.U64], chain_id).toString("base64");

    const packageAddressBytes: Uint8Array = new Uint8Array(Buffer.from(packageAddress.slice(2), 'hex'));

    msgToSign.push(addressBytes);

    msgToSign.push(Buffer.from(amountBytes, 'base64'));

    msgToSign.push(Buffer.from(expire_atBytes, 'base64'));
    msgToSign.push(Buffer.from(saltBytes, 'base64'));
    msgToSign.push(Buffer.from(feeBytes, 'base64'));
    msgToSign.push(Buffer.from(chain_idBytes, 'base64'));
    msgToSign.push(packageAddressBytes);

    return msgToSign;
}


// put user address here
const userAddress = "0x0000000000000000000000000000000000000000000000000000000000000111";

const amount = 1000;

const expire_at = 0;
const salt = 1;
const fee = 3;
const chain_id = 99;//1 mainnet 99 testnet
const packageAddress = "0xa23f846f3f65c18dd46ea114cd07f2368c4f4f2c392a69957f7ac81f257a03ea"

const msgToSign = constructMessageToSign(
    userAddress,
    amount,
    expire_at,
    salt,
    fee,
    chain_id,
    packageAddress
);

// get a private key
let privKey = [
    53, 239, 217, 255, 238,  89,  47,  39,
    86,  51, 167,  41,  71, 198, 183,  17,
    188, 144, 196, 207,  32, 160, 165, 103,
    243, 234,  31, 143,  29, 193,  81,  49
];

// make the keypair
const privKeyArray = new Uint8Array(privKey);
//let keypairAdmin = Secp256k1Keypair.fromSecretKey(privKeyArray);
let keypairAdmin = Secp256k1Keypair.fromSecretKey(Buffer.from(privKeyStr.slice(2), "hex"), { skipValidation: true });
console.log(" ------ Admin Public Key -----");
console.log(keypairAdmin.getPublicKey())

// Concatenate the message-to-sign Uint8Arrays to one byte array.
let msgToSignBytes: Uint8Array = new Uint8Array();

msgToSign.forEach((msg) => {
    msgToSignBytes = Uint8Array.from([...msgToSignBytes, ...msg]);
});

console.log(" ------ Message to Sign bytes -----")
console.log(msgToSignBytes);

// sign the message
const signedMsg = keypairAdmin.signData(msgToSignBytes);

console.log(" ------ Signed Message -----")
console.log(signedMsg);