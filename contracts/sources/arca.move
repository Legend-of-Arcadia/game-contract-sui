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
    const ENoActiveStakes: u64 = 6;

    struct ARCA has drop {}

    struct StakingAdmin has key {
        id: UID
    }

    struct VeARCA has key {
        id: UID,
        staked_amount: u64, // ARCA
        initial: u64, // initial_veARCA
        amount: u64, // current amount_veARCA
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
    }

    fun init(witness: ARCA, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 18, b"ARCA", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
        create_pool(ctx);
    }

    fun create_pool(ctx: &mut TxContext) {
        let cap = StakingAdmin {
            id: object::new(ctx),
        };
        transfer::transfer(cap, tx_context::sender(ctx));
        let staking_pool = StakingPool{
            id: object::new(ctx),
            liquidity: balance::zero<ARCA>(),
            rewards: balance::zero<ARCA>(),
            next_distribution_timestamp: 0,
            veARCA_holders: linked_table::new<address, vector<u64>>(ctx),
        };
        transfer::share_object(staking_pool);
    }

    fun mint_ve(staked_amount: u64, initial: u64, amount: u64, start_date: u64, end_date: u64, locking_period_sec: u64, ctx: &mut TxContext): VeARCA {
        let id = object::new(ctx);
        let veARCA = VeARCA{
            id,
            staked_amount,
            initial,
            amount,
            start_date,
            end_date,
            locking_period_sec,
            decimals: 100
        };

        veARCA
    }

    fun calc_initial_veARCA(staked_arca_amount: u64, denominator: u64): u64 {

        assert!(denominator !=0, EDenominatorIsZero);

        let veARCA_amount = staked_arca_amount / denominator;

        veARCA_amount
    }

    fun calc_veARCA(initial: u64, end_date: u64, locking_period_sec: u64, clock: &Clock): u64 {

        // debug::print(&initial);
        // debug::print(&locking_period_sec);
        
        initial * (end_date - (clock::timestamp_ms(clock)/1000)) / locking_period_sec
    }

    fun calc_vip_level_veARCA( veARCA_amount: u64, decimals: u64): u64 {
        let vip_level = 0;
        if(veARCA_amount >= (3*decimals) && veARCA_amount < (35*decimals)) {
            vip_level = 1;
        } else if(veARCA_amount >= (35*decimals) && veARCA_amount < (170*decimals)) {
            vip_level = 2;
        } else if(veARCA_amount >= (170*decimals) && veARCA_amount < (670*decimals)) {
            vip_level = 3;
        } else if(veARCA_amount >= (670*decimals) && veARCA_amount < (1_400*decimals)) {
            vip_level = 4;
        } else if(veARCA_amount >= (1_400*decimals) && veARCA_amount < (2_700*decimals)) {
            vip_level = 5;
        } else if(veARCA_amount >= (2_700*decimals) && veARCA_amount < (4_700*decimals)) {
            vip_level = 6;
        } else if(veARCA_amount >= (4_700*decimals) && veARCA_amount < (6_700*decimals)) {
            vip_level = 7;
        } else if(veARCA_amount >= (6_700*decimals) && veARCA_amount < (14_000*decimals)) {
            vip_level = 8;
        } else if(veARCA_amount >= (14_000*decimals) && veARCA_amount < (17_000*decimals)) {
            vip_level = 9;
        } else if(veARCA_amount >= (17_000*decimals) && veARCA_amount < (20_000*decimals)) {
            vip_level = 10;
        } else if(veARCA_amount >= (20_000*decimals) && veARCA_amount < (27_000*decimals)) {
            vip_level = 11;
        } else if(veARCA_amount >= (27_000*decimals) && veARCA_amount < (34_000*decimals)) {
            vip_level = 12;
        } else if(veARCA_amount >= (34_000*decimals) && veARCA_amount < (67_000*decimals)) {
            vip_level = 13;
        } else if(veARCA_amount >= (67_000*decimals) && veARCA_amount < (140_000*decimals)) {
            vip_level = 14;
        } else if(veARCA_amount >= (140_000*decimals) && veARCA_amount < (270_000*decimals)) {
            vip_level = 15;
        } else if(veARCA_amount >= (270_000*decimals) && veARCA_amount < (400_000*decimals)) {
            vip_level = 16;
        } else if(veARCA_amount >= (400_000*decimals) && veARCA_amount < (670_000*decimals)) {
            vip_level = 17;
        } else if(veARCA_amount >= (670_000*decimals) && veARCA_amount < (1_700_000*decimals)) {
            vip_level = 18;
        } else if(veARCA_amount >= (1_700_000*decimals) && veARCA_amount < (3_400_000*decimals)) {
            vip_level = 19;
        } else if(veARCA_amount >= (3_400_000*decimals)) {
            vip_level = 20;
        };

        vip_level
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
            locking_period_sec = WEAK_TO_UNIX_SECONDS;
            end_tmstmp = start_tmstmp + WEAK_TO_UNIX_SECONDS;
            staked_amount = calc_initial_veARCA(staked_amount*7, 365);

        } else if(staking_period == string::utf8(b"2w")) {
            locking_period_sec = 2 * WEAK_TO_UNIX_SECONDS;
            end_tmstmp = start_tmstmp + 2* WEAK_TO_UNIX_SECONDS;
            staked_amount = calc_initial_veARCA(staked_amount*14, 365);

        } else if(staking_period == string::utf8(b"1m")) {
            locking_period_sec = MONTH_TO_UNIX_SECONDS;
            end_tmstmp = start_tmstmp + MONTH_TO_UNIX_SECONDS;
            staked_amount = calc_initial_veARCA(staked_amount, 12);

        } else if(staking_period == string::utf8(b"3m")) {
            locking_period_sec = 3 * MONTH_TO_UNIX_SECONDS;
            // debug::print(&string::utf8(b"3m stake"));
            // debug::print(&locking_period_sec);
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

        assert!(staked_amount >= 300, ENotEnoughveARCA);
        
        let balance = coin::into_balance(arca);
        balance::join(&mut sp.liquidity, balance);

        // vector<u64>: initial veARCA amount, start lock, end lock, vip_level

        vector::push_back<u64>(&mut v, staked_amount);
        vector::push_back<u64>(&mut v, end_tmstmp);
        vector::push_back<u64>(&mut v, locking_period_sec);

        // debug::print(&staking_period);
        // debug::print(&v);

        linked_table::push_back(&mut sp.veARCA_holders, tx_context::sender(ctx), v);

        let veARCA = mint_ve(arca_amount, staked_amount, staked_amount, start_tmstmp, end_tmstmp, locking_period_sec, ctx);

        transfer::transfer(veARCA, tx_context::sender(ctx));
    }

    public fun append(sp: &mut StakingPool, veARCA: &mut VeARCA, arca: Coin<ARCA>, clock: &Clock) {
        
        let appended_amount = coin::value(&arca)*100;
        veARCA.amount = veARCA.amount + appended_amount;
        let current_timestamp = clock::timestamp_ms(clock) / 1000;
        let time_left = (veARCA.end_date - current_timestamp)/DAY_TO_UNIX_SECONDS;

        assert!(time_left >= 1, ENotAppendActionAvaialble);

        appended_amount = calc_initial_veARCA(appended_amount*time_left, 365);

        let balance = coin::into_balance(arca);
        balance::join(&mut sp.liquidity, balance);

        veARCA.initial = veARCA.initial + appended_amount;
    }

    public fun unstake(veARCA: VeARCA, sp: &mut StakingPool, clock: &Clock, ctx: &mut TxContext): Coin<ARCA> {
         
        let current_timestamp = clock::timestamp_ms(clock) / 1000;
        assert!(current_timestamp > veARCA.end_date, ENotValidAction);

        let coin_balance = balance::split<ARCA>(&mut sp.liquidity, veARCA.staked_amount);

        let arca = coin::from_balance<ARCA>(coin_balance, ctx);

        burn_veARCA(veARCA);

        linked_table::remove(&mut sp.veARCA_holders, tx_context::sender(ctx));

        arca
    }

    fun get_vip_percentage( vip_level: u64): u64 {
        let percentage = 0;
        if(vip_level == 1){
            percentage = 48
        } else if(vip_level == 2){
            percentage = 96
        } else if(vip_level == 3){
            percentage = 144
        } else if(vip_level == 4){
            percentage = 192
        } else if(vip_level == 5){
            percentage = 220
        } else if(vip_level == 6){
            percentage = 288
        } else if(vip_level == 7){
            percentage = 336
        } else if(vip_level == 8){
            percentage = 384
        } else if(vip_level == 9){
            percentage = 432
        } else if(vip_level == 10){
            percentage = 450
        } else if(vip_level == 11){
            percentage = 528
        } else if(vip_level == 12){
            percentage = 576
        } else if(vip_level == 13){
            percentage = 624
        } else if(vip_level == 14){
            percentage = 672
        } else if(vip_level == 15){
            percentage = 700
        } else if(vip_level == 16){
            percentage = 768
        } else if(vip_level == 17){
            percentage = 816
        } else if(vip_level == 18){
            percentage = 864
        } else if(vip_level == 19){
            percentage = 912
        } else if(vip_level == 20){
            percentage = 950
        };

        percentage
    }

    fun calc_reward(value: &vector<u64>, rewards_amount: u64, clock: &Clock): u64 {

        let veARCA_amount = calc_veARCA(*vector::borrow(value, 0), *vector::borrow(value, 1), *vector::borrow(value, 2), clock);

        let vip_level = calc_vip_level_veARCA(veARCA_amount, 100);
        let per = get_vip_percentage(vip_level);

        let reward = (rewards_amount * per) / 10_000;

        reward
    }

    public fun distribute_rewards(_cap: &StakingAdmin, sp: &mut StakingPool, clock: &Clock, ctx: &mut TxContext) {

        debug::print(&linked_table::length(&sp.veARCA_holders));
        assert!(!(linked_table::length(&sp.veARCA_holders) == 0), ENoActiveStakes);

        let rewards = balance::value<ARCA>(&sp.rewards) * 1;

        let i = 0;
        let holder_address = *option::borrow(linked_table::front(&sp.veARCA_holders));
        
        while( i < linked_table::length(&sp.veARCA_holders)) {
            let value = linked_table::borrow(&sp.veARCA_holders, holder_address);
            

            // debug::print(&string::utf8(b"value"));
            // debug::print(&holder_address);
            // debug::print(value);

            let reward = calc_reward(value, rewards, clock);

            let coin = coin::take<ARCA>(&mut sp.rewards, reward, ctx);

            debug::print(&string::utf8(b"holder_address"));

            debug::print(&holder_address);
            
            transfer::public_transfer(coin, holder_address);

            if(option::is_none(linked_table::next(&sp.veARCA_holders, holder_address))){
                break
            };

            holder_address = *option::borrow(linked_table::next(&sp.veARCA_holders, holder_address));
            i = i + 1;
        }

    }

    fun burn_veARCA(veARCA: VeARCA) {
        let VeARCA {id, staked_amount: _, initial: _, amount: _, start_date: _, end_date: _, locking_period_sec: _, decimals:_} = veARCA;
        object::delete(id);
    }

    public fun get_staked_amount_VeARCA(veARCA: &VeARCA): u64 {
        veARCA.staked_amount
    }

    public fun get_initial_VeARCA(veARCA: &VeARCA): u64 {
        veARCA.initial
    }

    public fun get_amount_VeARCA(veARCA: &VeARCA): u64 {
        veARCA.amount
    }

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

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        create_pool(ctx);
    }

    #[test_only]
    public fun increase_rewards_supply(sp: &mut StakingPool) {
        let new_balance = balance::create_for_testing<ARCA>(500_000);

        let _b = balance::join(&mut sp.rewards, new_balance);
    }

}