#[test_only]
module loa_game::test_game {
  use std::vector;
  use std::string;

  use sui::coin::{Self, Coin};
  use sui::test_scenario as ts;
  use sui::transfer;
  use sui::clock;

  use loa_game::game::{Self, EMustBurnAtLeastOneHero, ENotWhitelisted, EWrongPowerUpgradeFee, ESameAppearancePart, EGenderMismatch, GameCap, GameConfig, Upgrader, ObjBurn, BoxTicket, ArcaCounter, SeenMessages,
    HeroTicket, GachaConfigTable};
  use loa_game::hero::{Self, Hero};
  use loa_game::gacha::GachaBall;
  use loa::arca::ARCA;
  use multisig::multisig::{Self, MultiSignature};


  // errors
  const EWrongGrowths: u64 = 0;
  const EWrongAppearance: u64 = 1;
  const EWrongGameBalanceAfterUpgrade: u64 = 2;
  const EWrongHeroPendingUpgrade: u64 = 3;

  const GAME: address = @0x111;
  const USER: address = @0x222;
  const DECIMALS: u64 = 1_000_000_000;

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

      game::upgrade_hero(hero, vector[hero1, hero2], &mut upgrader,ts::ctx(&mut scenario));
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
      let upgrade_ticket = ts::take_from_sender<HeroTicket>(&mut scenario);

      game::upgrade_growth_by_ticket(&mut upgrade_ticket, new_growths);
      game::return_upgraded_hero_by_ticket(upgrade_ticket);

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

      game::upgrade_hero(hero, vector[hero1, hero2], &mut upgrader,ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
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
      let upgrade_ticket = ts::take_from_sender<HeroTicket>(&mut scenario);

      game::upgrade_base_by_ticket(&mut upgrade_ticket, new_base);
      game::return_upgraded_hero_by_ticket(upgrade_ticket);
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

      game::upgrade_hero(hero, vector[hero1, hero2], &mut upgrader, ts::ctx(&mut scenario));
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
      let upgrade_ticket = ts::take_from_sender<HeroTicket>(&mut scenario);

      game::upgrade_base_by_ticket(&mut upgrade_ticket, new_skills);
      game::return_upgraded_hero_by_ticket(upgrade_ticket);

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

      game::upgrade_hero(hero, vector[hero1, hero2], &mut upgrader, ts::ctx(&mut scenario));
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
      let upgrade_ticket = ts::take_from_sender<HeroTicket>(&mut scenario);

      game::upgrade_base_by_ticket(&mut upgrade_ticket, new_others);
      game::return_upgraded_hero_by_ticket(upgrade_ticket);

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

      game::upgrade_hero(hero, vector::empty<Hero>(), &mut upgrader, ts::ctx(&mut scenario));
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
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);
      let hero1 = ts::take_from_sender<Hero>(&mut scenario);
      let hero = ts::take_from_sender<Hero>(&mut scenario);
      let appearance_index = 2u64;
      game::makeover_hero(hero, hero1, appearance_index, &mut upgrader, ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    // game performs upgrade
    ts::next_tx(&mut scenario, GAME);
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let upgrade_ticket = ts::take_from_sender<HeroTicket>(&mut scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);

      game::upgrade_appearance_by_ticket(&mut upgrade_ticket, appearance);
      game::return_upgraded_hero_by_ticket(upgrade_ticket);

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
  #[expected_failure(abort_code = EGenderMismatch)]
  public fun makeover_test_fail_gender() {
    let appearance = vector[21, 22, 28, 24, 25, 26, 27, 28, 29, 30, 31];
    let base = vector[2,2,3,4,5,6];
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
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);
      let hero1 = ts::take_from_sender<Hero>(&mut scenario);
      let hero = ts::take_from_sender<Hero>(&mut scenario);
      let appearance_index = 2u64;
      game::makeover_hero(hero, hero1, appearance_index, &mut upgrader, ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    // game performs upgrade
    ts::next_tx(&mut scenario, GAME);
    {
      let upgrader = ts::take_shared<Upgrader>(&mut scenario);
      let upgrade_ticket = ts::take_from_sender<HeroTicket>(&mut scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&mut scenario);

      game::upgrade_appearance_by_ticket(&mut upgrade_ticket, appearance);
      game::return_upgraded_hero_by_ticket(upgrade_ticket);

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
      game::makeover_hero(hero, hero1, appearance_index, &mut upgrader, ts::ctx(&mut scenario));
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
      game::power_upgrade_hero(hero, vector[hero1, hero2],fee,  &mut upgrader, ts::ctx(&mut scenario));
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
      let upgrade_ticket = ts::take_from_sender<HeroTicket>(&mut scenario);

      game::upgrade_growth_by_ticket(&mut upgrade_ticket, new_growths);
      game::return_upgraded_hero_by_ticket(upgrade_ticket);

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
      game::power_upgrade_hero(hero, vector[hero1, hero2],fee,  &mut upgrader, ts::ctx(&mut scenario));
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

  #[test]
  public fun voucher_exchage_test() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    let clock = clock::create_for_testing(ts::ctx(&mut scenario));
    clock::share_for_testing(clock);

    // mint three heroes and send it to the user
    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let gacha_config_tb = ts::take_shared<GachaConfigTable>(&mut scenario);
      let gacha_id = 50000;
      let gacha_token_type = vector[28888, 27777];
      let gacha_name = vector[string::utf8(b"Grandia"), string::utf8(b"Grandia")];
      let gacha_type = vector[string::utf8(b"Grandia"), string::utf8(b"Grandia")];
      let gacha_collction = vector[string::utf8(b"Grandia"), string::utf8(b"Grandia")];
      let gacha_description = vector[string::utf8(b"Grandia"), string::utf8(b"Grandia")];
      let start_time = 0;
      let end_time = 0;

      game::add_gacha_config(&cap, &mut gacha_config_tb, gacha_id, gacha_token_type, gacha_name, gacha_type, gacha_collction,
      gacha_description, start_time, end_time);

      let voucher = game::mint_test_voucher(&cap, ts::ctx(&mut scenario));
      transfer::public_transfer(voucher, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(gacha_config_tb);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let voucher = ts::take_from_sender<GachaBall>(&mut scenario);
      let clock = ts::take_shared<clock::Clock>(&mut scenario);
      let game_config = ts::take_shared<GameConfig>(&mut scenario);

      let gacha_config_tb = ts::take_shared<GachaConfigTable>(&mut scenario);

      game::voucher_exchange(voucher, &gacha_config_tb, &clock, &game_config,ts::ctx(&mut scenario));

      ts::return_shared(gacha_config_tb);
      ts::return_shared(clock);
      ts::return_shared(game_config);
    };
    ts::next_tx(&mut scenario, GAME);
    {
      let ticket = ts::take_from_sender<BoxTicket>(&mut scenario);
      game::burn_box_ticket(ticket);

      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let gacha_id = 50000;
      let gacha_config_tb = ts::take_shared<GachaConfigTable>(&mut scenario);

      game::remove_gacha_config(&cap, &mut gacha_config_tb, gacha_id);

      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(gacha_config_tb);
    };

    ts::end(scenario);
  }


  #[test]
  public fun discount_exchage_test() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));
    let clock = clock::create_for_testing(ts::ctx(&mut scenario));
    clock::share_for_testing(clock);

    // mint three heroes and send it to the user
    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&mut scenario);
      let gacha_config_tb = ts::take_shared<GachaConfigTable>(&mut scenario);
      let gacha_id = 69999;
      let gacha_token_type = vector[28888, 27777];
      let gacha_name = vector[string::utf8(b"Grandia"), string::utf8(b"Grandia")];
      let gacha_type = vector[string::utf8(b"Grandia"), string::utf8(b"Grandia")];
      let gacha_collction = vector[string::utf8(b"Grandia"), string::utf8(b"Grandia")];
      let gacha_description = vector[string::utf8(b"Grandia"), string::utf8(b"Grandia")];
      let start_time = 0;
      let end_time = 0;

      game::add_gacha_config(&cap, &mut gacha_config_tb, gacha_id, gacha_token_type, gacha_name, gacha_type, gacha_collction,
        gacha_description, start_time, end_time);

      ts::next_tx(&mut scenario, GAME);
      game::set_discount_price<ARCA>(&cap, &mut gacha_config_tb, gacha_id, 1000);

      let discount = game::mint_test_discount(&cap, ts::ctx(&mut scenario));
      transfer::public_transfer(discount, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(gacha_config_tb);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {

      let pay = coin::mint_for_testing<ARCA>(1000, ts::ctx(&mut scenario));
      let discount = ts::take_from_sender<GachaBall>(&mut scenario);
      let clock = ts::take_shared<clock::Clock>(&mut scenario);
      let game_config = ts::take_shared<GameConfig>(&mut scenario);

      let gacha_config_tb = ts::take_shared<GachaConfigTable>(&mut scenario);

      game::discount_exchange(discount, &mut gacha_config_tb, pay, &clock, &game_config,ts::ctx(&mut scenario));

      ts::return_shared(gacha_config_tb);
      ts::return_shared(clock);
      ts::return_shared(game_config);
    };

    ts::next_tx(&mut scenario, GAME);
    {
      let ticket = ts::take_from_sender<BoxTicket>(&mut scenario);
      game::burn_box_ticket(ticket);
    };

    ts::end(scenario);
  }

  #[test]
  fun test_deposit() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));
    let coin = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, GAME);
    {
      let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
      game::deposit(coin, &mut arca_counter, ts::ctx(&mut scenario));

      ts::return_shared<ArcaCounter>(arca_counter);
    };

    ts::end(scenario);
  }

  #[test]
  fun test_deposit_and_withdraw_from_signature_1() {
    let mugen_pk: vector<u8> = vector[
      2, 103,  79,  79, 204,  13, 202, 247,
      197,  59,  99,  89, 191,  68, 208, 197,
      53,  13, 102, 206, 105, 188,  11, 224,
      201, 218, 204, 245,  28, 251, 215,  86,
      126
    ];
    let signed_message: vector<u8> =   vector[
      9,  36,  34, 221, 233, 141, 240,  33, 192, 151,  92,
      29, 233, 168, 167,  59, 211, 129,   4, 173, 232,  91,
      70,  71,  26, 165, 166,  27, 172, 124,  32,  74,  96,
      61, 239,  28,  89,  73, 207,  14, 235, 187, 109,  23,
      193,  91, 163, 108, 108,  28,   8, 155, 135, 176, 219,
      194,  98, 164,  56,  93, 200, 175, 172, 135
    ];

    let amount = 30*DECIMALS;
    let fee = 300;
    let chain_id = 99;
    let package:address = @0xa23f846f3f65c18dd46ea114cd07f2368c4f4f2c392a69957f7ac81f257a03ea;

    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));
    let coin = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));

    let clock = clock::create_for_testing(ts::ctx(&mut scenario));
    clock::share_for_testing(clock);

    ts::next_tx(&mut scenario, GAME);
    {
      let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
      game::deposit(coin, &mut arca_counter, ts::ctx(&mut scenario));

      ts::return_shared<ArcaCounter>(arca_counter);
    };
    ts::next_tx(&mut scenario, GAME);
    {
      let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
      let seen_messages = ts::take_shared<SeenMessages>(&mut scenario);
      let clock = ts::take_shared<clock::Clock>(&mut scenario);
      let game_cap = ts::take_from_sender<GameCap>(&mut scenario);
      game::set_mugen_pk(&game_cap, mugen_pk,&mut seen_messages);
      let coin_arca = game::withdraw(&mut arca_counter, amount, 0, 1, fee, chain_id, package, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));

      assert!(coin::value(&coin_arca) == amount - fee, 1);
      transfer::public_transfer(coin_arca, GAME);
      ts::return_shared(arca_counter);
      ts::return_shared(seen_messages);
      ts::return_shared(clock);
      ts::return_to_sender<GameCap>(&scenario, game_cap);
    };

    ts::end(scenario);
  }

  #[test]
  fun test_deposit_and_withdraw_from_signature_2() {
    let mugen_pk: vector<u8> = vector[
      2, 103,  79,  79, 204,  13, 202, 247,
      197,  59,  99,  89, 191,  68, 208, 197,
      53,  13, 102, 206, 105, 188,  11, 224,
      201, 218, 204, 245,  28, 251, 215,  86,
      126
    ];
    let signed_message: vector<u8> =   vector[
      241, 162,   1, 194, 128, 144, 151, 126, 252, 226,  62,
      147,  43,  18,  96,  51, 172,  56, 193, 244, 168, 149,
      28, 126,  65, 180, 111, 139, 246, 221, 132, 133,  33,
      114,  42,  49, 125, 244, 164, 159, 138,  60, 134, 103,
      22, 192,  68,  38,  33, 153, 141,  55, 220, 144, 238,
      160,  65, 123, 153, 167,  17,  57, 224, 112
    ];
    let chain_id = 99;
    let package:address = @0xa23f846f3f65c18dd46ea114cd07f2368c4f4f2c392a69957f7ac81f257a03ea;

    let amount = 1000;
    let fee = 3;
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));
    let coin = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));

    let clock = clock::create_for_testing(ts::ctx(&mut scenario));
    clock::share_for_testing(clock);

    ts::next_tx(&mut scenario, GAME);
    {
      let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
      game::deposit(coin, &mut arca_counter, ts::ctx(&mut scenario));

      ts::return_shared<ArcaCounter>(arca_counter);
    };
    ts::next_tx(&mut scenario, GAME);
    {
      let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
      let seen_messages = ts::take_shared<SeenMessages>(&mut scenario);
      let clock = ts::take_shared<clock::Clock>(&mut scenario);
      let game_cap = ts::take_from_sender<GameCap>(&mut scenario);
      game::set_mugen_pk(&game_cap,mugen_pk,&mut seen_messages);
      let coin_arca = game::withdraw(&mut arca_counter, amount, 0, 1, fee, chain_id, package, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));

      assert!(coin::value(&coin_arca) == amount - fee, 1);
      transfer::public_transfer(coin_arca, GAME);
      ts::return_shared(arca_counter);
      ts::return_shared(seen_messages);
      ts::return_shared(clock);
      ts::return_to_sender<GameCap>(&scenario, game_cap);
    };

    ts::end(scenario);
  }

  #[test]
  fun test_deposit_and_withdraw_from_signature_3() {
    let mugen_pk: vector<u8> = vector[
      2, 103,  79,  79, 204,  13, 202, 247,
      197,  59,  99,  89, 191,  68, 208, 197,
      53,  13, 102, 206, 105, 188,  11, 224,
      201, 218, 204, 245,  28, 251, 215,  86,
      126
    ];
    let signed_message: vector<u8> =   vector[
      116, 118, 135, 131, 192, 111, 223, 236, 120,  54,
      187,  91, 177, 248, 189, 224,  93, 185, 218, 254,
      36, 156, 125,  37, 204, 163, 222, 224,  67,  47,
      182, 230,  85,  27,  38,  94, 101,  84, 151,   1,
      223, 245, 100, 139, 221, 176, 103,  90, 254, 123,
      242, 174, 108, 164,  79, 237, 190,  20, 219, 180,
      116, 143, 105, 203
    ]
    ;

    let amount = 30*DECIMALS;
    let fee = 0;
    let chain_id = 99;
    let package:address = @0xa23f846f3f65c18dd46ea114cd07f2368c4f4f2c392a69957f7ac81f257a03ea;
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));
    let coin = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));

    let clock = clock::create_for_testing(ts::ctx(&mut scenario));
    clock::share_for_testing(clock);

    ts::next_tx(&mut scenario, GAME);
    {
      let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
      game::deposit(coin, &mut arca_counter, ts::ctx(&mut scenario));

      ts::return_shared<ArcaCounter>(arca_counter);
    };
    ts::next_tx(&mut scenario, GAME);
    {
      let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
      let seen_messages = ts::take_shared<SeenMessages>(&mut scenario);
      let clock = ts::take_shared<clock::Clock>(&mut scenario);
      let game_cap = ts::take_from_sender<GameCap>(&mut scenario);
      game::set_mugen_pk(&game_cap, mugen_pk,&mut seen_messages);
      clock::increment_for_testing(&mut clock, 1689304580000);
      let coin_arca = game::withdraw(&mut arca_counter, amount, 1691982960, 1, fee, chain_id, package, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));

      assert!(coin::value(&coin_arca) == amount - fee, 1);
      transfer::public_transfer(coin_arca, GAME);
      ts::return_shared(arca_counter);
      ts::return_shared(seen_messages);
      ts::return_shared(clock);
      ts::return_to_sender<GameCap>(&scenario, game_cap);
    };

    ts::end(scenario);
  }

  #[test]
  fun test_deposit_and_withdraw_by_multisig() {
    let amount = 30*DECIMALS;
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));
    let coin = coin::mint_for_testing<ARCA>(30*DECIMALS, ts::ctx(&mut scenario));

    let clock = clock::create_for_testing(ts::ctx(&mut scenario));
    clock::share_for_testing(clock);

    ts::next_tx(&mut scenario, GAME);
    {
      let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
      game::deposit(coin, &mut arca_counter, ts::ctx(&mut scenario));

      ts::return_shared<ArcaCounter>(arca_counter);
    };
    ts::next_tx(&mut scenario, GAME);
    {
      let multi_signature = ts::take_shared<MultiSignature>(&mut scenario);
      let config = ts::take_shared<GameConfig>(&mut scenario);
      game::withdraw_arca_request(&mut config, &mut multi_signature, amount, GAME,ts::ctx(&mut scenario));

      ts::return_shared(multi_signature);
      ts::return_shared(config);
    };
    ts::next_tx(&mut scenario, GAME);
    {
      let multi_signature = ts::take_shared<MultiSignature>(&mut scenario);
      let config = ts::take_shared<GameConfig>(&mut scenario);
      let arca_counter = ts::take_shared<ArcaCounter>(&mut scenario);
      multisig::vote(&mut multi_signature, 0, true, ts::ctx(&mut scenario));
      let b = game::withdraw_arca_execute(&mut config, &mut multi_signature, 0, true, &mut arca_counter,ts::ctx(&mut scenario));

      assert!(b, 1);

      ts::return_shared(multi_signature);
      ts::return_shared(config);
      ts::return_shared(arca_counter);
    };
    ts::end(scenario);
  }
}
