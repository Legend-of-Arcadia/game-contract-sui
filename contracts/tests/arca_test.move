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
            108,  39,  99,  41, 178, 183, 145, 121,  55,  51,  83,
            108,  51,  19,  13, 161, 170, 251,  64, 158,  79, 200,
            87, 101,  92,  48,  59, 123,  52, 153, 235,  25,  40,
            54, 112, 212,  64, 212, 163,  46,  13,  78,  25, 226,
            5,  71,  74, 211, 137,  75, 238, 234, 251, 152,  20,
            240, 240,   1, 250, 157,  40, 218, 240,  97
        ];

        let amount = 30*DECIMALS;
        let fee = 300;

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
            let coin_arca = arca::withdraw(&mut arca_counter, amount, 0, 1, fee, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));

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
            135,  21,  92,  94, 197, 233, 230, 228, 234,  46, 114,
            29, 163,  17, 103,  89,  95, 254, 198,  70, 163,  76,
            252,  83,  67, 137, 249,  11,   5,   4, 174,  19,  15,
            32, 113, 201,  38, 172, 157,  45, 157,  55, 209, 160,
            224, 140, 189, 115,  65, 219,  20, 154, 130, 182, 193,
            117, 157,  99,  92, 124,  65, 189,  95,  74
        ];

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
            let coin_arca = arca::withdraw(&mut arca_counter, amount, 0, 1, fee, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));

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
            58,  41, 102, 210, 232, 170, 182, 167, 236, 232,  25,
            22, 170, 207,  27, 230, 229,   6, 171, 107,  74,  66,
            165,  26,  53, 252,  95,  68, 223,   6, 129, 199,  41,
            238,  94, 124,  19,  11,  13, 111,  92, 236, 252, 220,
            221,  54,  44,  81, 148,  61, 245, 241, 212,   4,  55,
            251, 105,  61,  97, 141,  54,  68, 206, 127
        ];

        let amount = 30*DECIMALS;
        let fee = 0;
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
            let coin_arca = arca::withdraw(&mut arca_counter, amount, 1691982960, 1, fee, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));

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