module contracts::test_game {
  use std::string::{Self, String};

  use sui::coin;
  use sui::test_scenario as ts;
  use sui::transfer;
  use sui::sui::SUI;
  use sui::vec_map;

  use contracts::game::{Self, GameCap, GameConfig};

  const GAME: address = @0x111;
  const USER: address = @0x222;

 #[test]
 public fun test_buy() {
  let scenario = ts::begin(GAME);
  game::init_for_test(ts::ctx(&mut scenario));
  
  ts::next_tx(&mut scenario, GAME);
  {
    let config = ts::take_shared<GameConfig>(&mut scenario);
    let cap = ts::take_from_sender<GameCap>(&mut scenario);
    // add sui as allowed coin
    game::add_allowed_coin<SUI>(&cap, &mut config);
    // add prices for sui
    let sui_prices = game::borrow_mut<SUI>(&cap, &mut config);
    vec_map::insert<String, u64>(sui_prices, string::utf8(b"rare"), 10_000_000_000);
    vec_map::insert<String, u64>(sui_prices, string::utf8(b"legendary"), 20_000_000_000);
    ts::return_shared(config);
    ts::return_to_sender(&scenario, cap);
  };

  ts::next_tx(&mut scenario, USER);
  {
    let config = ts::take_shared<GameConfig>(&mut scenario);
    let payment = coin::mint_for_testing<SUI>(10_000_000_000, ts::ctx(&mut scenario));
    let type: String = string::utf8(b"rare");
    let collection: String = string::utf8(b"New Collection");
    let name: String = string::utf8(b"Cool Gacha");

    let gacha = game::buy_gacha(&mut config, payment, type, collection, name, ts::ctx(&mut scenario));
    transfer::public_transfer(gacha, USER);
    ts::return_shared(config);
  };

  ts::end(scenario);
 }
  #[test]
  fun test_hero_mint(){

    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, GAME);
    let cap = ts::take_from_sender<GameCap>(&mut scenario);

      let name = string::utf8(b"Tang Jia");
      let class = string::utf8(b"Fighter");
      let faction = string::utf8(b"Flamexecuter");
      let rarity = string::utf8(b"SR");
      let base_attributes_values = vector[string::utf8(b"female"), string::utf8(b"gloves")];
      let skill_attributes_values = vector[string::utf8(b"some ultimate skill"), string::utf8(b"some basic skill"), string::utf8(b"some passive skill")];
      let appearence_attributes_values = vector[string::utf8(b"round"), string::utf8(b"blue"), string::utf8(b"pointy"), string::utf8(b"basic"), string::utf8(b"tatoo"), string::utf8(b"tiara")];
      let stat_attributes_values = vector [0, 0, 0, 0, 0, 0, 0, 0];
      let other_attributes_values = vector[string::utf8(b"0")];
      let external_id = string::utf8(b"1337");

      let hero = game::mint_hero(
        &cap,
        name,
        class,
        faction,
        rarity,
        base_attributes_values,
        skill_attributes_values,
        appearence_attributes_values,
        stat_attributes_values,
        other_attributes_values,
        external_id,
        ts::ctx(&mut scenario),
      );

      transfer::public_transfer(hero, GAME);

      ts::return_to_sender<GameCap>(&scenario, cap);

      ts::end(scenario);
  }



}