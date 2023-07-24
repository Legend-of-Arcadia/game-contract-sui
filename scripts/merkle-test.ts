/// script for generating input for `mint_from_signature`
import { Secp256k1Keypair, Ed25519Keypair } from "@mysten/sui.js";
import { BCS, getSuiMoveConfig } from "@mysten/bcs"
import * as dotenv from "dotenv";
dotenv.config();
const keccak256 = require("keccak256");

const { MerkleTree } = require("merkletreejs");

const privKeyStr: string = process.env.PRIVATE_KEY!;


function constructMessageToSign(
    name: string,
    userAddress: string,
    amount: number,
){
    let msg: Array<Uint8Array> = [];
    let bcs = new BCS(getSuiMoveConfig());

    const nameBytes = bcs.ser(["string", BCS.STRING], name).toString("base64");

    const addressBytes: Uint8Array = new Uint8Array(Buffer.from(userAddress.slice(2), 'hex'));

    const amountBytes = bcs.ser(["u64", BCS.U64], amount).toString("base64");

    msg.push(Buffer.from(nameBytes, 'base64'))
    msg.push(addressBytes);

    msg.push(Buffer.from(amountBytes, 'base64'));


    return msg;
}


// put user address here
const userAddress = "0x0000000000000000000000000000000000000000000000000000000000000222";

const amount = 30000000000;

const name = "2023-7-19"

const msgToSign = constructMessageToSign(
    name,
    userAddress,
    amount
);



// Concatenate the message-to-sign Uint8Arrays to one byte array.
let msgToSignBytes: Uint8Array = new Uint8Array();

msgToSign.forEach((msg) => {
    msgToSignBytes = Uint8Array.from([...msgToSignBytes, ...msg]);
});

console.log(" ------ Message to Sign bytes -----")
console.log(msgToSignBytes);


console.log(BytesToHexString(msgToSignBytes));
console.log(BytesToHexString(keccak256(Buffer.from(msgToSignBytes))));

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

const name1 = "2023-7-19"
const userAddress1 = "0x0000000000000000000000000000000000000000000000000000000000000222";
const amount1 = 30000000000;
const userAddress2 = "0x0000000000000000000000000000000000000000000000000000000000000111";
const amount2 = 30000000000;
const userAddress3 = "0x0000000000000000000000000000000000000000000000000000000000000333";
const amount3 = 30000000000;

var users = [
    encodeData(name1, userAddress1, amount1),
    encodeData(name1, userAddress2, amount2),
    encodeData(name1, userAddress3, amount3),
]
console.log(users)
let merkleTree = new MerkleTree(
    users,
    keccak256,
    { sortPairs: true, hashLeaves: true }
);

console.log(merkleTree.toString())
console.log(merkleTree.getHexRoot())
console.log(merkleTree.getHexLeaves()[0])
console.log(merkleTree.getHexProof(merkleTree.getHexLeaves()[0]))
function encodeData(
    name: string,
    userAddress: string,
    amount: number
){
    let msgToSignBytes: Uint8Array = new Uint8Array();

    let msg = constructMessageToSign(
        name,
        userAddress,
        amount
    );
    msg.forEach((msg) => {
        msgToSignBytes = Uint8Array.from([...msgToSignBytes, ...msg]);
    });

    return Buffer.from(msgToSignBytes)
}