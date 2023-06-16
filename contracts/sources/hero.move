module contracts::hero {

    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_field as df;
    // use sui::coin::Coin;
    use sui::event;
    use sui::transfer;
    use sui::display;
    use sui::package;

    use std::string::{Self, String};

    // use contracts::arca::ARCA;
    // use contracts::shop;

    // friend contracts::demo;
    friend contracts::game;

    // === Error Codes ===

    const ENotSameHeroRarity: u64 = 0;
    const EVectorLengthMismatch: u64 = 1;

    // === Dynamic Field keys ===

    struct BaseDynamicFieldKey has store, copy, drop {}

    struct SkillDynamicFieldKey has store, copy, drop {}

    struct AppearenceDynamicFieldKey has store, copy, drop {}

    struct StatDynamicFieldKey has store, copy, drop {}

    struct OthersDynamicFieldKey has store, copy, drop {}

    // One Time Witness
    struct HERO has drop {}
    

    struct Hero has key, store {
        id: UID,
        name: String,
        class: String,
        faction: String,
        rarity: String,
        external_id: String
    }

    struct HeroMinted has copy, drop {
        id: ID
    }

    struct HeroUpgraded has copy, drop {
        id: ID
    }

    struct HeroBurned has copy, drop {
        id: ID
    }

    fun init(otw: HERO, ctx: &mut TxContext) {
        let publisher = package::claim(otw, ctx);

        let keys = vector[
            string::utf8(b"name"),
            string::utf8(b"image_url"),
            string::utf8(b"link"),
            string::utf8(b"description"),
            string::utf8(b"project_url")
        ];

        let values = vector[
            string::utf8(b"Hero"),
            // string::utf8(b"https://legendofarcadia.io/heroes/images/{external_id}"),
            string::utf8(b"{external_id}"), // this is just for the demo
            string::utf8(b"https://legendofarcadia.io/heroes/{external_id}"),
            string::utf8(b"Heroes of Arcadia"),
            string::utf8(b"https://legendofarcadia.io")
        ];

        let display = display::new_with_fields<Hero>(&publisher, keys, values, ctx);

        display::update_version<Hero>(&mut display);

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));    
    }

    public(friend) fun mint_hero(
        name: String,
        class: String,
        faction: String,
        rarity: String,
        base_attributes_values: vector<String>,
        skill_attributes_values: vector<String>,
        appearence_attributes_values: vector<String>,
        stat_attributes_values: vector<u64>,
        // TODO: determine if this should be a string or a u64
        other_attributes_values: vector<String>,
        external_id: String,
        ctx: &mut TxContext
        ): Hero {
        
        let id = object::new(ctx);
        let hero = Hero{
            id, 
            name, 
            class, 
            faction, 
            rarity,
            external_id
        };

        df::add<BaseDynamicFieldKey, vector<String>>(&mut hero.id, BaseDynamicFieldKey {}, base_attributes_values);
        df::add<SkillDynamicFieldKey, vector<String>>(&mut hero.id, SkillDynamicFieldKey {}, skill_attributes_values);
        df::add<AppearenceDynamicFieldKey, vector<String>>(&mut hero.id, AppearenceDynamicFieldKey {}, appearence_attributes_values);
        df::add<StatDynamicFieldKey, vector<u64>>(&mut hero.id, StatDynamicFieldKey {}, stat_attributes_values);
        df::add<OthersDynamicFieldKey, vector<String>>(&mut hero.id, OthersDynamicFieldKey {}, other_attributes_values);

        event::emit(HeroMinted {id: object::uid_to_inner(&hero.id)});

        hero
    }

    fun edit_df(hero: &mut Hero, name: String, new_value: u64) {
        let value = df::borrow_mut<String, u64>(&mut hero.id, name);
        *value = new_value;
    }    

    public(friend) fun burn_hero(hero: Hero) {
        let Hero {id, name: _, class: _, faction: _, rarity: _, external_id: _} = hero;
        event::emit(HeroBurned {id: object::uid_to_inner(&id)});
        object::delete(id);
    }

    // Accessors
    public fun get_hero_id(hero: &mut Hero): &UID {
        &hero.id
    }

}