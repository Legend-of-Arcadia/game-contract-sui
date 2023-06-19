module contracts::test_game {
  use std::string::{Self, String};
  use std::vector;
  // use std::debug;

  use sui::coin::{Self, Coin};
  use sui::test_scenario as ts;
  use sui::transfer;
  use sui::sui::SUI;
  use sui::vec_map;

  use contracts::game::{Self, EMustBurnAtLeastOneHero, EWrongPowerUpgradeFee, GameCap, GameConfig, Upgrader};
  use contracts::hero::{Self, Hero};
  use contracts::arca::ARCA;

  // errors
  const EWrongStats: u64 = 0;
  const EWrongAppearance: u64 = 1;
  const EWrongGameBalanceAfterUpgrade: u64 = 2;
  const EWrongHeroPendingUpgrade: u64 = 3;

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

    let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
    transfer::public_transfer(hero, GAME);

    ts::return_to_sender<GameCap>(&scenario, cap);

    ts::end(scenario);
  }


  #[test]
  public fun upgrade_test() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint a hero and send it to the user
    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
      let hero2 = game::mint_test_hero(&cap, ts::ctx(&mut scenario));

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      transfer::public_transfer(hero2, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let hero2 = ts::take_from_sender<Hero>(&mut scenario);
      let hero1 = ts::take_from_sender<Hero>(&mut scenario);
      let hero = ts::take_from_sender<Hero>(&mut scenario);

      let upgrader = ts::take_shared<Upgrader>(&mut scenario);

      game::upgrade_hero(hero, vector[hero1, hero2], &mut upgrader, false, ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
    };

    let new_stats: vector<u64> = vector[
        200,
        120,
        30,
        0,
        0,
        0,
        25
    ];

    // game performs upgrade
    ts::next_tx(&mut scenario, GAME);
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let cap = ts::take_from_sender<GameCap>(&mut scenario);

      let (hero, ticket) = game::get_for_upgrade(&cap, USER, &mut upgrader);
      assert!(hero::pending_upgrade(&hero) == &2, EWrongHeroPendingUpgrade);
      game::upgrade_stat(&cap, &mut hero, new_stats);
      game::return_upgraded_hero(hero, ticket);

      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(upgrader);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&mut scenario);
      assert!(*hero::stat_values(&hero) == new_stats, EWrongStats);
      assert!(hero::pending_upgrade(&hero) == &0, EWrongHeroPendingUpgrade);
      ts::return_to_sender<Hero>(&scenario, hero);
    };

    ts::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = EMustBurnAtLeastOneHero)]
  public fun upgrade_test_fail() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint a hero and send it to the user
    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));

      transfer::public_transfer(hero, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&mut scenario);

      let upgrader = ts::take_shared<Upgrader>(&mut scenario);

      game::upgrade_hero(hero, vector::empty<Hero>(), &mut upgrader, false, ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
    };

    ts::end(scenario);
  }

  #[test]
  public fun makeover_test() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint a hero and send it to the user
    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
      let hero2 = game::mint_test_hero(&cap, ts::ctx(&mut scenario));

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      transfer::public_transfer(hero2, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let hero2 = ts::take_from_sender<Hero>(&mut scenario);
      let hero1 = ts::take_from_sender<Hero>(&mut scenario);
      let hero = ts::take_from_sender<Hero>(&mut scenario);

      let upgrader = ts::take_shared<Upgrader>(&mut scenario);

      game::upgrade_hero(hero, vector[hero1, hero2], &mut upgrader, true, ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
    };

    let new_appearance: vector<String> = vector [
            string::utf8(b"Face2"),
            string::utf8(b"Eye3"),
            string::utf8(b"Nose4"),
            string::utf8(b"Mouth1"),
            string::utf8(b"Tattoo"),
            string::utf8(b"Hat2"),
            string::utf8(b"Cloth3"),
            string::utf8(b"Back4"),
            string::utf8(b"Trouser1"),
            string::utf8(b"Hand4"),
            string::utf8(b"Item Slots1"),
        ];

    // game performs upgrade
    ts::next_tx(&mut scenario, GAME);
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let cap = ts::take_from_sender<GameCap>(&mut scenario);

      let (hero, ticket) = game::get_for_upgrade(&cap, USER, &mut upgrader);
      assert!(hero::pending_upgrade(&hero) == &2, EWrongHeroPendingUpgrade);
      game::upgrade_appearance(&cap, &mut hero, new_appearance);
      game::return_upgraded_hero(hero, ticket);

      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(upgrader);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&mut scenario);
      assert!(*hero::appearance_values(&hero) == new_appearance, EWrongAppearance);
      assert!(hero::pending_upgrade(&hero) == &0, EWrongHeroPendingUpgrade);
      ts::return_to_sender<Hero>(&scenario, hero);
    };

    ts::end(scenario);
  }


  #[test]
  public fun power_upgrade_test() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint a hero and send it to the user
    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
      let hero2 = game::mint_test_hero(&cap, ts::ctx(&mut scenario));

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      transfer::public_transfer(hero2, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let hero2 = ts::take_from_sender<Hero>(&mut scenario);
      let hero1 = ts::take_from_sender<Hero>(&mut scenario);
      let hero = ts::take_from_sender<Hero>(&mut scenario);

      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      //12_500_000_000
      let fee: Coin<ARCA> = coin::mint_for_testing<ARCA>(25_000_000_000, ts::ctx(&mut scenario));
      game::power_upgrade_hero(hero, vector[hero1, hero2],fee,  &mut upgrader, ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
    };

    let new_stats: vector<u64> = vector[
        2000,
        1290,
        370,
        55,
        234,
        9,
        25
    ];

    // game performs upgrade
    ts::next_tx(&mut scenario, GAME);
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let cap = ts::take_from_sender<GameCap>(&mut scenario);

      let (hero, ticket) = game::get_for_upgrade(&cap, USER, &mut upgrader);
      assert!(hero::pending_upgrade(&hero) == &2, EWrongHeroPendingUpgrade);
      game::upgrade_stat(&cap, &mut hero, new_stats);
      game::return_upgraded_hero(hero, ticket);

      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(upgrader);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&mut scenario);
      assert!(*hero::stat_values(&hero) == new_stats, EWrongStats);
      assert!(hero::pending_upgrade(&hero) == &0, EWrongHeroPendingUpgrade);
      ts::return_to_sender<Hero>(&scenario, hero);
    };
    
    // withdraw upgrader profits
    ts::next_tx(&mut scenario, GAME);
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let coins = game::claim_upgrade_profits(&cap, &mut upgrader, ts::ctx(&mut scenario));
      assert!(coin::value<ARCA>(&coins) == 25_000_000_000, EWrongGameBalanceAfterUpgrade);
      transfer::public_transfer(coins, GAME);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(upgrader);
    };

    ts::end(scenario);
  }

  // power upgrade fail due to low price
  #[test]
  #[expected_failure(abort_code = EWrongPowerUpgradeFee)]
  public fun power_upgrade_test_fail() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint a hero and send it to the user
    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
      let hero2 = game::mint_test_hero(&cap, ts::ctx(&mut scenario));

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      transfer::public_transfer(hero2, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let hero2 = ts::take_from_sender<Hero>(&mut scenario);
      let hero1 = ts::take_from_sender<Hero>(&mut scenario);
      let hero = ts::take_from_sender<Hero>(&mut scenario);

      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      //12_500_000_000
      let fee: Coin<ARCA> = coin::mint_for_testing<ARCA>(2_000_000_000, ts::ctx(&mut scenario));
      game::power_upgrade_hero(hero, vector[hero1, hero2],fee,  &mut upgrader, ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
    };

    ts::end(scenario);
  }
}
