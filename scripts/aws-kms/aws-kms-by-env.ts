
import * as dotenv from 'dotenv';
import {KMSClientConfig} from "@aws-sdk/client-kms";
import {
    devnetConnection,
    JsonRpcProvider,
    mainnetConnection,
    SignerWithProvider,
    testnetConnection
} from "@mysten/sui.js";
import {AwsKmsSetting, AwsKmsSingerConfig} from "./aws-kms-config";
import {AwsKmsSinger} from "./aws-kms-singer";
dotenv.config()

const network = process.env.NETWORK || 'testnet';
const kmsConfig = new AwsKmsSingerConfig(
    process.env.KMS_KEY_ID!,
    new AwsKmsSetting(
        process.env.KMS_REGION || 'us-east-1',
        process.env.KMS_ACCESS_KEY_ID!,
        process.env.KMS_SECRET_ACCESS!,
    )
);

export function getProvider(): JsonRpcProvider{
    switch (process.env.NETWORK) {
        case "devnet":
            return new JsonRpcProvider(devnetConnection);
        case "testnet":
            return new JsonRpcProvider(testnetConnection);
        case "mainnet":
            return new JsonRpcProvider(mainnetConnection);
        default:
            return new JsonRpcProvider(devnetConnection);
    }
}

export async function getKmsSigner():Promise<SignerWithProvider> {
    const provider = getProvider();
    const singer = new AwsKmsSinger(provider, kmsConfig);
    const pubKey = await singer.getPublicKey();
    console.log(`public key: ${pubKey.toBase64()}  address: ${pubKey.toSuiAddress()}`)
    return singer;
}