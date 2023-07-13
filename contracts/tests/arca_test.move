#[test_only]
module contracts::arca_test {
    use contracts::arca::{Self, ARCA, ArcaCounter, SeenMessages};
    use sui::clock;
    use sui::test_scenario as ts;
    use sui::coin::{Self};
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
    fun test_deposit_and_withdraw() {
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

            let coin_arca = arca::withdraw(&mut arca_counter, 30*DECIMALS, 0, 1, vector[1,1], &mut seen_messages, &clock, ts::ctx(&mut scenario));

            assert!(coin::value(&coin_arca) == 30*DECIMALS, 1);
            transfer::public_transfer(coin_arca, GAME);
            ts::return_shared(arca_counter);
            ts::return_shared(seen_messages);
            ts::return_shared(clock);
        };

        ts::end(scenario);
    }
}