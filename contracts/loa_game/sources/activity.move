module loa_game::activity {
    use std::type_name::{Self, TypeName};
    use std::string::{Self, String};
    use std::option;

    use sui::vec_map::{Self, VecMap};
    use sui::clock::{Self, Clock};
    use sui::balance::{Self, Balance};
    use sui::dynamic_field as df;
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use loa_game::gacha::{Self};
    use loa_game::game::{Self, GameCap, GameConfig};
    use multisig::multisig::{Self, MultiSignature};

    const VERSION: u64 = 1;

    const EPaymentAmountInvalid: u64 = 0;
    const EOverflowMaxSupply: u64 = 1;
    const ECoinTypeNoExist: u64 = 2;
    const ECurrentTimeLTStartTime: u64 = 3;
    const ECurrentTimeGEEndTime: u64 = 4;
    const EPriceEQZero: u64 = 5;
    const ETimeSet: u64 = 6;
    const ECoinTypeMismatch: u64 = 7;
    const ENeedVote: u64 = 8;
    const EIncorrectVersion: u64 = 9;
    const ENotUpgrade: u64 = 10;

    const WithdrawActivityProfits: u64 = 5;

    struct ActivityProfits has key, store {
        id: UID,
        version: u64,
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

    struct WithdrawActivityProfitsRequest has key, store {
        id: UID,
        coin_type: TypeName,
        to: address
    }

    // event
    struct BuyEvent has copy, drop {
        config: ID,             // activity config id
        amount: u64,            // buy amount
        coin_type: TypeName,
        price: u64,
        token_type: u64,        // for statistics
        //ids: vector<address>, // NO need to record since we have GachaBallMinted event and amount(gas cost opt)
        total_supply: u64,      // for statistics
        max_supply: u64,        // for statistics
    }

    struct CreateConfigEvent has copy, drop {
        config: ID,
        token_type: u64,
        type: String,
        name: String,
    }

    struct UpdateConfigEvent has copy, drop {
        config: ID,
        token_type: u64,
        type: String,
        name: String
    }

    struct ResetSupplyEvent has copy, drop {
        config: ID,
        total_supply: u64,
    }

    struct SetPriceEvent has copy, drop {
        config: ID,
        coin_type: TypeName,
        price: u64,
    }

    struct RemovePriceEvent has copy, drop {
        config: ID,
        coin_type: TypeName,
    }

    fun init(ctx: &mut TxContext){
        let activity_profits = ActivityProfits{
            id: object::new(ctx),
            version: VERSION,
        };

        transfer::public_share_object(activity_profits);
    }

    public entry fun create_config(
        game_cap: &GameCap,
        start_time: u64,
        end_time: u64,
        max_supply: u64,
        token_type: u64,
        name: String,
        type: String,
        collection: String,
        description: String,
        game_config: &GameConfig,
        ctx: &mut TxContext,
    ) {
        game::check_game_cap(game_cap, game_config);
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
            name,
        });

        transfer::public_share_object(config);
    }

    // add update config for future use
    public entry fun update_config(
        game_cap: &GameCap,
        config: &mut ActivityConfig,
        start_time: u64,
        end_time: u64,
        max_supply: u64,
        token_type: u64,
        name: String,
        type: String,
        collection: String,
        description: String,
        game_config: &GameConfig,
    ) {
        game::check_game_cap(game_cap, game_config);
        assert_time_set(start_time, end_time);
        config.start_time = start_time;
        config.end_time = end_time;
        config.max_supply = max_supply;
        config.token_type = token_type;
        config.name = name;
        config.type = type;
        config.collection = collection;
        config.description = description;

        event::emit(UpdateConfigEvent {
            config: object::id(config),
            token_type,
            type,
            name,
        });
    }

    // add reset supply for future use
    public entry fun reset_supply(
        game_cap: &GameCap,
        config: &mut ActivityConfig,
        game_config: &GameConfig,
    ) {
        game::check_game_cap(game_cap, game_config);
        event::emit(ResetSupplyEvent {
            config: object::id(config),
            total_supply: config.total_supply,
        });

        config.total_supply = 0;
    }

    public entry fun set_price<COIN>(
        game_cap: &GameCap,
        config: &mut ActivityConfig,
        price: u64,
        game_config: &GameConfig,
    ) {
        game::check_game_cap(game_cap, game_config);
        assert_price_gt_zero(price);
        let coin_type = type_name::get<COIN>();
        if (vec_map::contains(&config.coin_prices, &coin_type)) {
            let previous = vec_map::get_mut(&mut config.coin_prices, &coin_type);
            *previous = price;
        } else {
            vec_map::insert(&mut config.coin_prices, coin_type, price);
        };

        event::emit(SetPriceEvent {
            config: object::id(config),
            coin_type,
            price,
        });
    }

    public entry fun remove_price<COIN>(
        game_cap: &GameCap,
        config: &mut ActivityConfig,
        game_config: &GameConfig,
    ) {
        game::check_game_cap(game_cap, game_config);
        let coin_type = type_name::get<COIN>();
        if (vec_map::contains(&config.coin_prices, &coin_type)) {
            vec_map::remove(&mut config.coin_prices, &coin_type);

            event::emit(RemovePriceEvent {
                config: object::id(config),
                coin_type,
            });
        };
    }

    // user buy gacha
    public entry fun buy<COIN>(
        config: &mut ActivityConfig,
        paid: Coin<COIN>,
        amount: u64,
        clock: &Clock,
        profits: &mut ActivityProfits,
        ctx: &mut TxContext,
    ) {
        assert!(VERSION == profits.version, EIncorrectVersion);
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
        while (i < amount) {
            let gacha_ball = gacha::mint(
                config.token_type,
                config.collection,
                config.name,
                config.type,
                config.description,
                ctx,
            );

            transfer::public_transfer(gacha_ball, tx_context::sender(ctx));
            i = i + 1;
        };

        config.total_supply = config.total_supply + amount;
        // events
        event::emit(BuyEvent {
            config: object::id(config),
            coin_type,
            price,
            amount,
            token_type: config.token_type,
            total_supply: config.total_supply,
            max_supply: config.max_supply,
        });
    }

    fun pay<COIN>(profits: &mut ActivityProfits, total: u64, paid: Coin<COIN>, ctx: &mut TxContext) {
        let paid_value: u64 = balance::value(coin::balance(&paid));
        assert_payment_amount(total, paid_value);

        let coin_type = type_name::get<COIN>();
        if (total < paid_value) {
            transfer::public_transfer(coin::split(&mut paid, paid_value - total, ctx), tx_context::sender(ctx));
        };

        if (df::exists_with_type<TypeName, Balance<COIN>>(&profits.id, coin_type)) {
            let coin_balance = df::borrow_mut<TypeName, Balance<COIN>>(&mut profits.id, coin_type);
            balance::join<COIN>(coin_balance, coin::into_balance<COIN>(paid));
        } else {
            df::add<TypeName, Balance<COIN>>(&mut profits.id, coin_type, coin::into_balance<COIN>(paid));
        };
    }

    fun withdraw_activity_profits<COIN>(profits: &mut ActivityProfits, to:address, ctx: &mut TxContext){
        let coin_type = type_name::get<COIN>();
        let coin_balance = df::borrow_mut<TypeName, Balance<COIN>>(&mut profits.id, coin_type);
        let balance_all = balance::withdraw_all<COIN>(coin_balance);
        transfer::public_transfer(coin::from_balance<COIN>(balance_all, ctx), to);
    }

    public entry fun withdraw_activity_profits_request<COIN>(game_config: &GameConfig, multi_signature: &mut MultiSignature, to: address, ctx: &mut TxContext) {
        // Only multi sig guardian
        game::only_multi_sig_scope(multi_signature, game_config);
        // Only participant
        game::only_participant(multi_signature, ctx);

        let coin_type = type_name::get<COIN>();
        let request = WithdrawActivityProfitsRequest{
            id: object::new(ctx),
            coin_type,
            to
        };

        let desc = sui::address::to_string(object::id_address(&request));

        multisig::create_proposal(multi_signature, *string::bytes(&desc), WithdrawActivityProfits, request, ctx);
    }

    public entry fun withdraw_activity_profits_execute<COIN>(
        game_config: &GameConfig,
        multi_signature: &mut MultiSignature,
        proposal_id: u256,
        is_approve: bool,
        profits: &mut ActivityProfits,
        ctx: &mut TxContext): bool {

        assert!(VERSION == profits.version, EIncorrectVersion);
        game::only_multi_sig_scope(multi_signature, game_config);
        // Only participant
        game::only_participant(multi_signature, ctx);

        if (is_approve) {
            let (approved, _ ) = multisig::is_proposal_approved(multi_signature, proposal_id);
            if (approved) {
                let request = multisig::borrow_proposal_request<WithdrawActivityProfitsRequest>(multi_signature, &proposal_id, ctx);

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

    // package upgrade
    entry fun migrate(profits: &mut ActivityProfits, game_cap: &GameCap, game_config: &GameConfig) {
        assert!(profits.version < VERSION, ENotUpgrade);
        game::check_game_cap(game_cap, game_config);
        profits.version = VERSION;
    }
    // === Accessors ===
    public fun get_activity_profits<COIN>(profits: &ActivityProfits):u64 {
        let coin_type = type_name::get<COIN>();
        balance::value(df::borrow<TypeName, Balance<COIN>>(&profits.id, coin_type))
    }

    #[test_only]
    public fun init_for_test(ctx: &mut TxContext) {
        init(ctx);
    }
}
