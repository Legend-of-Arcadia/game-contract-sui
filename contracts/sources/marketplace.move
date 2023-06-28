module contracts::marketplace{

    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::dynamic_object_field as dof;
    use sui::event;
    use sui::table::{Self, Table};
    use sui::object::{Self, UID};
    // use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use std::option::{Self, Option};

    use contracts::arca::ARCA;
    use contracts::game::GameCap;
    use contracts::staking::{Self, StakingPool};

    // errors
    const EAmountNotExact: u64 = 0;
    const EPaymentNotExact: u64 = 1;
    const ENoListingFound: u64 = 2;
    const EIncorrectVipLevel: u64 = 3;
    const EVersionMismatch: u64 = 4;

    // constants

    const VERSION: u64 = 1;

    // Fees are constants for user assurance. These are percentages in basis points.
    // Constants can only be changed with a contract upgrade, which makes it more difficult
    // to change on a whim.
    const BASE_TRADING_FEE: u64 = 300; // 3%
    const TO_BURN_FEE: u64 = 3970; // This is 39.7% of the trading fee value
    const TEAM_FEE: u64 = 2000; // 20% of the trading fee
    const REWARDS_FEE: u64 = 4000; // 40% of the trading fee
    const REFERRER_FEE: u64 = 30; // 0.3% of the trading fee

    struct Marketplace has key, store {
        id: UID,
        main: Stand<ARCA>,
        vip_fees: Table<u64, u64>
    }

    // here we need key because we will add items dof
    // this maybe will be possible to change if we add them in table
    // TODO: see if we can remove key if other COINS will not be supported in the future
    struct Stand<phantom COIN> has key, store {
        id: UID,
        primary_listings: Table<u64, Listing_P>,
        secondary_listings: Table<u64, Listing>,
        income: Balance<COIN> // from primary sells
    }

    struct Listing_P has store {
        item_id: address,
        price: u64
    }
    

    struct Listing has store {
        item_id: address,
        price: u64,
        seller: address
    }

    // events
    struct NewSecodaryListing has copy, drop {
        seller: address,
        item_id: address,
        listing_key: u64
    }

    struct ItemBought has copy, drop {
        is_primary_listing: bool,
        buyer_vip_level: u64,
        buyer: address,
        seller: address,
        item_id: address,
        listing_key: u64
    }

    fun init(ctx: &mut TxContext) {
        // init only with arca coin
        let arca_stand = Stand<ARCA> {
            id: object::new(ctx),
            primary_listings: table::new<u64, Listing_P>(ctx),
            secondary_listings: table::new<u64, Listing>(ctx),
            income: balance::zero<ARCA>()
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
            vip_fees
        };
        transfer::public_share_object<Marketplace>(marketplace);
    }

    public fun edit_vip_fees(_: &GameCap, marketplace: &mut Marketplace, vip_level: u64, fee: u64) {
        assert!(VERSION == 1, EVersionMismatch);
        *table::borrow_mut<u64, u64>(&mut marketplace.vip_fees, vip_level) = fee;
    }

    public fun take_profits_arca(
        _: &GameCap,
        marketplace: &mut Marketplace,
        ctx: &mut TxContext
        ): Coin<ARCA> 
    {
        assert!(VERSION == 1, EVersionMismatch);
        let stand = &mut marketplace.main;
        let balance_all = balance::withdraw_all<ARCA>(&mut stand.income);
        coin::from_balance<ARCA>(balance_all, ctx)
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
        let key = table::length<u64, Listing_P>(&stand.primary_listings) + 1;
        table::add<u64, Listing_P>(&mut stand.primary_listings, key, listing);
        dof::add<address, Item>(&mut stand.id, item_id, item);
        // emit event
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
        let listing = Listing{
            item_id,
            price,
            seller: tx_context::sender(ctx)
        };
        let key = table::length<u64, Listing>(&stand.secondary_listings) + 1;
        table::add<u64, Listing>(&mut stand.secondary_listings, key, listing);
        dof::add<address, Item>(&mut stand.id, item_id, item);
        // emit event
        let evt = NewSecodaryListing {
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
        let size: u64 = table::length<u64, Listing_P>(&stand.primary_listings);
        if (size > listing_number) {
            let last_listing = table::remove<u64, Listing_P>(&mut stand.primary_listings, size);
            table::add<u64, Listing_P>(&mut stand.primary_listings, listing_number, last_listing);
        };
        balance::join<ARCA>(&mut stand.income, coin::into_balance<ARCA>(payment));
        // event
        let evt = ItemBought {
            is_primary_listing: true,
            buyer_vip_level: 0, // incosequential since no fees
            buyer: tx_context::sender(ctx),
            seller: @0x00, // Mugen is the seller
            item_id: item_id,
            listing_key: listing_number // now this is occupied by the last listing
        };
        event::emit(evt);
        // return item
        dof::remove<address, Item>(&mut stand.id, item_id)
    }

    public fun buy_secondary_arca<Item: key+store, COIN>(
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
        let Listing {item_id, price, seller} = listing;
        assert!(price == coin::value<ARCA>(&payment), EPaymentNotExact);
        // if it is not the last listing take the last and insert it in its place
        // make this one the last and remove it
        let size: u64 = table::length<u64, Listing>(&stand.secondary_listings);
        if (size > listing_number) {
            let last_listing = table::remove<u64, Listing>(&mut stand.secondary_listings, size);
            table::add<u64, Listing>(&mut stand.secondary_listings, listing_number, last_listing);
        };

        fee_distribution_arca(
            &mut payment, 
            referrer,
            BASE_TRADING_FEE,
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
        let Listing {item_id, price, seller} = listing;
        assert!(price == coin::value<ARCA>(&payment), EPaymentNotExact);
        // if it is not the last listing take the last and insert it in its place
        // make this one the last and remove it
        let size: u64 = table::length<u64, Listing>(&stand.secondary_listings);
        if (size > listing_number) {
            let last_listing = table::remove<u64, Listing>(&mut stand.secondary_listings, size);
            table::add<u64, Listing>(&mut stand.secondary_listings, listing_number, last_listing);
        };
        
        // get base_trading fee based on vip level
        let timestamp = clock::timestamp_ms(clock)/1000;
        let vip_level = staking::calc_vip_level(sp, tx_context::sender(ctx), timestamp);
        assert!(vip_level < 21, EIncorrectVipLevel);
        let base_fee = *table::borrow_mut<u64, u64>(&mut marketplace.vip_fees, vip_level);
        fee_distribution_arca(
            &mut payment, 
            referrer,
            base_fee,
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
            item_id: item_id,
            listing_key: listing_number // now this is occupied by the last listing
        };
        event::emit(evt);
        // return item
        dof::remove<address, Item>(&mut stand.id, item_id)
    }

    // TODO: for any Coin when LPs are available
    // public fun list_primary<Item: key+store, COIN>()
    // public fun list_secondary<Item: key+store, COIN>()
    // public fun buy_primary<Item: key+store, COIN>()
    // public fun buy_secondary<Item: key+store, COIN>()

    fun fee_distribution_arca(
        payment: &mut Coin<ARCA>,
        referrer: Option<address>,
        base_fee_per: u64,
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
        ) = fee_calculation(coin::value<ARCA>(payment), base_fee_per);
        let team = coin::split<ARCA>(payment, team_value, ctx);
        balance::join<ARCA>(&mut stand.income, coin::into_balance<ARCA>(team));
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

    fun fee_calculation(
        payment: u64,
        base_fee: u64,
    ): (u64, u64, u64, u64)
    {
        // first the divisions to not overflow
        let base_value: u64 = (payment / 10000) * base_fee;
        let to_burn_value: u64 = (base_value / 10000) * TO_BURN_FEE;
        let team_value: u64 = (base_value / 10000) * TEAM_FEE;
        let rewards_value: u64 = (base_value / 10000) * REWARDS_FEE;
        let referrer_value: u64 = (base_value / 10000) * REFERRER_FEE;

        (to_burn_value, team_value, rewards_value, referrer_value)
    }

    // TODO: When Liquidity pools for other coins are available
    // fun fee_distribution<COIN>

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}