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
  use loa_game::gacha;


  // errors
  const EWrongGrowths: u64 = 0;
  const EWrongAppearance: u64 = 1;
  //const EWrongGameBalanceAfterUpgrade: u64 = 2;
  const EWrongHeroPendingUpgrade: u64 = 3;

  const GAME: address = @0x111;
  const USER: address = @0x222;
  const DECIMALS: u64 = 1_000_000_000;

  #[test]
  fun test_hero_mint(){

    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, GAME);
    let cap = ts::take_from_sender<GameCap>(&scenario);
    let config = ts::take_shared<GameConfig>(&scenario);

    let hero = game::mint_test_hero(&cap, &config,ts::ctx(&mut scenario));
    transfer::public_transfer(hero, GAME);

    ts::return_to_sender<GameCap>(&scenario, cap);
    ts::return_shared(config);

    ts::end(scenario);
  }


  #[test]
  public fun upgrade_growth_test() {
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    // mint three heroes and send it to the user
    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let hero = game::mint_test_hero(&cap, &config,ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));
      let hero2 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      transfer::public_transfer(hero2, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(config);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let hero2 = ts::take_from_sender<Hero>(&scenario);
      let hero1 = ts::take_from_sender<Hero>(&scenario);
      let hero = ts::take_from_sender<Hero>(&scenario);

      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&scenario);

      game::upgrade_hero(hero, vector[hero1, hero2], &upgrader,ts::ctx(&mut scenario));
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
      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let upgrade_ticket = ts::take_from_sender<HeroTicket>(&scenario);

      game::upgrade_growth_by_ticket(&mut upgrade_ticket, new_growths);
      game::return_upgraded_hero_by_ticket(upgrade_ticket);

      ts::return_shared(upgrader);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&scenario);
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
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let hero = game::mint_test_hero(&cap, &config,ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));
      let hero2 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      transfer::public_transfer(hero2, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(config);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let hero2 = ts::take_from_sender<Hero>(&scenario);
      let hero1 = ts::take_from_sender<Hero>(&scenario);
      let hero = ts::take_from_sender<Hero>(&scenario);

      let upgrader = ts::take_shared<Upgrader>(&scenario);

      game::upgrade_hero(hero, vector[hero1, hero2], &upgrader,ts::ctx(&mut scenario));
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
      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let upgrade_ticket = ts::take_from_sender<HeroTicket>(&scenario);

      game::upgrade_base_by_ticket(&mut upgrade_ticket, new_base);
      game::return_upgraded_hero_by_ticket(upgrade_ticket);
      ts::return_shared(upgrader);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&scenario);
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
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let hero = game::mint_test_hero(&cap, &config,ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));
      let hero2 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      transfer::public_transfer(hero2, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(config);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let hero2 = ts::take_from_sender<Hero>(&scenario);
      let hero1 = ts::take_from_sender<Hero>(&scenario);
      let hero = ts::take_from_sender<Hero>(&scenario);

      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&scenario);

      game::upgrade_hero(hero, vector[hero1, hero2], &upgrader, ts::ctx(&mut scenario));
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
      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let upgrade_ticket = ts::take_from_sender<HeroTicket>(&scenario);

      game::upgrade_base_by_ticket(&mut upgrade_ticket, new_skills);
      game::return_upgraded_hero_by_ticket(upgrade_ticket);

      ts::return_shared(upgrader);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&scenario);
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
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let hero = game::mint_test_hero(&cap, &config,ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));
      let hero2 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      transfer::public_transfer(hero2, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(config);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let hero2 = ts::take_from_sender<Hero>(&scenario);
      let hero1 = ts::take_from_sender<Hero>(&scenario);
      let hero = ts::take_from_sender<Hero>(&scenario);

      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&scenario);

      game::upgrade_hero(hero, vector[hero1, hero2], &upgrader, ts::ctx(&mut scenario));
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
      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let upgrade_ticket = ts::take_from_sender<HeroTicket>(&scenario);

      game::upgrade_base_by_ticket(&mut upgrade_ticket, new_others);
      game::return_upgraded_hero_by_ticket(upgrade_ticket);

      ts::return_shared(upgrader);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&scenario);
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
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let hero = game::mint_test_hero(&cap, &config,ts::ctx(&mut scenario));

      transfer::public_transfer(hero, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(config);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&scenario);

      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&scenario);

      game::upgrade_hero(hero, vector::empty<Hero>(), &upgrader, ts::ctx(&mut scenario));
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
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let hero = game::mint_test_hero(&cap, &config,ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));

      game::upgrade_appearance(&cap, &mut hero1, appearance, &config);

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(config);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&scenario);
      let hero1 = ts::take_from_sender<Hero>(&scenario);
      let hero = ts::take_from_sender<Hero>(&scenario);
      let appearance_index = 2u64;
      game::makeover_hero(hero, hero1, appearance_index, &upgrader, ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    // game performs upgrade
    ts::next_tx(&mut scenario, GAME);
    {
      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let upgrade_ticket = ts::take_from_sender<HeroTicket>(&scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&scenario);

      game::upgrade_appearance_by_ticket(&mut upgrade_ticket, appearance);
      game::return_upgraded_hero_by_ticket(upgrade_ticket);

      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&scenario);
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
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let hero = game::mint_test_hero(&cap, &config,ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));

      game::upgrade_appearance(&cap, &mut hero1, appearance, &config);
      game::upgrade_base(&cap, &mut hero1, base, &config);

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(config);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&scenario);
      let hero1 = ts::take_from_sender<Hero>(&scenario);
      let hero = ts::take_from_sender<Hero>(&scenario);
      let appearance_index = 2u64;
      game::makeover_hero(hero, hero1, appearance_index, &upgrader, ts::ctx(&mut scenario));
      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    // game performs upgrade
    ts::next_tx(&mut scenario, GAME);
    {
      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let upgrade_ticket = ts::take_from_sender<HeroTicket>(&scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&scenario);

      game::upgrade_appearance_by_ticket(&mut upgrade_ticket, appearance);
      game::return_upgraded_hero_by_ticket(upgrade_ticket);

      ts::return_shared(upgrader);
      ts::return_shared(obj_burn);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&scenario);
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
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let hero = game::mint_test_hero(&cap, &config,ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, &config,ts::ctx(&mut scenario));

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(config);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&scenario);
      let hero1 = ts::take_from_sender<Hero>(&scenario);
      let hero = ts::take_from_sender<Hero>(&scenario);
      let appearance_index = 2u64;
      game::makeover_hero(hero, hero1, appearance_index, &upgrader, ts::ctx(&mut scenario));
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
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let hero = game::mint_test_hero(&cap, &config,ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));
      let hero2 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      transfer::public_transfer(hero2, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(config);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let hero2 = ts::take_from_sender<Hero>(&scenario);
      let hero1 = ts::take_from_sender<Hero>(&scenario);
      let hero = ts::take_from_sender<Hero>(&scenario);

      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&scenario);
      //12_500_000_000
      let fee: Coin<ARCA> = coin::mint_for_testing<ARCA>(35_000_000_000, ts::ctx(&mut scenario));
      game::power_upgrade_hero(hero, vector[hero1, hero2],fee,  &mut upgrader, ts::ctx(&mut scenario));
      ts::next_tx(&mut scenario, USER);
      let coin = ts::take_from_sender<Coin<ARCA>>(&scenario);
      assert!(coin::value<ARCA>(&coin) == 10000000000, EWrongHeroPendingUpgrade);
      assert!(game::get_upgrade_profits(&upgrader) == 25000000000, EWrongHeroPendingUpgrade);
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
      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let upgrade_ticket = ts::take_from_sender<HeroTicket>(&scenario);

      game::upgrade_growth_by_ticket(&mut upgrade_ticket, new_growths);
      game::return_upgraded_hero_by_ticket(upgrade_ticket);

      ts::return_shared(upgrader);
    };

    //check
    ts::next_tx(&mut scenario, USER);
    {
      let hero = ts::take_from_sender<Hero>(&scenario);
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
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let hero = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));
      let hero2 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      transfer::public_transfer(hero2, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(config);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let hero2 = ts::take_from_sender<Hero>(&scenario);
      let hero1 = ts::take_from_sender<Hero>(&scenario);
      let hero = ts::take_from_sender<Hero>(&scenario);

      let upgrader = ts::take_shared<Upgrader>(&scenario);
      let obj_burn = ts::take_shared<ObjBurn>(&scenario);
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
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      // mint a hero
      let hero1 = game::mint_test_hero(&cap, &config,ts::ctx(&mut scenario));
      let hero2 = game::mint_test_hero(&cap, &config,ts::ctx(&mut scenario));
      let gacha_ball1 = game::mint_test_gacha(&cap, &config,ts::ctx(&mut scenario));
      game::whitelist_add(&cap, USER, vector[hero1, hero2], vector[gacha_ball1], &mut config);
      ts::return_shared(config);
      ts::return_to_sender<GameCap>(&scenario, cap);
    };

    // user claim whitelist
    ts::next_tx(&mut scenario, USER);
    {
      let config = ts::take_shared<GameConfig>(&scenario);
      game::whitelist_claim(&mut config, ts::ctx(&mut scenario));
      ts::return_shared(config);
    }; 
    
    // user tries to claim again -- fails
    ts::next_tx(&mut scenario, USER);
    {
      let config = ts::take_shared<GameConfig>(&scenario);
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
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let hero = game::mint_test_hero(&cap, &config,ts::ctx(&mut scenario));
      let hero1 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));
      let hero2 = game::mint_test_hero(&cap, &config, ts::ctx(&mut scenario));

      transfer::public_transfer(hero, USER);
      transfer::public_transfer(hero1, USER);
      transfer::public_transfer(hero2, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(config);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {
      let hero2 = ts::take_from_sender<Hero>(&scenario);
      let hero1 = ts::take_from_sender<Hero>(&scenario);
      let hero = ts::take_from_sender<Hero>(&scenario);

      let obj_burn = ts::take_shared<ObjBurn>(&scenario);

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
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let gacha = game::mint_test_gacha(&cap, &config,ts::ctx(&mut scenario));

      transfer::public_transfer(gacha, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(config);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {

      let gacha_ball = ts::take_from_sender<GachaBall>(&scenario);

      let game_config = ts::take_shared<GameConfig>(&scenario);

      game::open_gacha_ball(gacha_ball, &game_config, ts::ctx(&mut scenario));
      ts::return_shared(game_config);
    };

    ts::next_tx(&mut scenario, GAME);
    {
      let box_ticket = ts::take_from_sender<BoxTicket>(&scenario);
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
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let gacha = game::mint_test_gacha(&cap, &config,ts::ctx(&mut scenario));

      transfer::public_transfer(gacha, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(config);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {

      let gacha_ball = ts::take_from_sender<GachaBall>(&scenario);

      let game_config = ts::take_shared<GameConfig>(&scenario);

      game::open_gacha_ball(gacha_ball, &game_config, ts::ctx(&mut scenario));
      ts::return_shared(game_config);
    };

    ts::next_tx(&mut scenario, GAME);
    {
      let box_ticket = ts::take_from_sender<BoxTicket>(&scenario);
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
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let gacha_config_tb = ts::take_shared<GachaConfigTable>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let gacha_id = 50000;
      let gacha_token_types = vector[28888, 27777];
      let gacha_token_amounts = vector[1, 1];
      let gacha_name = string::utf8(b"Grandia");
      let gacha_type = string::utf8(b"Grandia");
      let gacha_collection = string::utf8(b"Grandia");
      let gacha_description = string::utf8(b"Grandia");
      let start_time = 0;
      let end_time = 0;

      game::add_gacha_config(&cap, &mut gacha_config_tb, gacha_id, gacha_token_types, gacha_token_amounts, start_time, end_time, &config);
      game::add_gacha_info(&cap, &mut gacha_config_tb, 28888, gacha_name, gacha_type, gacha_collection, gacha_description, &config);
      game::add_gacha_info(&cap, &mut gacha_config_tb, 27777, gacha_name, gacha_type, gacha_collection, gacha_description, &config);
      game::add_gacha_info(&cap, &mut gacha_config_tb, 29999, gacha_name, gacha_type, gacha_collection, gacha_description, &config);

      let voucher = game::mint_test_voucher(&cap, &config, ts::ctx(&mut scenario));
      transfer::public_transfer(voucher, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(gacha_config_tb);
      ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, USER);
    {
      let voucher = ts::take_from_sender<GachaBall>(&scenario);
      let clock = ts::take_shared<clock::Clock>(&scenario);
      let game_config = ts::take_shared<GameConfig>(&scenario);

      let gacha_config_tb = ts::take_shared<GachaConfigTable>(&scenario);

      game::voucher_exchange(voucher, &gacha_config_tb, &clock, &game_config,ts::ctx(&mut scenario));

      ts::return_shared(gacha_config_tb);
      ts::return_shared(clock);
      ts::return_shared(game_config);
    };
    ts::next_tx(&mut scenario, GAME);
    {
      let ticket = ts::take_from_sender<BoxTicket>(&scenario);
      game::burn_box_ticket(ticket);

      let cap = ts::take_from_sender<GameCap>(&scenario);
      let gacha_id = 50000;
      let gacha_config_tb = ts::take_shared<GachaConfigTable>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);

      game::remove_gacha_config(&cap, &mut gacha_config_tb, gacha_id, &config);

      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(gacha_config_tb);
      ts::return_shared(config);
    };

    // test update config
    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let gacha_config_tb = ts::take_shared<GachaConfigTable>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let gacha_id = 50000;
      let gacha_token_types = vector[29999];
      let gacha_token_amounts = vector[1];
      let start_time = 0;
      let end_time = 0;

      game::add_gacha_config(&cap, &mut gacha_config_tb, gacha_id, gacha_token_types, gacha_token_amounts, start_time, end_time, &config);

      let voucher = game::mint_test_voucher(&cap, &config,ts::ctx(&mut scenario));
      transfer::public_transfer(voucher, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(gacha_config_tb);
      ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, USER);
    {
      let voucher = ts::take_from_sender<GachaBall>(&scenario);
      let clock = ts::take_shared<clock::Clock>(&scenario);
      let game_config = ts::take_shared<GameConfig>(&scenario);

      let gacha_config_tb = ts::take_shared<GachaConfigTable>(&scenario);

      game::voucher_exchange(voucher, &gacha_config_tb, &clock, &game_config,ts::ctx(&mut scenario));

      ts::return_shared(gacha_config_tb);
      ts::return_shared(clock);
      ts::return_shared(game_config);
    };

    ts::next_tx(&mut scenario, USER);

    {
      let gacha1 = ts::take_from_sender<GachaBall>(&scenario);

      assert!(*gacha::tokenType(&gacha1) == 29999,1);
      ts::return_to_sender<GachaBall>(&scenario, gacha1);
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
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let gacha_config_tb = ts::take_shared<GachaConfigTable>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let gacha_id = 69999;
      let gacha_token_types = vector[28888, 27777];
      let gacha_token_amounts = vector[1, 1];
      let gacha_name = string::utf8(b"Grandia");
      let gacha_type = string::utf8(b"Grandia");
      let gacha_collection = string::utf8(b"Grandia");
      let gacha_description = string::utf8(b"Grandia");
      let start_time = 0;
      let end_time = 0;

      game::add_gacha_config(&cap, &mut gacha_config_tb, gacha_id, gacha_token_types, gacha_token_amounts, start_time, end_time, &config);
      game::add_gacha_info(&cap, &mut gacha_config_tb, 28888, gacha_name, gacha_type, gacha_collection, gacha_description, &config);
      game::add_gacha_info(&cap, &mut gacha_config_tb, 27777, gacha_name, gacha_type, gacha_collection, gacha_description, &config);

      ts::next_tx(&mut scenario, GAME);
      game::set_discount_price<ARCA>(&cap, &mut gacha_config_tb, gacha_id, 1000, &config);

      let discount = game::mint_test_discount(&cap, &config,ts::ctx(&mut scenario));
      transfer::public_transfer(discount, USER);
      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(gacha_config_tb);
      ts::return_shared(config);
    };

    //user starts the upgrade
    ts::next_tx(&mut scenario, USER);
    {

      let pay = coin::mint_for_testing<ARCA>(1000, ts::ctx(&mut scenario));
      let discount = ts::take_from_sender<GachaBall>(&scenario);
      let clock = ts::take_shared<clock::Clock>(&scenario);
      let game_config = ts::take_shared<GameConfig>(&scenario);

      let gacha_config_tb = ts::take_shared<GachaConfigTable>(&scenario);

      game::discount_exchange(discount, &mut gacha_config_tb, pay, &clock, &game_config,ts::ctx(&mut scenario));
      ts::next_tx(&mut scenario, USER);
      assert!(game::get_discount_profits<ARCA>(&gacha_config_tb) == 1000, 1);

      ts::return_shared(gacha_config_tb);
      ts::return_shared(clock);
      ts::return_shared(game_config);
    };

    ts::next_tx(&mut scenario, GAME);
    {
      let ticket = ts::take_from_sender<BoxTicket>(&scenario);
      game::burn_box_ticket(ticket);
    };

    ts::next_tx(&mut scenario, GAME);

    {
      let multi_signature = ts::take_shared<MultiSignature>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      game::withdraw_discount_profits_request<ARCA>(&config, &mut multi_signature, GAME,ts::ctx(&mut scenario));

      ts::return_shared(multi_signature);
      ts::return_shared(config);
    };
    ts::next_tx(&mut scenario, GAME);
    {
      let multi_signature = ts::take_shared<MultiSignature>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let config_tb = ts::take_shared<GachaConfigTable>(&scenario);
      multisig::vote(&mut multi_signature, 0, true, ts::ctx(&mut scenario));
      let b = game::withdraw_discount_profits_execute<ARCA>(&config, &mut multi_signature, 0, true, &mut config_tb,ts::ctx(&mut scenario));

      assert!(b, 1);
      ts::next_tx(&mut scenario, GAME);
      let coin = ts::take_from_sender<Coin<ARCA>>(&scenario);

      assert!(coin::value(&coin) == 1000,1);

      ts::return_shared(multi_signature);
      ts::return_shared(config);
      ts::return_shared(config_tb);
      ts::return_to_sender<Coin<ARCA>>(&scenario, coin);
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
      let arca_counter = ts::take_shared<ArcaCounter>(&scenario);
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
      let arca_counter = ts::take_shared<ArcaCounter>(&scenario);
      game::deposit(coin, &mut arca_counter, ts::ctx(&mut scenario));
      ts::next_tx(&mut scenario, GAME);
      //test get_counter_amount
      assert!(game::get_counter_amount(&arca_counter) == 30*DECIMALS, 1);

      ts::return_shared<ArcaCounter>(arca_counter);
    };
    ts::next_tx(&mut scenario, GAME);
    {
      let arca_counter = ts::take_shared<ArcaCounter>(&scenario);
      let seen_messages = ts::take_shared<SeenMessages>(&scenario);
      let clock = ts::take_shared<clock::Clock>(&scenario);
      let game_cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let multi_signature = ts::take_shared<MultiSignature>(&scenario);
      game::set_mugen_pk_request(&config,  &mut multi_signature, mugen_pk, ts::ctx(&mut scenario));
      ts::next_tx(&mut scenario, GAME);
      multisig::vote(&mut multi_signature, 0, true, ts::ctx(&mut scenario));
      let b = game::set_mugen_pk_execute(&config, &mut multi_signature, 0, true, &mut seen_messages,ts::ctx(&mut scenario));
      assert!(b, 1);
      //game::set_mugen_pk(&game_cap, mugen_pk,&mut seen_messages);
      let coin_arca = game::withdraw(&mut arca_counter, amount, 0, 1, fee, chain_id, package, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));

      assert!(coin::value(&coin_arca) == amount - fee, 1);
      transfer::public_transfer(coin_arca, GAME);
      ts::return_shared(arca_counter);
      ts::return_shared(seen_messages);
      ts::return_shared(clock);
      ts::return_to_sender<GameCap>(&scenario, game_cap);
      ts::return_shared(multi_signature);
      ts::return_shared(config);
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
      let arca_counter = ts::take_shared<ArcaCounter>(&scenario);
      game::deposit(coin, &mut arca_counter, ts::ctx(&mut scenario));

      ts::return_shared<ArcaCounter>(arca_counter);
    };
    ts::next_tx(&mut scenario, GAME);
    {
      let arca_counter = ts::take_shared<ArcaCounter>(&scenario);
      let seen_messages = ts::take_shared<SeenMessages>(&scenario);
      let clock = ts::take_shared<clock::Clock>(&scenario);
      let game_cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let multi_signature = ts::take_shared<MultiSignature>(&scenario);
      game::set_mugen_pk_request(&config,  &mut multi_signature, mugen_pk, ts::ctx(&mut scenario));
      ts::next_tx(&mut scenario, GAME);
      multisig::vote(&mut multi_signature, 0, true, ts::ctx(&mut scenario));
      let b = game::set_mugen_pk_execute(&config, &mut multi_signature, 0, true, &mut seen_messages,ts::ctx(&mut scenario));
      assert!(b, 1);
      let coin_arca = game::withdraw(&mut arca_counter, amount, 0, 1, fee, chain_id, package, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));

      assert!(coin::value(&coin_arca) == amount - fee, 1);
      transfer::public_transfer(coin_arca, GAME);
      ts::return_shared(arca_counter);
      ts::return_shared(seen_messages);
      ts::return_shared(clock);
      ts::return_to_sender<GameCap>(&scenario, game_cap);
      ts::return_shared(multi_signature);
      ts::return_shared(config);
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
      let arca_counter = ts::take_shared<ArcaCounter>(&scenario);
      game::deposit(coin, &mut arca_counter, ts::ctx(&mut scenario));

      ts::return_shared<ArcaCounter>(arca_counter);
    };
    ts::next_tx(&mut scenario, GAME);
    {
      let arca_counter = ts::take_shared<ArcaCounter>(&scenario);
      let seen_messages = ts::take_shared<SeenMessages>(&scenario);
      let clock = ts::take_shared<clock::Clock>(&scenario);
      let game_cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let multi_signature = ts::take_shared<MultiSignature>(&scenario);
      game::set_mugen_pk_request(&config,  &mut multi_signature, mugen_pk, ts::ctx(&mut scenario));
      ts::next_tx(&mut scenario, GAME);
      multisig::vote(&mut multi_signature, 0, true, ts::ctx(&mut scenario));
      let b = game::set_mugen_pk_execute(&config, &mut multi_signature, 0, true, &mut seen_messages,ts::ctx(&mut scenario));
      assert!(b, 1);
      clock::increment_for_testing(&mut clock, 1689304580000);
      let coin_arca = game::withdraw(&mut arca_counter, amount, 1691982960, 1, fee, chain_id, package, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));

      assert!(coin::value(&coin_arca) == amount - fee, 1);
      transfer::public_transfer(coin_arca, GAME);
      ts::return_shared(arca_counter);
      ts::return_shared(seen_messages);
      ts::return_shared(clock);
      ts::return_to_sender<GameCap>(&scenario, game_cap);
      ts::return_shared(multi_signature);
      ts::return_shared(config);
    };

    ts::end(scenario);
  }

  #[test]
  fun test_withdraw_gacha_from_signature() {
    let mugen_pk: vector<u8> = vector[
      2,  30, 162, 170, 151,  49, 215, 87,
      106, 246, 229,  96,  59,  99, 119, 37,
      19, 194, 239,  11,  72, 231, 164,  4,
      251, 227, 106, 176, 175,  64, 231, 38,
      174
    ];
    let signed_message: vector<u8> =   vector[
      206, 19,  26, 128,  42,  41, 136, 182,   6, 134, 236,
      40, 49,  25, 155, 246, 193,  72, 166, 155, 223, 221,
      134, 30, 209, 151, 186, 149, 147,  90, 163, 157,  91,
      127, 23, 166, 130, 247,  26, 247,  80,   6,  59, 255,
      150, 11, 108, 252, 140,  16,  67, 110, 146, 170, 194,
      179, 68,  72, 217,  88, 225,  70, 105, 127
    ];

    let token_types = vector[18888, 19999];
    let amounts = vector[10, 2];
    let chain_id = 99;
    let package:address = @0xc69c87d31fc58cb07373997c285fffb113f513fedc26355e0fa036449f4573f3;
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));

    let clock = clock::create_for_testing(ts::ctx(&mut scenario));
    clock::share_for_testing(clock);

    ts::next_tx(&mut scenario, GAME);
    {
      let cap = ts::take_from_sender<GameCap>(&scenario);
      let gacha_config_tb = ts::take_shared<GachaConfigTable>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let gacha_name = string::utf8(b"Grandia");
      let gacha_type = string::utf8(b"Grandia");
      let gacha_collection = string::utf8(b"Grandia");
      let gacha_description = string::utf8(b"Grandia");


      game::add_gacha_info(&cap, &mut gacha_config_tb, 18888, gacha_name, gacha_type, gacha_collection, gacha_description, &config);
      game::add_gacha_info(&cap, &mut gacha_config_tb, 19999, gacha_name, gacha_type, gacha_collection, gacha_description, &config);

      ts::return_to_sender<GameCap>(&scenario, cap);
      ts::return_shared(gacha_config_tb);
      ts::return_shared(config);
    };
    ts::next_tx(&mut scenario, GAME);
    {
      let seen_messages = ts::take_shared<SeenMessages>(&scenario);
      let game_cap = ts::take_from_sender<GameCap>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let multi_signature = ts::take_shared<MultiSignature>(&scenario);
      game::set_mugen_pk_request(&config,  &mut multi_signature, mugen_pk, ts::ctx(&mut scenario));
      ts::next_tx(&mut scenario, GAME);
      multisig::vote(&mut multi_signature, 0, true, ts::ctx(&mut scenario));
      let b = game::set_mugen_pk_execute(&config, &mut multi_signature, 0, true, &mut seen_messages,ts::ctx(&mut scenario));
      assert!(b, 1);

      ts::return_shared(seen_messages);
      ts::return_to_sender<GameCap>(&scenario, game_cap);
      ts::return_shared(multi_signature);
      ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, USER);
    {
      let gacha_config_tb = ts::take_shared<GachaConfigTable>(&scenario);
      let seen_messages = ts::take_shared<SeenMessages>(&scenario);
      let clock = ts::take_shared<clock::Clock>(&scenario);
      //let token_types = vector
      game::withdraw_gacha(&gacha_config_tb, token_types, amounts, 0, 1, chain_id, package, signed_message, &mut seen_messages, &clock, ts::ctx(&mut scenario));
      ts::return_shared(gacha_config_tb);
      ts::return_shared(seen_messages);
      ts::return_shared(clock);
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
      let arca_counter = ts::take_shared<ArcaCounter>(&scenario);
      game::deposit(coin, &mut arca_counter, ts::ctx(&mut scenario));

      ts::return_shared<ArcaCounter>(arca_counter);
    };
    ts::next_tx(&mut scenario, GAME);
    {
      let multi_signature = ts::take_shared<MultiSignature>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      game::withdraw_arca_request(&config, &mut multi_signature, amount, GAME,ts::ctx(&mut scenario));

      ts::return_shared(multi_signature);
      ts::return_shared(config);
    };
    ts::next_tx(&mut scenario, GAME);
    {
      let multi_signature = ts::take_shared<MultiSignature>(&scenario);
      let config = ts::take_shared<GameConfig>(&scenario);
      let arca_counter = ts::take_shared<ArcaCounter>(&scenario);
      multisig::vote(&mut multi_signature, 0, true, ts::ctx(&mut scenario));
      let b = game::withdraw_arca_execute(&config, &mut multi_signature, 0, true, &mut arca_counter,ts::ctx(&mut scenario));

      assert!(b, 1);

      ts::return_shared(multi_signature);
      ts::return_shared(config);
      ts::return_shared(arca_counter);
    };
    ts::end(scenario);
  }

  #[test]
  fun test_create_game_cap(){
    let scenario = ts::begin(GAME);
    game::init_for_test(ts::ctx(&mut scenario));
    ts::next_tx(&mut scenario, GAME);
    {
      let config = ts::take_shared<GameConfig>(&scenario);
      game::create_game_cap_by_admin(&config, USER, 2, ts::ctx(&mut scenario));
      ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, USER);
    {
      let game_cap1 = ts::take_from_sender<GameCap>(&scenario);
      let game_cap2 = ts::take_from_sender<GameCap>(&scenario);
      ts::return_to_sender<GameCap>(&scenario, game_cap1);
      ts::return_to_sender<GameCap>(&scenario, game_cap2);
    };
    ts::end(scenario);
  }
}
