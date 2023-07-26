#[test_only]
module contracts::marketplace_tests {

    use loa::arca::{ARCA};
    use contracts::marketplace::{Self, Marketplace};
    use contracts::hero::Hero;
    use contracts::staking::{Self, StakingPool};
    use contracts::game::{Self, GameCap, GameConfig};

    use sui::clock;
    use sui::test_scenario as ts;
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use multisig::multisig::{Self, MultiSignature};

    use std::option;
    use std::debug;
    //use std::string;

    const EToBurnNotCorrect: u64 = 0;

    const GAME: address = @0x111;
    const USER1_ADDRESS: address = @0xABCD;

    const DECIMALS: u64 = 1_000_000_000;

    #[test]
    fun test_buy_primary_arca() {
        let scenario = ts::begin(GAME);

        let coin = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));

        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));
        marketplace::init_for_testing(ts::ctx(&mut scenario));
        //arca::init_for_testing(ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);

            //let treasury = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);

            staking::init_for_testing(&cap, ts::ctx(&mut scenario));

            let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
            transfer::public_transfer(hero, GAME);

            ts::return_to_sender<GameCap>(&scenario, cap);
            //ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, treasury);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let hero = ts::take_from_sender<Hero>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);

            marketplace::list_primary_arca<Hero>(&cap, &mut marketplace, hero, 30*DECIMALS);

            ts::return_shared(marketplace);
            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);

            let hero = marketplace::buy_primary_arca<Hero>(coin, &mut marketplace, 1, ts::ctx(&mut scenario));

            transfer::public_transfer(hero, GAME);
            ts::return_shared(marketplace);
            ts::return_to_sender<GameCap>(&scenario, cap);

        };

        ts::next_tx(&mut scenario, GAME);
        {
            let sp = ts::take_shared<StakingPool>(&mut scenario);


            let rewards_value = staking::get_rewards_value(&sp);

            assert!(rewards_value == 0, EToBurnNotCorrect);

            ts::return_shared(sp);
        
        };
        ts::end(scenario);
    }

    #[test]
    fun test_buy_secondary_arca() {
        let scenario = ts::begin(GAME);

        let coin = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));

        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));
        marketplace::init_for_testing(ts::ctx(&mut scenario));
        //arca::init_for_testing(ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);

            //let treasury = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);

            staking::init_for_testing(&cap, ts::ctx(&mut scenario));

            let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
            transfer::public_transfer(hero, GAME);

            ts::return_to_sender<GameCap>(&scenario, cap);
            //ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, treasury);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let hero = ts::take_from_sender<Hero>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);

            marketplace::list_secondary_arca<Hero>(&mut marketplace, hero, 30*DECIMALS, ts::ctx(&mut scenario));

            ts::return_shared(marketplace);
            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);

            let hero = marketplace::buy_secondary_arca<Hero, Coin<ARCA>>(coin, 1, option::none<address>(), &mut marketplace, &mut sp, ts::ctx(&mut scenario));

            transfer::public_transfer(hero, GAME);
            ts::return_shared(marketplace);
            ts::return_shared(sp);
            ts::return_to_sender<GameCap>(&scenario, cap);

        };

        ts::next_tx(&mut scenario, GAME);
        {
            let sp = ts::take_shared<StakingPool>(&mut scenario);


            let rewards_value = staking::get_rewards_value(&sp);

            assert!(rewards_value == 360000000, EToBurnNotCorrect);

            ts::return_shared(sp);
        
        };

        ts::end(scenario);

    }

    #[test]
    fun test_buy_secondary_vip_arca() {
        let scenario = ts::begin(GAME);

        let coin = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));
        let coin2 = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));

        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));
        marketplace::init_for_testing(ts::ctx(&mut scenario));
        //arca::init_for_testing(ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);

            //let treasury = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);

            staking::init_for_testing(&cap, ts::ctx(&mut scenario));

            let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
            transfer::public_transfer(hero, GAME);

            ts::return_to_sender<GameCap>(&scenario, cap);
            //ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, treasury);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let hero = ts::take_from_sender<Hero>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);


            staking::stake(
                &mut sp,
                coin2,
                &clock,
                31_556_926,
                ts::ctx(&mut scenario)
            );

            marketplace::list_secondary_arca<Hero>(&mut marketplace, hero, 30*DECIMALS, ts::ctx(&mut scenario));

            ts::return_shared(marketplace);
            ts::return_shared(sp);
            ts::return_shared(clock);
            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);


            let hero = marketplace::buy_secondary_vip_arca<Hero>(coin, 1, option::none<address>(), &mut marketplace, &mut sp, &clock, ts::ctx(&mut scenario));

            transfer::public_transfer(hero, GAME);
            ts::return_shared(marketplace);
            ts::return_shared(sp);
            ts::return_shared(clock);
            ts::return_to_sender<GameCap>(&scenario, cap);

        };

        ts::next_tx(&mut scenario, GAME);
        {
            let sp = ts::take_shared<StakingPool>(&mut scenario);


            let rewards_value = staking::get_rewards_value(&sp);

            assert!(rewards_value == 360000000, EToBurnNotCorrect);

            ts::return_shared(sp);
        
        };

        ts::end(scenario);

    }

    #[test]
    fun test_buy_secondarya() {
        let scenario = ts::begin(GAME);

        let coin = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));

        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));
        marketplace::init_for_testing(ts::ctx(&mut scenario));
        //arca::init_for_testing(ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);

            //let treasury = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);

            staking::init_for_testing(&cap, ts::ctx(&mut scenario));

            let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
            transfer::public_transfer(hero, GAME);

            ts::return_to_sender<GameCap>(&scenario, cap);
            //ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, treasury);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let hero = ts::take_from_sender<Hero>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);

            marketplace::list_secondary<Hero, ARCA>(&mut marketplace, hero, 30*DECIMALS, ts::ctx(&mut scenario));

            ts::return_shared(marketplace);
            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);

            let hero = marketplace::buy_secondary<Hero, ARCA>(coin, 1,  &mut marketplace,  ts::ctx(&mut scenario));

            transfer::public_transfer(hero, GAME);
            ts::return_shared(marketplace);
            ts::return_shared(sp);
            ts::return_to_sender<GameCap>(&scenario, cap);

        };

        ts::next_tx(&mut scenario, GAME);
        {
            let multi_signature = ts::take_shared<MultiSignature>(&mut scenario);
            let config = ts::take_shared<GameConfig>(&mut scenario);
            marketplace::withdraw_fee_profits_request<ARCA>(&mut config, &mut multi_signature, GAME,ts::ctx(&mut scenario));

            ts::return_shared(multi_signature);
            ts::return_shared(config);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let multi_signature = ts::take_shared<MultiSignature>(&mut scenario);
            let config = ts::take_shared<GameConfig>(&mut scenario);
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            multisig::vote(&mut multi_signature, 0, true, ts::ctx(&mut scenario));
            let b = marketplace::withdraw_fee_profits_execute<ARCA>(&mut config, &mut multi_signature, 0, true, &mut marketplace,ts::ctx(&mut scenario));

            assert!(b, 1);

            ts::next_tx(&mut scenario, GAME);
            let coin = ts::take_from_address<Coin<ARCA>>(&mut scenario, GAME);
            //let x = coin::value(&coin);
            debug::print(&coin::value<ARCA>(&coin));
            assert!(coin::value<ARCA>(&coin) == 30*DECIMALS * 3/100, 1);

            ts::return_to_sender(&mut scenario, coin);
            ts::return_shared(multi_signature);
            ts::return_shared(config);
            ts::return_shared(marketplace);
        };

        ts::end(scenario);

    }


    #[test]
    fun test_buy_secondary_vip() {
        let scenario = ts::begin(GAME);

        let coin = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));
        let coin2 = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));

        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));
        marketplace::init_for_testing(ts::ctx(&mut scenario));
        //arca::init_for_testing(ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);

            //let treasury = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);

            staking::init_for_testing(&cap, ts::ctx(&mut scenario));

            let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
            transfer::public_transfer(hero, GAME);

            ts::return_to_sender<GameCap>(&scenario, cap);
            //ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, treasury);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let hero = ts::take_from_sender<Hero>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);


            staking::stake(
                &mut sp,
                coin2,
                &clock,
                31_556_926,
                ts::ctx(&mut scenario)
            );

            marketplace::list_secondary<Hero, ARCA>(&mut marketplace, hero, 30*DECIMALS, ts::ctx(&mut scenario));

            ts::return_shared(marketplace);
            ts::return_shared(sp);
            ts::return_shared(clock);
            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);


            let hero = marketplace::buy_secondary_vip<Hero, ARCA>(coin, 1, &mut marketplace, &mut sp, &clock, ts::ctx(&mut scenario));

            transfer::public_transfer(hero, GAME);
            ts::return_shared(marketplace);
            ts::return_shared(sp);
            ts::return_shared(clock);
            ts::return_to_sender<GameCap>(&scenario, cap);

        };

        ts::next_tx(&mut scenario, GAME);
        // {
        //     let sp = ts::take_shared<StakingPool>(&mut scenario);
        //
        //
        //     let rewards_value = staking::get_rewards_value(&sp);
        //
        //     assert!(rewards_value == 360000000, EToBurnNotCorrect);
        //
        //     ts::return_shared(sp);
        //
        // };

        ts::end(scenario);

    }

    #[test]
    fun test_take_item() {
        let scenario = ts::begin(GAME);

        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));
        marketplace::init_for_testing(ts::ctx(&mut scenario));
        //arca::init_for_testing(ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);

            //let treasury = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);

            staking::init_for_testing(&cap, ts::ctx(&mut scenario));

            let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
            transfer::public_transfer(hero, GAME);

            ts::return_to_sender<GameCap>(&scenario, cap);
            //ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, treasury);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let hero = ts::take_from_sender<Hero>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);

            marketplace::list_secondary<Hero, ARCA>(&mut marketplace, hero, 30*DECIMALS, ts::ctx(&mut scenario));

            ts::return_shared(marketplace);
            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);

            let hero = marketplace::take_item<Hero>(1,  &mut marketplace,  ts::ctx(&mut scenario));

            transfer::public_transfer(hero, GAME);
            ts::return_shared(marketplace);
            ts::return_shared(sp);
            ts::return_to_sender<GameCap>(&scenario, cap);

        };


        ts::end(scenario);

    }


}