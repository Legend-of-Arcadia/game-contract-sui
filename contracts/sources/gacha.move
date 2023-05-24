module contracts::gacha{

    use sui::object::{Self, ID, UID};
    use sui::tx_context::TxContext;
    use sui::event;
    
    use std::string::String;

    struct GachaBall<phantom T, phantom C> has key, store {
        id: UID,
        collection: String,
        name: String,
        initial_price: u64,
    }

    struct GachaBallMinted has copy, drop {
        id: ID
    }

    struct GachaBallBurned has copy, drop {
        id: ID
    }

    public(friend) fun mint<T, C>(
        collection: String,
        name: String,
        initial_price: u64,
        ctx: &mut TxContext
    ): GachaBall<T, C> {
        let id = object::new(ctx);

        let new_ball = GachaBall<T, C> {
            id, 
            collection,
            name,
            initial_price
        };

        event::emit(GachaBallMinted {id: object::uid_to_inner(&new_ball.id)});

        new_ball
    }

    public(friend) fun burn<T, C> (gacha_ball: GachaBall<T, C>) {
        let GachaBall<T, C> {id, collection: _, name: _, initial_price: _} = gacha_ball;
        event::emit(GachaBallBurned {id: object::uid_to_inner(&id)});
        object::delete(id);
    }


}