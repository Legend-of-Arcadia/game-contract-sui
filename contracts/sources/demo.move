// module contracts::demo {

//     use contracts::hero::{Self, Hero};

//     use std::string::{String};

//     use sui::tx_context::TxContext;
  
//     public fun mint(
//         name: String,
//         class: String,
//         faction: String,
//         skill: String,
//         rarity: String,
//         external_id: String,
//         ctx: &mut TxContext
//     ): Hero 
//     {
//         hero::mint_hero(name, class, faction, skill, rarity, external_id, ctx)
//     }

//     public fun burn(nft: Hero) {
//         hero::burn_hero(nft);
//     }

//     public(friend) fun upgrade_hero(
//         hero: &mut Hero, 
//         heroes: vector<Hero>, 
//         attributes: vector<String>, 
//         values: vector<u64>) {
//             hero::upgrade_hero(hero, heroes, attributes, values);
//         }
// }