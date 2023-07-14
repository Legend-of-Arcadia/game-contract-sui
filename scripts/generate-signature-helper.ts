/// script for generating input for `mint_from_signature`
import { Secp256k1Keypair, Ed25519Keypair } from "@mysten/sui.js";
import { BCS, getSuiMoveConfig } from "@mysten/bcs"
import * as dotenv from "dotenv";
dotenv.config();

const privKeyStr: string = process.env.PRIVATE_KEY!;


//        amount: u64,
//         expire_at: u64,
//         salt: u64,

function constructMessageToSign(
    userAddress: string,
    amount: number,
    expire_at: number,
    salt: number,
){
    let msgToSign: Array<Uint8Array> = [];
    let bcs = new BCS(getSuiMoveConfig());

    const addressBytes: Uint8Array = new Uint8Array(Buffer.from(userAddress.slice(2), 'hex'));

    const amountBytes = bcs.ser(["u64", BCS.U64], amount).toString("base64");
    const expire_atBytes = bcs.ser(["u64", BCS.U64], expire_at).toString("base64");
    const saltBytes = bcs.ser(["u64", BCS.U64], salt).toString("base64");

    // const heroNameBytes = bcs.ser(["string", BCS.STRING], heroName).toString("base64");
    // const heroClassBytes = bcs.ser(["string", BCS.STRING], heroClass).toString("base64");
    // const heroFactionBytes = bcs.ser(["string", BCS.STRING], heroFaction).toString("base64");
    // const heroRarityBytes = bcs.ser(["string", BCS.STRING], heroRarity).toString("base64");
    //
    // const baseValuesBytes = bcs.ser(["vector", BCS.U8], baseValues).toString("base64");
    // const skillValuesBytes = bcs.ser(["vector", BCS.U8], skillValues).toString("base64");
    // const appearenceValuesBytes = bcs.ser(["vector", BCS.U8], appearenceValues).toString("base64");
    // const statValuesBytes = bcs.ser(["vector", BCS.U64], statValues).toString("base64");
    // const otherValuesBytes = bcs.ser(["vector", BCS.U8], otherValues).toString("base64");
    //
    // const heroExternalIdBytes = bcs.ser(["string", BCS.STRING], heroExternalId).toString("base64");

    msgToSign.push(addressBytes);

    msgToSign.push(Buffer.from(amountBytes, 'base64'));

    msgToSign.push(Buffer.from(expire_atBytes, 'base64'));
    msgToSign.push(Buffer.from(saltBytes, 'base64'));

    return msgToSign;
}


// put user address here
const userAddress = "0x0000000000000000000000000000000000000000000000000000000000000111";

const amount = 30 * 1000000000;

const expire_at = 1691982960;
const salt = 1;

const msgToSign = constructMessageToSign(
    userAddress,
    amount,
    expire_at,
    salt,
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
console.log(BytesToHexString(msgToSignBytes));

// sign the message
const signedMsg = keypairAdmin.signData(msgToSignBytes);

console.log(" ------ Signed Message -----")
console.log(signedMsg);
console.log(BytesToHexString(signedMsg));

//0000000000000000000000000000000000000000000000000000000000000222e80300000000000000000000000000000100000000000000
//0x0000000000000000000000000000000000000000000000000000000000000111e80300000000000000000000000000000100000000000000
function BytesToHexString(arrBytes: any) {
    var str = "";
    for (var i = 0; i < arrBytes.length; i++) {
        var tmp;
        var num=arrBytes[i];
        if (num < 0) {
            //此处填坑，当byte因为符合位导致数值为负时候，需要对数据进行处理
            tmp =(255+num+1).toString(16);
        } else {
            tmp = num.toString(16);
        }
        if (tmp.length == 1) {
            tmp = "0" + tmp;
        }
        str += tmp;
    }
    return str;
}