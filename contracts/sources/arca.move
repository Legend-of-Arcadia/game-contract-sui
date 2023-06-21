module contracts::arca {

    use std::option;
    use std::string::{Self, String};
    use std::vector;
    use std::debug;

    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::linked_table::{Self, LinkedTable};
    use sui::table::{Self, Table};

    friend contracts::game;

    const DECIMALS: u64 = 1_000_000_000;
    const TOTAL_SUPPLY_ARCA: u64 = 1_000_000_000;
    const TOTAL_SUPPLY_ARCA_DEVISION: u64 = 1_000_000_000_000_000_000;

//  https://www.advancedconverter.com/unit-conversions/time-conversion/weeks-to-milliseconds
    const DAY_TO_UNIX_SECONDS: u64 = 86_400;
    const WEEK_TO_UNIX_SECONDS: u64 = 604_800;
    const MONTH_TO_UNIX_SECONDS: u64 = 2_629_744; // rounded up
    const YEAR_TO_UNIX_SECONDS: u64 = 31_556_926;

    const ENotEnoughveARCA: u64 = 0;
    const ELockPeriodNotElapsed: u64 = 1;
    const EOngoingStaking: u64 = 2;
    const EDenominatorIsZero: u64 = 3;
    const ENotCorrectStakingPeriod: u64 = 4;
    const ENotAppendActionAvaialble: u64 = 5;
    const ENoActiveStakes: u64 = 6;
    const ENoRewardsLeft: u64 = 7;
    const EDistributionRewardsNotAvaialable: u64 = 8;

    struct ARCA has drop {}

    struct StakingAdmin has key {
        id: UID
    }

    struct VeARCA has key {
        id: UID,
        staked_amount: u64, // ARCA
        initial: u64, // initial_veARCA
        start_date: u64,
        end_date: u64,
        locking_period_sec: u64,
        decimals: u64,
    }

    struct StakingPool has key, store {
        id: UID,
        liquidity: Balance<ARCA>,
        rewards: Balance<ARCA>,
        next_distribution_timestamp: u64,
        veARCA_holders: LinkedTable<address, vector<u64>>,
        holders_vip_level: LinkedTable<u64, vector<address>>,
        vip_per_table: Table<u64, u64>, // vip level, percentage
    }

    // ======================== Init ======================

    fun init(witness: ARCA, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 9, b"ARCA", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
        let cap = StakingAdmin {
            id: object::new(ctx),
        };
        transfer::transfer(cap, tx_context::sender(ctx));
    }

    public(friend) fun create_pool(_cap: &StakingAdmin, clock: &Clock, ctx: &mut TxContext) {
        let staking_pool = StakingPool{
            id: object::new(ctx),
            liquidity: balance::zero<ARCA>(),
            rewards: balance::zero<ARCA>(),
            next_distribution_timestamp: (clock::timestamp_ms(clock)/1000) + WEEK_TO_UNIX_SECONDS,
            veARCA_holders: linked_table::new<address, vector<u64>>(ctx),
            holders_vip_level: linked_table::new<u64, vector<address>>(ctx),
            vip_per_table: table::new<u64, u64>(ctx),
        };
        populate_vip_per_table(&mut staking_pool);
        transfer::share_object(staking_pool);
    }

    fun populate_vip_per_table(sp: &mut StakingPool) {
        table::add(&mut sp.vip_per_table, 0, 0);
        table::add(&mut sp.vip_per_table, 1, 48);
        table::add(&mut sp.vip_per_table, 2, 96);
        table::add(&mut sp.vip_per_table, 3, 144);
        table::add(&mut sp.vip_per_table, 4, 192);
        table::add(&mut sp.vip_per_table, 5, 220);
        table::add(&mut sp.vip_per_table, 6, 288);
        table::add(&mut sp.vip_per_table, 7, 336);
        table::add(&mut sp.vip_per_table, 8, 384);
        table::add(&mut sp.vip_per_table, 9, 432);
        table::add(&mut sp.vip_per_table, 10, 450);
        table::add(&mut sp.vip_per_table, 11, 528);
        table::add(&mut sp.vip_per_table, 12, 576);
        table::add(&mut sp.vip_per_table, 13, 624);
        table::add(&mut sp.vip_per_table, 14, 672);
        table::add(&mut sp.vip_per_table, 15, 700);
        table::add(&mut sp.vip_per_table, 16, 768);
        table::add(&mut sp.vip_per_table, 17, 816);
        table::add(&mut sp.vip_per_table, 18, 864);
        table::add(&mut sp.vip_per_table, 19, 912);
        table::add(&mut sp.vip_per_table, 20, 950);
    }

    // =============================================

    fun mint_ve(staked_amount: u64, initial: u64, start_date: u64, end_date: u64, locking_period_sec: u64, ctx: &mut TxContext): VeARCA {
        let id = object::new(ctx);
        let veARCA = VeARCA{
            id,
            staked_amount,
            initial,
            start_date,
            end_date,
            locking_period_sec,
            decimals: 100
        };

        veARCA
    }

    public fun stake(sp: &mut StakingPool, arca: Coin<ARCA>, clock: &Clock, staking_period: String, ctx: &mut TxContext) {

        assert!(!linked_table::contains(&sp.veARCA_holders, tx_context::sender(ctx)), EOngoingStaking);

        let arca_amount = coin::value(&arca);
        let staked_amount = arca_amount*100;
        let start_tmstmp = clock::timestamp_ms(clock) / 1000;
        let end_tmstmp = 0;
        let locking_period_sec = 0;
        let v = vector::empty<u64>();


        if(staking_period == string::utf8(b"1w")) {
            locking_period_sec = WEEK_TO_UNIX_SECONDS;
            end_tmstmp = start_tmstmp + WEEK_TO_UNIX_SECONDS;
            staked_amount = calc_initial_veARCA(staked_amount*7, 365);

        } else if(staking_period == string::utf8(b"2w")) {
            locking_period_sec = 2 * WEEK_TO_UNIX_SECONDS;
            end_tmstmp = start_tmstmp + 2* WEEK_TO_UNIX_SECONDS;
            staked_amount = calc_initial_veARCA(staked_amount*14, 365);

        } else if(staking_period == string::utf8(b"1m")) {
            locking_period_sec = MONTH_TO_UNIX_SECONDS;
            end_tmstmp = start_tmstmp + MONTH_TO_UNIX_SECONDS;
            staked_amount = calc_initial_veARCA(staked_amount, 12);

        } else if(staking_period == string::utf8(b"3m")) {
            locking_period_sec = 3 * MONTH_TO_UNIX_SECONDS;
            end_tmstmp = start_tmstmp + (3 * MONTH_TO_UNIX_SECONDS);
            staked_amount = calc_initial_veARCA(staked_amount, 4);

        } else if(staking_period == string::utf8(b"6m")) {
            end_tmstmp = start_tmstmp + (6 * MONTH_TO_UNIX_SECONDS);
            staked_amount = calc_initial_veARCA(staked_amount, 2);
            locking_period_sec = 6 * MONTH_TO_UNIX_SECONDS;

        } else if(staking_period == string::utf8(b"1y")) {
            end_tmstmp = start_tmstmp + YEAR_TO_UNIX_SECONDS;
            locking_period_sec = YEAR_TO_UNIX_SECONDS;

        } else {
            assert!(true, ENotCorrectStakingPeriod);
        };

        assert!(staked_amount >= 300*DECIMALS, ENotEnoughveARCA);
        
        let balance = coin::into_balance(arca);
        balance::join(&mut sp.liquidity, balance);

        vector::push_back<u64>(&mut v, staked_amount);
        vector::push_back<u64>(&mut v, end_tmstmp);
        vector::push_back<u64>(&mut v, locking_period_sec);

        linked_table::push_back(&mut sp.veARCA_holders, tx_context::sender(ctx), v);

        let veARCA = mint_ve(arca_amount, staked_amount, start_tmstmp, end_tmstmp, locking_period_sec, ctx);

        transfer::transfer(veARCA, tx_context::sender(ctx));
    }

    public fun append(sp: &mut StakingPool, veARCA: &mut VeARCA, arca: Coin<ARCA>, clock: &Clock, ctx: &mut TxContext) {

        let appended_amount = coin::value(&arca)*100;
        veARCA.staked_amount = veARCA.staked_amount + coin::value(&arca);
        let current_timestamp = clock::timestamp_ms(clock) / 1000;
        let time_left = (veARCA.end_date - current_timestamp)/DAY_TO_UNIX_SECONDS;

        assert!(time_left >= 1, ENotAppendActionAvaialble);

        appended_amount = calc_initial_veARCA(appended_amount*time_left, 365);

        let balance = coin::into_balance(arca);
        balance::join(&mut sp.liquidity, balance);

        veARCA.initial = veARCA.initial + appended_amount;

        let lt_initial = *linked_table::borrow(&mut sp.veARCA_holders, tx_context::sender(ctx));

        *vector::borrow_mut<u64>(&mut lt_initial, 0) = veARCA.initial;

        *linked_table::borrow_mut(&mut sp.veARCA_holders, tx_context::sender(ctx)) = lt_initial;
    }

    public fun unstake(veARCA: VeARCA, sp: &mut StakingPool, clock: &Clock, ctx: &mut TxContext): Coin<ARCA> {
         
        let current_timestamp = clock::timestamp_ms(clock) / 1000;
        assert!(current_timestamp > veARCA.end_date, ELockPeriodNotElapsed);

        let coin_balance = balance::split<ARCA>(&mut sp.liquidity, veARCA.staked_amount);

        let arca = coin::from_balance<ARCA>(coin_balance, ctx);

        burn_veARCA(veARCA);

        linked_table::remove(&mut sp.veARCA_holders, tx_context::sender(ctx));

        arca
    }

    fun classify_vip_addresses(sp: &mut StakingPool, clock: &Clock) {
        
        let i = 0;
        let holder_address = *option::borrow_with_default<address>(linked_table::front(&sp.veARCA_holders), &@0x0);

        debug::print(&linked_table::length(&sp.veARCA_holders));

        while( i < linked_table::length(&sp.veARCA_holders)) {
            if(holder_address == @0x0) {
                break
            };

            let value = linked_table::borrow(&sp.veARCA_holders, holder_address);

            debug::print(value);

            // let vip = calc_vip_level(value, sp.next_distribution_timestamp);
            let vip = calc_vip_level(value, clock);

            debug::print(&vip);

            if(!linked_table::contains(&sp.holders_vip_level, vip)){
                let v = vector::empty<address>();

                vector::push_back<address>(&mut v, holder_address);

                linked_table::push_back(&mut sp.holders_vip_level, vip, v);
            } else {
                let v = linked_table::borrow_mut(&mut sp.holders_vip_level, vip);

                vector::push_back(v, holder_address);
            };  

            if(option::is_none(linked_table::next(&sp.veARCA_holders, holder_address))) {
                break
            };

            holder_address = *option::borrow(linked_table::next(&sp.veARCA_holders, holder_address));
            i = i + 1;
        };
    }

    public fun distribute_rewards(_cap: &StakingAdmin, sp: &mut StakingPool, clock: &Clock, ctx: &mut TxContext) {

        assert!((clock::timestamp_ms(clock) >= sp.next_distribution_timestamp), EDistributionRewardsNotAvaialable);

        let rewards = balance::value<ARCA>(&sp.rewards);
        let rewards_left = balance::value<ARCA>(&sp.rewards);

        classify_vip_addresses(sp, clock);

        // debug::print(&sp.holders_vip_level);
        
        while(!linked_table::is_empty(&sp.holders_vip_level)) {

            let (vip, value) = linked_table::pop_back(&mut sp.holders_vip_level);

            let sum_reward = calc_reward(vip, rewards, &sp.vip_per_table);

            if(rewards_left == 0){
                break
            };

            if(rewards_left < sum_reward){
                sum_reward = rewards_left;
            };

            rewards_left = rewards_left - sum_reward;

            let reward = sum_reward/vector::length<address>(&value);

            // debug::print(&reward);

            while(!vector::is_empty(&value)) {
                let coin = coin::take<ARCA>(&mut sp.rewards, reward, ctx);
                let recipient = vector::pop_back<address>(&mut value);
                transfer::public_transfer(coin, recipient);
            };
        };

        sp.next_distribution_timestamp = sp.next_distribution_timestamp + WEEK_TO_UNIX_SECONDS;
    }

    fun burn_veARCA(veARCA: VeARCA) {
        let VeARCA {id, staked_amount: _, initial: _, start_date: _, end_date: _, locking_period_sec: _, decimals:_} = veARCA;
        object::delete(id);
    }

    // ========================= Helper functions =========================

    fun calc_initial_veARCA(staked_arca_amount: u64, denominator: u64): u64 {

        assert!(denominator !=0, EDenominatorIsZero);

        let veARCA_amount = staked_arca_amount / denominator;

        veARCA_amount
    }

    // we have to put the next distribution timestamp and not the current
    // also probably we have to divide that reward by the users of the respective vip level
    // probably I should put an assert somewhere to be sure that the end_date of the staking period has not pass and the stake is still valid
    // fun calc_veARCA(initial: u64, next_distribution_timestamp: u64, end_date: u64, locking_period_sec: u64, clock: &Clock): u64 {       
    fun calc_veARCA(initial: u64, end_date: u64, locking_period_sec: u64, clock: &Clock): u64 {       
        // initial * ((end_date - next_distribution_timestamp) / locking_period_sec)
        // debug::print(&clock::timestamp_ms(clock));
        // debug::print(&initial);
        // debug::print(&(((end_date - clock::timestamp_ms(clock))*10 / locking_period_sec*10)));
        // this is not working properly, so we need more precise timestamps
        // let s: u64 = (initial * ((end_date - clock::timestamp_ms(clock))*1000 / locking_period_sec*1000))/1000;

        // debug::print(&s);

        initial * (((end_date - clock::timestamp_ms(clock)))*1000 / locking_period_sec*1000)
    }

    fun calc_vip_level_veARCA( veARCA_amount: u64, decimals: u64): u64 {

        debug::print(&veARCA_amount);
        let vip_level = 0;
        if(veARCA_amount >= (3*decimals*DECIMALS) && veARCA_amount < (35*decimals*DECIMALS)) {
            vip_level = 1;
        } else if(veARCA_amount >= (35*decimals*DECIMALS) && veARCA_amount < (170*decimals*DECIMALS)) {
            vip_level = 2;
        } else if(veARCA_amount >= (170*decimals*DECIMALS) && veARCA_amount < (670*decimals*DECIMALS)) {
            vip_level = 3;
        } else if(veARCA_amount >= (670*decimals*DECIMALS) && veARCA_amount < (1_400*decimals*DECIMALS)) {
            vip_level = 4;
        } else if(veARCA_amount >= (1_400*decimals*DECIMALS) && veARCA_amount < (2_700*decimals*DECIMALS)) {
            vip_level = 5;
        } else if(veARCA_amount >= (2_700*decimals*DECIMALS) && veARCA_amount < (4_700*decimals*DECIMALS)) {
            vip_level = 6;
        } else if(veARCA_amount >= (4_700*decimals*DECIMALS) && veARCA_amount < (6_700*decimals*DECIMALS)) {
            vip_level = 7;
        } else if(veARCA_amount >= (6_700*decimals*DECIMALS) && veARCA_amount < (14_000*decimals*DECIMALS)) {
            vip_level = 8;
        } else if(veARCA_amount >= (14_000*decimals*DECIMALS) && veARCA_amount < (17_000*decimals*DECIMALS)) {
            vip_level = 9;
        } else if(veARCA_amount >= (17_000*decimals*DECIMALS) && veARCA_amount < (20_000*decimals*DECIMALS)) {
            vip_level = 10;
        } else if(veARCA_amount >= (20_000*decimals*DECIMALS) && veARCA_amount < (27_000*decimals*DECIMALS)) {
            vip_level = 11;
        } else if(veARCA_amount >= (27_000*decimals*DECIMALS) && veARCA_amount < (34_000*decimals*DECIMALS)) {
            vip_level = 12;
        } else if(veARCA_amount >= (34_000*decimals*DECIMALS) && veARCA_amount < (67_000*decimals*DECIMALS)) {
            vip_level = 13;
        } else if(veARCA_amount >= (67_000*decimals*DECIMALS) && veARCA_amount < (140_000*decimals*DECIMALS)) {
            vip_level = 14;
        } else if(veARCA_amount >= (140_000*decimals*DECIMALS) && veARCA_amount < (270_000*decimals*DECIMALS)) {
            vip_level = 15;
        } else if(veARCA_amount >= (270_000*decimals*DECIMALS) && veARCA_amount < (400_000*decimals*DECIMALS)) {
            vip_level = 16;
        } else if(veARCA_amount >= (400_000*decimals*DECIMALS) && veARCA_amount < (670_000*decimals*DECIMALS)) {
            vip_level = 17;
        } else if(veARCA_amount >= (670_000*decimals*DECIMALS) && veARCA_amount < (1_700_000*decimals*DECIMALS)) {
            vip_level = 18;
        } else if(veARCA_amount >= (1_700_000*decimals*DECIMALS) && veARCA_amount < (3_400_000*decimals*DECIMALS)) {
            vip_level = 19;
        } else if(veARCA_amount >= (3_400_000*decimals*DECIMALS)) {
            vip_level = 20;
        };

        vip_level
    }

    // fun calc_vip_level(value: &vector<u64>, next_distribution_timestamp: u64): u64 {
    fun calc_vip_level(value: &vector<u64>, clock: &Clock): u64 {
        // let veARCA_amount = calc_veARCA(*vector::borrow(value, 0), next_distribution_timestamp, *vector::borrow(value, 1), *vector::borrow(value, 2));
        let veARCA_amount = calc_veARCA(*vector::borrow(value, 0), *vector::borrow(value, 1), *vector::borrow(value, 2), clock);

        debug::print(&veARCA_amount);
        
        let vip_level = calc_vip_level_veARCA(veARCA_amount, 100);

        vip_level
    }

    fun calc_reward(vip_level: u64, rewards_amount: u64, t: &Table<u64, u64>):  u64 {
        let per = *table::borrow(t, vip_level);

        let reward = (rewards_amount * per) / 10_000;

        reward
    }

    // ======================= Accessors ========================

    public fun get_staked_amount_VeARCA(veARCA: &VeARCA): u64 {
        veARCA.staked_amount
    }

    public fun get_initial_VeARCA(veARCA: &VeARCA): u64 {
        veARCA.initial
    }

    // public fun get_amount_VeARCA(veARCA: &VeARCA, sp: &StakingPool): u64 {
    //     calc_veARCA(veARCA.initial, sp.next_distribution_timestamp, veARCA.end_date, veARCA.locking_period_sec)
    // }

    public fun get_start_date_VeARCA(veARCA: &VeARCA): u64 {
        veARCA.start_date
    }

    public fun get_end_date_VeARCA(veARCA: &VeARCA): u64 {
        veARCA.end_date
    }

    public fun get_locking_period_sec_VeARCA(veARCA: &VeARCA): u64 {
        veARCA.locking_period_sec
    }

    public fun get_decimals_VeARCA(veARCA: &VeARCA): u64 {
        veARCA.decimals
    }

    public fun get_id_VeARCA(veARCA: &VeARCA): ID {
        object::uid_to_inner(&veARCA.id)
    }

    public fun get_holders_number(sp: &StakingPool): u64 {
        linked_table::length(&sp.veARCA_holders)
    }

    public fun get_next_distribution_timestamp(sp: &StakingPool): u64 {
        sp.next_distribution_timestamp
    }

    public fun update_percentage_table(_cap: &StakingAdmin, sp: &mut StakingPool, key: u64, percentage: u64) {
        if(table::contains(&sp.vip_per_table, key)) {
            *table::borrow_mut(&mut sp.vip_per_table, key) = percentage;
        } else {
            table::add(&mut sp.vip_per_table, key, percentage);
        };
    }

    // ============================================================

    #[test_only]
    public fun init_for_testing(clock: &Clock, ctx: &mut TxContext) {
        let cap = StakingAdmin {
            id: object::new(ctx),
        };
        create_pool(&cap, clock, ctx);
        transfer::transfer(cap, tx_context::sender(ctx));

    }

    #[test_only]
    public fun increase_rewards_supply(sp: &mut StakingPool) {
        let new_balance = balance::create_for_testing<ARCA>(5_000*DECIMALS);

        let _b = balance::join(&mut sp.rewards, new_balance);
    }

}