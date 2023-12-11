import {
    SerializedSignature,
    JsonRpcProvider,
    SuiAddress,
    SignerWithProvider,
    Secp256k1PublicKey,
    toSerializedSignature
} from "@mysten/sui.js";
import * as dotenv from "dotenv";
import {KMSClient} from "@aws-sdk/client-kms";
import {awsKmsGetPublicKey, awsKmsSign} from "../aws-kms/aws-kms-utils";
import {blake2b} from "@noble/hashes/blake2b";
import {SignatureScheme} from "@mysten/sui.js/dist/cryptography/signature";
dotenv.config();

const keyId = process.env.KMS_KEY_ID!;

export class KmsSigner extends SignerWithProvider {
    private readonly kmsKeyId: string;
    private readonly awsCli: KMSClient;
    private pubKey?: Secp256k1PublicKey;

    constructor(provider: JsonRpcProvider) {
        super(provider);
        this.kmsKeyId = keyId;
        this.awsCli = new KMSClient({});
    }

    async getPublicKey(): Promise<Secp256k1PublicKey> {
        if (this.pubKey) {
            return this.pubKey;
        }
        this.pubKey = await awsKmsGetPublicKey(this.awsCli, this.kmsKeyId);
        return this.pubKey;
    }

    async getAddress(): Promise<SuiAddress> {
        return (await this.getPublicKey()).toSuiAddress();
    }

    async signData(data: Uint8Array): Promise<SerializedSignature> {
        const pubKey = await this.getPublicKey();
        const digest = blake2b(data, { dkLen: 32 });
        const signature = await awsKmsSign(this.awsCli, this.kmsKeyId, digest);
        const signatureScheme: SignatureScheme = 'Secp256k1';
        return toSerializedSignature({
            signatureScheme,
            signature,
            pubKey,
        });
    }

    connect(provider: JsonRpcProvider): SignerWithProvider {
        return new KmsSigner(provider);
    }
}