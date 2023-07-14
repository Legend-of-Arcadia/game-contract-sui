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
            196, 197, 251,   0, 121, 202,  22,  17,  38, 188, 145,
            142,  46, 122,   9,  27, 171, 144,  51, 216,  41, 207,
            249, 148, 116, 251, 208,   8, 152, 122, 117, 252,  59,
            181, 211,   1, 155, 179,  27,  32, 155,  14, 161, 177,
            154,  14, 101,  72, 253,  12, 218, 130,  93,  69, 195,
            159, 100, 225, 107, 245,  95,  28, 108, 141
        ];
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
            let coin_arca = arca::withdraw(&mut arca_counter, 1000, 0, 1, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));

            assert!(coin::value(&coin_arca) == 1000, 1);
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
            46,  29,  82, 160,  14, 170,  91,  67, 117, 168, 164,
            74, 217, 106,  19, 218, 155, 180,  88,  17, 134,  66,
            163, 122,  76, 244, 214, 236,  85,  82, 131, 130,  55,
            196,  39,  85, 164, 137, 168,  59,  60, 224, 148,  83,
            41, 109, 139, 253,  42,  92, 197, 201,  82,  66,  35,
            224, 104, 165,  21, 242, 130, 116,  32,  54
        ];
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
            let coin_arca = arca::withdraw(&mut arca_counter, 30*DECIMALS, 0, 1, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));

            assert!(coin::value(&coin_arca) == 30*DECIMALS, 1);
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
            65, 169, 161, 146,  36, 102, 185, 104,  44,  48, 108,
            20,  59,  17,  16, 190, 202, 174,  49, 197,  22, 142,
            12,  22, 247,   9,   3,  19, 170,  34,  48, 193,  14,
            208,  73,   7, 242,  64, 226,  82,  16, 185,  14, 203,
            48,  90,  42, 174, 113, 201, 214, 191, 197,  65, 217,
            26, 162, 142, 157, 236,  76, 149, 194,   0
        ];
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
            let coin_arca = arca::withdraw(&mut arca_counter, 30*DECIMALS, 1691982960, 1, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));

            assert!(coin::value(&coin_arca) == 30*DECIMALS, 1);
            transfer::public_transfer(coin_arca, GAME);
            ts::return_shared(arca_counter);
            ts::return_shared(seen_messages);
            ts::return_shared(clock);
            ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, treasury);
        };

        ts::end(scenario);
    }
}