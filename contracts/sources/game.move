module contracts::game{

  use std::option;
  use std::string::{Self, String};
  use std::vector;

  use sui::balance::{Self, Balance};
  use sui::coin::{Self, Coin};
  use sui::event;
  use sui::object::{Self, ID, UID};
  use sui::dynamic_field as df;
  use sui::dynamic_object_field as dof;
  use sui::vec_map::{Self, VecMap};
  use sui::table::{Self, Table};
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};

  use contracts::arca::ARCA;
  use contracts::hero::{Self, Hero};
  use contracts::gacha::{Self, GachaBall};

  const VERSION: u64 = 1;

  // errors
  const EAmountNotExact: u64 = 0;
  const ECoinNotAllowed: u64 = 1;
  const ETypeDoesNotExist: u64 = 2;
  const EIncorrectVersion: u64 = 3;
  const ERarityMismatch: u64 = 4;
  const EReturningWrongHero: u64 = 5;
  const EWrongPowerUpgradeFee: u64 = 6;
  const EMustBurnAtLeastOneHero: u64 = 7;

  // config struct
  struct GameConfig has key, store {
    id: UID,
    caps_created: u64,
    game_address: address,
  }

  // upgrader and hot potato
  struct Upgrader has key, store {
    id: UID,
    power_prices: Table<String, u64>,
    profits: Balance<ARCA>
  }

  struct ReturnTicket {
    player_address: address,
    hero_id: address
  }

  // events
  struct GachaBallOpened has copy, drop {
    id: ID,
    // address of user that opened the ball
    user: address,
  }

  struct UpgradeRequest has copy, drop {
    hero_id: address,
    player_address: address,
    burned_heroes: u64,
    is_makeover: bool
  }

  struct PowerUpgadeRequest has copy, drop {
    hero_id: address,
    user: address,
    burned_heroes: u64,
    arca_payed: u64
  }

  // game capability
  // allows to mint heros
  // and to set the prices for buying gacha balls
  struct GameCap has key, store {
    id: UID,
  }

  // C is the coin
  struct AllowedCoin<phantom C> has store, copy, drop {}

  fun init(ctx: &mut TxContext){

    // create game cap
    let game_cap = GameCap { id: object::new(ctx) };

    // add power upgrade default prices
    let power_upgrade_prices = table::new<String, u64>(ctx);
    table::add<String, u64>(&mut power_upgrade_prices, string::utf8(b"N"), 1_667_000_000);
    table::add<String, u64>(&mut power_upgrade_prices, string::utf8(b"R"), 3_333_000_000);
    table::add<String, u64>(&mut power_upgrade_prices, string::utf8(b"SR"), 12_500_000_000);
    table::add<String, u64>(&mut power_upgrade_prices, string::utf8(b"SSR"), 25_000_000_000);

    let upgrader = Upgrader {
      id: object::new(ctx),
      power_prices: power_upgrade_prices,
      profits: balance::zero<ARCA>()
    };

    let config = GameConfig {
      id: object::new(ctx),
      caps_created: 1,
      game_address: tx_context::sender(ctx)
    };

    transfer::public_share_object(config);
    transfer::public_share_object(upgrader);
    transfer::public_transfer(game_cap, tx_context::sender(ctx));
  }

  // === Game-only function ===

  /// add coin type C as an allowed coin to buy gacha
  public fun add_allowed_coin<C> (_: &GameCap, config: &mut GameConfig) {
    let allowed_coin = AllowedCoin<C>{};
    df::add<AllowedCoin<C>, VecMap<String, u64>>(&mut config.id, allowed_coin, vec_map::empty<String, u64>());
  }

  /// remove coin of type C from the allowd coin types to buy gacha
  public fun remove_allowed_coin<C> (_: &GameCap, config: &mut GameConfig) {
    let allowed_coin = AllowedCoin<C>{};
    df::remove<AllowedCoin<C>, vector<u64>>(&mut config.id, allowed_coin);
  }

  /// get a mutable reference for vec map containing gacha type->price for coin C
  public fun borrow_mut<C>(_: &GameCap, config: &mut GameConfig): &mut VecMap<String, u64>{
    let allowed_coin = AllowedCoin<C>{};
    let prices = df::borrow_mut(&mut config.id, allowed_coin);
    prices
  }

  /// set or change the price of a gacha ball for a coin type C
  public fun set_gacha_price<C>(
    game_cap: &GameCap,
    config: &mut GameConfig,
    elite_price: u64,
    legendary_price: u64,
    epic_price: u64,
    vip_price: u64,
  ) {
    let prices = borrow_mut<C>(game_cap, config);
    vec_map::insert<String, u64>(prices, string::utf8(b"elite"), elite_price);
    vec_map::insert<String, u64>(prices, string::utf8(b"legendary"), legendary_price);
    vec_map::insert<String, u64>(prices, string::utf8(b"epic"), epic_price);
    vec_map::insert<String, u64>(prices, string::utf8(b"vip"), vip_price);
  }

  /// set address that will claim gacha sell profits
  public fun set_game_address(_: &GameCap, new_address: address, config: &mut GameConfig) {
    config.game_address = new_address;
  }

  /// claim profits
  public fun claim_upgrade_profits(_: &GameCap, upgrader: &mut Upgrader , ctx: &mut TxContext): Coin<ARCA> {
    let total: Balance<ARCA> = balance::withdraw_all<ARCA>(&mut upgrader.profits);
    coin::from_balance(total, ctx)
  }

  public fun mint_hero(
      _: &GameCap,
      name: String,
      class: String,
      faction: String,
      rarity: String,
      base_attributes_values: vector<String>,
      skill_attributes_values: vector<String>,
      appearence_attributes_values: vector<String>,
      stat_attributes_values: vector<u64>,
      other_attributes_values: vector<String>,
      external_id: String,
      ctx: &mut TxContext
      ): Hero {

      let hero = hero::mint(
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
        ctx,
      );

      hero
    }
  
  public fun mint_gacha(
    _: &GameCap,
    collection: String,
    name: String,
    initial_price: u64,
    type: String,
    ctx: &mut TxContext
  ): GachaBall {

    let gacha_ball = gacha::mint(collection, name, initial_price, type, ctx);

    gacha_ball
  }

  public fun create_game_cap(_: &GameCap, config: &mut GameConfig, ctx: &mut TxContext): GameCap {
    let game_cap = GameCap { id: object::new(ctx) };
    config.caps_created = config.caps_created + 1;
    game_cap
  }

  // burn the game cap
  public fun burn_game_cap(game_cap: GameCap, config: &mut GameConfig){
    config.caps_created = config.caps_created - 1;
    let GameCap { id } = game_cap;
    object::delete(id); 
  }

  /// === Upgrader functions ===
  fun put_hero(hero: Hero, player_address: address, heroes_burned: u64, upgrader: &mut Upgrader) {
    hero::add_pending_upgrade(&mut hero, heroes_burned);
    dof::add<address, Hero>(&mut upgrader.id, player_address, hero);
    // event
  }

  fun put_power_hero(
    hero: Hero,
    player_address: address,
    heroes_burned:u64, 
    fee: Coin<ARCA>, 
    upgrader: &mut Upgrader) 
    {
      hero::add_pending_upgrade(&mut hero, heroes_burned);
      dof::add<address, Coin<ARCA>>(&mut upgrader.id, object::id_address(&hero), fee);
      dof::add<address, Hero>(&mut upgrader.id, player_address, hero);
    }

  public fun get_for_upgrade(_: &GameCap, player_address: address, upgrader: &mut Upgrader): (Hero, ReturnTicket) {
    let hero = dof::remove<address, Hero>(&mut upgrader.id, player_address);
    let hero_address: address = object::id_address(&hero);
    if (dof::exists_<address>(&mut upgrader.id, hero_address)) {
      let fee: Coin<ARCA> = dof::remove<address, Coin<ARCA>>(&mut upgrader.id, hero_address);
      balance::join<ARCA>(&mut upgrader.profits, coin::into_balance<ARCA>(fee));
    };

    let ticket = ReturnTicket {
      player_address,
      hero_id: hero_address
    };

    (hero, ticket)
  }

  public fun return_upgraded_hero(hero: Hero, ticket: ReturnTicket) {
    let ReturnTicket {player_address, hero_id} = ticket;
    assert!(object::id_address<Hero>(&hero) == hero_id, EReturningWrongHero);
    hero::add_pending_upgrade(&mut hero, 0);
    transfer::public_transfer(hero, player_address);
  }

  // upgrade
  public fun upgrade_appearance(_: &GameCap, hero: &mut Hero, new_values: vector<String>) {
    hero::edit_string_fields(hero, string::utf8(b"appearance"), new_values);
  }

  public fun upgrade_stat(_: &GameCap, hero: &mut Hero, new_values: vector<u64>) {
    hero::edit_number_fields(hero, string::utf8(b"stat"), new_values);
  }

  /// === Player functions ===

  /// buy a gacha ball
  /// @param type: type of Gacha we want to buy
  /// C: type of coin we want to use. Must be listed in config
  public fun buy_gacha<C>(
    config: &mut GameConfig,
    payment: Coin<C>,
    type: String,
    collection: String,
    name: String,
    ctx: &mut TxContext
    ): GachaBall
    {
      assert!(VERSION == 1, EIncorrectVersion); 
      let allowed_coin = AllowedCoin<C>{};
      assert!(df::exists_<AllowedCoin<C>>(&mut config.id, allowed_coin), ECoinNotAllowed);
      let prices = df::borrow<AllowedCoin<C>, VecMap<String, u64>>(&mut config.id, allowed_coin);
      
      // TODO: do safe get and have an assertion
      let price = vec_map::try_get<String, u64>(prices, &type);
      assert!(option::is_some(&price), ETypeDoesNotExist);
      assert!(coin::value<C>(&payment) == *option::borrow<u64>(&price), EAmountNotExact);
      let gacha_ball = gacha::mint(collection, name, *option::borrow<u64>(&price), type, ctx);
    
      transfer::public_transfer(payment, config.game_address);
      gacha_ball
  }

  /// open a gacha ball
  public fun open_gacha_ball(gacha_ball: GachaBall, ctx: &mut TxContext){

    assert!(VERSION == 1, EIncorrectVersion); 

    let gacha_ball_id = gacha::id(&gacha_ball);
    let user = tx_context::sender(ctx);

    // burn gacha ball
    gacha::burn(gacha_ball);

    // create and emit an event
    let open_evt = GachaBallOpened { id: gacha_ball_id, user };
    event::emit(open_evt);
  }

  public fun upgrade_hero(
    main_hero: Hero,
    to_burn: vector<Hero>,
    upgrader: &mut Upgrader,
    is_makeover: bool,
    ctx: &mut TxContext)
  {
    assert!(VERSION == 1, EIncorrectVersion);

    let l = vector::length<Hero>(&to_burn);
    assert!(l > 0, EMustBurnAtLeastOneHero);
    let main_rarity = hero::rarity(&main_hero);
    let i: u64 = 0;
    while (i < l) {
      let burnable = vector::pop_back<Hero>(&mut to_burn);
      assert!(main_rarity == hero::rarity(& burnable), ERarityMismatch);
      hero::burn(burnable);
      i = i + 1;
    };
    vector::destroy_empty<Hero>(to_burn);
    // events
    let evt = UpgradeRequest {
      hero_id: object::id_address(&main_hero),
      player_address: tx_context::sender(ctx),
      burned_heroes: l,
      is_makeover
    };
    event::emit(evt);
    put_hero(main_hero, tx_context::sender(ctx), l, upgrader);
    
  }

  public fun power_upgrade_hero(
    main_hero: Hero,
    to_burn: vector<Hero>,
    fee: Coin<ARCA>,
    upgrader: &mut Upgrader,
    ctx: &mut TxContext
  )
  {
    let l = vector::length<Hero>(&to_burn);
    assert!(l > 0, EMustBurnAtLeastOneHero);
    let main_rarity = hero::rarity(&main_hero);
    let correct_price: u64 = *table::borrow<String, u64>(&mut upgrader.power_prices, *main_rarity) * l;
    assert!(coin::value(&fee) == correct_price, EWrongPowerUpgradeFee);
    let i: u64 = 0;
    while (i < l) {
      let burnable = vector::pop_back<Hero>(&mut to_burn);
      assert!(main_rarity == hero::rarity(& burnable), ERarityMismatch);
      hero::burn(burnable);
      i = i + 1;
    };
    vector::destroy_empty<Hero>(to_burn);

    let evt = PowerUpgadeRequest {
      hero_id: object::id_address(&main_hero),
      user: tx_context::sender(ctx),
      burned_heroes: l,
      arca_payed: correct_price
    };

    event::emit(evt);

    put_power_hero(main_hero, tx_context::sender(ctx), l, fee, upgrader);
  }

  // === Test-only ===

  #[test_only]
  public fun init_for_test(ctx: &mut TxContext) {
    init(ctx);
  }

  #[test_only]
  public fun mint_test_hero(cap: &GameCap, ctx: &mut TxContext): Hero {
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

      let hero = mint_hero(
        cap,
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
        ctx,
      );
      hero
  }
}