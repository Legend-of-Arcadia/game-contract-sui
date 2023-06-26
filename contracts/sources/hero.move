module contracts::hero {

    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_field as df;
    use sui::transfer;
    use sui::display;
    use sui::package;

    use std::string::{Self, String};

    friend contracts::game;

    #[test_only]
    friend contracts::unit_tests;

    // === Error Codes ===

    const ENotSameHeroRarity: u64 = 0;
    const EVectorLengthMismatch: u64 = 1;

    // One Time Witness
    struct HERO has drop {}
    

    struct Hero has key, store {
        id: UID,
        name: String,
        class: String,
        faction: String,
        rarity: String,
        external_id: String, // should we keep this
        pending_upgrade: u64 //heroes burned
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
            string::utf8(b"https://legendofarcadia.io/heroes/images/{external_id}"),
            string::utf8(b"https://legendofarcadia.io/heroes/{external_id}"),
            string::utf8(b"Heroes of Arcadia"),
            string::utf8(b"https://legendofarcadia.io")
        ];

        let display = display::new_with_fields<Hero>(&publisher, keys, values, ctx);

        display::update_version<Hero>(&mut display);

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));    
    }

    public(friend) fun mint(
        name: String,
        class: String,
        faction: String,
        rarity: String,
        base_attributes_values: vector<u8>,
        skill_attributes_values: vector<u8>,
        appearance_attributes_values: vector<u8>,
        stat_attributes_values: vector<u64>,
        // TODO: determine if this should be a string or a u64
        other_attributes_values: vector<u8>,
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
            external_id,
            pending_upgrade: 0
        };

        df::add<String, vector<u8>>(&mut hero.id, string::utf8(b"base"), base_attributes_values);
        df::add<String, vector<u8>>(&mut hero.id, string::utf8(b"skill"), skill_attributes_values);
        df::add<String, vector<u8>>(&mut hero.id, string::utf8(b"appearance"), appearance_attributes_values);
        df::add<String, vector<u64>>(&mut hero.id, string::utf8(b"stat"), stat_attributes_values);
        df::add<String, vector<u8>>(&mut hero.id, string::utf8(b"others"), other_attributes_values);

        hero
    }

    public(friend) fun edit_fields<T: copy+drop+store>(hero: &mut Hero, name: String, new_value: vector<T>) {
        let value = df::borrow_mut<String, vector<T>>(&mut hero.id, name);
        *value = new_value;
    }

    public(friend) fun add_field<T: store+drop>(hero: &mut Hero, name: String, new_field: T) {
        df::add<String, T>(&mut hero.id, name, new_field);
    }

    public(friend) fun remove_field<T: store+drop>(hero: &mut Hero, name: String) {
        df::remove<String, T>(&mut hero.id, name);
    }

    public(friend) fun add_pending_upgrade(hero: &mut Hero, burned_heroes: u64) {
        hero.pending_upgrade = burned_heroes;
    }

    public(friend) fun burn(hero: Hero) {
        df::remove<String, vector<u8>>(&mut hero.id, string::utf8(b"base"));
        df::remove<String, vector<u8>>(&mut hero.id, string::utf8(b"skill"));
        df::remove<String, vector<u8>>(&mut hero.id, string::utf8(b"appearance"));
        df::remove<String, vector<u64>>(&mut hero.id, string::utf8(b"stat"));
        df::remove<String, vector<u8>>(&mut hero.id, string::utf8(b"others"));

        let Hero {id, name: _, class: _, faction: _, rarity: _, external_id: _, pending_upgrade: _} = hero;
        object::delete(id);
    }

    // === Accessors ===
    public fun name(hero: &Hero): &String {
        &hero.name
    }

    public fun class(hero: &Hero): &String {
        &hero.class
    }

    public fun faction(hero: &Hero): &String {
        &hero.faction
    }

    public fun rarity(hero: &Hero): &String {
        &hero.rarity
    }

    public fun external_id(hero: &Hero): &String {
        &hero.external_id
    }

    public fun pending_upgrade(hero: &Hero): &u64 {
        &hero.pending_upgrade
    }

    public fun base_values(hero: &Hero): &vector<u8> {
        df::borrow<String, vector<u8>>(&hero.id, string::utf8(b"base"))
    }

    public fun skill_values(hero: &Hero): &vector<u8> {
        df::borrow<String, vector<u8>>(&hero.id, string::utf8(b"skill"))
    }

    public fun appearance_values(hero: &Hero): &vector<u8> {
        df::borrow<String, vector<u8>>(&hero.id, string::utf8(b"appearance"))
    }

    public fun stat_values(hero: &Hero): &vector<u64> {
        df::borrow<String, vector<u64>>(&hero.id, string::utf8(b"stat"))
    }

    public fun others_values(hero: &Hero): &vector<u8> {
        df::borrow<String, vector<u8>>(&hero.id, string::utf8(b"others"))
    }

    public fun field<T: store+drop>(hero: &Hero, field: String): &T {
        df::borrow<String, T>(&hero.id, field)
    }

}

#[test_only]
module contracts::unit_tests {
    use std::string::{Self, String};

    use sui::test_scenario as ts;
    use sui::transfer;

    use contracts::hero::{Self, Hero};

    // errors
    const EWrongName: u64 = 0;
    const EWrongClass: u64 = 1;
    const EWrongFaction: u64 = 2;
    const EWrongRarity: u64 = 3;
    const EWrongExternalId: u64 = 4;
    const EWrongPendingUpgradeValue: u64 = 5;
    const EWrongBaseValues: u64 = 6;
    const EWrongSkillValues: u64 = 7;
    const EWrongAppearanceValues: u64 = 8;
    const EWrongStatValues: u64 = 9;
    const EWrongCustomValues: u64 = 10;


    const SENDER: address = @0xADD;

    #[test]
    public fun test_functions() {
        let scenario = ts::begin(SENDER);
        let name = string::utf8(b"Wo Long");
        let class = string::utf8(b"Assassin");
        let faction = string::utf8(b"Void Walker");
        let rarity = string::utf8(b"R");
        let external_id = string::utf8(b"1337");

        let base_values: vector<u8> = vector[
            1,
            2,
            3,
            4,
            5,
            6
        ];

        let skill_values: vector<u8> = vector[
            200,
            201,
            202,
            203
        ];

        let appearance_values: vector<u8> = vector [
            100,
            101,
            102,
            103,
            104,
            105,
            106,
            107,
            108,
            109,
            110,
            111
        ];

        let stat_values: vector<u64> = vector[
            40,
            0,
            0,
            0,
            0,
            0,
            0,
            0
        ];

        let others_values: vector<u8> = vector[
            34
        ];

        let hero = hero::mint(
            name,
            class,
            faction,
            rarity,
            base_values,
            skill_values,
            appearance_values,
            stat_values,
            others_values,
            external_id,
            ts::ctx(&mut scenario)
        );

        transfer::public_transfer(hero, SENDER);

        ts::next_tx(&mut scenario, SENDER);
        {
            let hero = ts::take_from_sender<Hero>(&mut scenario);
            assert!(hero::name(&hero) == &name, EWrongName);
            assert!(hero::class(&hero) == &class, EWrongClass);
            assert!(hero::faction(&hero) == &faction, EWrongFaction);
            assert!(hero::rarity(&hero) == &rarity, EWrongRarity);
            assert!(hero::external_id(&hero) == &external_id, EWrongExternalId);
            assert!(hero::pending_upgrade(&hero) == &0, EWrongPendingUpgradeValue);
            assert!(hero::base_values(&hero) == &base_values, EWrongBaseValues);
            assert!(hero::skill_values(&hero) == &skill_values, EWrongSkillValues);
            assert!(hero::appearance_values(&hero) == &appearance_values, EWrongAppearanceValues);
            assert!(hero::stat_values(&hero) == &stat_values, EWrongStatValues);
            assert!(hero::others_values(&hero) == &others_values, EWrongBaseValues);

            ts::return_to_sender<Hero>(&scenario, hero);
        };

        let new_base_values: vector<u8> = vector[
            10,
            11,
            12,
            13,
            14,
            15,
            16
        ];
        
        let new_stat_values: vector<u64> = vector[
            102,
            1050,
            5000,
            268,
            3800,
            520,
            500,
            888
        ];

        let new_field: String = string::utf8(b"senses");
        let new_field_values: vector<u8> = vector [
            1,
            2
        ];

        ts::next_tx(&mut scenario, SENDER);
        {
            let hero = ts::take_from_sender<Hero>(&mut scenario);
            hero::edit_fields<u8>(&mut hero, string::utf8(b"base"), new_base_values);
            hero::edit_fields<u64>(&mut hero, string::utf8(b"stat"), new_stat_values);
            hero::add_field<vector<u8>>(&mut hero, new_field, new_field_values);
            ts::return_to_sender<Hero>(&scenario, hero);
        };

        ts::next_tx(&mut scenario, SENDER);
        {
            let hero = ts::take_from_sender<Hero>(&mut scenario);
            assert!(hero::base_values(&hero) == &new_base_values, EWrongBaseValues);
            assert!(hero::stat_values(&hero) == &new_stat_values, EWrongStatValues);
            assert!(hero::field(&hero, new_field) == &new_field_values, EWrongCustomValues);
            ts::return_to_sender<Hero>(&scenario, hero);
        };

        // burn
        ts::next_tx(&mut scenario, SENDER);
        {
            let hero = ts::take_from_sender<Hero>(&mut scenario);
            hero::remove_field<vector<u8>>(&mut hero, new_field);
            hero::burn(hero);
        };

        ts::end(scenario);
    }

}