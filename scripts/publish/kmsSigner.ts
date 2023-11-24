import {
    SerializedSignature,
    toSerializedSignature,
    JsonRpcProvider,
    SuiAddress,
    SignerWithProvider,
    Secp256k1PublicKey,
} from "@mysten/sui.js";
import * as dotenv from "dotenv";
const { execSync } = require('child_process');
dotenv.config();

const base64pk = process.env.KMS_BASE64PK!;
const keyId = process.env.KMS_KEY_ID!;
const cliPath: string = process.env.CLI_PATH!;

export class KmsSigner extends SignerWithProvider {
    //       this.sui = new Sui(await Transport.create());

    readonly base64Pk: string;
    readonly kmsKeyId: string;
    //readonly suiAddress: string;

    constructor(provider: JsonRpcProvider) {
        super(provider);
        this.base64Pk = base64pk;
        this.kmsKeyId = keyId;
    }

    async getPublicKey(): Promise<Secp256k1PublicKey> {
        const pk = new Secp256k1PublicKey(Buffer.from(this.base64Pk, 'base64').slice(1))
        console.log("public key of KMS wallet: ", pk.toString(), pk.toSuiAddress());
        return pk;
    }

    async getAddress(): Promise<SuiAddress> {
        return (await this.getPublicKey()).toSuiAddress();
    }

    // 因为sui keytool sign-kms 签名工具签名intent意向值是在工具内处理的, signData接口是需要data里面有意向信息，暂无法兼容
    async signData(data: Uint8Array): Promise<SerializedSignature> {
        const pubkey = await this.getPublicKey();

        //const digest = blake2b(data, { dkLen: 32 });
        // const result = await (await this.getSinger()).signTransaction(PATH, data);
        // const signature = result.signature;
        const tx_data = Buffer.from(data).toString('base64')
        const { serializedSigBase64 } = JSON.parse(
            execSync(`${cliPath} keytool sign-kms --data ${tx_data} --keyid ${keyId} --base64pk ${base64pk} --json`),
        );

        const signature = serializedSigBase64
        const signatureScheme = "Secp256k1";

        return toSerializedSignature({
            signatureScheme,
            signature,
            pubKey: pubkey,
        });
    }

    connect(provider: JsonRpcProvider): SignerWithProvider {
        return new KmsSigner(provider);
    }
}