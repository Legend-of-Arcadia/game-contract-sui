module contracts::shop{

    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};

    const EAmountNotExact: u64 = 0;
    // const ENoProfits: u64 = 1;

    struct ShopAdmin has key {
        id: UID
    }

    struct Shop has key {
        id: UID,
        recipient: address,
    }

    fun init(ctx: &mut TxContext) {
        let cap = ShopAdmin {
            id: object::new(ctx),
        };
        transfer::transfer(cap, tx_context::sender(ctx));
        let shop = Shop {
            id: object::new(ctx),
            recipient: tx_context::sender(ctx)
        };
        transfer::share_object(shop);
    }

    public fun pay<T>(shop: &mut Shop, cost: u64, coin: Coin<T>){
        assert!(cost == coin::value(&coin), EAmountNotExact);

        transfer::public_transfer(coin, shop.recipient);
    }
}