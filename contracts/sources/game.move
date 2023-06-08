module contracts::game{

  use std::string::{String, utf8};
  use std::option;

  use sui::coin::{Self, Coin};
  use sui::event;
  use sui::object::{Self, ID, UID};
  use sui::dynamic_field as df;
  use sui::vec_map::{Self, VecMap};
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};

  // use contracts::arca::ARCA;
  use contracts::hero::{Self, Hero};
  use contracts::gacha::{Self, GachaBall};

  const VERSION: u64 = 1;

  // errors
  const EAmountNotExact: u64 = 0;
  const ECoinNotAllowed: u64 = 1;
  const ETypeDoesNotExist: u64 = 2;
  const EIncorrectVersion: u64 = 3;

  // config struct
  struct GameConfig has key, store {
    id: UID,
    caps_created: u64,
    game_address: address
  }

  // event for when a gacha ball is opened
  struct GachaBallOpened has copy, drop {
    id: ID,
    // address of user that opened the ball
    user: address,
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

    let config = GameConfig {
      id: object::new(ctx),
      caps_created: 1,
      game_address: tx_context::sender(ctx)

    };

    transfer::public_share_object(config);
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
    vec_map::insert<String, u64>(prices, utf8(b"elite"), elite_price);
    vec_map::insert<String, u64>(prices, utf8(b"legendary"), legendary_price);
    vec_map::insert<String, u64>(prices, utf8(b"epic"), epic_price);
    vec_map::insert<String, u64>(prices, utf8(b"vip"), vip_price);
  }

  /// change recipient address of the gacha ball profits
  public fun set_game_address(_: &GameCap, config: &mut GameConfig, new: address) {
    config.game_address = new;
  }

  public fun admin_mint_hero(
      _: &GameCap, 
      name: String,
      class: String,
      factions: String,
      skill: String,
      rarity: String,
      external_id: String,
      ctx: &mut TxContext
    ): Hero {

      let hero = hero::mint_hero(name, class, factions, skill, rarity, external_id, ctx);
      hero
    }
  
  public fun admin_mint_gacha(
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

  // === Test-only ===

  #[test_only]
  public fun init_for_test(ctx: &mut TxContext) {
    let config = GameConfig {
      id: object::new(ctx),
      caps_created: 0,
      game_address: tx_context::sender(ctx)
    };
    let cap = GameCap {
      id: object::new(ctx)
    };
    transfer::public_share_object(config);
    transfer::public_transfer(cap, tx_context::sender(ctx));
  }
}

#[test_only]
module contracts::test_game {
  use std::string::{utf8, String};

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
    vec_map::insert<String, u64>(sui_prices, utf8(b"rare"), 10_000_000_000);
    vec_map::insert<String, u64>(sui_prices, utf8(b"legendary"), 20_000_000_000);
    ts::return_shared(config);
    ts::return_to_sender(&scenario, cap);
  };

  ts::next_tx(&mut scenario, USER);
  {
    let config = ts::take_shared<GameConfig>(&mut scenario);
    let payment = coin::mint_for_testing<SUI>(10_000_000_000, ts::ctx(&mut scenario));
    let type: String = utf8(b"rare");
    let collection: String = utf8(b"New Collection");
    let name: String = utf8(b"Cool Gacha");

    let gacha = game::buy_gacha(&mut config, payment, type, collection, name, ts::ctx(&mut scenario));
    transfer::public_transfer(gacha, USER);
    ts::return_shared(config);
  };

  ts::end(scenario);
 }

}