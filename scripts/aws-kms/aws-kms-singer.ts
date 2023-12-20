import {
  JsonRpcProvider,
  Secp256k1PublicKey,
  SerializedSignature,
  SignerWithProvider,
  toSerializedSignature,
} from '@mysten/sui.js';
import { AwsKmsSetting, AwsKmsSingerConfig } from './aws-kms-config';
import { KMSClient } from '@aws-sdk/client-kms';
import { blake2b } from '@noble/hashes/blake2b';
import { SignatureScheme } from '@mysten/sui.js/dist/cryptography/signature';
import { awsKmsGetPublicKey, awsKmsSign } from './aws-kms-utils';

export class AwsKmsSinger extends SignerWithProvider {
  private readonly config: AwsKmsSingerConfig;
  private readonly awsCli: KMSClient;
  private pubKey?: Secp256k1PublicKey;

  constructor(provider: JsonRpcProvider, config: AwsKmsSingerConfig) {
    super(provider);
    this.awsCli = new KMSClient({
      region: config.region,
      credentials: {
        accessKeyId: config.accessKeyId,
        secretAccessKey: config.secretAccessKey,
      },
    });
    this.config = config;
  }

  async getPublicKey(): Promise<Secp256k1PublicKey> {
    if (this.pubKey) {
      return this.pubKey;
    }
    this.pubKey = await awsKmsGetPublicKey(this.awsCli, this.config.keyId);
    return this.pubKey;
  }

  async getAddress(): Promise<string> {
    return (await this.getPublicKey()).toSuiAddress();
  }

  async signData(data: Uint8Array): Promise<SerializedSignature> {
    const pubKey = await this.getPublicKey();
    const digest = blake2b(data, { dkLen: 32 });
    const signature = await awsKmsSign(this.awsCli, this.config.keyId, digest);
    const signatureScheme: SignatureScheme = 'Secp256k1';
    return toSerializedSignature({
      signatureScheme,
      signature,
      pubKey,
    });
  }

  override connect(provider: JsonRpcProvider): SignerWithProvider {
    return new AwsKmsSinger(provider, this.config);
  }
}

export async function awsKmsGetPublicKeyBySetting(setting: AwsKmsSetting, keyId: string): Promise<Secp256k1PublicKey> {
  const cli = new KMSClient({
    region: setting.region,
    credentials: {
      accessKeyId: setting.accessKeyId,
      secretAccessKey: setting.secretAccessKey,
    },
  });
  const key = await awsKmsGetPublicKey(cli, keyId);
  cli.destroy();
  return key;
}

export async function awsKmsSignBySetting(setting: AwsKmsSetting, keyId: string, digest: Uint8Array): Promise<Uint8Array> {
  const cli = new KMSClient({
    region: setting.region,
    credentials: {
      accessKeyId: setting.accessKeyId,
      secretAccessKey: setting.secretAccessKey,
    },
  });
  const signature = await awsKmsSign(cli, keyId, digest);
  cli.destroy();
  return signature;
}
