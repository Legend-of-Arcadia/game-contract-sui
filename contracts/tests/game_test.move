#[test_only]
module contracts::test_game {
  use std::vector;

  use sui::coin::{Self, Coin};
  use sui::test_scenario as ts;
  use sui::transfer;

  use contracts::game::{Self, EMustBurnAtLeastOneHero, ENotWhitelisted, EWrongPowerUpgradeFee, ESameAppearancePart, EGenderismatch, GameCap, GameConfig, Upgrader, ObjBurn, BoxTicket};
  use contracts::hero::{Self, Hero};
  use contracts::arca::ARCA;
  use sui::object;
  use contracts::gacha::GachaBall;
  use std::string;

  // errors
  const EWrongGrowths: u64 = 0;
  const EWrongAppearance: u64 = 1;
  const EWrongGameBalanceAfterUpgrade: u64 = 2;
  const EWrongHeroPendingUpgrade: u64 = 3;

  const GAME: address = @0x111;
  const USER: address = @0x222;

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
  public fun upgrade_growth_test() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint three heroes and send it to the user
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
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);

      game::upgrade_hero(hero, vector[hero1, hero2], &mut upgrader, &mut obj_burn,ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    let new_growths: vector<u16> = vector[
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
      game::upgrade_growth(&cap, &mut hero, new_growths);
      game::return_upgraded_hero(hero, ticket);

      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(upgrader);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&mut scenario);
      assert!(*hero::growth_values(&hero) == new_growths, EWrongGrowths);
      assert!(hero::pending_upgrade(&hero) == &0, EWrongHeroPendingUpgrade);
      ts::return_to_sender<Hero>(&scenario, hero);
    };

    ts::end(scenario);
  }

  #[test]
  public fun upgrade_base_test() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint three heroes and send it to the user
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
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);

      game::upgrade_hero(hero, vector[hero1, hero2], &mut upgrader, &mut obj_burn,ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    let new_base: vector<u16> = vector[
        1,
        2,
        5,
        6,
        7,
        8,
    ];

    // game performs upgrade
    ts::next_tx(&mut scenario, GAME);
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let cap = ts::take_from_sender<GameCap>(&mut scenario);

      let (hero, ticket) = game::get_for_upgrade(&cap, USER, &mut upgrader);
      assert!(hero::pending_upgrade(&hero) == &2, EWrongHeroPendingUpgrade);
      game::upgrade_base(&cap, &mut hero, new_base);
      game::return_upgraded_hero(hero, ticket);

      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(upgrader);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&mut scenario);
      assert!(*hero::base_values(&hero) == new_base, EWrongGrowths);
      assert!(hero::pending_upgrade(&hero) == &0, EWrongHeroPendingUpgrade);
      ts::return_to_sender<Hero>(&scenario, hero);
    };

    ts::end(scenario);
  }

  #[test]
  public fun upgrade_skill_test() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint three heroes and send it to the user
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
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);

      game::upgrade_hero(hero, vector[hero1, hero2], &mut upgrader, &mut obj_burn,ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    let new_skills: vector<u16> = vector[
        20,
        20,
        20,
        20,
        30,
        30,
        30,
    ];

    // game performs upgrade
    ts::next_tx(&mut scenario, GAME);
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let cap = ts::take_from_sender<GameCap>(&mut scenario);

      let (hero, ticket) = game::get_for_upgrade(&cap, USER, &mut upgrader);
      assert!(hero::pending_upgrade(&hero) == &2, EWrongHeroPendingUpgrade);
      game::upgrade_base(&cap, &mut hero, new_skills);
      game::return_upgraded_hero(hero, ticket);

      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(upgrader);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&mut scenario);
      assert!(*hero::base_values(&hero) == new_skills, EWrongGrowths);
      assert!(hero::pending_upgrade(&hero) == &0, EWrongHeroPendingUpgrade);
      ts::return_to_sender<Hero>(&scenario, hero);
    };

    ts::end(scenario);
  }

  #[test]
  public fun upgrade_other_test() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint three heroes and send it to the user
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
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);

      game::upgrade_hero(hero, vector[hero1, hero2], &mut upgrader, &mut obj_burn, ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    let new_others: vector<u16> = vector[
        33,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
    ];

    // game performs upgrade
    ts::next_tx(&mut scenario, GAME);
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let cap = ts::take_from_sender<GameCap>(&mut scenario);

      let (hero, ticket) = game::get_for_upgrade(&cap, USER, &mut upgrader);
      assert!(hero::pending_upgrade(&hero) == &2, EWrongHeroPendingUpgrade);
      game::upgrade_base(&cap, &mut hero, new_others);
      game::return_upgraded_hero(hero, ticket);

      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(upgrader);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&mut scenario);
      assert!(*hero::base_values(&hero) == new_others, EWrongGrowths);
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
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);

      game::upgrade_hero(hero, vector::empty<Hero>(), &mut upgrader, &mut obj_burn, ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    ts::end(scenario);
  }

  #[test]
  public fun makeover_test() {
    let appearance = vector[21, 22, 28, 24, 25, 26, 27, 28, 29, 30, 31];
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint a hero and send it to the user
    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, ts::ctx(&mut scenario));

      game::upgrade_appearance(&cap, &mut hero1, appearance);

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    let burn_hero;
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);
      let hero1 = ts::take_from_sender<Hero>(&mut scenario);
      let hero = ts::take_from_sender<Hero>(&mut scenario);
      burn_hero = object::id_address(&hero1);
      let appearance_index = 2u64;
      game::makeover_hero(hero, hero1, appearance_index, &mut upgrader, &mut obj_burn, ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    // game performs upgrade
    ts::next_tx(&mut scenario, GAME);
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);

      let (hero, ticket) = game::get_for_upgrade(&cap, USER, &mut upgrader);
      assert!(hero::pending_upgrade(&hero) == &1, EWrongHeroPendingUpgrade);
      game::upgrade_appearance(&cap, &mut hero, appearance);
      game::return_upgraded_hero(hero, ticket);
      game::get_hero_and_burn(&cap, burn_hero, &mut obj_burn);

      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&mut scenario);
      assert!(*hero::appearance_values(&hero) == appearance, EWrongAppearance);
      ts::return_to_sender<Hero>(&scenario, hero);
    };

    ts::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = EGenderismatch)]
  public fun makeover_test_fail_gender() {
    let appearance = vector[21, 22, 28, 24, 25, 26, 27, 28, 29, 30, 31];
    let base = vector[1,2,5,4,5,6];
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint a hero and send it to the user
    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, ts::ctx(&mut scenario));

      game::upgrade_appearance(&cap, &mut hero1, appearance);
      game::upgrade_base(&cap, &mut hero1, base);

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    let burn_hero;
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);
      let hero1 = ts::take_from_sender<Hero>(&mut scenario);
      let hero = ts::take_from_sender<Hero>(&mut scenario);
      burn_hero = object::id_address(&hero1);
      let appearance_index = 2u64;
      game::makeover_hero(hero, hero1, appearance_index, &mut upgrader, &mut obj_burn, ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    // game performs upgrade
    ts::next_tx(&mut scenario, GAME);
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);

      let (hero, ticket) = game::get_for_upgrade(&cap, USER, &mut upgrader);
      assert!(hero::pending_upgrade(&hero) == &1, EWrongHeroPendingUpgrade);
      game::upgrade_appearance(&cap, &mut hero, appearance);
      game::return_upgraded_hero(hero, ticket);
      game::get_hero_and_burn(&cap, burn_hero, &mut obj_burn);

      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&mut scenario);
      assert!(*hero::appearance_values(&hero) == appearance, EWrongAppearance);
      ts::return_to_sender<Hero>(&scenario, hero);
    };

    ts::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = ESameAppearancePart)]
  public fun makeover_test_fail() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint a hero and send it to the user
    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, ts::ctx(&mut scenario));

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);
      let hero1 = ts::take_from_sender<Hero>(&mut scenario);
      let hero = ts::take_from_sender<Hero>(&mut scenario);
      let appearance_index = 2u64;
      game::makeover_hero(hero, hero1, appearance_index, &mut upgrader, &mut obj_burn, ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
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
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);
      //12_500_000_000
      let fee: Coin<ARCA> = coin::mint_for_testing<ARCA>(35_000_000_000, ts::ctx(&mut scenario));
      game::power_upgrade_hero(hero, vector[hero1, hero2],fee,  &mut upgrader, &mut obj_burn, ts::ctx(&mut scenario));
      ts::next_tx(&mut scenario, USER);
      let coin = ts::take_from_sender<Coin<ARCA>>(&mut scenario);
      assert!(coin::value<ARCA>(&coin) == 10000000000, EWrongHeroPendingUpgrade);
      ts::return_to_sender<Coin<ARCA>>(&scenario, coin);
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    let new_growths: vector<u16> = vector[
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
      game::upgrade_growth(&cap, &mut hero, new_growths);
      game::return_upgraded_hero(hero, ticket);

      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(upgrader);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&mut scenario);
      assert!(*hero::growth_values(&hero) == new_growths, EWrongGrowths);
      assert!(hero::pending_upgrade(&hero) == &0, EWrongHeroPendingUpgrade);
      ts::return_to_sender<Hero>(&scenario, hero);
    };
    
    // withdraw upgrader profits
    ts::next_tx(&mut scenario, GAME);
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let coins = game::claim_upgrade_profits(&cap, &mut upgrader, ts::ctx(&mut scenario));
      assert!(coin::value<ARCA>(&coins) == 25_000_000_000, EWrongGameBalanceAfterUpgrade);
      transfer::public_transfer(coins, GAME);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
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
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);
      //12_500_000_000
      let fee: Coin<ARCA> = coin::mint_for_testing<ARCA>(2_000_000_000, ts::ctx(&mut scenario));
      game::power_upgrade_hero(hero, vector[hero1, hero2],fee,  &mut upgrader, &mut obj_burn,ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    ts::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = ENotWhitelisted)]
  public fun test_whitelist() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // add user to whitelist
    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let config = ts::take_shared<GameConfig>(&mut scenario);
      // mint a hero
      let hero1 = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
      let hero2 = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
      let gacha_ball1 = game::mint_test_gacha(&cap, ts::ctx(&mut scenario));
      game::whitelist_add(&cap, USER, vector[hero1, hero2], vector[gacha_ball1], &mut config);
      ts::return_shared(config);
      ts::return_to_sender<GameCap>(&scenario, cap);
    };

    // user claim whitelist
    ts::next_tx(&mut scenario, USER);
    {
      let config = ts::take_shared<GameConfig>(&mut scenario);
      game::whitelist_claim(&mut config, ts::ctx(&mut scenario));
      ts::return_shared(config);
    }; 
    
    // user tries to claim again -- fails
    ts::next_tx(&mut scenario, USER);
    {
      let config = ts::take_shared<GameConfig>(&mut scenario);
      game::whitelist_claim(&mut config, ts::ctx(&mut scenario));
      ts::return_shared(config);
    };

    ts::end(scenario);
  }

  #[test]
  public fun charge_hero_test() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint three heroes and send it to the user
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

      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);

      game::charge_hero(vector[hero, hero1, hero2], &mut obj_burn, ts::ctx(&mut scenario));
      ts::return_shared(obj_burn);
    };

    ts::end(scenario);
  }
  // exchange coupon
  //#[test]
  // public fun test_exchange_coupon() {
  //   let scenario = ts::begin(GAME);
  //   game::init_for_test(ts::ctx(&mut scenario));
  //
  //   // send coupon to user
  //   ts::next_tx(&mut scenario, GAME);
  //   {
  //     let cap = ts::take_from_sender<GameCap>(&mut scenario);
  //     // mint a hero
  //     let hero = game::mint_test_hero(&cap, ts::ctx(&mut scenario));
  //     let coupon = game::mint_exchange_coupon<Hero>(&cap, hero, ts::ctx(&mut scenario));
  //     transfer::public_transfer(coupon, USER);
  //     ts::return_to_sender<GameCap>(&scenario, cap);
  //   };
  //
  //   //claim coupon
  //   ts::next_tx(&mut scenario, USER);
  //   {
  //     let coupon = ts::take_from_sender<ExchangeCoupon<Hero>>(&mut scenario);
  //     let hero = game::claim_exchange_coupon<Hero>(coupon);
  //     transfer::public_transfer(hero, USER);
  //   };
  //
  //   ts::end(scenario);
  // }

  #[test]
  public fun box_ticket_test() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint three heroes and send it to the user
    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let gacha = game::mint_test_gacha(&cap, ts::ctx(&mut scenario));

      transfer::public_transfer(gacha, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {

      let gacha_ball = ts::take_from_sender<GachaBall>(&mut scenario);

      let game_config = ts::take_shared<GameConfig>(&mut scenario);

      game::open_gacha_ball(gacha_ball, &game_config, ts::ctx(&mut scenario));
      ts::return_shared(game_config);
    };

    ts::next_tx(&mut scenario, GAME);
    {
      let box_ticket = ts::take_from_sender<BoxTicket>(&mut scenario);
      game::burn_box_ticket(box_ticket)
    };
    ts::end(scenario);
  }

  #[test]
  public fun box_ticket_mint_test() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint three heroes and send it to the user
    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let gacha = game::mint_test_gacha(&cap, ts::ctx(&mut scenario));

      transfer::public_transfer(gacha, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {

      let gacha_ball = ts::take_from_sender<GachaBall>(&mut scenario);

      let game_config = ts::take_shared<GameConfig>(&mut scenario);

      game::open_gacha_ball(gacha_ball, &game_config, ts::ctx(&mut scenario));
      ts::return_shared(game_config);
    };

    ts::next_tx(&mut scenario, GAME);
    {
      let box_ticket = ts::take_from_sender<BoxTicket>(&mut scenario);
      let name = string::utf8(b"Tang Jia");
      let class = string::utf8(b"Fighter");
      let faction = string::utf8(b"Flamexecuter");
      let rarity = string::utf8(b"SR");
      let base_attributes_values: vector<u16> = vector[1,2,3,4,5,6];
      let skill_attributes_values: vector<u16> = vector[31, 32, 33, 34];
      let appearance_attributes_values: vector<u16> = vector[21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31];
      let growth_attributes_values: vector<u16> = vector [0, 0, 0, 0, 0, 0, 0, 0];
      let external_id = string::utf8(b"1337");
      let hero =game::mint_hero_by_ticket(
        box_ticket,
        name,
        class,
        faction,
        rarity,
        base_attributes_values,
        skill_attributes_values,
        appearance_attributes_values,
        growth_attributes_values,
        external_id,
        ts::ctx(&mut scenario),
      );
      transfer::public_transfer(hero, USER);
    };
    ts::end(scenario);
  }
}
