import {
  JsonRpcProvider,
  devnetConnection,
  TransactionBlock,
  RawSigner,
  fromB64,
  Ed25519Keypair,
  toB64,
} from "@mysten/sui.js";
import * as dotenv from "dotenv";
dotenv.config();

interface Hero {
  name: string;
  class: string;
  faction: string;
  skill: string;
  rarity: string;
  externalId: string;
}

const heroes = [
  {
    name: "Hero no 1",
    class: "Fighter",
    faction: "Lightbringer",
    skill: "Atk +30%",
    rarity: "SSR",
    externalId: "https://lh3.googleusercontent.com/-cwPXga5-9olh8FI9b3NDnJBMAgYJwYCF9DdswXSGTPHC-S9V3NeBIMyb2fP1iJ3UZvwflDGGIUqsaZYOTmo3_7M5g27DcfFNK7NtYLV9Z0vqDM--Il-Fz1v47x60qp5G_TYN0Y6=w250-h330-no",
  },
  {
    name: "Hero no 2",
    class: "Swordsman",
    faction: "Frostsect",
    skill: "Reflect 20% DMG",
    rarity: "SSR",
    externalId: "https://lh3.googleusercontent.com/XO_b-VB92hPCEo9vOxu9PgjpvSnu1tnPc-5of-b_TQFobNP6-sCBhn_LIxTN7nFqA9MY0XlBVtuskcB9DMBRkTbta7kGEQ7jNpucuscjPxUYyuCymfiU3pg_YBxGhmE7J-V6_gZ-=w220-h296-no",
  },
  {
    name: "Hero no 3",
    class: "Bastion",
    faction: "Voidowanderer",
    skill: "Evasion 10%",
    rarity: "SR",
    externalId: "https://lh3.googleusercontent.com/JkKyocOrkzD06YbX-XJyzXo81bpFFdz7cpLiVdTbiyMoTjT0fWTHrs4eNcNeYRnsx4IVIu8kgt2N_KnRixqNqXA8B5cWrt_5HsKtMxAOnyNNmUQK_xos_tQAulm2DhQlC9p_0X3x=w232-h312-no",
  },
];

const pkg =
  "0xabc8c51ae594ddfe0b9e10301b8dab904c3c01b6a46e3a570b6960d78af85539";

const mint = async (hero: Hero, recipient: string, signer: RawSigner) => {
  const tx = new TransactionBlock();

  const heroNFT = tx.moveCall({
    target: `${pkg}::demo::mint`,
    typeArguments: [],
    arguments: [
      tx.pure(hero.name),
      tx.pure(hero.class),
      tx.pure(hero.faction),
      tx.pure(hero.skill),
      tx.pure(hero.rarity),
      tx.pure(hero.externalId),
    ],
  });
  tx.transferObjects([heroNFT], tx.pure(recipient));

  const response = await signer.signAndExecuteTransactionBlock({
    transactionBlock: tx,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
    },
  });
};

const batchMint = async (
  heroes: Hero[],
  address: string,
  signer: RawSigner
) => {
  const tx = new TransactionBlock();

  const heroesNFT = heroes.map((hero) =>
    tx.moveCall({
      target: `${pkg}::demo::mint`,
      typeArguments: [],
      arguments: [
        tx.pure(hero.name),
        tx.pure(hero.class),
        tx.pure(hero.faction),
        tx.pure(hero.skill),
        tx.pure(hero.rarity),
        tx.pure(hero.externalId),
      ],
    })
  );

  tx.transferObjects(heroesNFT, tx.pure(address));

  tx.setSender(address);

  const response = signer.signAndExecuteTransactionBlock({
    transactionBlock: tx,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
    },
  });
  return response;
};

const main = async () => {
  const privKey = fromB64(process.env.PRIVATE_KEY as string);
  const keypair = Ed25519Keypair.fromSecretKey(privKey);


  // // our address
  const address = `${keypair.getPublicKey().toSuiAddress()}`;
  const provider = new JsonRpcProvider(devnetConnection);
  const signer = new RawSigner(keypair, provider);

  const r = await batchMint(heroes, address, signer);
  console.log(JSON.stringify(r));
};

main();