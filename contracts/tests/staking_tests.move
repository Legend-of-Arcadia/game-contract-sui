#[test_only]
module contracts::staking_tests {
    //
    use loa::arca::{ARCA};
    //use contracts::staking::{Self, StakingPool};
    use contracts::game;
    use multisig::multisig::{Self, MultiSignature};

    use sui::test_scenario as ts;
    use sui::coin::{Self, Coin};
    use sui::clock;
    use std::vector;

    use std::string;
    use contracts::staking::{Self, WeekReward, StakingPool, VeARCA};
    use contracts::game::{GameCap, GameConfig};
    use std::debug;
    use sui::transfer;
    //use sui::balance;

    const WEEK_TO_UNIX_SECONDS: u64 = 604_800;
    const MONTH_TO_UNIX_SECONDS: u64 = 2_629_744; // rounded up
    const YEAR_TO_UNIX_SECONDS: u64 = 31_556_926;
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
            staking::create_week_reward(&cap, name, merkle_root, total_reward, ts::ctx(&mut scenario));


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
            //let x = coin::value(&coin);
            debug::print(&coin::value<ARCA>(&coin));
            assert!(coin::value<ARCA>(&coin) == 30*DECIMALS, 1);

            ts::return_to_sender(&mut scenario, coin);
            ts::return_shared(multi_signature);
            ts::return_shared(config);
            ts::return_shared(sp);
        };

        ts::end(scenario);

    }
    //
    // const EVeARCAAmountNotMuch: u64 = 0;
    // const ENotCorrectAmmountTransfered: u64 = 1;
    // const EAppendNotWorking: u64 = 2;
    // const EUnstakeNotWorking: u64 = 3;
    // const ENumberOfHoldersNotCorrect: u64 = 4;
    // const ENextDistributionNotCorrect: u64 = 5;
    // const ENotRightAmountDistributed: u64 = 6;
    //
    // const USER1_ADDRESS: address = @0xABCD;
    // const USER2_ADDRESS: address = @0x1234;
    // const USER3_ADDRESS: address = @0x5678;
    // const USER4_ADDRESS: address = @0x1459;
    // const USER5_ADDRESS: address = @0x1359;
    // const USER6_ADDRESS: address = @0x1559;
    // const USER7_ADDRESS: address = @0x1659;
    // const USER8_ADDRESS: address = @0x1759;
    // const USER9_ADDRESS: address = @0x1859;
    // const USER10_ADDRESS: address = @0x1959;
    // const USER11_ADDRESS: address = @0x2559;
    // const USER12_ADDRESS: address = @0x2558;
    //
    // const DECIMALS: u64 = 1_000_000_000;
    //
    //
    // #[test]
    // fun test_staking() {
    //     let scenario = ts::begin(USER1_ADDRESS);
    //
    //     let user_coin = coin::mint_for_testing<ARCA>(10_000*DECIMALS, ts::ctx(&mut scenario));
    //     let user2_coin = coin::mint_for_testing<ARCA>(10_000*DECIMALS, ts::ctx(&mut scenario));
    //
    //     let c = clock::create_for_testing(ts::ctx(&mut scenario));
    //     clock::share_for_testing(c);
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         arca::init_for_testing(ts::ctx(&mut scenario));
    //         game::init_for_test(ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         let cap = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
    //
    //         staking::init_for_testing(&cap, &clock, ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //         ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, cap);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let veARCA_object = ts::take_from_sender<staking::VeARCA>(&mut scenario);
    //
    //         assert!(staking::get_initial_VeARCA(&veARCA_object) == 1_000_000*DECIMALS, ENotCorrectAmmountTransfered);
    //
    //         ts::return_to_sender<staking::VeARCA>(&scenario, veARCA_object);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER2_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user2_coin,
    //             &clock,
    //             string::utf8(b"1w"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER2_ADDRESS);
    //     {
    //         let veARCA_object = ts::take_from_sender<staking::VeARCA>(&mut scenario);
    //
    //         assert!(staking::get_initial_VeARCA(&veARCA_object) == 19178082191780, ENotCorrectAmmountTransfered);
    //
    //         ts::return_to_sender<staking::VeARCA>(&scenario, veARCA_object);
    //     };
    //
    //     ts::end(scenario);
    // }
    //
    // #[test, expected_failure]
    // fun test_stake_twice() {
    //     let scenario = ts::begin(USER1_ADDRESS);
    //
    //     let user_coin = coin::mint_for_testing<ARCA>(10_000*DECIMALS, ts::ctx(&mut scenario));
    //     let second_user_coin = coin::mint_for_testing<ARCA>(10_000*DECIMALS, ts::ctx(&mut scenario));
    //
    //     let c = clock::create_for_testing(ts::ctx(&mut scenario));
    //     clock::share_for_testing(c);
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         game::init_for_test(ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         let cap = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
    //
    //         staking::init_for_testing(&cap, &clock, ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //         ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, cap);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             second_user_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //
    //     };
    //
    //     ts::end(scenario);
    // }
    //
    //
    // #[test]
    // fun test_append_to_stake() {
    //     let scenario = ts::begin(USER1_ADDRESS);
    //
    //     let user_coin = coin::mint_for_testing<ARCA>(10_000*DECIMALS, ts::ctx(&mut scenario));
    //     let second_user_coin = coin::mint_for_testing<ARCA>(10_000*DECIMALS, ts::ctx(&mut scenario));
    //
    //     let c = clock::create_for_testing(ts::ctx(&mut scenario));
    //     clock::share_for_testing(c);
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //         arca::init_for_testing(ts::ctx(&mut scenario));
    //         game::init_for_test(ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //         let cap = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
    //
    //         staking::init_for_testing(&cap, &clock, ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //         ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, cap);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let test_clock = ts::take_shared<clock::Clock>(&mut scenario);
    //         let veARCA_object = ts::take_from_sender<staking::VeARCA>(&mut scenario);
    //
    //         clock::increment_for_testing(&mut test_clock, 2_629_744*6*1000);
    //
    //         staking::append(
    //             &mut staking_pool,
    //             &mut veARCA_object,
    //             second_user_coin,
    //             &test_clock,
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(test_clock);
    //         ts::return_to_sender<staking::VeARCA>(&scenario, veARCA_object);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let test_clock = ts::take_shared<clock::Clock>(&mut scenario);
    //         let veARCA_object = ts::take_from_sender<staking::VeARCA>(&mut scenario);
    //
    //         assert!(staking::get_initial_VeARCA(&veARCA_object) == 1498630136986301, EAppendNotWorking);
    //         assert!(staking::get_staked_amount_VeARCA(&veARCA_object) == 20_000*DECIMALS, EAppendNotWorking);
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(test_clock);
    //         ts::return_to_sender<staking::VeARCA>(&scenario, veARCA_object);
    //     };
    //
    //     ts::end(scenario);
    // }
    //
    // #[test, expected_failure]
    // fun test_append_to_stake_fail() {
    //     let scenario = ts::begin(USER1_ADDRESS);
    //
    //     let user_coin = coin::mint_for_testing<ARCA>(10_000*DECIMALS, ts::ctx(&mut scenario));
    //     let second_user_coin = coin::mint_for_testing<ARCA>(10_000*DECIMALS, ts::ctx(&mut scenario));
    //
    //     let c = clock::create_for_testing(ts::ctx(&mut scenario));
    //     clock::share_for_testing(c);
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         arca::init_for_testing(ts::ctx(&mut scenario));
    //         game::init_for_test(ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //         let cap = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
    //
    //         staking::init_for_testing(&cap, &clock, ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //         ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, cap);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user_coin,
    //             &clock,
    //             string::utf8(b"1w"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let test_clock = ts::take_shared<clock::Clock>(&mut scenario);
    //         let veARCA_object = ts::take_from_sender<staking::VeARCA>(&mut scenario);
    //
    //         clock::increment_for_testing(&mut test_clock, 86_400*7*1000);
    //
    //         staking::append(
    //             &mut staking_pool,
    //             &mut veARCA_object,
    //             second_user_coin,
    //             &test_clock,
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(test_clock);
    //         ts::return_to_sender<staking::VeARCA>(&scenario, veARCA_object);
    //     };
    //
    //     ts::end(scenario);
    // }
    //
    // #[test]
    // fun test_unstake() {
    //     let scenario = ts::begin(USER1_ADDRESS);
    //
    //     let user_coin = coin::mint_for_testing<ARCA>(10_000*DECIMALS, ts::ctx(&mut scenario));
    //
    //     let c = clock::create_for_testing(ts::ctx(&mut scenario));
    //     clock::share_for_testing(c);
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         arca::init_for_testing(ts::ctx(&mut scenario));
    //         game::init_for_test(ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //         let cap = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
    //
    //         staking::init_for_testing(&cap, &clock, ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //         ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, cap);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user_coin,
    //             &clock,
    //             string::utf8(b"1w"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let test_clock = ts::take_shared<clock::Clock>(&mut scenario);
    //         let veARCA_object = ts::take_from_sender<staking::VeARCA>(&mut scenario);
    //
    //         clock::increment_for_testing(&mut test_clock, 8*86_400*1000);
    //
    //         let arca_coin = staking::unstake(veARCA_object, &mut staking_pool, &test_clock, ts::ctx(&mut scenario));
    //
    //         assert!(coin::value(&arca_coin) == 10_000*DECIMALS, EUnstakeNotWorking);
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(test_clock);
    //
    //         transfer::public_transfer(arca_coin, USER1_ADDRESS);
    //
    //     };
    //
    //     ts::end(scenario);
    // }
    //
    // #[test]
    // fun test_distribute_rewards() {
    //     let scenario = ts::begin(USER1_ADDRESS);
    //
    //     let user_coin = coin::mint_for_testing<ARCA>(10_000*DECIMALS, ts::ctx(&mut scenario));
    //     let user2_coin = coin::mint_for_testing<ARCA>(25_000*DECIMALS, ts::ctx(&mut scenario));
    //     let user3_coin = coin::mint_for_testing<ARCA>(100_000*DECIMALS, ts::ctx(&mut scenario));
    //     let user4_coin = coin::mint_for_testing<ARCA>(200_000*DECIMALS, ts::ctx(&mut scenario));
    //
    //     let c = clock::create_for_testing(ts::ctx(&mut scenario));
    //     clock::share_for_testing(c);
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         arca::init_for_testing(ts::ctx(&mut scenario));
    //         game::init_for_test(ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //         let cap = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
    //
    //         staking::init_for_testing(&cap, &clock, ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //         ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, cap);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user_coin,
    //             &clock,
    //             string::utf8(b"1w"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER2_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user2_coin,
    //             &clock,
    //             string::utf8(b"1m"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER3_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user3_coin,
    //             &clock,
    //             string::utf8(b"3m"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER4_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user4_coin,
    //             &clock,
    //             string::utf8(b"3m"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         assert!(staking::get_holders_number(&staking_pool) == 4, ENumberOfHoldersNotCorrect);
    //
    //         staking::increase_rewards_supply(&mut staking_pool);
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         let cap = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
    //
    //         clock::increment_for_testing(&mut clock, staking::get_next_distribution_timestamp(&staking_pool)*1000);
    //
    //         let timestamp_before = staking::get_next_distribution_timestamp(&staking_pool);
    //
    //         staking::distribute_rewards(&mut cap, &mut staking_pool, &clock, ts::ctx(&mut scenario));
    //
    //         assert!((staking::get_next_distribution_timestamp(&staking_pool) == (timestamp_before + 604_800)) , ENextDistributionNotCorrect);
    //
    //         ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, cap);
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::end(scenario);
    // }
    //
    // #[test, expected_failure]
    // fun test_distribute_rewards_earlier() {
    //     let scenario = ts::begin(USER1_ADDRESS);
    //
    //     let user_coin = coin::mint_for_testing<ARCA>(10_000*DECIMALS, ts::ctx(&mut scenario));
    //
    //     let c = clock::create_for_testing(ts::ctx(&mut scenario));
    //     clock::share_for_testing(c);
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         game::init_for_test(ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //         let cap = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
    //
    //         staking::init_for_testing(&cap, &clock, ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //         ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, cap);
    //     };
    //
    //      ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user_coin,
    //             &clock,
    //             string::utf8(b"1w"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         let cap = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
    //
    //         staking::distribute_rewards(&mut cap, &mut staking_pool, &clock, ts::ctx(&mut scenario));
    //
    //         ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, cap);
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::end(scenario);
    // }
    //
    // #[test]
    // fun test_distribute_rewards_no_stakes() {
    //     let scenario = ts::begin(USER1_ADDRESS);
    //
    //     let c = clock::create_for_testing(ts::ctx(&mut scenario));
    //     clock::share_for_testing(c);
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         arca::init_for_testing(ts::ctx(&mut scenario));
    //         game::init_for_test(ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //         let cap = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
    //
    //         staking::init_for_testing(&cap, &clock, ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //         ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, cap);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //         let cap = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
    //
    //         clock::increment_for_testing(&mut clock, staking::get_next_distribution_timestamp(&staking_pool)*1000);
    //
    //         staking::distribute_rewards(&mut cap, &mut staking_pool, &clock, ts::ctx(&mut scenario));
    //
    //         ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, cap);
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::end(scenario);
    // }
    //
    // #[test]
    // fun test_distribute_rewards2() {
    //     let scenario = ts::begin(USER1_ADDRESS);
    //
    //     let user1_coin = coin::mint_for_testing<ARCA>(5_000_000*DECIMALS, ts::ctx(&mut scenario));
    //     let user2_coin = coin::mint_for_testing<ARCA>(5_000_000*DECIMALS, ts::ctx(&mut scenario));
    //     let user3_coin = coin::mint_for_testing<ARCA>(5_000_000*DECIMALS, ts::ctx(&mut scenario));
    //     let user4_coin = coin::mint_for_testing<ARCA>(5_000_000*DECIMALS, ts::ctx(&mut scenario));
    //     let user5_coin = coin::mint_for_testing<ARCA>(5_000_000*DECIMALS, ts::ctx(&mut scenario));
    //     let user6_coin = coin::mint_for_testing<ARCA>(5_000_000*DECIMALS, ts::ctx(&mut scenario));
    //     let user7_coin = coin::mint_for_testing<ARCA>(5_000_000*DECIMALS, ts::ctx(&mut scenario));
    //     let user8_coin = coin::mint_for_testing<ARCA>(5_000_000*DECIMALS, ts::ctx(&mut scenario));
    //     let user9_coin = coin::mint_for_testing<ARCA>(5_000_000*DECIMALS, ts::ctx(&mut scenario));
    //     let user10_coin = coin::mint_for_testing<ARCA>(5_000_000*DECIMALS, ts::ctx(&mut scenario));
    //     let user11_coin = coin::mint_for_testing<ARCA>(5_000_000*DECIMALS, ts::ctx(&mut scenario));
    //     let user12_coin = coin::mint_for_testing<ARCA>(5_000_000*DECIMALS, ts::ctx(&mut scenario));
    //
    //     let c = clock::create_for_testing(ts::ctx(&mut scenario));
    //     clock::share_for_testing(c);
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         arca::init_for_testing(ts::ctx(&mut scenario));
    //         game::init_for_test(ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //         let cap = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
    //
    //         staking::init_for_testing(&cap, &clock, ts::ctx(&mut scenario));
    //
    //         ts::return_shared(clock);
    //         ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, cap);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user1_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER2_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user2_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER3_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user3_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER4_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user4_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER5_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user5_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER6_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user6_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER7_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user7_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER8_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user8_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER9_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user9_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER10_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user10_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER11_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user11_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER12_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         staking::stake(
    //             &mut staking_pool,
    //             user12_coin,
    //             &clock,
    //             string::utf8(b"1y"),
    //             ts::ctx(&mut scenario));
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         assert!(staking::get_holders_number(&staking_pool) == 12, ENumberOfHoldersNotCorrect);
    //
    //         staking::increase_rewards_supply(&mut staking_pool);
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER1_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         let cap = ts::take_from_sender<TreasuryCap<ARCA>>(&mut scenario);
    //
    //         clock::increment_for_testing(&mut clock, staking::get_next_distribution_timestamp(&staking_pool)*1000);
    //
    //         let timestamp_before = staking::get_next_distribution_timestamp(&staking_pool);
    //
    //         staking::distribute_rewards(&mut cap, &mut staking_pool, &clock, ts::ctx(&mut scenario));
    //
    //         assert!((staking::get_next_distribution_timestamp(&staking_pool) == (timestamp_before + 604_800)) , ENextDistributionNotCorrect);
    //
    //         ts::return_to_sender<TreasuryCap<ARCA>>(&scenario, cap);
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::next_tx(&mut scenario, USER4_ADDRESS);
    //     {
    //         let staking_pool = ts::take_shared<staking::StakingPool>(&mut scenario);
    //         let clock = ts::take_shared<clock::Clock>(&mut scenario);
    //
    //         let arca_coin = ts::take_from_sender<coin::Coin<ARCA>>(&mut scenario);
    //
    //         assert!(coin::value(&arca_coin) == 39583333333, ENotRightAmountDistributed);
    //
    //         ts::return_to_sender<coin::Coin<ARCA>>(&scenario, arca_coin);
    //
    //         ts::return_shared(staking_pool);
    //         ts::return_shared(clock);
    //     };
    //
    //     ts::end(scenario);
    // }
    
}