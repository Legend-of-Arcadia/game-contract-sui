module contracts::activity {
    use std::type_name::{Self, TypeName};
    use sui::vec_map::{Self, VecMap};
    use std::string::{Self, String};
    use sui::clock::{Self, Clock};
    use std::option;
    use std::vector;

    use sui::balance::{Self, Balance};
    use sui::dynamic_field as df;
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::object::{Self, ID, UID};
    //use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use contracts::gacha::{Self};
    use contracts::game::{Self, GameCap, GameConfig};
    use multisig::multisig::{Self, MultiSignature};


    const EPaymentAmountInvalid: u64 = 0;
    const EOverflowMaxSupply: u64 = 1;
    const ECoinTypeNoExist: u64 = 2;
    const ECurrentTimeLTStartTime: u64 = 3;
    const ECurrentTimeGEEndTime: u64 = 4;
    const EPriceEQZero: u64 = 5;
    const ETimeSet: u64 = 6;
    const ECoinTypeMismatch: u64 = 7;
    const ENeedVote: u64 = 8;

    const WithdrawActivityProfits: u64 = 0;

    struct ActivityProfits has key, store {
        id: UID,
    }

    struct ActivityConfig has key, store {
        id: UID,
        start_time: u64,
        end_time: u64,
        max_supply: u64,
        total_supply: u64,
        coin_prices: VecMap<TypeName, u64>,
        token_type: u64,
        name: String,
        type: String,
        collection: String,
        description: String,
    }

    struct WithdrawActivityProfitsQequest has key, store {
        id: UID,
        coin_type: TypeName,
        to: address
    }

    // event
    struct BuyEvent has copy, drop {
        coin_type: TypeName,
        type: String,
        price: u64,
        amount: u64,
        total: u64,
        token_types: vector<address>,
    }

    struct CreateConfigEvent has copy, drop {
        config: ID,
        token_type: u64,
        type: String,
        name: String,
        collection: String,
    }

    struct RemoveConfigEvent has copy, drop {
        config_object_id: ID,
    }

    struct SetPriceEvent has copy, drop {
        config_object_id: ID,
        coin_type: TypeName,
        price: u64,
    }

    struct RemovePriceEvent has copy, drop {
        config_object_id: ID,
        coin_type: TypeName,
    }

    fun init(ctx: &mut TxContext){
        let activity_profits = ActivityProfits{
            id: object::new(ctx),
        };

        transfer::public_share_object(activity_profits);
    }

    public entry fun create_config(
        _: &GameCap,
        start_time: u64,
        end_time: u64,
        max_supply: u64,
        token_type: u64,
        name: String,
        type: String,
        collection: String,
        description: String,
        ctx: &mut TxContext,
    ) {
        assert_time_set(start_time, end_time);
        let config = ActivityConfig {
            id: object::new(ctx),
            start_time,
            end_time,
            max_supply,
            total_supply: 0,
            coin_prices: vec_map::empty<TypeName, u64>(),
            token_type,
            name,
            type,
            collection,
            description
        };

        event::emit(CreateConfigEvent {
            config: object::id(&config),
            token_type,
            type,
            name: config.name,
            collection,
        });

        transfer::public_share_object(config);
    }

    public entry fun remove_config(_: &GameCap, config: ActivityConfig) {
        event::emit(RemoveConfigEvent {
            config_object_id: object::id(&config),
        });

        let ActivityConfig{id, start_time:_, end_time: _,
            max_supply: _, total_supply:_, coin_prices:_,
            token_type:_, name:_, type:_, collection:_, description: _} = config;

        object::delete(id);
    }

    public entry fun set_price<COIN>(
        _: &GameCap,
        config: &mut ActivityConfig,
        price: u64,
    ) {
        assert_price_gt_zero(price);
        let coin_type = type_name::get<COIN>();
        if (vec_map::contains(&config.coin_prices, &coin_type)) {
            let previous = vec_map::get_mut(&mut config.coin_prices, &coin_type);
            *previous = price;
        } else {
            vec_map::insert(&mut config.coin_prices, coin_type, price);
        };

        event::emit(SetPriceEvent {
            config_object_id: object::id(config),
            coin_type,
            price,
        });
    }

    public entry fun remove_price<COIN>(
        _: &GameCap,
        config: &mut ActivityConfig,
    ) {
        let coin_type = type_name::get<COIN>();
        if (vec_map::contains(&config.coin_prices, &coin_type)) {
            vec_map::remove(&mut config.coin_prices, &coin_type);
        };
        event::emit(RemovePriceEvent {
            config_object_id: object::id(config),
            coin_type,
        });
    }

    public entry fun buy<COIN>(
        config: &mut ActivityConfig,
        paid: Coin<COIN>,
        amount: u64,
        clock: &Clock,
        profits: &mut ActivityProfits,
        ctx: &mut TxContext,
    ) {
        let current_time: u64 = clock::timestamp_ms(clock);
        let coin_type = type_name::get<COIN>();
        let (contain, price) = (false, 0);
        let priceVal = vec_map::try_get(&config.coin_prices, &coin_type);
        if (option::is_some(&priceVal)) {
            contain = true;
            price = *option::borrow(&priceVal);
        };

        assert_coin_type_exist(contain);
        assert_price_gt_zero(price);
        assert_current_time_ge_start_time(current_time, config.start_time);
        assert_current_time_lt_end_time(current_time, config.end_time);
        assert_total_supply(config.total_supply, config.max_supply, amount);

        let total: u64 = price * amount;
        // payment
        pay(profits, total, paid, ctx);
        // mint nft
        let i = 0;
        let token_types: vector<address> = vector::empty<address>();
        while (i < amount) {
            let gacha_ball = gacha::mint(
                config.token_type,
                config.collection,
                config.name,
                config.type,
                config.description,
                ctx,
            );

            let token_type = object::id_address(&gacha_ball);
            vector::push_back(&mut token_types, token_type);
            transfer::public_transfer(gacha_ball, tx_context::sender(ctx));
            i = i + 1;
        };

        config.total_supply = config.total_supply + amount;
        // events
        event::emit(BuyEvent {
            coin_type,
            type: config.type,
            price,
            amount,
            total,
            token_types,
        });
    }

    fun pay<COIN>(profits: &mut ActivityProfits, total: u64, paid: Coin<COIN>, ctx: &mut TxContext) {
        let paid_value: u64 = balance::value(coin::balance(&paid));
        assert_payment_amount(total, paid_value);

        let coin_type = type_name::get<COIN>();
        if (total < paid_value) {
            transfer::public_transfer(coin::split(&mut paid, paid_value - total, ctx), tx_context::sender(ctx));
        };

        if (df::exists_with_type<TypeName, Balance<COIN>>(&mut profits.id, coin_type)) {
            let coin_balance = df::borrow_mut<TypeName, Balance<COIN>>(&mut profits.id, coin_type);
            balance::join<COIN>(coin_balance, coin::into_balance<COIN>(paid));
        } else {
            df::add<TypeName, Balance<COIN>>(&mut profits.id, coin_type, coin::into_balance<COIN>(paid));
        };
    }

    // public fun take_fee_profits<COIN>(_: &GameCap, config: &mut ActivityConfig, ctx: &mut TxContext): Coin<COIN>{
    //     let coin_type = type_name::get<COIN>();
    //     let coin_balance = df::borrow_mut<TypeName, Balance<COIN>>(&mut config.id, coin_type);
    //     let balance_all = balance::withdraw_all<COIN>(coin_balance);
    //     coin::from_balance<COIN>(balance_all, ctx)
    // }
    fun withdraw_activity_profits<COIN>(profits: &mut ActivityProfits, to:address, ctx: &mut TxContext){
        let coin_type = type_name::get<COIN>();
        let coin_balance = df::borrow_mut<TypeName, Balance<COIN>>(&mut profits.id, coin_type);
        let balance_all = balance::withdraw_all<COIN>(coin_balance);
        transfer::public_transfer(coin::from_balance<COIN>(balance_all, ctx), to);
    }

    public fun withdraw_activity_profits_request<COIN>(game_config:&mut GameConfig, multi_signature : &mut MultiSignature, to: address, ctx: &mut TxContext) {
        // Only multi sig guardian
        game::only_multi_sig_scope(multi_signature, game_config);
        // Only participant
        game::only_participant(multi_signature, ctx);

        let coin_type = type_name::get<COIN>();
        let request = WithdrawActivityProfitsQequest{
            id: object::new(ctx),
            coin_type,
            to
        };

        let desc = sui::address::to_string(object::id_address(&request));

        multisig::create_proposal(multi_signature, *string::bytes(&desc), WithdrawActivityProfits, request, ctx);
    }

    public fun withdraw_activity_profits_execute<COIN>(
        game_config:&mut GameConfig,
        multi_signature : &mut MultiSignature,
        proposal_id: u256,
        is_approve: bool,
        profits: &mut ActivityProfits,
        ctx: &mut TxContext): bool {

        game::only_multi_sig_scope(multi_signature, game_config);
        // Only participant
        game::only_participant(multi_signature, ctx);

        if (is_approve) {
            let (approved, _ ) = multisig::is_proposal_approved(multi_signature, proposal_id);
            if (approved) {
                let request = multisig::borrow_proposal_request<WithdrawActivityProfitsQequest>(multi_signature, &proposal_id, ctx);

                assert!(request.coin_type == type_name::get<COIN>(), ECoinTypeMismatch);
                withdraw_activity_profits<COIN>(profits, request.to, ctx);
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

    // asserts
    fun assert_coin_type_exist(contain: bool) {
        assert!(contain, ECoinTypeNoExist);
    }

    fun assert_price_gt_zero(price: u64) {
        assert!(price > 0, EPriceEQZero);
    }

    fun assert_current_time_ge_start_time(current_time: u64, start_time: u64) {
        if (start_time > 0) {
            assert!(current_time >= start_time, ECurrentTimeLTStartTime);
        };
    }

    fun assert_current_time_lt_end_time(current_time: u64, end_time: u64) {
        if (end_time > 0) {
            assert!(current_time < end_time, ECurrentTimeGEEndTime);
        };
    }

    fun assert_total_supply(total_supply: u64, max_supply: u64, amount: u64) {
        assert!(total_supply + amount <= max_supply, EOverflowMaxSupply);
    }

    fun assert_payment_amount(total: u64, paid_value: u64) {
        assert!(total <= paid_value, EPaymentAmountInvalid);
    }

    fun assert_time_set(start_time: u64, end_time: u64) {
        if (start_time > 0 && end_time > 0) {
            assert!(end_time >= start_time, ETimeSet);
        };
    }

    #[test_only]
    public fun init_for_test(ctx: &mut TxContext) {
        init(ctx);
    }
}
