module contracts::staking {
    //use std::option;
    use sui::bcs;
    use std::string::{Self, String};
    use std::vector;

    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::dynamic_field as df;
    use sui::linked_table::{Self, LinkedTable};
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use contracts::arca::ARCA;
    use contracts::merkle_proof;
    //use std::debug;
    use sui::hash as hash2;

    friend contracts::marketplace;

    const VERSION: u64 = 1;

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
    const EDistributionRewardsNotAvailable: u64 = 8;
    const EVersionMismatch: u64 = 9;
    const EProofInvalid: u64 = 10;

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
        veARCA_holders: LinkedTable<address, vector<u64>>,
        holders_vip_level: LinkedTable<u64, vector<address>>,
        vip_per_table: Table<u64, u64>, // vip level, percentage
        vip_level_veARCA: vector<u128>,
    }

    struct WeekReward has key, store {
        id: UID,
        name: String,
        merkle_root: vector<u8>,
        total_reward: u64,
        claimed: u64,
        claimed_address: Table<address, bool>,
    }

    struct Leaf has drop {
        week_reward_name: String,
        user: address,
        amount: u64,
    }

    public fun create_pool(_cap: &TreasuryCap<ARCA>, ctx: &mut TxContext) {
        assert!(VERSION == 1, EVersionMismatch);
        let staking_pool = StakingPool{
            id: object::new(ctx),
            liquidity: balance::zero<ARCA>(),
            rewards: balance::zero<ARCA>(),
            veARCA_holders: linked_table::new<address, vector<u64>>(ctx),
            holders_vip_level: linked_table::new<u64, vector<address>>(ctx),
            vip_per_table: table::new<u64, u64>(ctx),
            vip_level_veARCA: vector::empty<u128>(),
        };
        populate_vip_per_table(&mut staking_pool);
        populate_vip_level_veARCA(&mut staking_pool, 100);
        // marketplace fee part that is to be burned
        df::add<String, Balance<ARCA>>(
            &mut staking_pool.id,
            string::utf8(b"to_burn"),
            balance::zero<ARCA>());
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

    fun populate_vip_level_veARCA(sp: &mut StakingPool, decimals: u64) {
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 3*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 35*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 170*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 670*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 1_400*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 2_700*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 4_700*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 6_700*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 14_000*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 17_000*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 20_000*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 27_000*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 34_000*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 67_000*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 140_000*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 270_000*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 400_000*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 670_000*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 1_700_000*(decimals as u128)*(DECIMALS as u128));
        vector::push_back<u128>(&mut sp.vip_level_veARCA, 3_400_000*(decimals as u128)*(DECIMALS as u128));
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

    public fun stake(sp: &mut StakingPool, arca: Coin<ARCA>, clock: &Clock, staking_period: u64, ctx: &mut TxContext) {

        assert!(VERSION == 1, EVersionMismatch);

        assert!(!linked_table::contains(&sp.veARCA_holders, tx_context::sender(ctx)), EOngoingStaking);

        assert!(staking_period >= DAY_TO_UNIX_SECONDS && staking_period<= YEAR_TO_UNIX_SECONDS, ENotCorrectStakingPeriod);

        let arca_amount = coin::value(&arca);
        let staked_amount = arca_amount*100;
        let start_tmstmp = clock::timestamp_ms(clock) / 1000;
        let end_tmstmp = start_tmstmp + staking_period;
        let locking_period_sec = staking_period;
        let v = vector::empty<u64>();

        staked_amount = calc_initial_veARCA(staked_amount*(staking_period/DAY_TO_UNIX_SECONDS), 365);

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

        assert!(VERSION == 1, EVersionMismatch);

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
         
        assert!(VERSION == 1, EVersionMismatch);
        
        let current_timestamp = clock::timestamp_ms(clock) / 1000;
        assert!(current_timestamp > veARCA.end_date, ELockPeriodNotElapsed);

        let coin_balance = balance::split<ARCA>(&mut sp.liquidity, veARCA.staked_amount);

        let arca = coin::from_balance<ARCA>(coin_balance, ctx);

        burn_veARCA(veARCA);

        linked_table::remove(&mut sp.veARCA_holders, tx_context::sender(ctx));

        arca
    }

    public fun create_week_reward(_: &mut TreasuryCap<ARCA>, name: String, merkle_root: vector<u8>, total_reward: u64, ctx: &mut TxContext){
        assert!(VERSION == 1, EVersionMismatch);
        let week_reward = WeekReward{
            id: object::new(ctx),
            name,
            merkle_root,
            total_reward,
            claimed: 0,
            claimed_address: table::new<address, bool>(ctx),
        };

        transfer::public_share_object(week_reward);
    }

    public fun claim(
        sp: &mut StakingPool,
        week_reward: &mut WeekReward,
        week_reward_name: String,
        amount: u64,
        merkle_proof: vector<vector<u8>>,
        ctx: &mut TxContext
    ){
        let user = tx_context::sender(ctx);
        assert!(!table::contains(&mut week_reward.claimed_address, user), 1);
        if (vector::length(&week_reward.merkle_root) > 0) {
            let x = bcs::to_bytes<Leaf>(& Leaf{week_reward_name, user, amount});
            // let leaf = hash::sha2_256(bcs::to_bytes<Leaf>(& Leaf{week_reward_name, user, amount}));
            let leaf = hash2::keccak256(&x);
            // debug::print(&bcs::to_bytes<Leaf>(& Leaf{week_reward_name, user, amount}));
            // debug::print(&leaf);
            // debug::print(&leaf2);
            let verified = merkle_proof::verify(&merkle_proof, week_reward.merkle_root, leaf);
            assert!(verified, EProofInvalid);
        };

        assert!(amount + week_reward.claimed <= week_reward.total_reward, EProofInvalid);
        let coin = coin::take<ARCA>(&mut sp.rewards, amount, ctx);
        week_reward.claimed = week_reward.claimed + amount;

        table::add(&mut week_reward.claimed_address, user, true);

        transfer::public_transfer(coin, user);
    }

    fun burn_veARCA(veARCA: VeARCA) {
        let VeARCA {id, staked_amount: _, initial: _, start_date: _, end_date: _, locking_period_sec: _, decimals:_} = veARCA;
        object::delete(id);
    }

    public fun receive_rewards(_cap: &TreasuryCap<ARCA>, sp: &mut StakingPool, amount: u64, ctx: &mut TxContext): Coin<ARCA> {
        assert!(VERSION == 1, EVersionMismatch);

        let coin = coin::take<ARCA>(&mut sp.rewards, amount, ctx);

        coin
    }

    // ========================= Helper functions =========================

    fun calc_initial_veARCA(staked_arca_amount: u64, denominator: u64): u64 {

        assert!(denominator !=0, EDenominatorIsZero);

        let veARCA_amount = staked_arca_amount / denominator;

        veARCA_amount
    }

    public fun calc_veARCA(initial: u64, clock: &Clock, end_date: u64, locking_period_sec: u64): u64 {
        let initial_128 = (initial as u128);
        let end_date_128 = (end_date as u128);
        let locking_period_sec_128 = (locking_period_sec as u128);
        let current_timestamp = (clock::timestamp_ms(clock) as u128);

        let veARCA_amount = initial_128 * (end_date_128 - current_timestamp) / locking_period_sec_128;

        (veARCA_amount as u64)
    }

    public fun public_calc_veARCA(initial: u64, end_date: u64, locking_period_sec: u64, clock: &Clock): u64 {

        assert!(VERSION == 1, EVersionMismatch);

        calc_veARCA(initial, clock, end_date, locking_period_sec)
    }

    public fun calc_vip_level_veARCA( veARCA_amount: u64, vip_level_veARCA: &vector<u128>): u64 {

        assert!(VERSION == 1, EVersionMismatch);

        let vip_level = 0;

        let veARCA_amount_128 = (veARCA_amount as u128);

        let l = vector::length(vip_level_veARCA) - 1;

        if(veARCA_amount_128 >= *vector::borrow(vip_level_veARCA, l)) {
            vip_level = vector::length(vip_level_veARCA);
        } else if(veARCA_amount_128 < *vector::borrow(vip_level_veARCA, 0)) {
            vip_level = 0;
        };

        l = l - 1;
        while(l > 0) {
            if(veARCA_amount_128 >= *vector::borrow(vip_level_veARCA, l) && veARCA_amount_128 < *vector::borrow(vip_level_veARCA, l+1)){
                vip_level = l;
                break
            };
            l = l-1;
        };

        vip_level
    }


    public fun calc_vip_level(sp: &StakingPool, holder: address, clock: &Clock): u64 {
        assert!(VERSION == 1, EVersionMismatch);

        let value = linked_table::borrow(&sp.veARCA_holders, holder);
        let veARCA_amount = calc_veARCA(
            *vector::borrow(value, 0),
            clock,
            *vector::borrow(value, 1),
            *vector::borrow(value, 2));

        let vip_level = calc_vip_level_veARCA(veARCA_amount, &sp.vip_level_veARCA);

        vip_level
    }


    fun calc_reward(vip_level: u64, rewards_amount: u64, t: &Table<u64, u64>):  u64 {
        let per = *table::borrow(t, vip_level);

        let reward = (rewards_amount * per) / 10_000;

        reward
    }

    // ======================= Accessors ========================

    public fun get_staked_amount_VeARCA(veARCA: &VeARCA): u64 {

        assert!(VERSION == 1, EVersionMismatch);

        veARCA.staked_amount
    }

    public fun get_initial_VeARCA(veARCA: &VeARCA): u64 {

        assert!(VERSION == 1, EVersionMismatch);

        veARCA.initial
    }

    public fun get_amount_VeARCA(veARCA: &VeARCA, clock: &Clock): u64 {

        assert!(VERSION == 1, EVersionMismatch);

        calc_veARCA(veARCA.initial, clock, veARCA.end_date, veARCA.locking_period_sec)
    }

    public fun get_start_date_VeARCA(veARCA: &VeARCA): u64 {

        assert!(VERSION == 1, EVersionMismatch);

        veARCA.start_date
    }

    public fun get_end_date_VeARCA(veARCA: &VeARCA): u64 {

        assert!(VERSION == 1, EVersionMismatch);

        veARCA.end_date
    }

    public fun get_locking_period_sec_VeARCA(veARCA: &VeARCA): u64 {

        assert!(VERSION == 1, EVersionMismatch);

        veARCA.locking_period_sec
    }

    public fun get_decimals_VeARCA(veARCA: &VeARCA): u64 {

        assert!(VERSION == 1, EVersionMismatch);

        veARCA.decimals
    }

    public fun get_holders_number(sp: &StakingPool): u64 {

        assert!(VERSION == 1, EVersionMismatch);

        linked_table::length(&sp.veARCA_holders)
    }


    public fun get_rewards_value(sp: &StakingPool): u64 {
        balance::value(&sp.rewards)
    }

    public fun update_percentage_table(_cap: &TreasuryCap<ARCA>, sp: &mut StakingPool, key: u64, percentage: u64) {

        assert!(VERSION == 1, EVersionMismatch);

        if(table::contains(&sp.vip_per_table, key)) {
            *table::borrow_mut(&mut sp.vip_per_table, key) = percentage;
        } else {
            table::add(&mut sp.vip_per_table, key, percentage);
        };
    }

    public fun update_vip_veARCA_vector(_cap: &TreasuryCap<ARCA>, sp: &mut StakingPool, index: u64, veARCA_amount: u64, decimals: u64) {

        assert!(VERSION == 1, EVersionMismatch);

        let value: u128 = (veARCA_amount as u128) * (decimals as u128) * (DECIMALS as u128);

        if(index >= vector::length(&sp.vip_level_veARCA)) {
            vector::push_back(&mut sp.vip_level_veARCA, value);
        } else {
            *vector::borrow_mut(&mut sp.vip_level_veARCA, index) = value;
        };
    }


    public fun append_rewards(_cap: &TreasuryCap<ARCA>, sp: &mut StakingPool, new_balance: Balance<ARCA>) {

        assert!(VERSION == 1, EVersionMismatch);

        balance::join(&mut sp.rewards, new_balance);
    }

    public(friend) fun marketplace_add_to_burn(sp: &mut StakingPool, c: Coin<ARCA>)
    {   
        assert!(VERSION == 1, EVersionMismatch);
        balance::join(
            df::borrow_mut<String, Balance<ARCA>>(&mut sp.id, string::utf8(b"to_burn")),
            coin::into_balance<ARCA>(c)
        );
    }

    public(friend) fun marketplace_add_rewards(sp: &mut StakingPool, c: Coin<ARCA>)
    {
        assert!(VERSION == 1, EVersionMismatch);
        balance::join(&mut sp.rewards, coin::into_balance<ARCA>(c));
    }

    // ============================================================

    #[test_only]
    public fun init_for_testing(cap: &TreasuryCap<ARCA>, ctx: &mut TxContext) {
        create_pool(cap,  ctx);
    }

    #[test_only]
    public fun increase_rewards_supply(sp: &mut StakingPool) {
        let new_balance = balance::create_for_testing<ARCA>(5_000*DECIMALS);

        let _b = balance::join(&mut sp.rewards, new_balance);
    }    
}