#[test_only]
module contracts::staking_tests {

    use contracts::arca::{Self, ARCA};

    use sui::test_scenario as ts;
    use sui::coin;
    use sui::clock;
    use sui::transfer;
    // use sui::linked_table;

    use std::string;
    use std::debug;

    const EVeARCAAmountNotMuch: u64 = 0;
    const ENotCorrectAmmountTransfered: u64 = 1;
    const EAppendNotWorking: u64 = 2;
    const EUnstakeNotWorking: u64 = 3;
    const ENumberOfHoldersNotCorrect: u64 = 4;

    const USER_ADDRESS: address = @0xABCD;
    const USER2_ADDRESS: address = @0x1234;
    const USER3_ADDRESS: address = @0x5678;
    const USER4_ADDRESS: address = @0x1459;


    #[test]
    fun test_staking() {
        let scenario = ts::begin(USER_ADDRESS);

        let user_coin = coin::mint_for_testing<ARCA>(10_000, ts::ctx(&mut scenario));
        let user2_coin = coin::mint_for_testing<ARCA>(10_000, ts::ctx(&mut scenario));

        let c = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(c);

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {
            arca::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {   
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            arca::stake(
                &mut staking_pool, 
                user_coin, 
                &clock, 
                string::utf8(b"1y"), 
                ts::ctx(&mut scenario));

            ts::return_shared(staking_pool);
            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {
            let veARCA_object = ts::take_from_sender<arca::VeARCA>(&mut scenario);

            assert!(arca::get_amount_VeARCA(&veARCA_object) == 1_000_000, ENotCorrectAmmountTransfered);

            ts::return_to_sender<arca::VeARCA>(&scenario, veARCA_object);
        };

        ts::next_tx(&mut scenario, USER2_ADDRESS);
        {   
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            arca::stake(
                &mut staking_pool, 
                user2_coin, 
                &clock, 
                string::utf8(b"1w"), 
                ts::ctx(&mut scenario));

            ts::return_shared(staking_pool);
            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, USER2_ADDRESS);
        {
            let veARCA_object = ts::take_from_sender<arca::VeARCA>(&mut scenario);

            assert!(arca::get_amount_VeARCA(&veARCA_object) == 19_178, ENotCorrectAmmountTransfered);

            ts::return_to_sender<arca::VeARCA>(&scenario, veARCA_object);
        };

        ts::end(scenario);
    }

    #[test, expected_failure]
    fun test_stake_twice() {
        let scenario = ts::begin(USER_ADDRESS);

        let user_coin = coin::mint_for_testing<ARCA>(10_000, ts::ctx(&mut scenario));
        let second_user_coin = coin::mint_for_testing<ARCA>(10_000, ts::ctx(&mut scenario));

        let c = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(c);

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {
            arca::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {   
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            arca::stake(
                &mut staking_pool, 
                user_coin, 
                &clock, 
                string::utf8(b"1y"), 
                ts::ctx(&mut scenario));

            ts::return_shared(staking_pool);
            ts::return_shared(clock);

        };

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {   
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            arca::stake(
                &mut staking_pool, 
                second_user_coin, 
                &clock, 
                string::utf8(b"1y"), 
                ts::ctx(&mut scenario));

            ts::return_shared(staking_pool);
            ts::return_shared(clock);

        };

        ts::end(scenario);
    }


    #[test]
    fun test_append_to_stake() {
        let scenario = ts::begin(USER_ADDRESS);

        let user_coin = coin::mint_for_testing<ARCA>(10_000, ts::ctx(&mut scenario));
        let second_user_coin = coin::mint_for_testing<ARCA>(10_000, ts::ctx(&mut scenario));

        let c = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(c);

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {
            arca::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {   
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            arca::stake(
                &mut staking_pool, 
                user_coin, 
                &clock, 
                string::utf8(b"1y"), 
                ts::ctx(&mut scenario));

            ts::return_shared(staking_pool);
            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let test_clock = ts::take_shared<clock::Clock>(&mut scenario);
            let veARCA_object = ts::take_from_sender<arca::VeARCA>(&mut scenario);

            clock::increment_for_testing(&mut test_clock, 86_400*1000);

            arca::append(
                &mut staking_pool,
                &mut veARCA_object,
                second_user_coin, 
                &test_clock,
                ts::ctx(&mut scenario));

            ts::return_shared(staking_pool);
            ts::return_shared(test_clock);
            ts::return_to_sender<arca::VeARCA>(&scenario, veARCA_object);
        };

        ts::end(scenario);
    }

    #[test, expected_failure]
    fun test_append_to_stake_fail() {
        let scenario = ts::begin(USER_ADDRESS);

        let user_coin = coin::mint_for_testing<ARCA>(10_000, ts::ctx(&mut scenario));
        let second_user_coin = coin::mint_for_testing<ARCA>(10_000, ts::ctx(&mut scenario));

        let c = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(c);

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {
            arca::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {   
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            arca::stake(
                &mut staking_pool, 
                user_coin, 
                &clock, 
                string::utf8(b"1w"), 
                ts::ctx(&mut scenario));

            ts::return_shared(staking_pool);
            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let test_clock = ts::take_shared<clock::Clock>(&mut scenario);
            let veARCA_object = ts::take_from_sender<arca::VeARCA>(&mut scenario);

            clock::increment_for_testing(&mut test_clock, 86_400*7*1000);

            arca::append(
                &mut staking_pool,
                &mut veARCA_object,
                second_user_coin, 
                &test_clock,
                ts::ctx(&mut scenario)); 

            ts::return_shared(staking_pool);
            ts::return_shared(test_clock);
            ts::return_to_sender<arca::VeARCA>(&scenario, veARCA_object);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_unstake() {
        let scenario = ts::begin(USER_ADDRESS);

        let user_coin = coin::mint_for_testing<ARCA>(10_000, ts::ctx(&mut scenario));

        let c = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(c);

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {
            arca::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {   
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            arca::stake(
                &mut staking_pool, 
                user_coin, 
                &clock, 
                string::utf8(b"1w"), 
                ts::ctx(&mut scenario));

            ts::return_shared(staking_pool);
            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let test_clock = ts::take_shared<clock::Clock>(&mut scenario);
            let veARCA_object = ts::take_from_sender<arca::VeARCA>(&mut scenario);

            clock::increment_for_testing(&mut test_clock, 8*86_400*1000);

            let arca_coin = arca::unstake(veARCA_object, &mut staking_pool, &test_clock, ts::ctx(&mut scenario));

            assert!(coin::value(&arca_coin) == 10_000, EUnstakeNotWorking);

            ts::return_shared(staking_pool);
            ts::return_shared(test_clock);

            transfer::public_transfer(arca_coin, USER_ADDRESS);

        };

        ts::end(scenario);
    }

    #[test]
    fun test_distribute_rewards() {
        let scenario = ts::begin(USER_ADDRESS);

        let user_coin = coin::mint_for_testing<ARCA>(10_000, ts::ctx(&mut scenario));
        let user2_coin = coin::mint_for_testing<ARCA>(25_000, ts::ctx(&mut scenario));
        let user3_coin = coin::mint_for_testing<ARCA>(100_000, ts::ctx(&mut scenario));
        let user4_coin = coin::mint_for_testing<ARCA>(200_000, ts::ctx(&mut scenario));

        let c = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::share_for_testing(c);

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {
            arca::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {   
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            arca::stake(
                &mut staking_pool, 
                user_coin, 
                &clock, 
                string::utf8(b"1w"), 
                ts::ctx(&mut scenario));

            ts::return_shared(staking_pool);
            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, USER2_ADDRESS);
        {   
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            arca::stake(
                &mut staking_pool, 
                user2_coin, 
                &clock, 
                string::utf8(b"1m"), 
                ts::ctx(&mut scenario));

            ts::return_shared(staking_pool);
            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, USER3_ADDRESS);
        {   
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            arca::stake(
                &mut staking_pool, 
                user3_coin, 
                &clock, 
                string::utf8(b"3m"), 
                ts::ctx(&mut scenario));

            ts::return_shared(staking_pool);
            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, USER4_ADDRESS);
        {   
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            arca::stake(
                &mut staking_pool, 
                user4_coin, 
                &clock, 
                string::utf8(b"3m"), 
                ts::ctx(&mut scenario));

            debug::print(&string::utf8(b"this transaction executed"));

            ts::return_shared(staking_pool);
            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            assert!(arca::get_holders_number(&staking_pool) == 4, ENumberOfHoldersNotCorrect);

            ts::return_shared(staking_pool);
            ts::return_shared(clock);
        
        };

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {
            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            arca::increase_rewards_supply(&mut staking_pool);

            ts::return_shared(staking_pool);
            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {
            // let veARCA_object = ts::take_from_sender<arca::VeARCA>(&mut scenario);

            let staking_pool = ts::take_shared<arca::StakingPool>(&mut scenario);
            let clock = ts::take_shared<clock::Clock>(&mut scenario);

            let cap = ts::take_from_sender<arca::StakingAdmin>(&mut scenario);

            // debug::print(&arca::get_holders_number(&staking_pool));
    // public fun distribute_rewards(_cap: &StakingAdmin, sp: &mut StakingPool, clock: &Clock, ctx: &mut TxContext) {

            arca::distribute_rewards(&cap, &mut staking_pool, &clock, ts::ctx(&mut scenario));

            // arca::
            
            ts::return_to_sender<arca::StakingAdmin>(&scenario, cap);
            
            ts::return_shared(staking_pool);
            ts::return_shared(clock);
        };

        ts::end(scenario);
    }
    
}