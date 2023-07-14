module contracts::item{

    use sui::display;
    use sui::object::{Self, ID, UID};
    use sui::package;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;

    use std::string::{Self, String};

    friend contracts::game;

    // one-time witness
    struct ITEM has drop {}

    struct Item has key, store {
        id: UID,
        token_type: u64,
        collection: String,
        name: String,
        type: String,
        description: String,
    }

    struct ItemMinted has copy, drop {
        id: ID,
        token_type: u64
    }

    struct ItemBurned has copy, drop {
        id: ID
    }

    fun init(otw: ITEM, ctx: &mut TxContext){

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
            string::utf8(b"https://legendofarcadia.io/items/images/{token_type}"),
            string::utf8(b"{description}"),
            string::utf8(b"{type}"),
            string::utf8(b"{https://legendofarcadia.io}"),
        ];

        let display = display::new_with_fields<Item>(&publisher, keys, values, ctx);
        display::update_version<Item>(&mut display);

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
    ): Item {
        let id = object::new(ctx);

        let new_item = Item {
            id,
            token_type,
            collection,
            name,
            type,
            description,
        };

        event::emit(ItemMinted {id: object::uid_to_inner(&new_item.id),token_type});

        new_item
    }

    public(friend) fun burn(item: Item) {
        let Item {id, token_type: _, collection: _, name: _, type: _, description: _} = item;
        event::emit(ItemBurned {id: object::uid_to_inner(&id)});
        object::delete(id);
    }

    public(friend) fun id(gacha_ball: &Item): ID {
        object::uid_to_inner(&gacha_ball.id)
    }

    // === Accessors ===

    public fun collection(item: &Item): &String {
        &item.collection
    }

    public fun name(item: &Item): &String {
        &item.name
    }

    public fun type(item: &Item): &String {
        &item.type
    }

}