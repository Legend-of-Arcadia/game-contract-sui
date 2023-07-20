#[test_only]
module contracts::arca_test {
    use contracts::arca::{Self, ARCA, ArcaCounter, SeenMessages};
    use sui::clock;
    use sui::test_scenario as ts;
    use sui::coin::{Self, TreasuryCap};
    use sui::transfer;

    const GAME: address = @0x111;
    const USER1_ADDRESS: address = @0xABCD;
    const DECIMALS: u64 = 1_000_000_000;

    #[test]
    fun test_deposit() {
        let scenario = ts::begin(GAME);
        arca::init_for_testing(ts::ctx(&mut scenario));
        let coin = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, GAME);
        {
            let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
            arca::deposit(coin, &mut arca_counter, ts::ctx(&mut scenario));

            ts::return_shared<ArcaCounter>(arca_counter);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_deposit_and_withdraw_from_signature_1() {
        let mugen_pk: vector<u8> = vector[
            2, 103,  79,  79, 204,  13, 202, 247,
            197,  59,  99,  89, 191,  68, 208, 197,
            53,  13, 102, 206, 105, 188,  11, 224,
            201, 218, 204, 245,  28, 251, 215,  86,
            126
        ];
        let signed_message: vector<u8> =   vector[
            9,  36,  34, 221, 233, 141, 240,  33, 192, 151,  92,
            29, 233, 168, 167,  59, 211, 129,   4, 173, 232,  91,
            70,  71,  26, 165, 166,  27, 172, 124,  32,  74,  96,
            61, 239,  28,  89,  73, 207,  14, 235, 187, 109,  23,
            193,  91, 163, 108, 108,  28,   8, 155, 135, 176, 219,
            194,  98, 164,  56,  93, 200, 175, 172, 135
        ];

        let amount = 30*DECIMALS;
        let fee = 300;
        let chain_id = 99;
        let package:address = @0xa23f846f3f65c18dd46ea114cd07f2368c4f4f2c392a69957f7ac81f257a03ea;

        let scenario = ts::begin(GAME);
        arca::init_for_testing(ts::ctx(&mut scenario));
        let coin = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));

        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        ts::next_tx(&mut scenario, GAME);
        {
            let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
            arca::deposit(coin, &mut arca_counter, ts::ctx(&mut scenario));

            ts::return_shared<ArcaCounter>(arca_counter);
        };
        ts::next_tx(&mut scenario, GAME);
        {
            let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
            let seen_messages = ts::take_shared<SeenMessages>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            let treasury = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
            arca::set_mugen_pk(&treasury,mugen_pk,&mut seen_messages);
            let coin_arca = arca::withdraw(&mut arca_counter, amount, 0, 1, fee, chain_id, package, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));

            assert!(coin::value(&coin_arca) == amount - fee, 1);
            transfer::public_transfer(coin_arca, GAME);
            ts::return_shared(arca_counter);
            ts::return_shared(seen_messages);
            ts::return_shared(clock);
            ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, treasury);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_deposit_and_withdraw_from_signature_2() {
        let mugen_pk: vector<u8> = vector[
            2, 103,  79,  79, 204,  13, 202, 247,
            197,  59,  99,  89, 191,  68, 208, 197,
            53,  13, 102, 206, 105, 188,  11, 224,
            201, 218, 204, 245,  28, 251, 215,  86,
            126
        ];
        let signed_message: vector<u8> =   vector[
            241, 162,   1, 194, 128, 144, 151, 126, 252, 226,  62,
            147,  43,  18,  96,  51, 172,  56, 193, 244, 168, 149,
            28, 126,  65, 180, 111, 139, 246, 221, 132, 133,  33,
            114,  42,  49, 125, 244, 164, 159, 138,  60, 134, 103,
            22, 192,  68,  38,  33, 153, 141,  55, 220, 144, 238,
            160,  65, 123, 153, 167,  17,  57, 224, 112
        ];
        let chain_id = 99;
        let package:address = @0xa23f846f3f65c18dd46ea114cd07f2368c4f4f2c392a69957f7ac81f257a03ea;

        let amount = 1000;
        let fee = 3;
        let scenario = ts::begin(GAME);
        arca::init_for_testing(ts::ctx(&mut scenario));
        let coin = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));

        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        ts::next_tx(&mut scenario, GAME);
        {
            let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
            arca::deposit(coin, &mut arca_counter, ts::ctx(&mut scenario));

            ts::return_shared<ArcaCounter>(arca_counter);
        };
        ts::next_tx(&mut scenario, GAME);
        {
            let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
            let seen_messages = ts::take_shared<SeenMessages>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            let treasury = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
            arca::set_mugen_pk(&treasury,mugen_pk,&mut seen_messages);
            let coin_arca = arca::withdraw(&mut arca_counter, amount, 0, 1, fee, chain_id, package, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));

            assert!(coin::value(&coin_arca) == amount - fee, 1);
            transfer::public_transfer(coin_arca, GAME);
            ts::return_shared(arca_counter);
            ts::return_shared(seen_messages);
            ts::return_shared(clock);
            ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, treasury);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_deposit_and_withdraw_from_signature_3() {
        let mugen_pk: vector<u8> = vector[
            2, 103,  79,  79, 204,  13, 202, 247,
            197,  59,  99,  89, 191,  68, 208, 197,
            53,  13, 102, 206, 105, 188,  11, 224,
            201, 218, 204, 245,  28, 251, 215,  86,
            126
        ];
        let signed_message: vector<u8> =   vector[
            116, 118, 135, 131, 192, 111, 223, 236, 120,  54,
            187,  91, 177, 248, 189, 224,  93, 185, 218, 254,
            36, 156, 125,  37, 204, 163, 222, 224,  67,  47,
            182, 230,  85,  27,  38,  94, 101,  84, 151,   1,
            223, 245, 100, 139, 221, 176, 103,  90, 254, 123,
            242, 174, 108, 164,  79, 237, 190,  20, 219, 180,
            116, 143, 105, 203
        ]
        ;

        let amount = 30*DECIMALS;
        let fee = 0;
        let chain_id = 99;
        let package:address = @0xa23f846f3f65c18dd46ea114cd07f2368c4f4f2c392a69957f7ac81f257a03ea;
        let scenario = ts::begin(GAME);
        arca::init_for_testing(ts::ctx(&mut scenario));
        let coin = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));

        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        ts::next_tx(&mut scenario, GAME);
        {
            let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
            arca::deposit(coin, &mut arca_counter, ts::ctx(&mut scenario));

            ts::return_shared<ArcaCounter>(arca_counter);
        };
        ts::next_tx(&mut scenario, GAME);
        {
            let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
            let seen_messages = ts::take_shared<SeenMessages>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            let treasury = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
            arca::set_mugen_pk(&treasury,mugen_pk,&mut seen_messages);
            clock::increment_for_testing(&mut clock, 1689304580000);
            let coin_arca = arca::withdraw(&mut arca_counter, amount, 1691982960, 1, fee, chain_id, package, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));

            assert!(coin::value(&coin_arca) == amount - fee, 1);
            transfer::public_transfer(coin_arca, GAME);
            ts::return_shared(arca_counter);
            ts::return_shared(seen_messages);
            ts::return_shared(clock);
            ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, treasury);
        };

        ts::end(scenario);
    }
}