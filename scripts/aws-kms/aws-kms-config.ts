
export class AwsKmsSetting {
  region!: string;

  accessKeyId!: string;

  secretAccessKey!: string;

  constructor(region: string, accessKeyId: string, secretAccessKey: string) {
      this.region = region;
      this.accessKeyId = accessKeyId;
      this.secretAccessKey = secretAccessKey;
  }
}

export class AwsKmsSingerConfig {
  keyId!: string;

  region!: string;

  accessKeyId!: string;

  secretAccessKey!: string;

  constructor(keyId: string, setting: AwsKmsSetting) {
    this.keyId = keyId;
    this.region = setting.region;
    this.accessKeyId = setting.accessKeyId;
    this.secretAccessKey = setting.secretAccessKey;
  }
}