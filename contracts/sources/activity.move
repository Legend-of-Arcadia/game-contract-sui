module contracts::activity {
    use std::type_name::{Self, TypeName};
    use sui::vec_map::{Self, VecMap};
    use std::string::{String};
    use sui::clock::{Self, Clock};
    use std::option;
    use std::vector;

    use sui::balance::{Self};
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::object::{Self, ID, UID};
    //use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use contracts::gacha::{Self};
    use contracts::game::GameCap;


    const EPaymentAmountInvalid: u64 = 0;
    const EOverflowMaxSupply: u64 = 1;
    const ECoinTypeNoExist: u64 = 2;
    const ECurrentTimeLTStartTime: u64 = 3;
    const ECurrentTimeGEEndTime: u64 = 4;
    const EPriceEQZero: u64 = 5;

    struct ActivityConfig has key, store {
        id: UID,
        start_time: u64,
        end_time: u64,
        max_supply: u64,
        total_supply: u64,
        finance_address: address,
        coin_prices: VecMap<TypeName, u64>,
        token_type: u64,
        name: String,
        type: String,
        collection: String,
        description: String,
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

    public entry fun create_config(
        _: &GameCap,
        start_time: u64,
        end_time: u64,
        max_supply: u64,
        finance_address: address,
        token_type: u64,
        name: String,
        type: String,
        collection: String,
        description: String,
        ctx: &mut TxContext,
    ) {
        let config = ActivityConfig {
            id: object::new(ctx),
            start_time,
            end_time,
            max_supply,
            total_supply: 0,
            finance_address,
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
            max_supply: _, total_supply:_, finance_address:_,
            coin_prices:_, token_type:_, name:_, type:_, collection:_, description: _} = config;

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
        pay(config, total, paid, ctx);
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

    fun pay<COIN>(config: &mut ActivityConfig, total: u64, paid: Coin<COIN>, ctx: &mut TxContext) {
        let paid_value: u64 = balance::value(coin::balance(&paid));
        assert_payment_amount(total, paid_value);
        if (total == paid_value) {
            transfer::public_transfer(paid, config.finance_address);
        } else {
            transfer::public_transfer(coin::split(&mut paid, total, ctx), config.finance_address);
            transfer::public_transfer(paid, tx_context::sender(ctx));
        };
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
        assert!(total <= paid_value, EPaymentAmountInvalid)
    }
}