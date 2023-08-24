#[test_only]
module loa_facilities::staking_tests {

    use std::vector;
    use std::string;

    use sui::test_scenario as ts;
    use sui::coin::{Self, Coin};
    use sui::clock;

    use sui::transfer;

    use loa::arca::{ARCA};
    use loa_game::game;
    use loa_game::game::{GameCap, GameConfig};
    use loa_facilities::staking::{Self, WeekReward, StakingPool, VeARCA};
    use multisig::multisig::{Self, MultiSignature};
    use std::debug;


    const WEEK_TO_UNIX_SECONDS: u64 = 604_800;
    const MONTH_TO_UNIX_SECONDS: u64 = 2_628_000; // rounded up
    const YEAR_TO_UNIX_SECONDS: u64 = 31_536_000;
    const GAME: address = @0x111;
    const USER1_ADDRESS: address = @0x222;
    const DECIMALS: u64 = 1_000_000_000;


    #[test]
    fun test_staking() {
        let scenario = ts::begin(GAME);


        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));

        let coin = coin::mint_for_testing<ARCA>(300*DECIMALS, ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            staking::init_for_testing(&cap, ts::ctx(&mut scenario));


            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            staking::stake(&mut sp, coin, &clock, YEAR_TO_UNIX_SECONDS, ts::ctx(&mut scenario));
            ts::next_tx(&mut scenario, USER1_ADDRESS);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            assert!(staking::get_amount_VeARCA(&ve_arca, &clock) == 300 * DECIMALS, 1);

            ts::return_shared(sp);
            ts::return_shared(clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);
        };
        ts::end(scenario);
    }

    #[test]
    fun test_vip_lv() {
        let scenario = ts::begin(GAME);


        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));

        let coin = coin::mint_for_testing<ARCA>(5*DECIMALS, ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            staking::init_for_testing(&cap, ts::ctx(&mut scenario));


            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            staking::stake(&mut sp, coin, &clock, YEAR_TO_UNIX_SECONDS, ts::ctx(&mut scenario));
            ts::next_tx(&mut scenario, USER1_ADDRESS);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            //assert!(staking::get_amount_VeARCA(&ve_arca, &clock) == 300 * DECIMALS * 100, 1);
            let lv= staking::calc_vip_level(&sp, USER1_ADDRESS, &clock);
            assert!(lv == 1, 1);

            ts::return_shared(sp);
            ts::return_shared(clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);
        };
        ts::end(scenario);
    }

    #[test]
    fun test_append() {
        let scenario = ts::begin(GAME);


        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));

        let coin = coin::mint_for_testing<ARCA>(300*DECIMALS, ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            staking::init_for_testing(&cap, ts::ctx(&mut scenario));

            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            staking::stake(&mut sp, coin, &clock, YEAR_TO_UNIX_SECONDS, ts::ctx(&mut scenario));

            ts::return_shared(sp);
            ts::return_shared(clock);
        };
        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            let x= staking::get_amount_VeARCA(&ve_arca, &clock);
            assert!(x == 300 * DECIMALS, 1);
            let coin = coin::mint_for_testing<ARCA>(300*DECIMALS, ts::ctx(&mut scenario));

            clock::increment_for_testing(&mut clock, YEAR_TO_UNIX_SECONDS * 1000/2);
            staking::append(&mut sp, &mut ve_arca, coin, &clock,ts::ctx(&mut scenario));


            ts::return_shared(sp);
            ts::return_shared(clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_append_time() {
        let scenario = ts::begin(GAME);


        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));

        let coin = coin::mint_for_testing<ARCA>(300*DECIMALS, ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            staking::init_for_testing(&cap, ts::ctx(&mut scenario));

            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            staking::stake(&mut sp, coin, &clock, YEAR_TO_UNIX_SECONDS, ts::ctx(&mut scenario));

            ts::return_shared(sp);
            ts::return_shared(clock);
        };
        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            let x= staking::get_amount_VeARCA(&ve_arca, &clock);
            assert!(x == 300 * DECIMALS, 1);

            clock::increment_for_testing(&mut clock, YEAR_TO_UNIX_SECONDS * 1000/2);
            staking::append_time(&mut sp, &mut ve_arca, YEAR_TO_UNIX_SECONDS/2, &clock,ts::ctx(&mut scenario));

            ts::next_tx(&mut scenario, USER1_ADDRESS);
            let x= staking::get_amount_VeARCA(&ve_arca, &clock);
            assert!(x == 300 * DECIMALS, 1);


            ts::return_shared(sp);
            ts::return_shared(clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_unstake() {
        let scenario = ts::begin(GAME);


        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));

        let coin = coin::mint_for_testing<ARCA>(300*DECIMALS, ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            staking::init_for_testing(&cap, ts::ctx(&mut scenario));


            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            staking::stake(&mut sp, coin, &clock, YEAR_TO_UNIX_SECONDS, ts::ctx(&mut scenario));

            ts::return_shared(sp);
            ts::return_shared(clock);
        };
        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            clock::increment_for_testing(&mut clock, YEAR_TO_UNIX_SECONDS * 1000);
            let coin = staking::unstake(ve_arca, &mut sp, &clock, ts::ctx(&mut scenario));
            assert!(coin::value<ARCA>(&coin) == 300 * DECIMALS, 1);

            transfer::public_transfer(coin, USER1_ADDRESS);

            ts::return_shared(sp);
            ts::return_shared(clock);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_merkle_claim() {
        let scenario = ts::begin(GAME);


        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));

        let coin = coin::mint_for_testing<ARCA>(300*DECIMALS, ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            staking::init_for_testing(&cap, ts::ctx(&mut scenario));


            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            //public fun create_week_reward(_: &mut TreasuryCap<ARCA>, name: String, merkle_root: vector<u8>, total_reward: u64, ctx: &mut TxContext){
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let name = string::utf8(b"2023-7-19");
            let merkle_root = x"76355b7a319f1fa85e831800eea9d8e041801fab8c3daadc7ff0f416cc9d36ee";
            let total_reward = 1000*DECIMALS;
            staking::create_week_reward(&cap, name, merkle_root, total_reward, &mut sp,ts::ctx(&mut scenario));


            staking::append_rewards(&cap, &mut sp, coin::into_balance(coin));
            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(sp);
        };

        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let week_reward = ts::take_shared<WeekReward>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let name = string::utf8(b"2023-7-19");
            let amount = 30000000000;
            let proof = vector::empty<vector<u8>>();
            vector::push_back(&mut proof, x"9a8fbbcafadbc2a8442cdc69a5729fd5b49e3c947c9ca01af40dfff38bf25383");
            vector::push_back(&mut proof, x"0b6cec191caa87f23ccd4019bcaa750699d47a26049aa0d912f1ca2f494f30ba");

            staking::claim(&mut sp, &mut week_reward, name, amount, proof, ts::ctx(&mut scenario));
            ts::return_shared(week_reward);
            ts::return_shared(sp);

        };

        ts::end(scenario);

    }

    #[test]
    fun test_multisig_withdraw() {
        let scenario = ts::begin(GAME);


        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));

        let coin = coin::mint_for_testing<ARCA>(300*DECIMALS, ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            staking::init_for_testing(&cap, ts::ctx(&mut scenario));


            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);

            staking::append_rewards(&cap, &mut sp, coin::into_balance(coin));
            ts::next_tx(&mut scenario, GAME);
            assert!(staking::get_rewards_value(&sp) == 300*DECIMALS, 1);
            ts::return_to_sender<GameCap>(&scenario, cap);
            ts::return_shared(sp);
        };


        ts::next_tx(&mut scenario, GAME);
        {
            let multi_signature = ts::take_shared<MultiSignature>(&mut scenario);
            let config = ts::take_shared<GameConfig>(&mut scenario);
            staking::withdraw_rewards_request(&mut config, &mut multi_signature, GAME, 30*DECIMALS,ts::ctx(&mut scenario));

            ts::return_shared(multi_signature);
            ts::return_shared(config);
        };

        ts::next_tx(&mut scenario, GAME);
        {
            let multi_signature = ts::take_shared<MultiSignature>(&mut scenario);
            let config = ts::take_shared<GameConfig>(&mut scenario);
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            multisig::vote(&mut multi_signature, 0, true, ts::ctx(&mut scenario));
            let b = staking::withdraw_rewards_execute(&mut config, &mut multi_signature, 0, true, &mut sp,ts::ctx(&mut scenario));

            assert!(b, 1);

            ts::next_tx(&mut scenario, GAME);
            let coin = ts::take_from_address<Coin<ARCA>>(&mut scenario, GAME);
            assert!(coin::value<ARCA>(&coin) == 30*DECIMALS, 1);

            ts::return_to_sender(&mut scenario, coin);
            ts::return_shared(multi_signature);
            ts::return_shared(config);
            ts::return_shared(sp);
        };

        ts::end(scenario);

    }

    #[test]
    fun test_staking_2() {
        let scenario = ts::begin(GAME);


        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));

        let coin = coin::mint_for_testing<ARCA>(1000*DECIMALS, ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            staking::init_for_testing(&cap, ts::ctx(&mut scenario));


            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            staking::stake(&mut sp, coin, &clock, YEAR_TO_UNIX_SECONDS, ts::ctx(&mut scenario));
            ts::next_tx(&mut scenario, USER1_ADDRESS);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            let i = 0;
            let l = 12;
            while (i < l) {
                clock::increment_for_testing(&mut clock, MONTH_TO_UNIX_SECONDS * 1000);
                ts::next_tx(&mut scenario, USER1_ADDRESS);
                let amount =staking::get_amount_VeARCA(&ve_arca, &clock);
                debug::print(&amount);

                i = i + 1;
            };
            // ts::next_tx(&mut scenario, USER1_ADDRESS);
            // let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            // assert!(staking::get_amount_VeARCA(&ve_arca, &clock) == 300 * DECIMALS, 1);

            ts::return_shared(sp);
            ts::return_shared(clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);
        };
        ts::end(scenario);
    }

    #[test]
    fun test_staking_3() {
        let scenario = ts::begin(GAME);


        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));

        let coin = coin::mint_for_testing<ARCA>(1000*DECIMALS, ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            staking::init_for_testing(&cap, ts::ctx(&mut scenario));


            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            staking::stake(&mut sp, coin, &clock, YEAR_TO_UNIX_SECONDS, ts::ctx(&mut scenario));
            ts::next_tx(&mut scenario, USER1_ADDRESS);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            let i = 0;
            let l = 12;
            while (i < l ) {

                clock::increment_for_testing(&mut clock, MONTH_TO_UNIX_SECONDS * 1000);
                ts::next_tx(&mut scenario, USER1_ADDRESS);
                let amount =staking::get_amount_VeARCA(&ve_arca, &clock);
                debug::print(&amount);
                staking::append_time(&mut sp, &mut ve_arca, MONTH_TO_UNIX_SECONDS/2, &clock,ts::ctx(&mut scenario));
                ts::next_tx(&mut scenario, USER1_ADDRESS);
                // let amount =staking::get_amount_VeARCA(&ve_arca, &clock);
                // debug::print(&amount);

                i = i + 1;
            };
            // ts::next_tx(&mut scenario, USER1_ADDRESS);
            // let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            // assert!(staking::get_amount_VeARCA(&ve_arca, &clock) == 300 * DECIMALS, 1);

            ts::return_shared(sp);
            ts::return_shared(clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);
        };
        ts::end(scenario);
    }


    #[test]
    fun test_staking_4() {
        let scenario = ts::begin(GAME);


        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));

        let coin = coin::mint_for_testing<ARCA>(1000*DECIMALS, ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            staking::init_for_testing(&cap, ts::ctx(&mut scenario));


            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            staking::stake(&mut sp, coin, &clock, YEAR_TO_UNIX_SECONDS, ts::ctx(&mut scenario));
            ts::next_tx(&mut scenario, USER1_ADDRESS);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            let i = 0;
            let l = 11;
            while (i < l ) {

                let coin = coin::mint_for_testing<ARCA>(100*DECIMALS, ts::ctx(&mut scenario));
                clock::increment_for_testing(&mut clock, MONTH_TO_UNIX_SECONDS * 1000);
                ts::next_tx(&mut scenario, USER1_ADDRESS);
                let amount =staking::get_amount_VeARCA(&ve_arca, &clock);
                debug::print(&amount);
                staking::append(&mut sp, &mut ve_arca, coin, &clock,ts::ctx(&mut scenario));
                ts::next_tx(&mut scenario, USER1_ADDRESS);
                // let amount =staking::get_amount_VeARCA(&ve_arca, &clock);
                // debug::print(&amount);

                i = i + 1;
            };
            // ts::next_tx(&mut scenario, USER1_ADDRESS);
            // let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            // assert!(staking::get_amount_VeARCA(&ve_arca, &clock) == 300 * DECIMALS, 1);

            ts::return_shared(sp);
            ts::return_shared(clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);
        };
        ts::end(scenario);
    }

    #[test]
    fun test_staking_5() {
        let scenario = ts::begin(GAME);


        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));

        let coin = coin::mint_for_testing<ARCA>(1000*DECIMALS, ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            staking::init_for_testing(&cap, ts::ctx(&mut scenario));


            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            staking::stake(&mut sp, coin, &clock, YEAR_TO_UNIX_SECONDS, ts::ctx(&mut scenario));
            ts::next_tx(&mut scenario, USER1_ADDRESS);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            let i = 0;
            let l = 10;
            while (i < l ) {

                let coin = coin::mint_for_testing<ARCA>(100*DECIMALS, ts::ctx(&mut scenario));
                clock::increment_for_testing(&mut clock, 2 * MONTH_TO_UNIX_SECONDS * 1000);
                ts::next_tx(&mut scenario, USER1_ADDRESS);
                // let amount =staking::get_amount_VeARCA(&ve_arca, &clock);
                // debug::print(&amount);
                staking::append(&mut sp, &mut ve_arca, coin, &clock,ts::ctx(&mut scenario));
                staking::append_time(&mut sp, &mut ve_arca, MONTH_TO_UNIX_SECONDS, &clock,ts::ctx(&mut scenario));
                // ts::next_tx(&mut scenario, USER1_ADDRESS);
                let amount =staking::get_amount_VeARCA(&ve_arca, &clock);
                debug::print(&amount);

                i = i + 1;
            };
            // ts::next_tx(&mut scenario, USER1_ADDRESS);
            // let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            // assert!(staking::get_amount_VeARCA(&ve_arca, &clock) == 300 * DECIMALS, 1);

            ts::return_shared(sp);
            ts::return_shared(clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);
        };
        ts::end(scenario);
    }


    #[test]
    fun test_staking_6() {
        let scenario = ts::begin(GAME);


        let  user2: address = @0x223;
        let  user3: address = @0x224;
        let  user4: address = @0x225;

        let amount1_1;
        let amount1_2;
        let amount1_3;
        let amount1_4;

        let amount2_1;
        let amount2_2;
        let amount2_3;
        let amount2_4;

        let amount3_1;
        let amount3_2;
        let amount3_3;
        let amount3_4;

        let amount4_1;
        let amount4_2;
        let amount4_3;
        let amount4_4;

        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(clock);

        game::init_for_test(ts::ctx(&mut scenario));

        let coin = coin::mint_for_testing<ARCA>(1000*DECIMALS, ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, GAME);
        {
            let cap = ts::take_from_sender<GameCap>(&mut scenario);
            staking::init_for_testing(&cap, ts::ctx(&mut scenario));


            ts::return_to_sender<GameCap>(&scenario, cap);
        };

        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let sp = ts::take_shared<StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            staking::stake(&mut sp, coin, &clock, YEAR_TO_UNIX_SECONDS, ts::ctx(&mut scenario));
            ts::next_tx(&mut scenario, user2);
            let coin2 = coin::mint_for_testing<ARCA>(100*DECIMALS, ts::ctx(&mut scenario));
            staking::stake(&mut sp, coin2, &clock, 11*MONTH_TO_UNIX_SECONDS, ts::ctx(&mut scenario));

            ts::next_tx(&mut scenario, user3);
            let coin2 = coin::mint_for_testing<ARCA>(100*DECIMALS, ts::ctx(&mut scenario));
            staking::stake(&mut sp, coin2, &clock, 10*MONTH_TO_UNIX_SECONDS, ts::ctx(&mut scenario));

            ts::next_tx(&mut scenario, user4);
            let coin2 = coin::mint_for_testing<ARCA>(100*DECIMALS, ts::ctx(&mut scenario));
            staking::stake(&mut sp, coin2, &clock, 9*MONTH_TO_UNIX_SECONDS, ts::ctx(&mut scenario));
            // let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            // let i = 0;
            // let l = 11;
            // while (i < l ) {
            //
            //     let coin = coin::mint_for_testing<ARCA>(100*DECIMALS, ts::ctx(&mut scenario));
            //     clock::increment_for_testing(&mut clock, MONTH_TO_UNIX_SECONDS * 1000);
            //     ts::next_tx(&mut scenario, USER1_ADDRESS);
            //     // let amount =staking::get_amount_VeARCA(&ve_arca, &clock);
            //     // debug::print(&amount);
            //     staking::append(&mut sp, &mut ve_arca, coin, &clock,ts::ctx(&mut scenario));
            //     ts::next_tx(&mut scenario, USER1_ADDRESS);
            //     let amount =staking::get_amount_VeARCA(&ve_arca, &clock);
            //     debug::print(&amount);
            //
            //     i = i + 1;
            // };
            // ts::next_tx(&mut scenario, USER1_ADDRESS);
            // let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            // assert!(staking::get_amount_VeARCA(&ve_arca, &clock) == 300 * DECIMALS, 1);

            ts::return_shared(sp);
            ts::return_shared(clock);
            //ts::return_to_sender<VeARCA>(&scenario, ve_arca);
        };

        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            ts::next_tx(&mut scenario, USER1_ADDRESS);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount1_1 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::next_tx(&mut scenario, user2);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount2_1 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::next_tx(&mut scenario, user3);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount3_1 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::next_tx(&mut scenario, user4);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount4_1 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            clock::increment_for_testing(&mut clock, MONTH_TO_UNIX_SECONDS * 1000);
            ts::next_tx(&mut scenario, USER1_ADDRESS);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount1_2 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::next_tx(&mut scenario, user2);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount2_2 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::next_tx(&mut scenario, user3);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount3_2 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::next_tx(&mut scenario, user4);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount4_2 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::return_shared(clock);
        };
        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            clock::increment_for_testing(&mut clock, MONTH_TO_UNIX_SECONDS * 1000);
            ts::next_tx(&mut scenario, USER1_ADDRESS);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount1_3 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::next_tx(&mut scenario, user2);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount2_3 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::next_tx(&mut scenario, user3);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount3_3 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::next_tx(&mut scenario, user4);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount4_3 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, USER1_ADDRESS);
        {
            let clock = ts::take_shared<clock::Clock>(&mut scenario);
            clock::increment_for_testing(&mut clock, MONTH_TO_UNIX_SECONDS * 1000);
            ts::next_tx(&mut scenario, USER1_ADDRESS);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount1_4 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::next_tx(&mut scenario, user2);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount2_4 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::next_tx(&mut scenario, user3);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount3_4 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::next_tx(&mut scenario, user4);
            let ve_arca = ts::take_from_sender<VeARCA>(&mut scenario);
            amount4_4 =staking::get_amount_VeARCA(&ve_arca, &clock);
            ts::return_to_sender<VeARCA>(&scenario, ve_arca);

            ts::return_shared(clock);
        };

        let total_p_1 = amount1_2;
        let total_p_2 = amount1_3 + amount2_2;
        let total_p_3 = amount1_4 + amount2_3 + amount3_2;

        let total_1 = amount1_2 + amount2_1;
        let total_2 = amount1_3 + amount2_2 + amount3_1;
        let total_3 = amount1_4 + amount2_3 + amount3_2 + amount4_1;


        debug::print(&amount1_1);
        debug::print(&amount1_2);
        debug::print(&amount1_3);
        debug::print(&amount1_4);
        debug::print(&amount2_1);
        debug::print(&amount2_2);
        debug::print(&amount2_3);
        debug::print(&amount2_4);
        debug::print(&amount3_1);
        debug::print(&amount3_2);
        debug::print(&amount3_3);
        debug::print(&amount3_4);
        debug::print(&amount4_1);
        debug::print(&amount4_2);
        debug::print(&amount4_3);
        debug::print(&amount4_4);



        debug::print(&total_p_1);
        debug::print(&total_p_2);
        debug::print(&total_p_3);
        debug::print(&total_1);
        debug::print(&total_2);
        debug::print(&total_3);
        ts::end(scenario);
    }
}