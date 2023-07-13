module contracts::gacha{

    use sui::display;
    use sui::object::{Self, ID, UID};
    use sui::package;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    
    use std::string::{Self, String};

    friend contracts::game;
    friend contracts::activity;

    // one-time witness
    struct GACHA has drop {}

    struct GachaBall has key, store {
        id: UID,
        token_type: u64,
        collection: String,
        name: String,
        type: String,
        description: String
    }

    struct GachaBallMinted has copy, drop {
        id: ID
    }

    struct GachaBallBurned has copy, drop {
        id: ID
    }

    fun init(otw: GACHA, ctx: &mut TxContext){

        // claim publisher
        let publisher = package::claim(otw, ctx);

        // make display
        let keys = vector[
            string::utf8(b"collection"),
            string::utf8(b"name"),
            string::utf8(b"image_url"),
            string::utf8(b"description"),
            string::utf8(b"type"),
            string::utf8(b"project_url"),
        ];

        let values = vector[
            string::utf8(b"{collection}"),
            string::utf8(b"{name}"),
            // link empty right now
            // one example of a link is b"{example.com/{type}"
            string::utf8(b"https://lh3.googleusercontent.com/pw/AJFCJaVqjr41iECxSNLZ2POCLVwRuKPu5UE0MrCCGMCclzg9ssDjNqeCpPSYIWzryjLKRRGPD70_iVpo9m71wEWPssYU4DeL7BgZlAsofiFo9bqYtxcQqQ=w113-h86-no"),
            string::utf8(b"{description}"),
            string::utf8(b"{type}"),
            string::utf8(b"https://legendofarcadia.io"),
        ];

        let display = display::new_with_fields<GachaBall>(&publisher, keys, values, ctx);
        display::update_version<GachaBall>(&mut display);

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx)); 
    }

    public(friend) fun mint(
        token_type: u64,
        collection: String,
        name: String,
        type: String,
        description: String,
        ctx: &mut TxContext
    ): GachaBall {
        let id = object::new(ctx);

        let new_ball = GachaBall {
            id,
            token_type,
            collection,
            name,
            type,
            description,
        };

        event::emit(GachaBallMinted {id: object::uid_to_inner(&new_ball.id)});

        new_ball
    }

    public(friend) fun burn(gacha_ball: GachaBall) {
        let GachaBall {id, token_type: _, collection: _, name: _, type: _, description: _} = gacha_ball;
        event::emit(GachaBallBurned {id: object::uid_to_inner(&id)});
        object::delete(id);
    }

    public(friend) fun id(gacha_ball: &GachaBall): ID {
        object::uid_to_inner(&gacha_ball.id)
    }

    // === Accessors ===

    public fun collection(gacha_ball: &GachaBall): &String {
        &gacha_ball.collection
    }

    public fun name(gacha_ball: &GachaBall): &String {
        &gacha_ball.name
    }

    public fun type(gacha_ball: &GachaBall): &String {
        &gacha_ball.type
    }

    public fun tokenType(gacha_ball: &GachaBall): &u64 {
        &gacha_ball.token_type
    }

}