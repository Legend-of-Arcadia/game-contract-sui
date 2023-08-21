module loa_facilities::marketplace{

    use sui::balance::{Self, Balance};
    use sui::clock::{Clock};
    use sui::coin::{Self, Coin};
    use sui::dynamic_object_field as dof;
    use sui::dynamic_field as df;
    use sui::event;
    use sui::table::{Self, Table};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use std::option::{Self, Option};
    use std::type_name::{Self, TypeName};
    use std::string;
    use std::debug;

    use loa::arca::ARCA;
    use loa_game::game::{Self, GameCap, GameConfig};
    use loa_facilities::staking::{Self, StakingPool};
    use multisig::multisig::{Self, MultiSignature};

    // errors
    const EAmountNotExact: u64 = 0;
    const EPaymentNotExact: u64 = 1;
    const ENoListingFound: u64 = 2;
    const EIncorrectVipLevel: u64 = 3;
    const EVersionMismatch: u64 = 4;
    const EPaymentMismatch: u64 = 5;
    const ENoItemSeller: u64 = 6;
    const EVipLvNoExsit: u64 = 7;
    const ECoinTypeMismatch: u64 = 8;
    const ENeedVote: u64 = 9;
    const EFeeSet: u64 = 10;

    const WithdrawFeeProfits: u64 = 5;

    // constants

    const VERSION: u64 = 1;

    // Fees are constants for user assurance. These are percentages in basis points.
    // Constants can only be changed with a contract upgrade, which makes it more difficult
    // to change on a whim.

    struct Marketplace has key, store {
        id: UID,
        main: Stand<ARCA>,
        vip_fees: Table<u64, u64>,
        base_trading_fee: u64,
        to_burn_fee: u64,
        team_fee: u64,
        rewards_fee: u64,
        referrer_fee: u64
    }

    // here we need key because we will add items dof
    // this maybe will be possible to change if we add them in table
    // TODO: see if we can remove key if other COINS will not be supported in the future
    struct Stand<phantom COIN> has key, store {
        id: UID,
        primary_listings: Table<u64, Listing_P>,
        secondary_listings: Table<u64, Listing>,
        //income: Balance<COIN>, // from primary sells
        primary_list_index: u64,
        secondary_list_index: u64
    }

    struct Listing_P has store {
        item_id: address,
        price: u64
    }
    

    struct Listing has store {
        coin_type: TypeName,
        item_id: address,
        price: u64,
        seller: address
    }

    struct WithdrawFeeProfitsRequest has key, store {
        id: UID,
        coin_type: TypeName,
        to: address
    }
    // events
    struct NewSecondaryListing has copy, drop {
        coin_type: TypeName,
        price: u64,
        seller: address,
        item_id: address,
        listing_key: u64
    }

    struct NewPrimaryListing has copy, drop {
        coin_type: TypeName,
        price: u64,
        item_id: address,
        listing_key: u64
    }

    struct ItemBought has copy, drop {
        is_primary_listing: bool,
        buyer_vip_level: u64,
        buyer: address,
        seller: address,
        coin_type: TypeName,
        item_id: address,
        listing_key: u64
    }

    struct ItemTake has copy, drop {
        seller: address,
        item_id: address,
        listing_key: u64
    }

    struct VipFeeUpdate has copy, drop {
        vip_level: u64,
        fee: u64
    }

    struct VipFeeRemove has copy, drop {
        vip_level: u64
    }

    struct TradingFeeUpdate has copy, drop {
        new_base_fee: u64,
        new_to_burn_fee: u64,
        new_team_fee: u64,
        new_rewards_fee: u64,
        new_referrer_fee: u64
    }

    fun init(ctx: &mut TxContext) {
        // init only with arca coin
        let arca_stand = Stand<ARCA> {
            id: object::new(ctx),
            primary_listings: table::new<u64, Listing_P>(ctx),
            secondary_listings: table::new<u64, Listing>(ctx),
            //income: balance::zero<ARCA>(),
            primary_list_index: 0,
            secondary_list_index: 0
        };

        let vip_fees = table::new<u64, u64>(ctx);
        table::add<u64, u64>(&mut vip_fees, 0, 300);
        table::add<u64, u64>(&mut vip_fees, 1, 300);
        table::add<u64, u64>(&mut vip_fees, 2, 300);
        table::add<u64, u64>(&mut vip_fees, 3, 300);
        table::add<u64, u64>(&mut vip_fees, 4, 284);
        table::add<u64, u64>(&mut vip_fees, 5, 268);
        table::add<u64, u64>(&mut vip_fees, 6, 252);
        table::add<u64, u64>(&mut vip_fees, 7, 236);
        table::add<u64, u64>(&mut vip_fees, 8, 221);
        table::add<u64, u64>(&mut vip_fees, 9, 205);
        table::add<u64, u64>(&mut vip_fees, 10, 189);
        table::add<u64, u64>(&mut vip_fees, 11, 173);
        table::add<u64, u64>(&mut vip_fees, 12, 157);
        table::add<u64, u64>(&mut vip_fees, 13, 141);
        table::add<u64, u64>(&mut vip_fees, 14, 125);
        table::add<u64, u64>(&mut vip_fees, 15, 109);
        table::add<u64, u64>(&mut vip_fees, 16, 94);
        table::add<u64, u64>(&mut vip_fees, 17, 78);
        table::add<u64, u64>(&mut vip_fees, 18, 62);
        table::add<u64, u64>(&mut vip_fees, 19, 46);
        table::add<u64, u64>(&mut vip_fees, 20, 30);

        let marketplace = Marketplace {
            id: object::new(ctx),
            main: arca_stand,
            vip_fees,
            base_trading_fee: 300,
            to_burn_fee: 0,
            team_fee: 10000,
            rewards_fee: 0,
            referrer_fee: 0
        };
        transfer::public_share_object<Marketplace>(marketplace);
    }

    // add or update vip fee
    public fun update_vip_fees(_: &GameCap, marketplace: &mut Marketplace, vip_level: u64, fee: u64) {
        assert!(VERSION == 1, EVersionMismatch);

        if (table::contains(&mut marketplace.vip_fees, vip_level)) {
            *table::borrow_mut<u64, u64>(&mut marketplace.vip_fees, vip_level) = fee;
        } else {
            table::add(&mut marketplace.vip_fees, vip_level, fee);
        };

        let evt = VipFeeUpdate {
            vip_level,
            fee
        };
        event::emit(evt);
    }


    public fun remove_vip_fees(_: &GameCap, marketplace: &mut Marketplace, vip_level: u64) {
        assert!(VERSION == 1, EVersionMismatch);
        assert!(table::contains(&mut marketplace.vip_fees, vip_level), EVipLvNoExsit);
        table::remove(&mut marketplace.vip_fees, vip_level);

        let evt = VipFeeRemove {
            vip_level
        };
        event::emit(evt);
    }


    public fun update_trading_fee(
        _: &GameCap,
        marketplace: &mut Marketplace,
        new_base_fee: u64,
        new_to_burn_fee: u64,
        new_team_fee: u64,
        new_rewards_fee: u64,
        new_referrer_fee: u64) {
        assert!(VERSION == 1, EVersionMismatch);
        assert!(new_base_fee <= 10000, EFeeSet);
        assert!(new_to_burn_fee + new_team_fee + new_rewards_fee + new_referrer_fee == 10000, EFeeSet);

        marketplace.base_trading_fee = new_base_fee;
        marketplace.to_burn_fee = new_to_burn_fee;
        marketplace.team_fee = new_team_fee;
        marketplace.rewards_fee = new_rewards_fee;
        marketplace.referrer_fee = new_referrer_fee;

        let evt = TradingFeeUpdate {
            new_base_fee,
            new_to_burn_fee,
            new_team_fee,
            new_rewards_fee,
            new_referrer_fee
        };
        event::emit(evt);
    }

    public fun list_primary_arca<Item: key+store>(
        _: &GameCap,
        marketplace: &mut Marketplace,
        item: Item,
        price: u64
    )
    {
        assert!(VERSION == 1, EVersionMismatch);
        let stand = &mut marketplace.main;
        let item_id = object::id_address(&item);
        let listing = Listing_P {
            item_id,
            price
        };
        stand.primary_list_index = stand.primary_list_index + 1;
        let key = stand.primary_list_index;
        table::add<u64, Listing_P>(&mut stand.primary_listings, key, listing);
        dof::add<address, Item>(&mut stand.id, item_id, item);
        // emit event

        let evt = NewPrimaryListing {
            coin_type: type_name::get<ARCA>(),
            price,
            item_id,
            listing_key: key
        };
        event::emit(evt);
    }

    // any type of NFT can be listed by anyone
    public fun list_secondary_arca<Item: key+store>(
        marketplace: &mut Marketplace,
        item: Item,
        price: u64,
        ctx: &mut TxContext
    )
    {
        assert!(VERSION == 1, EVersionMismatch);
        let stand = &mut marketplace.main;
        let item_id: address = object::id_address(&item);
        let coin_type = type_name::get<ARCA>();
        let listing = Listing{
            coin_type,
            item_id,
            price,
            seller: tx_context::sender(ctx)
        };
        stand.secondary_list_index = stand.secondary_list_index + 1;
        let key = stand.secondary_list_index;
        table::add<u64, Listing>(&mut stand.secondary_listings, key, listing);
        dof::add<address, Item>(&mut stand.id, item_id, item);
        // emit event
        let evt = NewSecondaryListing {
            coin_type,
            price,
            seller: tx_context::sender(ctx),
            item_id,
            listing_key: key
        };
        event::emit(evt);
    }

    public fun buy_primary_arca<Item: key+store>(
        payment: Coin<ARCA>,
        marketplace: &mut Marketplace,
        listing_number: u64,
        ctx: &mut TxContext
    ): Item
    {
        assert!(VERSION == 1, EVersionMismatch);
        let stand = &mut marketplace.main;
        assert!(table::contains<u64, Listing_P>(&stand.primary_listings, listing_number), ENoListingFound);
        let listing = table::remove<u64, Listing_P>(&mut stand.primary_listings, listing_number);
        let Listing_P {item_id, price} = listing;
        assert!(price == coin::value<ARCA>(&payment), EPaymentNotExact);

        put_coin<ARCA>(stand, payment);
        // event
        let evt = ItemBought {
            is_primary_listing: true,
            buyer_vip_level: 0, // incosequential since no fees
            buyer: tx_context::sender(ctx),
            seller: @0x00, // Mugen is the seller
            coin_type: type_name::get<ARCA>(),
            item_id: item_id,
            listing_key: listing_number // now this is occupied by the last listing
        };
        event::emit(evt);
        // return item
        dof::remove<address, Item>(&mut stand.id, item_id)
    }

    public fun buy_secondary_arca<Item: key+store>(
        payment: Coin<ARCA>,
        listing_number: u64,
        referrer: Option<address>,
        marketplace: &mut Marketplace,
        sp: &mut StakingPool,
        ctx: &mut TxContext): Item 
    {
        assert!(VERSION == 1, EVersionMismatch);
        let stand = &mut marketplace.main;
        assert!(table::contains<u64, Listing>(&stand.secondary_listings, listing_number), ENoListingFound);
        let listing = table::remove<u64, Listing>(&mut stand.secondary_listings, listing_number);
        let Listing {coin_type, item_id, price, seller} = listing;
        assert!(coin_type == type_name::get<ARCA>(), EPaymentMismatch);
        assert!(price == coin::value<ARCA>(&payment), EPaymentNotExact);

        fee_distribution_arca(
            &mut payment, 
            referrer,
            marketplace.base_trading_fee,
            marketplace.to_burn_fee,
            marketplace.team_fee,
            marketplace.rewards_fee,
            marketplace.referrer_fee,
            stand,
            sp,
            ctx
        );
        
        transfer::public_transfer(payment, seller);
        // event
        let evt = ItemBought {
            is_primary_listing: false,
            buyer_vip_level: 0, // no vip
            buyer: tx_context::sender(ctx),
            seller,
            coin_type: type_name::get<ARCA>(),
            item_id: item_id,
            listing_key: listing_number // now this is occupied by the last listing
        };
        event::emit(evt);
        // return item
        dof::remove<address, Item>(&mut stand.id, item_id)
    }

    public fun buy_secondary_vip_arca<Item: key+store>(
        payment: Coin<ARCA>,
        listing_number: u64,
        referrer: Option<address>,
        marketplace: &mut Marketplace,
        sp: &mut StakingPool,
        clock: &Clock,
        ctx: &mut TxContext): Item 
    {
        assert!(VERSION == 1, EVersionMismatch);
        let stand = &mut marketplace.main;
        assert!(table::contains<u64, Listing>(&stand.secondary_listings, listing_number), ENoListingFound);
        let listing = table::remove<u64, Listing>(&mut stand.secondary_listings, listing_number);
        let Listing {coin_type, item_id, price, seller} = listing;
        assert!(coin_type == type_name::get<ARCA>(), EPaymentMismatch);
        assert!(price == coin::value<ARCA>(&payment), EPaymentNotExact);
        
        // get base_trading fee based on vip level
        let vip_level = staking::calc_vip_level(sp, seller, clock);
        //assert!(vip_level < 21, EIncorrectVipLevel);
        let base_fee = *table::borrow_mut<u64, u64>(&mut marketplace.vip_fees, vip_level);
        fee_distribution_arca(
            &mut payment, 
            referrer,
            base_fee,
            marketplace.to_burn_fee,
            marketplace.team_fee,
            marketplace.rewards_fee,
            marketplace.referrer_fee,
            stand,
            sp,
            ctx
        );
        
        transfer::public_transfer(payment, seller);
        // event
        let evt = ItemBought {
            is_primary_listing: false,
            buyer_vip_level: vip_level,
            buyer: tx_context::sender(ctx),
            seller: seller,
            coin_type,
            item_id: item_id,
            listing_key: listing_number // now this is occupied by the last listing
        };
        event::emit(evt);
        // return item
        dof::remove<address, Item>(&mut stand.id, item_id)
    }

    // TODO: for any Coin when LPs are available
    // public fun list_primary<Item: key+store, COIN>()
    // public fun buy_primary<Item: key+store, COIN>()
    public fun list_secondary<Item: key+store, COIN>(
        marketplace: &mut Marketplace,
        item: Item,
        price: u64,
        ctx: &mut TxContext
    ) {
        assert!(VERSION == 1, EVersionMismatch);
        let stand = &mut marketplace.main;
        let item_id: address = object::id_address(&item);
        let coin_type = type_name::get<COIN>();
        let listing = Listing{
            coin_type,
            item_id,
            price,
            seller: tx_context::sender(ctx)
        };
        stand.secondary_list_index = stand.secondary_list_index + 1;
        let key = stand.secondary_list_index;
        table::add<u64, Listing>(&mut stand.secondary_listings, key, listing);
        dof::add<address, Item>(&mut stand.id, item_id, item);
        // emit event
        let evt = NewSecondaryListing {
            coin_type,
            price,
            seller: tx_context::sender(ctx),
            item_id,
            listing_key: key
        };
        event::emit(evt);
    }

    public fun buy_secondary<Item: key+store, COIN>(
        payment: Coin<COIN>,
        listing_number: u64,
        marketplace: &mut Marketplace,
        ctx: &mut TxContext
    ): Item {
        assert!(VERSION == 1, EVersionMismatch);
        let stand = &mut marketplace.main;
        assert!(table::contains<u64, Listing>(&stand.secondary_listings, listing_number), ENoListingFound);
        let listing = table::remove<u64, Listing>(&mut stand.secondary_listings, listing_number);
        let Listing {coin_type, item_id, price, seller} = listing;
        assert!(coin_type == type_name::get<COIN>(), EPaymentMismatch);
        assert!(price == coin::value<COIN>(&payment), EPaymentNotExact);

        fee_distribution(
            &mut payment,
            marketplace.base_trading_fee,
            stand,
            ctx
        );

        transfer::public_transfer(payment, seller);
        // event
        let evt = ItemBought {
            is_primary_listing: false,
            buyer_vip_level: 0, // no vip
            buyer: tx_context::sender(ctx),
            seller,
            coin_type,
            item_id: item_id,
            listing_key: listing_number // now this is occupied by the last listing
        };
        event::emit(evt);
        // return item
        dof::remove<address, Item>(&mut stand.id, item_id)
    }

    public fun buy_secondary_vip<Item: key+store, COIN>(
        payment: Coin<COIN>,
        listing_number: u64,
        marketplace: &mut Marketplace,
        sp: &mut StakingPool,
        clock: &Clock,
        ctx: &mut TxContext): Item
    {
        assert!(VERSION == 1, EVersionMismatch);
        let stand = &mut marketplace.main;
        assert!(table::contains<u64, Listing>(&stand.secondary_listings, listing_number), ENoListingFound);
        let listing = table::remove<u64, Listing>(&mut stand.secondary_listings, listing_number);
        let Listing {coin_type, item_id, price, seller} = listing;
        assert!(coin_type == type_name::get<COIN>(), EPaymentMismatch);
        assert!(price == coin::value<COIN>(&payment), EPaymentNotExact);

        // get base_trading fee based on vip level
        let vip_level = staking::calc_vip_level(sp, seller, clock);
        //assert!(vip_level < 21, EIncorrectVipLevel);
        let base_fee = *table::borrow_mut<u64, u64>(&mut marketplace.vip_fees, vip_level);
        fee_distribution(
            &mut payment,
            base_fee,
            stand,
            ctx
        );

        transfer::public_transfer(payment, seller);
        // event
        let evt = ItemBought {
            is_primary_listing: false,
            buyer_vip_level: vip_level,
            buyer: tx_context::sender(ctx),
            seller: seller,
            coin_type,
            item_id: item_id,
            listing_key: listing_number // now this is occupied by the last listing
        };
        event::emit(evt);
        // return item
        dof::remove<address, Item>(&mut stand.id, item_id)
    }


    fun fee_distribution_arca(
        payment: &mut Coin<ARCA>,
        referrer: Option<address>,
        base_trading_fee: u64,
        to_burn_fee: u64,
        team_fee: u64,
        rewards_fee: u64,
        referrer_fee: u64,
        stand: &mut Stand<ARCA>,
        sp: &mut StakingPool,
        ctx: &mut TxContext
    )
    {
        let (
            to_burn_value,
            team_value,
            rewards_value,
            referrer_value
        ) = fee_calculation(coin::value<ARCA>(payment), base_trading_fee, to_burn_fee, team_fee, rewards_fee, referrer_fee);
        let team = coin::split<ARCA>(payment, team_value, ctx);
        put_coin<ARCA>(stand, team);
        //balance::join<ARCA>(&mut stand.income, coin::into_balance<ARCA>(team));
        let rewards = coin::split<ARCA>(payment, rewards_value, ctx);
        staking::marketplace_add_rewards(sp, rewards);
        if (option::is_some<address>(&referrer))
        {
            let referrer_coin = coin::split<ARCA>(payment, referrer_value, ctx);
            transfer::public_transfer(referrer_coin, option::extract<address>(&mut referrer));
            let to_burn = coin::split<ARCA>(payment, to_burn_value, ctx);
            staking::marketplace_add_to_burn(sp, to_burn);
        } else {
            let to_burn = coin::split<ARCA>(payment, to_burn_value + referrer_value, ctx);
            staking::marketplace_add_to_burn(sp, to_burn);
        };
    }

    // fun fee_calculation(
    //     payment: u64,
    //     base_trading_fee: u64,
    //     to_burn_fee: u64,
    //     team_fee: u64,
    //     rewards_fee: u64,
    //     referrer_fee: u64
    // ): (u64, u64, u64, u64)
    // {
    //     // first the divisions to not overflow
    //     let base_value: u64 = (payment / 10000) * base_trading_fee;
    //     let to_burn_value: u64 = (base_value / 10000) * to_burn_fee;
    //     let team_value: u64 = (base_value / 10000) * team_fee;
    //     let rewards_value: u64 = (base_value / 10000) * rewards_fee;
    //     let referrer_value: u64 = (base_value / 10000) * referrer_fee;
    //
    //     (to_burn_value, team_value, rewards_value, referrer_value)
    // }

    fun fee_calculation(
        payment: u64,
        base_trading_fee: u64,
        to_burn_fee: u64,
        team_fee: u64,
        rewards_fee: u64,
        referrer_fee: u64
    ): (u64, u64, u64, u64)
    {
        let base_value: u128 = ((payment as u128) * (base_trading_fee as u128)) / 10000;
        let to_burn_value: u64 = (((base_value * (to_burn_fee as u128)) / 10000) as u64);
        let team_value: u64 = (((base_value * (team_fee as u128)) / 10000) as u64);
        let rewards_value: u64 = (((base_value * (rewards_fee as u128)) / 10000) as u64);
        let referrer_value: u64 = (((base_value * (referrer_fee as u128)) / 10000) as u64);
        (to_burn_value, team_value, rewards_value, referrer_value)
    }


    fun fee_distribution<COIN>(
        payment: &mut Coin<COIN>,
        base_fee_per: u64,
        stand: &mut Stand<ARCA>,
        ctx: &mut TxContext
    )
    {
        let base_value: u64 = (coin::value<COIN>(payment) / 10000) * base_fee_per;
        let fee = coin::split<COIN>(payment, base_value, ctx);
        put_coin<COIN>(stand, fee);
    }

    fun withdraw_fee_profits<COIN>(marketplace: &mut Marketplace, to: address,ctx: &mut TxContext){
        let stand = &mut marketplace.main;
        let coin_type = type_name::get<COIN>();
        let coin_balance = df::borrow_mut<TypeName, Balance<COIN>>(&mut stand.id, coin_type);
        let balance_all = balance::withdraw_all<COIN>(coin_balance);
        transfer::public_transfer(coin::from_balance<COIN>(balance_all, ctx), to);
    }

    public fun withdraw_fee_profits_request<COIN>(game_config:&mut GameConfig, multi_signature : &mut MultiSignature, to: address, ctx: &mut TxContext) {
        // Only multi sig guardian
        game::only_multi_sig_scope(multi_signature, game_config);
        // Only participant
        game::only_participant(multi_signature, ctx);

        let coin_type = type_name::get<COIN>();
        let request = WithdrawFeeProfitsRequest{
            id: object::new(ctx),
            coin_type,
            to
        };

        let desc = sui::address::to_string(object::id_address(&request));

        multisig::create_proposal(multi_signature, *string::bytes(&desc), WithdrawFeeProfits, request, ctx);
    }

    public fun withdraw_fee_profits_execute<COIN>(
        game_config:&mut GameConfig,
        multi_signature : &mut MultiSignature,
        proposal_id: u256,
        is_approve: bool,
        marketplace: &mut Marketplace,
        ctx: &mut TxContext): bool {

        game::only_multi_sig_scope(multi_signature, game_config);
        // Only participant
        game::only_participant(multi_signature, ctx);

        if (is_approve) {
            let (approved, _ ) = multisig::is_proposal_approved(multi_signature, proposal_id);
            if (approved) {
                let request = multisig::borrow_proposal_request<WithdrawFeeProfitsRequest>(multi_signature, &proposal_id, ctx);

                assert!(request.coin_type == type_name::get<COIN>(), ECoinTypeMismatch);
                withdraw_fee_profits<COIN>(marketplace, request.to, ctx);
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

    fun put_coin<COIN>(stand: &mut Stand<ARCA>, coin: Coin<COIN>,) {
        let coin_type = type_name::get<COIN>();

        if (df::exists_with_type<TypeName, Balance<COIN>>(&mut stand.id, coin_type)) {
            let coin_balance = df::borrow_mut<TypeName, Balance<COIN>>(&mut stand.id, coin_type);
            balance::join<COIN>(coin_balance, coin::into_balance<COIN>(coin));
        } else {
            df::add<TypeName, Balance<COIN>>(&mut stand.id, coin_type, coin::into_balance<COIN>(coin));
        };
    }

    public fun take_item<Item: key+store>(listing_number: u64, marketplace: &mut Marketplace, ctx: &mut TxContext): Item {
        assert!(VERSION == 1, EVersionMismatch);
        let stand = &mut marketplace.main;
        assert!(table::contains<u64, Listing>(&stand.secondary_listings, listing_number), ENoListingFound);
        let listing = table::remove<u64, Listing>(&mut stand.secondary_listings, listing_number);
        let Listing {coin_type: _, item_id, price: _, seller} = listing;
        assert!(seller == tx_context::sender(ctx), ENoItemSeller);

        // event
        let evt = ItemTake {
            seller,
            item_id,
            listing_key: listing_number // now this is occupied by the last listing
        };
        event::emit(evt);

        // return item
        dof::remove<address, Item>(&mut stand.id, item_id)
    }

    // === Accessors ===
    public fun get_fee_profits<COIN>(marketplace: &Marketplace):u64 {
        let coin_type = type_name::get<COIN>();
        balance::value(df::borrow<TypeName, Balance<COIN>>(&marketplace.main.id, coin_type))
    }

    public fun get_vip_fee(marketplace: &Marketplace, key: u64):u64 {
        *table::borrow(&marketplace.vip_fees, key)
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    // #[test]
    // public fun test_precision_loss() {
    //     let payment: u64 = 12345;
    //     let base_trading_fee: u64 = 1234;
    //     let to_burn_fee: u64 = 567;
    //     let team_fee: u64 = 890;
    //     let rewards_fee: u64 = 123;
    //     let referrer_fee: u64 = 456;
    //     let (original_to_burn_value, _original_team_value,
    //         _original_rewards_value, _original_referrer_value) =
    //         fee_calculation(payment, base_trading_fee, to_burn_fee, team_fee,
    //             rewards_fee, referrer_fee);
    //     let (revised_to_burn_value, _revised_team_value,
    //         _revised_rewards_value, _revised_referrer_value) =
    //         revised_fee_calculation(payment, base_trading_fee, to_burn_fee,
    //             team_fee, rewards_fee, referrer_fee);
    //     // Print the results
    //     debug::print(&original_to_burn_value);
    //     debug::print(&revised_to_burn_value);
    //     // Assert that the results are different
    //     assert!(original_to_burn_value != revised_to_burn_value, 101);
    // }

    #[test]
    public fun test_fee_calculation_overflow() {
        let payment : u64 = 18446744073709551615; // the max value of u64
        let base_trading_fee: u64 = 10_000; // the max value we can take as 10_000/10_000 = 1
        let to_burn_fee: u64 = 10_000; // do not take this number seriously since it's only for overflow test
        let team_fee: u64 = 0;
        let rewards_fee: u64 = 0;
        let referrer_fee: u64 = 0;
        // if overflow then it will just abort
        let (revised_to_burn_value, _revised_team_value,
        _revised_rewards_value, _revised_referrer_value) =
        fee_calculation(payment, base_trading_fee, to_burn_fee,
        team_fee, rewards_fee, referrer_fee);
        debug::print(&revised_to_burn_value);
    }
}