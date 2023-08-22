module loa_facilities::staking {
    use std::string::{Self, String};
    use std::vector;

    use sui::bcs;
    use sui::hash;
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::dynamic_field as df;
    use sui::linked_table::{Self, LinkedTable};
    use sui::object::{Self, UID, ID};
    use sui::event;
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use loa::arca::ARCA;
    use loa_facilities::merkle_proof;
    use loa_game::game::{Self, GameConfig};
    use loa_game::game::GameCap;
    use multisig::multisig::{Self, MultiSignature};

    friend loa_facilities::marketplace;

    const VERSION: u64 = 1;

    const DECIMALS: u64 = 1_000_000_000;

    //  https://www.advancedconverter.com/unit-conversions/time-conversion/weeks-to-milliseconds
    const DAY_TO_UNIX_SECONDS: u64 = 86_400;
    const WEEK_TO_UNIX_SECONDS: u64 = 604_800;
    //const MONTH_TO_UNIX_SECONDS: u64 = 2_629_744; // rounded up
    const YEAR_TO_UNIX_SECONDS: u64 = 31_556_926;

    const ENotEnoughveARCA: u64 = 0;
    const ELockPeriodNotElapsed: u64 = 1;
    const EOngoingStaking: u64 = 2;
    const EDenominatorIsZero: u64 = 3;
    const ENotCorrectStakingPeriod: u64 = 4;
    const ENotAppendActionAvaialble: u64 = 5;
    const ENoActiveStakes: u64 = 6;
    const ENoRewardsLeft: u64 = 7;
    const EVersionMismatch: u64 = 8;
    const EProofInvalid: u64 = 9;
    const ENeedVote: u64 = 10;
    const EClaimed: u64 = 11;
    const EWeekRewardCreated: u64 = 11;

    const WithdrawReward: u64 = 4;

    struct VeARCA has key {
        id: UID,
        staked_amount: u64, // ARCA
        initial: u64, // initial_veARCA
        start_time: u64,
        end_time: u64,
        locking_period_sec: u64,
        decimals: u64,
    }

    struct StakingPool has key, store {
        id: UID,
        liquidity: Balance<ARCA>,
        rewards: Balance<ARCA>,
        veARCA_holders: LinkedTable<address, vector<u64>>,
        vip_level_veARCA: vector<u128>,
        week_reward_table: Table<String, bool>
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

    struct WithdrawRewardRequest has key, store {
        id: UID,
        to: address,
        amount: u64
    }

    //event
    struct ArcaStake has copy, drop {
        user: address,
        amount: u64,        // arca amount
        start_time: u64,    // stake start time
        end_time: u64,      // stake end time
        veARCA_id: ID,
    }

    struct AppendArca has copy, drop {
        user: address,
        amount: u64,        // appended arca amount
        current_time: u64, // current time
        veARCA_id: ID,
    }

    struct AppendTime has copy, drop {
        user: address,
        append_time: u64,        // appended time
        current_time: u64,       // current time
        veARCA_id: ID,
    }

    struct UnStake has copy, drop {
        user: address,
        veARCA_id: ID,
    }

    struct WeekRewardCreated has copy, drop {
        name: String,
        merkle_root: vector<u8>,
        total_reward: u64,
        week_reward_id: ID,
    }

    struct Claimed has copy, drop {
        user: address,
        amount: u64,
        week_reward_id: ID,
    }

    fun init(ctx: &mut TxContext){
        let staking_pool = StakingPool{
            id: object::new(ctx),
            liquidity: balance::zero<ARCA>(),
            rewards: balance::zero<ARCA>(),
            veARCA_holders: linked_table::new<address, vector<u64>>(ctx),
            vip_level_veARCA: vector::empty<u128>(),
            week_reward_table: table::new<String, bool>(ctx)
        };
        populate_vip_level_veARCA(&mut staking_pool, 1);
        // marketplace fee part that is to be burned
        df::add<String, Balance<ARCA>>(
            &mut staking_pool.id,
            string::utf8(b"to_burn"),
            balance::zero<ARCA>());
        transfer::share_object(staking_pool);
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


    fun mint_ve(staked_amount: u64, initial: u64, start_time: u64, end_time: u64, locking_period_sec: u64, ctx: &mut TxContext): VeARCA {
        let id = object::new(ctx);
        let veARCA = VeARCA{
            id,
            staked_amount,
            initial,
            start_time,
            end_time,
            locking_period_sec,
            decimals: DECIMALS
        };

        veARCA
    }

    public fun stake(sp: &mut StakingPool, arca: Coin<ARCA>, clock: &Clock, staking_period: u64, ctx: &mut TxContext) {

        assert!(VERSION == 1, EVersionMismatch);

        assert!(!linked_table::contains(&sp.veARCA_holders, tx_context::sender(ctx)), EOngoingStaking);

        assert!(staking_period >= WEEK_TO_UNIX_SECONDS && staking_period<= YEAR_TO_UNIX_SECONDS, ENotCorrectStakingPeriod);

        let amount = coin::value(&arca);
        let staked_amount = amount;
        let start_time = clock::timestamp_ms(clock) / 1000;
        let end_time = start_time + staking_period;
        let locking_period_sec = staking_period;
        let v = vector::empty<u64>();

        staked_amount = calc_initial_veARCA(staked_amount*(staking_period/DAY_TO_UNIX_SECONDS), 365);

        assert!(staked_amount > 0, ENotEnoughveARCA);

        let balance = coin::into_balance(arca);
        balance::join(&mut sp.liquidity, balance);

        vector::push_back<u64>(&mut v, staked_amount);
        vector::push_back<u64>(&mut v, end_time);
        vector::push_back<u64>(&mut v, locking_period_sec);

        linked_table::push_back(&mut sp.veARCA_holders, tx_context::sender(ctx), v);

        let veARCA = mint_ve(amount, staked_amount, start_time, end_time, locking_period_sec, ctx);

        let evt = ArcaStake {
            user: tx_context::sender(ctx),
            amount,
            start_time,
            end_time,
            veARCA_id: object::id(&veARCA),
        };

        event::emit(evt);

        transfer::transfer(veARCA, tx_context::sender(ctx));

    }

    public fun append(sp: &mut StakingPool, veARCA: &mut VeARCA, arca: Coin<ARCA>, clock: &Clock, ctx: &mut TxContext) {

        assert!(VERSION == 1, EVersionMismatch);

        let amount = coin::value(&arca);
        assert!(amount > 0, ENotEnoughveARCA);
        veARCA.staked_amount = veARCA.staked_amount + amount;
        let current_time = clock::timestamp_ms(clock) / 1000;
        assert!(veARCA.end_time > current_time, ENoActiveStakes);
        let time_left = (veARCA.end_time - current_time)/DAY_TO_UNIX_SECONDS;

        assert!(time_left >= 1, ENotAppendActionAvaialble);

        let appended_amount = calc_initial_veARCA(amount *time_left, 365);
        assert!(appended_amount > 0, ENotEnoughveARCA);

        let balance = coin::into_balance(arca);
        balance::join(&mut sp.liquidity, balance);

        veARCA.initial = veARCA.initial + appended_amount;

        let lt_initial = *linked_table::borrow(&mut sp.veARCA_holders, tx_context::sender(ctx));

        *vector::borrow_mut<u64>(&mut lt_initial, 0) = veARCA.initial;

        *linked_table::borrow_mut(&mut sp.veARCA_holders, tx_context::sender(ctx)) = lt_initial;

        let evt = AppendArca {
            user: tx_context::sender(ctx),
            amount,
            current_time,
            veARCA_id: object::id(veARCA),
        };

        event::emit(evt);
    }

    public fun append_time(sp: &mut StakingPool, veARCA: &mut VeARCA, append_time: u64, clock: &Clock, ctx: &mut TxContext) {

        assert!(VERSION == 1, EVersionMismatch);
        assert!(append_time >= WEEK_TO_UNIX_SECONDS, ENotCorrectStakingPeriod);

        let current_time = clock::timestamp_ms(clock) / 1000;
        let staking_period = veARCA.end_time - current_time + append_time;
        if (staking_period > YEAR_TO_UNIX_SECONDS) {
            staking_period = YEAR_TO_UNIX_SECONDS;
            append_time = YEAR_TO_UNIX_SECONDS - current_time;
        };

        assert!(veARCA.end_time > current_time, ENoActiveStakes);

        let staked_amount = calc_initial_veARCA(veARCA.staked_amount*(staking_period/DAY_TO_UNIX_SECONDS), 365);
        assert!(staked_amount > 0, ENotEnoughveARCA);
        veARCA.start_time = current_time;
        veARCA.end_time = current_time + staking_period;
        veARCA.initial = staked_amount;
        veARCA.locking_period_sec = staking_period;

        let lt_initial = *linked_table::borrow(&mut sp.veARCA_holders, tx_context::sender(ctx));

        *vector::borrow_mut<u64>(&mut lt_initial, 0) = veARCA.initial;
        *vector::borrow_mut<u64>(&mut lt_initial, 1) = veARCA.end_time;
        *vector::borrow_mut<u64>(&mut lt_initial, 2) = veARCA.locking_period_sec;

        *linked_table::borrow_mut(&mut sp.veARCA_holders, tx_context::sender(ctx)) = lt_initial;

        let evt = AppendTime {
            user: tx_context::sender(ctx),
            append_time,
            current_time,
            veARCA_id: object::id(veARCA),
        };

        event::emit(evt);
    }

    public fun unstake(veARCA: VeARCA, sp: &mut StakingPool, clock: &Clock, ctx: &mut TxContext): Coin<ARCA> {
         
        assert!(VERSION == 1, EVersionMismatch);
        
        let current_timestamp = clock::timestamp_ms(clock) / 1000;
        assert!(current_timestamp >= veARCA.end_time, ELockPeriodNotElapsed);

        let coin_balance = balance::split<ARCA>(&mut sp.liquidity, veARCA.staked_amount);

        let arca = coin::from_balance<ARCA>(coin_balance, ctx);

        let evt = UnStake {
            user: tx_context::sender(ctx),
            veARCA_id: object::id(&veARCA),
        };

        event::emit(evt);

        burn_veARCA(veARCA);

        linked_table::remove(&mut sp.veARCA_holders, tx_context::sender(ctx));

        arca
    }

    public fun create_week_reward(_: &GameCap, name: String, merkle_root: vector<u8>, total_reward: u64, sp: &mut StakingPool, ctx: &mut TxContext){
        assert!(VERSION == 1, EVersionMismatch);
        assert!(!table::contains(&sp.week_reward_table, name), EWeekRewardCreated);
        let week_reward = WeekReward{
            id: object::new(ctx),
            name,
            merkle_root,
            total_reward,
            claimed: 0,
            claimed_address: table::new<address, bool>(ctx),
        };

        let evt = WeekRewardCreated {
            name,
            merkle_root,
            total_reward,
            week_reward_id: object::id(&week_reward),
        };

        event::emit(evt);

        table::add(&mut sp.week_reward_table, name, true);
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
        assert!(!table::contains(&mut week_reward.claimed_address, user), EClaimed);
        if (vector::length(&week_reward.merkle_root) > 0) {
            let x = bcs::to_bytes<Leaf>(& Leaf{week_reward_name, user, amount});
            let leaf = hash::keccak256(&x);
            let verified = merkle_proof::verify(&merkle_proof, week_reward.merkle_root, leaf);
            assert!(verified, EProofInvalid);
        };

        assert!(amount + week_reward.claimed <= week_reward.total_reward, ENoRewardsLeft);
        let coin = coin::take<ARCA>(&mut sp.rewards, amount, ctx);
        week_reward.claimed = week_reward.claimed + amount;

        table::add(&mut week_reward.claimed_address, user, true);

        let evt = Claimed {
            user,
            amount,
            week_reward_id: object::id(week_reward),
        };

        event::emit(evt);

        transfer::public_transfer(coin, user);
    }

    fun burn_veARCA(veARCA: VeARCA) {
        let VeARCA {id, staked_amount: _, initial: _, start_time: _, end_time: _, locking_period_sec: _, decimals:_} = veARCA;
        object::delete(id);
    }


    fun withdraw_rewards(sp: &mut StakingPool, to:address, amount: u64, ctx: &mut TxContext){
        assert!(VERSION == 1, EVersionMismatch);

        let coin = coin::take<ARCA>(&mut sp.rewards, amount, ctx);

        transfer::public_transfer(coin, to);
    }

    public fun withdraw_rewards_request(game_config:&mut GameConfig, multi_signature : &mut MultiSignature, to: address, amount: u64, ctx: &mut TxContext) {
        // Only multi sig guardian
        game::only_multi_sig_scope(multi_signature, game_config);
        // Only participant
        game::only_participant(multi_signature, ctx);

        let request = WithdrawRewardRequest{
            id: object::new(ctx),
            to,
            amount
        };

        let desc = sui::address::to_string(object::id_address(&request));

        multisig::create_proposal(multi_signature, *string::bytes(&desc), WithdrawReward, request, ctx);
    }

    public fun withdraw_rewards_execute(
        game_config:&mut GameConfig,
        multi_signature : &mut MultiSignature,
        proposal_id: u256,
        is_approve: bool,
        sp: &mut StakingPool,
        ctx: &mut TxContext): bool {

        game::only_multi_sig_scope(multi_signature, game_config);
        // Only participant
        game::only_participant(multi_signature, ctx);

        if (is_approve) {
            let (approved, _ ) = multisig::is_proposal_approved(multi_signature, proposal_id);
            if (approved) {
                let request = multisig::borrow_proposal_request<WithdrawRewardRequest>(multi_signature, &proposal_id, ctx);

                withdraw_rewards(sp, request.to, request.amount, ctx);
                multisig::multisig::mark_proposal_complete(multi_signature, proposal_id, ctx);
                return true
            };
        }else {
            let (rejected, _ ) = multisig::is_proposal_rejected(multi_signature, proposal_id);
            if (rejected) {
                multisig::multisig::mark_proposal_complete(multi_signature, proposal_id, ctx);
                return true
            }
        };

        abort ENeedVote
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
        let current_timestamp = (clock::timestamp_ms(clock) / 1000 as u128);

        assert!(locking_period_sec_128 !=0, EDenominatorIsZero); // add an assertion
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
        while(l >= 0) {
            if(veARCA_amount_128 >= *vector::borrow(vip_level_veARCA, l) && veARCA_amount_128 < *vector::borrow(vip_level_veARCA, l+1)){
                vip_level = l + 1;
                break
            };
            if (l == 0){
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

        calc_veARCA(veARCA.initial, clock, veARCA.end_time, veARCA.locking_period_sec)
    }

    public fun get_start_time_VeARCA(veARCA: &VeARCA): u64 {

        assert!(VERSION == 1, EVersionMismatch);

        veARCA.start_time
    }

    public fun get_end_time_VeARCA(veARCA: &VeARCA): u64 {

        assert!(VERSION == 1, EVersionMismatch);

        veARCA.end_time
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

    public fun update_vip_veARCA_vector(_: &GameCap, sp: &mut StakingPool, index: u64, veARCA_amount: u64, decimals: u64) {

        assert!(VERSION == 1, EVersionMismatch);

        let value: u128 = (veARCA_amount as u128) * (decimals as u128) * (DECIMALS as u128);

        if(index >= vector::length(&sp.vip_level_veARCA)) {
            vector::push_back(&mut sp.vip_level_veARCA, value);
        } else {
            *vector::borrow_mut(&mut sp.vip_level_veARCA, index) = value;
        };
    }


    public fun append_rewards(_: &GameCap, sp: &mut StakingPool, new_balance: Balance<ARCA>) {

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
    public fun init_for_testing(_: &GameCap, ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public fun increase_rewards_supply(sp: &mut StakingPool) {
        let new_balance = balance::create_for_testing<ARCA>(5_000*DECIMALS);

        let _b = balance::join(&mut sp.rewards, new_balance);
    }    
}