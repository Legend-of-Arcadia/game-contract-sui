#[test_only]
module loa_facilities::marketplace_tests {

    use std::option;

    use sui::clock;
    use sui::test_scenario as ts;
    use sui::coin::{Self, Coin};
    use sui::transfer;

    use loa::arca::{ARCA};
    use loa_facilities::marketplace::{Self, Marketplace};
    use loa_facilities::staking::{Self, StakingPool};
    use loa_game::hero::Hero;
    use loa_game::game::{Self, GameCap, GameConfig};

    use multisig::multisig::{Self, MultiSignature};
    use sui::clock::Clock;


    const EToBurnNotCorrect: u64 = 0;

    const GAME: address = @0x111;
    const USER1_ADDRESS: address = @0xABCD;

    const DECIMALS: u64 = 1_000_000_000;

    const WEEK_TO_UNIX_SECONDS: u64 = 604_800;
    const MONTH_TO_UNIX_SECONDS: u64 = 2_628_000; // rounded up
    const YEAR_TO_UNIX_SECONDS: u64 = 31_536_000;

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
            let game_config = ts::take_shared<GameConfig>(&mut scenario);

            //let treasury = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);

            staking::init_for_testing(&cap, ts::ctx(&mut scenario));

            let hero = game::mint_test_hero(&cap, &game_config,ts::ctx(&mut scenario));
            transfer::public_transfer(hero, GAME);

            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(game_config);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let hero = ts::take_from_sender<Hero>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let game_config = ts::take_shared<GameConfig>(&mut scenario);

            marketplace::list_primary_arca<Hero>(&cap, &mut marketplace, hero, 30*DECIMALS, &game_config);

            ts::return_shared(marketplace);
            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(game_config);
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
            let game_config = ts::take_shared<GameConfig>(&mut scenario);

            staking::init_for_testing(&cap, ts::ctx(&mut scenario));

            let hero = game::mint_test_hero(&cap, &game_config,ts::ctx(&mut scenario));
            transfer::public_transfer(hero, GAME);

            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(game_config);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let hero = ts::take_from_sender<Hero>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let clock= ts::take_shared<Clock>(&mut scenario);

            marketplace::list_secondary_arca<Hero>(&mut marketplace, hero, 30*DECIMALS, 0, &clock,ts::ctx(&mut scenario));

            ts::return_shared(marketplace);
            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            let hero = marketplace::buy_secondary_vip_arca<Hero>(coin, 1, option::none<address>(), &mut marketplace, &mut sp, &clock,ts::ctx(&mut scenario));

            transfer::public_transfer(hero, GAME);
            ts::return_shared(clock);
            ts::return_shared(marketplace);
            ts::return_shared(sp);
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
            let game_config = ts::take_shared<GameConfig>(&mut scenario);

            staking::init_for_testing(&cap, ts::ctx(&mut scenario));

            let hero = game::mint_test_hero(&cap, &game_config, ts::ctx(&mut scenario));
            transfer::public_transfer(hero, GAME);

            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(game_config);
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
                YEAR_TO_UNIX_SECONDS,
                ts::ctx(&mut scenario)
            );

            marketplace::list_secondary_arca<Hero>(&mut marketplace, hero, 30*DECIMALS, 0, &clock,ts::ctx(&mut scenario));

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

            assert!(rewards_value == 0, EToBurnNotCorrect);

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
            let game_config = ts::take_shared<GameConfig>(&mut scenario);

            staking::init_for_testing(&cap, ts::ctx(&mut scenario));

            let hero = game::mint_test_hero(&cap, &game_config,ts::ctx(&mut scenario));
            transfer::public_transfer(hero, GAME);

            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(game_config);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let hero = ts::take_from_sender<Hero>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let clock= ts::take_shared<Clock>(&mut scenario);

            marketplace::list_secondary<Hero, ARCA>(&mut marketplace, hero, 30*DECIMALS, 0, &clock,ts::ctx(&mut scenario));

            ts::return_shared(marketplace);
            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            let hero = marketplace::buy_secondary<Hero, ARCA>(coin, 1,  &mut marketplace,  &clock, ts::ctx(&mut scenario));
            ts::next_tx(&mut scenario, GAME);
            assert!(marketplace::get_fee_profits<ARCA>(&marketplace) == 30*DECIMALS * 3/100, 1)
            ;

            transfer::public_transfer(hero, GAME);
            ts::return_shared(marketplace);
            ts::return_shared(sp);
            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(clock);

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
            let game_config = ts::take_shared<GameConfig>(&mut scenario);

            staking::init_for_testing(&cap, ts::ctx(&mut scenario));

            let hero = game::mint_test_hero(&cap, &game_config,ts::ctx(&mut scenario));
            transfer::public_transfer(hero, GAME);

            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(game_config);
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
                YEAR_TO_UNIX_SECONDS,
                ts::ctx(&mut scenario)
            );

            marketplace::list_secondary<Hero, ARCA>(&mut marketplace, hero, 30*DECIMALS, 0, &clock,ts::ctx(&mut scenario));

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
            let game_config = ts::take_shared<GameConfig>(&mut scenario);

            staking::init_for_testing(&cap, ts::ctx(&mut scenario));

            let hero = game::mint_test_hero(&cap, &game_config, ts::ctx(&mut scenario));
            transfer::public_transfer(hero, GAME);

            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(game_config);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let hero = ts::take_from_sender<Hero>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let clock= ts::take_shared<Clock>(&mut scenario);

            marketplace::list_secondary<Hero, ARCA>(&mut marketplace, hero, 30*DECIMALS, 0, &clock,ts::ctx(&mut scenario));

            ts::return_shared(marketplace);
            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(clock);
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

    #[test]
    fun update_vip_fee_test() {
        let scenario = ts::begin(GAME);

        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));
        marketplace::init_for_testing(ts::ctx(&mut scenario));
        //arca::init_for_testing(ts::ctx(&mut scenario));

        let vip2Amount = 40*DECIMALS;
        let viplv = 2;
        let buy_amount = 30*DECIMALS;
        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let game_config = ts::take_shared<GameConfig>(&mut scenario);

            staking::init_for_testing(&cap, ts::ctx(&mut scenario));

            let hero = game::mint_test_hero(&cap, &game_config,ts::ctx(&mut scenario));
            transfer::public_transfer(hero, GAME);

            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(game_config);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let hero = ts::take_from_sender<Hero>(&mut scenario);
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let clock= ts::take_shared<Clock>(&mut scenario);
            let game_config = ts::take_shared<GameConfig>(&mut scenario);

            marketplace::update_vip_fees(&cap, &mut marketplace, viplv, 100, &game_config);
            marketplace::list_secondary<Hero, ARCA>(&mut marketplace, hero, buy_amount, 0, &clock,ts::ctx(&mut scenario));

            ts::return_shared(marketplace);
            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(clock);
            ts::return_shared(game_config);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            let coin = coin::mint_for_testing<ARCA>(vip2Amount, ts::ctx(&mut scenario));

            staking::stake(&mut sp, coin, &clock, YEAR_TO_UNIX_SECONDS, ts::ctx(&mut scenario));
            ts::next_tx(&mut scenario, USER1_ADDRESS);
            //let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            //assert!(staking::get_amount_VeARCA(&ve_arca, &clock) == 300 * DECIMALS * 100, 1);
            let lv= staking::calc_vip_level(&sp, GAME, &clock);
            assert!(lv == viplv, 1);

            ts::return_shared(sp);
            ts::return_shared(clock);
            //ts::return_to_sender<VeARCA>(&scenario, ve_arca);
        };

        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let marketplace = ts::take_shared<Marketplace>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            let coin = coin::mint_for_testing<ARCA>(buy_amount, ts::ctx(&mut scenario));

            let hero = marketplace::buy_secondary_vip<Hero, ARCA>(coin, 1, &mut marketplace, &mut sp, &clock, ts::ctx(&mut scenario));

            transfer::public_transfer(hero, GAME);
            ts::return_shared(marketplace);
            ts::return_shared(sp);
            ts::return_shared(clock);

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
            assert!(coin::value<ARCA>(&coin) == buy_amount * 1/100, 1);

            ts::return_to_sender(&mut scenario, coin);
            ts::return_shared(multi_signature);
            ts::return_shared(config);
            ts::return_shared(marketplace);
        };

        ts::end(scenario);

    }


}