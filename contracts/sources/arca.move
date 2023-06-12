module contracts::arca {

    use std::option;
    use std::string::{Self, String};

    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::dynamic_field as dfield;
    // use std::debug;

//  https://www.advancedconverter.com/unit-conversions/time-conversion/weeks-to-milliseconds
    const DAY_TO_UNIX_SECONDS: u64 = 86_400;
    const WEAK_TO_UNIX_SECONDS: u64 = 604_800;
    const MONTH_TO_UNIX_SECONDS: u64 = 2_629_744; // rounded up
    const YEAR_TO_UNIX_SECONDS: u64 = 31_556_926;

    const ENotEnoughveARCA: u64 = 0;
    const ENotValidAction: u64 = 1;
    const EOngoingStaking: u64 = 2;
    const EDenominatorIsZero: u64 = 3;
    const ENotCorrectStakingPeriod: u64 = 4;
    const ENotAppendActionAvaialble: u64 = 5;

    struct ARCA has drop {}

    struct VeARCA has key {
        id: UID,
        staked_amount: u64,
        amount: u64,
        start_date: u64,
        end_date: u64,
        decimals: u64,
    }

    struct StakingPool has key, store {
        id: UID,
        liquidity: Balance<ARCA>,
        total_supply_VeARCA: u64,
        rewards: Balance<ARCA>,
        next_distribution_timestamp: u64,
    }

    fun init(witness: ARCA, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 18, b"ARCA", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    fun create_pool(ctx: &mut TxContext) {
        let staking_pool = StakingPool{
            id: object::new(ctx),
            liquidity: balance::zero<ARCA>(),
            total_supply_VeARCA: 0,
            next_distribution_timestamp: 0,
            rewards: balance::zero<ARCA>()
        };
        transfer::share_object(staking_pool);
    }

    fun mint_ve(staked_amount: u64, amount: u64, start_date: u64, end_date: u64, ctx: &mut TxContext): VeARCA {
        let id = object::new(ctx);
        let veARCA = VeARCA{
            id,
            staked_amount,
            amount,
            start_date,
            end_date,
            decimals: 100
        };

        veARCA
    }

    fun calc_veARCA(staked_arca_amount: u64, denominator: u64): u64 {

        assert!(denominator !=0, EDenominatorIsZero);

        let veARCA_amount = staked_arca_amount / denominator;

        veARCA_amount
    }

    public fun stake(sp: &mut StakingPool, arca: Coin<ARCA>, clock: &Clock, staking_period: String, ctx: &mut TxContext) {
        
        assert!(!dfield::exists_(&sp.id, tx_context::sender(ctx)), EOngoingStaking);

        let arca_amount = coin::value(&arca);
        let staked_amount = arca_amount*100;
        let start_tmstmp = clock::timestamp_ms(clock) / 1000;
        let end_tmstmp = 0;

        if(staking_period == string::utf8(b"1w")) {
            end_tmstmp = start_tmstmp + WEAK_TO_UNIX_SECONDS;
            staked_amount = calc_veARCA(staked_amount*7, 365);
        } else if(staking_period == string::utf8(b"2w")) {
            end_tmstmp = start_tmstmp + 2* WEAK_TO_UNIX_SECONDS;
            staked_amount = calc_veARCA(staked_amount*14, 365);

        } else if(staking_period == string::utf8(b"1m")) {
            end_tmstmp = start_tmstmp + MONTH_TO_UNIX_SECONDS;
            staked_amount = calc_veARCA(staked_amount, 12);

        } else if(staking_period == string::utf8(b"3m")) {
            end_tmstmp = start_tmstmp + (3 * MONTH_TO_UNIX_SECONDS);
            staked_amount = calc_veARCA(staked_amount, 4);

        } else if(staking_period == string::utf8(b"6m")) {
            end_tmstmp = start_tmstmp + (6 * MONTH_TO_UNIX_SECONDS);
            staked_amount = calc_veARCA(staked_amount, 2);

        } else if(staking_period == string::utf8(b"1y")) {
            end_tmstmp = start_tmstmp + YEAR_TO_UNIX_SECONDS;
        } else {
            assert!(true, ENotCorrectStakingPeriod);
        };

        assert!(staked_amount >= 300, ENotEnoughveARCA);
        
        let balance = coin::into_balance(arca);
        balance::join(&mut sp.liquidity, balance);

        sp.total_supply_VeARCA = sp.total_supply_VeARCA + staked_amount;

        dfield::add(&mut sp.id, tx_context::sender(ctx), staked_amount);

        let veARCA = mint_ve(staked_amount, arca_amount, start_tmstmp, end_tmstmp, ctx);
        
        transfer::transfer(veARCA, tx_context::sender(ctx));
    }

    public fun append(sp: &mut StakingPool, veARCA: &mut VeARCA, arca: Coin<ARCA>, clock: &Clock, ctx: &mut TxContext) {
        
        let appended_stake = coin::value(&arca)*100;
        veARCA.amount = veARCA.amount + appended_stake;
        let current_timestamp = clock::timestamp_ms(clock) / 1000;
        let time_left = (veARCA.end_date - current_timestamp)/DAY_TO_UNIX_SECONDS;

        assert!(time_left >= 1, ENotAppendActionAvaialble);

        appended_stake = calc_veARCA(appended_stake*time_left, 365);

        let balance = coin::into_balance(arca);
        balance::join(&mut sp.liquidity, balance);

        sp.total_supply_VeARCA = sp.total_supply_VeARCA + appended_stake;

        veARCA.staked_amount = veARCA.staked_amount + appended_stake;

        *dfield::borrow_mut(&mut sp.id, tx_context::sender(ctx)) = appended_stake + *dfield::borrow(&sp.id, tx_context::sender(ctx));

    }

    public fun unstake(veARCA: VeARCA, sp: &mut StakingPool, clock: &Clock, ctx: &mut TxContext): Coin<ARCA> {
         
        let current_timestamp = clock::timestamp_ms(clock) / 1000;
        assert!(current_timestamp > veARCA.end_date, ENotValidAction);

        let coin_balance = balance::split<ARCA>(&mut sp.liquidity, veARCA.amount);
        sp.total_supply_VeARCA = sp.total_supply_VeARCA - veARCA.staked_amount;

        let arca = coin::from_balance<ARCA>(coin_balance, ctx);

        let _v = dfield::remove<address, u64>(&mut sp.id, tx_context::sender(ctx));

        burn_veARCA(veARCA);

        arca
    }

    // fun distribute_rewards(staking_pool:, clock: ) {
        
    // }

    fun burn_veARCA(veARCA: VeARCA) {
        let VeARCA {id, staked_amount: _, amount: _, start_date: _, end_date: _, decimals:_} = veARCA;
        object::delete(id);
    }

    public fun get_total_supply_VeARCA(sp: &StakingPool): u64 {
        sp.total_supply_VeARCA
    }

    public fun get_staked_amount_VeARCA(veARCA: &VeARCA): u64 {
        veARCA.staked_amount
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        create_pool(ctx);
    }

}

#[test_only]
module contracts::staking_tests {

    use contracts::arca::{Self, ARCA};

    use sui::test_scenario as ts;
    use sui::coin;
    use sui::clock;
    use sui::transfer;

    use std::string;

    const EVeARCAAmountNotMuch: u64 = 0;
    const ENotCorrectAmmountTransfered: u64 = 1;
    const EAppendNotWorking: u64 = 2;

    const USER_ADDRESS: address = @0xABCD;
    const USER2_ADDRESS: address = @0x1234;

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

            assert!(arca::get_total_supply_VeARCA(&staking_pool) == 1_000_000, EVeARCAAmountNotMuch);

            ts::return_shared(staking_pool);
            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, USER_ADDRESS);
        {
            let veARCA_object = ts::take_from_sender<arca::VeARCA>(&mut scenario);

            assert!(arca::get_staked_amount_VeARCA(&veARCA_object) == 1_000_000, ENotCorrectAmmountTransfered);

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

            assert!(arca::get_total_supply_VeARCA(&staking_pool) == 1_019_178, EVeARCAAmountNotMuch);

            ts::return_shared(staking_pool);
            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, USER2_ADDRESS);
        {
            let veARCA_object = ts::take_from_sender<arca::VeARCA>(&mut scenario);

            assert!(arca::get_staked_amount_VeARCA(&veARCA_object) == 19_178, ENotCorrectAmmountTransfered);

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

            assert!(arca::get_total_supply_VeARCA(&staking_pool) > 1_000_000, EAppendNotWorking);

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

            assert!(coin::value(&arca_coin) == 10_000, EAppendNotWorking);

            ts::return_shared(staking_pool);
            ts::return_shared(test_clock);

            transfer::public_transfer(arca_coin, USER_ADDRESS);

        };

        ts::end(scenario);
    }



}