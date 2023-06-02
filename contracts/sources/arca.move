module contracts::arca {

    use std::option;
    use std::string::{Self, String};

    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    // use sui::math;

//  https://www.advancedconverter.com/unit-conversions/time-conversion/weeks-to-milliseconds
    const DAY_TO_UNIX_SECONDS: u64 = 86_400;
    const WEAK_TO_UNIX_SECONDS: u64 = 604_800;
    const MONTH_TO_UNIX_SECONDS: u64 = 2_629_744; // rounded up
    const YEAR_TO_UNIX_SECONDS: u64 = 31_556_926;

    const ENotEnoughveARCA: u64 = 0;

    struct ARCA has drop {}

    struct VeARCA has key {
        id: UID,
        staked_amount: u64,
        //appended_amount
        start_date: u64,
        end_date: u64,
    }

    struct StakingPool has key, store {
        id: UID,
        liquidity: Balance<ARCA>,
        total_supply_VeARCA: u64,
        // rewards
        next_distribution_timestamp: u64,
    }

    fun init(witness: ARCA, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 18, b"ARCA", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }

    fun create_pool(ctx: &mut TxContext) {
        let staking_pool = StakingPool{
            id: object::new(ctx),
            liquidity: balance::zero<ARCA>(),
            total_supply_VeARCA: 0,
            next_distribution_timestamp: 0,
        };
        transfer::share_object(staking_pool);
    }

    fun mint_ve(staked_amount: u64, start_date: u64, end_date: u64, ctx: &mut TxContext): VeARCA {
        let id = object::new(ctx);
        let veARCA = VeARCA{
            id,
            staked_amount,
            start_date,
            end_date
        };

        veARCA
    }

    fun calc_veARCA(staked_arca_amount: u64, denominator: u64): u64 {

        let veARCA_amount = staked_arca_amount / denominator;

        veARCA_amount
    }

    public fun stake(sp: &mut StakingPool, arca: Coin<ARCA>, clock: &Clock, staking_period: String, ctx: &mut TxContext): VeARCA {

        let staked_amount = coin::value(&arca);
        let start_tmstmp = clock::timestamp_ms(clock) / 1000;
        let end_tmstmp = 0;

        if(staking_period == string::utf8(b"1w")) {
            end_tmstmp = start_tmstmp + WEAK_TO_UNIX_SECONDS;
            staked_amount = calc_veARCA(staked_amount, 1/365*7);

        } else if(staking_period == string::utf8(b"2w")) {
            end_tmstmp = start_tmstmp + 2* WEAK_TO_UNIX_SECONDS;
            staked_amount = calc_veARCA(staked_amount, 1/365*14);

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
        };

        assert!(staked_amount >= 3, ENotEnoughveARCA);
        
        let balance = coin::into_balance(arca);
        balance::join(&mut sp.liquidity, balance);

        sp.total_supply_VeARCA = sp.total_supply_VeARCA + staked_amount;

        let veARCA = mint_ve(staked_amount, start_tmstmp, end_tmstmp, ctx);
        
        veARCA
    }

    // public fun unstake(ve_arca:, clock:): ARCA {

    // }

    // fun distribute_rewards(staking_pool:, clock: ) {
        
    // }


}