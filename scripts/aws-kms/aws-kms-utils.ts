// https://github.com/GradiusX/sui-kms/blob/main/index.ts
import { GetPublicKeyCommand, KMSClient, SignCommand } from '@aws-sdk/client-kms';
import EthCrypto from 'eth-crypto';
import { Secp256k1PublicKey, SerializedSignature, SignatureScheme, toSerializedSignature } from '@mysten/sui.js';
import { secp256k1 } from '@noble/curves/secp256k1';
import { blake2b } from '@noble/hashes/blake2b';

const asn1 = require('asn1.js');
// Definition of EcdsaPubKey
const EcdsaPubKey = asn1.define('EcdsaPubKey', function(this: any) {
  // https://tools.ietf.org/html/rfc5480#section-2
  this.seq().obj(
    this.key('algo').seq().obj(
      this.key('algorithm').objid(),
      this.key('parameters').objid(),
    ),
    this.key('pubKey').bitstr(),
  );
});

async function awsKmsGetPublicKey(cli: KMSClient, keyId: string): Promise<Secp256k1PublicKey> {
  const params = {
    KeyId: keyId,
  };
  const cmd = new GetPublicKeyCommand(params);
  const pk_full_raw = await cli.send(cmd);
  const pk_raw = pk_full_raw.PublicKey!;
  const res = EcdsaPubKey.decode(Buffer.from(pk_raw), 'der');
  const kms_pk_comp = EthCrypto.publicKey.compress(res.pubKey.data);
  const pubKey = new Secp256k1PublicKey(Uint8Array.from(Buffer.from(kms_pk_comp, 'hex')));
  console.log('public key of KMS wallet: ', pubKey.toString(), pubKey.toSuiAddress());
  return pubKey;
}

async function awsKmsSign(cli: KMSClient, keyId: string, digest: Uint8Array): Promise<Uint8Array> {
  const cmd = new SignCommand({
    KeyId: keyId,
    Message: Buffer.from(digest),
    MessageType: 'RAW',  // https://github.com/MystenLabs/sui/blob/dc099596ed74fabe97c110c172c8548686812d5e/crates/sui/src/keytool.rs#L756
    SigningAlgorithm: 'ECDSA_SHA_256', // https://github.com/MystenLabs/sui/blob/dc099596ed74fabe97c110c172c8548686812d5e/crates/sui/src/keytool.rs#L757
  });

  const response = await cli.send(cmd);
  if (!response.Signature) {
    throw new Error('Signature not available');
  }

  const sig_r_s = secp256k1.Signature.fromDER(Buffer.from(response.Signature).toString('hex'));
  const sig_normalized = sig_r_s.normalizeS(); // very important
  return sig_normalized.toCompactRawBytes();
}

async function awsKmsSignTx(cli: KMSClient, keyId: string, txData: Uint8Array): Promise<SerializedSignature> {
  const pubKey = await awsKmsGetPublicKey(cli, keyId);
  const digest = blake2b(txData, { dkLen: 32 });
  const signature = await awsKmsSign(cli, keyId, digest);
  const signatureScheme: SignatureScheme = 'Secp256k1';
  return toSerializedSignature({
    signatureScheme,
    signature,
    pubKey,
  });
}


export {
  awsKmsGetPublicKey,
  awsKmsSign,
  awsKmsSignTx,
};