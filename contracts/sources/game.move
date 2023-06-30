module contracts::game{

  use std::string::{Self, String};
  use std::vector;

  use sui::balance::{Self, Balance};
  use sui::coin::{Self, Coin};
  use sui::event;
  use sui::object::{Self, ID, UID};
  use sui::dynamic_field as df;
  use sui::dynamic_object_field as dof;
  use sui::table::{Self, Table};
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};

  use contracts::arca::ARCA;
  use contracts::hero::{Self, Hero};
  use contracts::gacha::{Self, GachaBall};
  use contracts::item::{Self, Item};
  use std::debug;

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
  const EWhitelistInputsNotSameLength: u64 = 8;
  const ENotWhitelisted: u64 = 9;
  const EBodyPartCannotBeExchanged: u64 = 10;
  const ESameAppearancePart: u64 = 11;

  // config struct
  struct GameConfig has key, store {
    id: UID,
    caps_created: u64,
    game_address: address
    //gacha_config: Table<u64,GachaConfig>
  }

  // struct GachaConfig has store {
  //   open_fee:u64,
  //   name: String,
  //   type: String,
  //   collection: String
  // }

  // upgrader and hot potato
  struct Upgrader has key, store {
    id: UID,
    power_prices: Table<String, u64>,
    profits: Balance<ARCA>
  }

  // At present, the blind boxes and heroes that I need to destroy are all stored in this object
  struct ObjBurn has key, store {
    id: UID
  }

  struct ReturnTicket {
    player_address: address,
    hero_id: address
  }

  struct WhitelistRewards has store {
    heroes: vector<Hero>,
    gacha_balls: vector<GachaBall>
  }

  // events
  struct GachaBallOpened has copy, drop {
    id: ID,
    // address of user that opened the ball
    user: address,
    type: String
  }

  struct UpgradeRequest has copy, drop {
    hero_id: address,
    player_address: address,
    burned_heroes: vector<address>
  }

  struct PowerUpgradeRequest has copy, drop {
    hero_id: address,
    user: address,
    burned_heroes: vector<address>,
    arca_payed: u64
  }

  struct MakeoverRequest has copy, drop {
    hero_id: address,
    player_address: address,
    burned_hero_id: address,
    hero_part: u64
  }

  // game capability
  // allows to mint heros
  // and to set the prices for buying gacha balls
  struct GameCap has key, store {
    id: UID,
  }

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

    let objBurn = ObjBurn {
      id: object::new(ctx),
    };

    transfer::public_share_object(config);
    transfer::public_share_object(upgrader);
    transfer::public_share_object(objBurn);
    transfer::public_transfer(game_cap, tx_context::sender(ctx));
  }

  // === Game-only function ===
 
  /// set address that will claim gacha sell profits
  public fun set_game_address(_: &GameCap, new_address: address, config: &mut GameConfig) {
    config.game_address = new_address;
  }

  /// claim profits
  public fun claim_upgrade_profits(_: &GameCap, upgrader: &mut Upgrader , ctx: &mut TxContext): Coin<ARCA> {
    let total: Balance<ARCA> = balance::withdraw_all<ARCA>(&mut upgrader.profits);
    coin::from_balance(total, ctx)
  }
  // TODO: Each address can get more than one rewards
  /// whitelist add addresses and corresponding rewards
  // address.length == rewards.length
  public fun whitelist_add(
    _: &GameCap,
    player_address: address,
    hero_rewards: vector<Hero>,
    gacha_rewards:vector<GachaBall>,
    config: &mut GameConfig)
  {
    let rewards = WhitelistRewards {
      heroes: hero_rewards,
      gacha_balls: gacha_rewards
    };
    df::add<address, WhitelistRewards>(&mut config.id, player_address, rewards);
  }

  public fun mint_hero(
      _: &GameCap,
      name: String,
      class: String,
      faction: String,
      rarity: String,
      base_attributes_values: vector<u16>,
      skill_attributes_values: vector<u16>,
      appearence_attributes_values: vector<u16>,
      growth_attributes_values: vector<u16>,
      //other_attributes_values: vector<u8>,
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
        growth_attributes_values,
        //other_attributes_values,
        external_id,
        ctx,
      );

      hero
    }

  // For casting blind boxes, a new id attribute is added. Use type or id to distinguish the level of blind boxes?
  // The content described in display is currently fixed, whether to use the parameters passed in
  public fun mint_gacha(
    _: &GameCap,
    gacha_id: u64,
    collection: String,
    name: String,
    type: String,
    ctx: &mut TxContext
  ): GachaBall {

    let gacha_ball = gacha::mint(gacha_id, collection, name, type, ctx);

    gacha_ball
  }

  // For casting items, use type to distinguish types of avatars, medals, etc., or add item id attributes
  public fun mint_item(
    _: &GameCap,
    collection: String,
    name: String,
    type: String,
    ctx: &mut TxContext
  ): Item {

    let item = item::mint(collection, name, type, ctx);

    item
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

  // Set the cost of power upgrades
  public fun set_upgrade_price(_: &GameCap, upgrader: &mut Upgrader , keys: vector<String>, values: vector<u64>){
    let i = 0;
    let len = vector::length(&keys);
    while(i < len) {
      let key = vector::borrow(&keys, i);
      let value = vector::borrow(&values, i);
      if(table::contains<String, u64>(&mut upgrader.power_prices, *key)) {
        table::remove<String, u64>(&mut upgrader.power_prices, *key);
      };
      table::add<String, u64>(&mut upgrader.power_prices, *key, *value);
    }
  }

  /// === Upgrader functions ===
  // place an upgraded hero
  fun put_hero(hero: Hero, player_address: address, heroes_burned: u64, upgrader: &mut Upgrader) {
    hero::add_pending_upgrade(&mut hero, heroes_burned);
    dof::add<address, Hero>(&mut upgrader.id, player_address, hero);
    // event
  }

  // Place heroes with powerful upgrades (charging arca)
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

  // Admin gets upgraded heroes
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

  // Admins return upgraded heroes
  public fun return_upgraded_hero(hero: Hero, ticket: ReturnTicket) {
    let ReturnTicket {player_address, hero_id} = ticket;
    assert!(object::id_address<Hero>(&hero) == hero_id, EReturningWrongHero);
    hero::add_pending_upgrade(&mut hero, 0);
    transfer::public_transfer(hero, player_address);
  }

  // place destroyed hero
  fun put_burn_hero(hero: Hero, hero_address: address, obj_burn: &mut ObjBurn) {
    dof::add<address, Hero>(&mut obj_burn.id, hero_address, hero);
    // event
  }

  // admin burn hero
  public fun get_burn_hero_and_burn(_: &GameCap, hero_address: address, obj_burn: &mut ObjBurn) {
    let burn_hero = dof::remove<address, Hero>(&mut obj_burn.id, hero_address);
    hero::burn(burn_hero);
    // event
  }
  // upgrade

  // Admin Upgrade Properties
  public fun upgrade_base(_: &GameCap, hero: &mut Hero, new_values: vector<u16>) {
    hero::edit_fields<u16>(hero, string::utf8(b"base"), new_values);
  }

  public fun upgrade_skill(_: &GameCap, hero: &mut Hero, new_values: vector<u16>) {
    hero::edit_fields<u16>(hero, string::utf8(b"skill"), new_values);
  }

  public fun upgrade_appearance(_: &GameCap, hero: &mut Hero, new_values: vector<u16>) {
    hero::edit_fields<u16>(hero, string::utf8(b"appearance"), new_values);
  }

  public fun upgrade_growth(_: &GameCap, hero: &mut Hero, new_values: vector<u16>) {
    hero::edit_fields<u16>(hero, string::utf8(b"growth"), new_values);
  }

  /// === Open gacha functions ===
  // Place the destroyed blind box
  fun put_gacha(gacha: GachaBall, gacha_ball_address: address, obj_burn: &mut ObjBurn) {
    dof::add<address, GachaBall>(&mut obj_burn.id, gacha_ball_address, gacha);
    // event
  }

  // The administrator destroys the blind box
  public fun get_gacha_and_burn(_: &GameCap, gacha_ball_address: address, obj_burn: &mut ObjBurn) {
    let gacha_ball = dof::remove<address, GachaBall>(&mut obj_burn.id, gacha_ball_address);
    gacha::burn(gacha_ball);
    // event
  }
  /// === Player functions ===

  /// open a gacha ball
  // User opens blind box
  public fun open_gacha_ball(gacha_ball: GachaBall, obj_burn: &mut ObjBurn, ctx: &mut TxContext){

    assert!(VERSION == 1, EIncorrectVersion); 

    let gacha_ball_id = gacha::id(&gacha_ball);
    let user = tx_context::sender(ctx);
    let type = *gacha::type(&gacha_ball);
    let gacha_ball_address: address = object::id_address(&gacha_ball);
    // burn gacha ball
    // gacha::burn(gacha_ball);
    put_gacha(gacha_ball, gacha_ball_address, obj_burn);

    // create and emit an event
    let open_evt = GachaBallOpened { id: gacha_ball_id, user, type };
    event::emit(open_evt);
  }

  // appearance_index is the index of the part inside the appearance vector
  // eg: eye is 0, appearance[0]
  public fun makeover_hero(
    main_hero: Hero,
    to_burn: Hero,
    appearance_index: u64,
    upgrader: &mut Upgrader,
    obj_burn: &mut ObjBurn,
    ctx: &mut TxContext) {
    assert!(VERSION == 1, EIncorrectVersion);
    assert!(
      appearance_index != 0 &&
      appearance_index != 4 &&
      appearance_index != 7 &&
      appearance_index <=10,
      EBodyPartCannotBeExchanged
    );

    let main_hero_part= vector::borrow(hero::appearance_values(&main_hero), appearance_index);
    let burn_hero_part= vector::borrow(hero::appearance_values(&to_burn), appearance_index);
    debug::print(main_hero_part);
    debug::print(burn_hero_part);
    assert!(*main_hero_part != *burn_hero_part, ESameAppearancePart);

    let evt = MakeoverRequest {
      hero_id: object::id_address(&main_hero),
      player_address: tx_context::sender(ctx),
      burned_hero_id: object::id_address(&to_burn),
      hero_part: appearance_index
    };
    event::emit(evt);
    //hero::burn(to_burn);
    let burn_hero_address = object::id_address(&to_burn);
    put_burn_hero(to_burn, burn_hero_address, obj_burn);
    put_hero(main_hero, tx_context::sender(ctx), 1, upgrader);
  }

  public fun upgrade_hero(
    main_hero: Hero,
    to_burn: vector<Hero>,
    upgrader: &mut Upgrader,
    obj_burn: &mut ObjBurn,
    ctx: &mut TxContext)
  {
    assert!(VERSION == 1, EIncorrectVersion);

    let l = vector::length<Hero>(&to_burn);
    assert!(l > 0, EMustBurnAtLeastOneHero);
    let main_rarity = hero::rarity(&main_hero);
    let i: u64 = 0;
    let burn_addresses: vector<address> = vector::empty<address>();
    while (i < l) {
      let burnable = vector::pop_back<Hero>(&mut to_burn);
      assert!(main_rarity == hero::rarity(& burnable), ERarityMismatch);
      // hero::burn(burnable);
      let burn_hero_address = object::id_address(&burnable);
      vector::push_back(&mut burn_addresses, burn_hero_address);
      put_burn_hero(burnable, burn_hero_address, obj_burn);
      i = i + 1;
    };
    vector::destroy_empty<Hero>(to_burn);
    // events
    let evt = UpgradeRequest {
      hero_id: object::id_address(&main_hero),
      player_address: tx_context::sender(ctx),
      burned_heroes: burn_addresses
    };
    event::emit(evt);
    put_hero(main_hero, tx_context::sender(ctx), l, upgrader);
    
  }

  public fun power_upgrade_hero(
    main_hero: Hero,
    to_burn: vector<Hero>,
    fee: Coin<ARCA>,
    upgrader: &mut Upgrader,
    obj_burn: &mut ObjBurn,
    ctx: &mut TxContext
  )
  {
    let l = vector::length<Hero>(&to_burn);
    assert!(l > 0, EMustBurnAtLeastOneHero);
    let main_rarity = hero::rarity(&main_hero);
    let correct_price: u64 = *table::borrow<String, u64>(&mut upgrader.power_prices, *main_rarity) * l;
    assert!(coin::value(&fee) == correct_price, EWrongPowerUpgradeFee);
    let i: u64 = 0;
    let burn_addresses: vector<address> = vector::empty<address>();
    while (i < l) {
      let burnable = vector::pop_back<Hero>(&mut to_burn);
      assert!(main_rarity == hero::rarity(& burnable), ERarityMismatch);
      // hero::burn(burnable);
      let burn_hero_address = object::id_address(&burnable);
      vector::push_back(&mut burn_addresses, burn_hero_address);
      put_burn_hero(burnable, burn_hero_address, obj_burn);
      i = i + 1;
    };
    vector::destroy_empty<Hero>(to_burn);

    let evt = PowerUpgradeRequest {
      hero_id: object::id_address(&main_hero),
      user: tx_context::sender(ctx),
      burned_heroes: burn_addresses,
      arca_payed: correct_price
    };

    event::emit(evt);

    put_power_hero(main_hero, tx_context::sender(ctx), l, fee, upgrader);
  }

  // whitelist claim
  public fun whitelist_claim(
    config: &mut GameConfig,
    ctx: &mut TxContext
  )
  {
    let sender: address = tx_context::sender(ctx);
    assert!(df::exists_<address>(&mut config.id, sender), ENotWhitelisted);
    let rewards = df::remove<address, WhitelistRewards>(&mut config.id, sender);
    let WhitelistRewards {heroes, gacha_balls} = rewards;
    while(vector::length(&heroes) > 0) {
      transfer::public_transfer(vector::pop_back<Hero>(&mut heroes), sender);
    };
    vector::destroy_empty<Hero>(heroes);
    while(vector::length(&gacha_balls) > 0) {
      transfer::public_transfer(vector::pop_back<GachaBall>(&mut gacha_balls), sender);
    };
    vector::destroy_empty<GachaBall>(gacha_balls);
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
      let base_attributes_values: vector<u16> = vector[1,2,3,4,5,6];
      let skill_attributes_values: vector<u16> = vector[31, 32, 33, 34];
      let appearance_attributes_values: vector<u16> = vector[21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31];
      let growth_attributes_values: vector<u16> = vector [0, 0, 0, 0, 0, 0, 0, 0];
      //let other_attributes_values: vector<u8> = vector[9];
      let external_id = string::utf8(b"1337");

      let hero = mint_hero(
        cap,
        name,
        class,
        faction,
        rarity,
        base_attributes_values,
        skill_attributes_values,
        appearance_attributes_values,
        growth_attributes_values,
        //other_attributes_values,
        external_id,
        ctx,
      );
      hero
  }

  #[test_only]
  public fun mint_test_gacha(cap: &GameCap, ctx: &mut TxContext): GachaBall {
    mint_gacha(
      cap,
      1000,
      string::utf8(b"Halloween"),
      string::utf8(b"Grandia"),
      string::utf8(b"VIP"),
      ctx
    )
  }
}