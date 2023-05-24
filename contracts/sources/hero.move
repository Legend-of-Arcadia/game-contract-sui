module contracts::hero {

    use sui::object::{Self, UID, ID};
    use sui::tx_context::{TxContext};
    use sui::dynamic_field as dfield;
    use sui::coin::Coin;
    use sui::event;

    use std::string::{Self, String, utf8};
    use std::vector;

    use contracts::arca::ARCA;
    use contracts::shop;

    const ENotSameHeroRarity: u64 = 0;
    

    struct Hero has key, store {
        id: UID,
        name: String,
        class: String,
        factions: String,
        skill: String,
        rarity: String,
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

    public(friend) fun mint_hero(name: vector<u8>, class: vector<u8>, factions: vector<u8>, skill: vector<u8>, rarity: vector<u8>, ctx: &mut TxContext): Hero {
        
        let id = object::new(ctx);
        let hero = Hero{
            id, 
            name: string::utf8(name), 
            class: string::utf8(class), 
            factions: string::utf8(factions), 
            skill: string::utf8(skill), 
            rarity: string::utf8(rarity)
        };

        dfield::add(&mut hero.id, utf8(b"Health"), 0);
        dfield::add(&mut hero.id, utf8(b"Magic_Attack"), 0);
        dfield::add(&mut hero.id, utf8(b"Defense"), 0);
        dfield::add(&mut hero.id, utf8(b"Magic_Defence"), 0);
        dfield::add(&mut hero.id, utf8(b"CRIT_Rate"), 0);
        dfield::add(&mut hero.id, utf8(b"Block_Rate"), 0);
        dfield::add(&mut hero.id, utf8(b"Hit_Rate"), 0);
        dfield::add(&mut hero.id, utf8(b"Evasion_Rate"), 0);

        event::emit(HeroMinted {id: object::uid_to_inner(&hero.id)});

        hero
    }

    fun edit_df(heroId: &mut UID, name: String, new_value: u64) {
        let _ = dfield::remove<String, u64>(heroId, name);
        dfield::add<String, u64>(heroId, name, new_value);
    }    

    public(friend) fun burn_hero(hero: Hero) {
        let Hero {id, name: _, class: _, factions: _, skill: _, rarity: _} = hero;
        event::emit(HeroBurned {id: object::uid_to_inner(&id)});
        object::delete(id);
    }

    public(friend) fun upgrade_hero(
        hero: &mut Hero, 
        heroes: vector<Hero>, 
        attributes: vector<String>, 
        values: vector<u64>) {
        let i = 0;
        while(i < vector::length(&heroes)) {
            let hero_pop = vector::pop_back(&mut heroes);
            assert!(hero.rarity == hero_pop.rarity, ENotSameHeroRarity);
            burn_hero(hero_pop);
            i = i + 1;
        };

        let i = 0;
        while(i < vector::length(&attributes)) {
            dfield::add<String, u64>(&mut hero.id, *vector::borrow(&attributes, i), *vector::borrow(&values, i));
            i = i + 1;
        };

        vector::destroy_empty(heroes);
        event::emit(HeroUpgraded{id: object::uid_to_inner(&hero.id)});
    }

    public(friend) fun power_upgrade_hero(
        hero_shop: &mut shop::Shop, 
        hero: &mut Hero, 
        heroes: vector<Hero>, 
        attributes: vector<String>, 
        values: vector<u64>, 
        cost: u64, 
        coin: Coin<ARCA>) {
        shop::pay<ARCA>(hero_shop, cost, coin);

        upgrade_hero(hero, heroes, attributes, values);
    }

}