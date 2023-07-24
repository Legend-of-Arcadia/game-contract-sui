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
  use sui::bcs;
  use sui::ecdsa_k1;
  use sui::clock::{Self, Clock};
  use sui::address;

  use loa::arca::ARCA;
  use contracts::hero::{Self, Hero};
  use contracts::gacha::{Self, GachaBall};
  use contracts::item::{Self, Item};

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
  const ENoGameAdmin:u64 = 12;
  const EGenderismatch:u64 = 13;
  const EInvalidSignature: u64 = 14;
  const EInvalidSalt: u64 = 15;
  const ETimeExpired: u64 = 16;

  // config struct
  struct GameConfig has key, store {
    id: UID,
    game_address: address,
    mint_address: address,
  }

  //airdrop
  struct BoxTicket has key {
    id: UID,
    gacha_ball: GachaBall,
  }

  struct UpgradeTicket has key {
    id: UID,
    main_hero: Hero,
    burn_heroes: vector<Hero>,
    user_address: address
  }

  // upgrader and hot potato
  struct Upgrader has key, store {
    id: UID,
    upgrade_address: address,
    power_prices: Table<String, u64>,
    profits: Balance<ARCA>
  }

  // At present, the blind boxes and heroes that I need to destroy are all stored in this object
  struct ObjBurn has key, store {
    id: UID
  }

  struct SeenMessages has key, store {
    id: UID,
    mugen_pk: vector<u8>,
    salt_table: Table<u64, bool>
  }

  struct ArcaCounter has key, store {
    id: UID,
    arca_balance : Balance<ARCA>
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
    ticket_id: ID,
    token_type: u64
  }

  struct UpgradeRequest has copy, drop {
    hero_id: address,
    user_address: address,
    burned_heroes: vector<address>,
    ticket_id: ID,
  }

  struct PowerUpgradeRequest has copy, drop {
    hero_id: address,
    user: address,
    burned_heroes: vector<address>,
    ticket_id: ID,
    arca_payed: u64
  }

  struct MakeoverRequest has copy, drop {
    hero_id: address,
    user_address: address,
    burned_hero_id: address,
    ticket_id: ID,
    hero_part: u64
  }

  struct ChargeRequest has copy, drop {
    user: address,
    burned_heroes: vector<address>
  }

  struct BoxTicketBurn has copy, drop {
    box_ticket_id: ID,
    gacha_ball_id: ID
  }

  struct UserDeposit has copy, drop {
    depositer: address,
    amount: u64
  }

  struct UserWithdraw has copy, drop {
    user: address,
    amount: u64,
    fee: u64,
    salt: u64
  }

  struct GameCap has key {
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
      upgrade_address: tx_context::sender(ctx),
      power_prices: power_upgrade_prices,
      profits: balance::zero<ARCA>()
    };

    let config = GameConfig {
      id: object::new(ctx),
      game_address: tx_context::sender(ctx),
      mint_address: tx_context::sender(ctx),
    };

    let objBurn = ObjBurn {
      id: object::new(ctx),
    };

    let seen_messages = SeenMessages {
      id: object::new(ctx),
      mugen_pk: vector::empty<u8>(),
      salt_table: table::new<u64, bool>(ctx)
    };

    let arca_counter = ArcaCounter{
      id: object::new(ctx),
      arca_balance: balance::zero<ARCA>()
    };

    transfer::public_share_object(config);
    transfer::public_share_object(upgrader);
    transfer::public_share_object(objBurn);
    transfer::public_share_object(seen_messages);
    transfer::public_share_object(arca_counter);
    transfer::transfer(game_cap, tx_context::sender(ctx));
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
    user_address: address,
    hero_rewards: vector<Hero>,
    gacha_rewards:vector<GachaBall>,
    config: &mut GameConfig)
  {
    let rewards = WhitelistRewards {
      heroes: hero_rewards,
      gacha_balls: gacha_rewards
    };
    df::add<address, WhitelistRewards>(&mut config.id, user_address, rewards);
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
      external_id,
      ctx,
    );

    hero
  }

  public fun mint_hero_by_ticket(
    box_ticket: BoxTicket,
    name: String,
    class: String,
    faction: String,
    rarity: String,
    base_attributes_values: vector<u16>,
    skill_attributes_values: vector<u16>,
    appearence_attributes_values: vector<u16>,
    growth_attributes_values: vector<u16>,
    external_id: String,
    ctx: &mut TxContext
  ): Hero {
    burn_box_ticket(box_ticket);
    let hero = hero::mint(
      name,
      class,
      faction,
      rarity,
      base_attributes_values,
      skill_attributes_values,
      appearence_attributes_values,
      growth_attributes_values,
      external_id,
      ctx,
    );

    hero
  }

  // For casting blind boxes, a new id attribute is added. Use type or id to distinguish the level of blind boxes?
  // The content described in display is currently fixed, whether to use the parameters passed in
  public fun mint_gacha(
    _: &GameCap,
    token_type: u64,
    collection: String,
    name: String,
    type: String,
    description: String,
    ctx: &mut TxContext
  ): GachaBall {

    let gacha_ball = gacha::mint(token_type, collection, name, type, description, ctx);

    gacha_ball
  }

  // For casting items, use type to distinguish types of avatars, medals, etc., or add item id attributes
  public fun mint_item(
    _: &GameCap,
    token_type: u64,
    collection: String,
    name: String,
    type: String,
    description: String,
    ctx: &mut TxContext
  ): Item {

    let item = item::mint(token_type, collection, name, type, description, ctx);

    item
  }

  public fun burn_box_ticket(box_ticket: BoxTicket) {
    let BoxTicket {id, gacha_ball} = box_ticket;
    event::emit(BoxTicketBurn {box_ticket_id: object::uid_to_inner(&id), gacha_ball_id: object::id(&gacha_ball)});
    gacha::burn(gacha_ball);
    object::delete(id);
  }

  public fun create_game_cap_by_admin(config: &GameConfig, ctx: &mut TxContext){
    assert!(config.game_address == tx_context::sender(ctx), ENoGameAdmin);
    let game_cap = GameCap { id: object::new(ctx) };
    transfer::transfer(game_cap, config.game_address);
  }

  // burn the game cap
  public fun burn_game_cap(game_cap: GameCap){
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
      i = i + 1;
    }
  }

  public fun add_acra(_: &GameCap, payment: Coin<ARCA>, arca_counter: &mut ArcaCounter) {
    balance::join(&mut arca_counter.arca_balance, coin::into_balance<ARCA>(payment));
  }

  public fun withdraw_acra(_: &GameCap, amoount: u64, arca_counter: &mut ArcaCounter, ctx: &mut TxContext) : Coin<ARCA> {
    let coin_balance = balance::split<ARCA>(&mut arca_counter.arca_balance, amoount);
    coin::from_balance(coin_balance, ctx)
  }

  /// configure mugen_pk field of SeenMessages
  public fun set_mugen_pk(_: &GameCap, mugen_pk: vector<u8>, seen_messages: &mut SeenMessages) {
    seen_messages.mugen_pk = mugen_pk;
  }
  /// === Upgrader functions ===
  // place an upgraded hero

  // Admins return upgraded heroes
  public fun return_upgraded_hero_by_ticket(upgrade_ticket: UpgradeTicket) {
    let UpgradeTicket{id, main_hero, burn_heroes, user_address} = upgrade_ticket;
    let l = vector::length(&burn_heroes);
    let i = 0;
    if (l > 0) {
      while (i < l) {
        let burn_hero = vector::pop_back(&mut burn_heroes);
        hero::burn(burn_hero);
        i = i + 1;
      };
    };

    vector::destroy_empty<Hero>(burn_heroes);
    
    transfer::public_transfer(main_hero, user_address);

    object::delete(id);
  }

  // place destroyed hero
  fun put_burn_hero(hero: Hero, hero_address: address, obj_burn: &mut ObjBurn) {
    dof::add<address, Hero>(&mut obj_burn.id, hero_address, hero);
    // event
  }

  // admin burn hero
  public fun get_hero_and_burn(_: &GameCap, hero_address: address, obj_burn: &mut ObjBurn) {
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

  public fun upgrade_base_by_ticket(upgrade_ticket: &mut UpgradeTicket, new_values: vector<u16>) {
    hero::edit_fields<u16>(&mut upgrade_ticket.main_hero, string::utf8(b"base"), new_values);
  }

  public fun upgrade_skill_by_ticket(upgrade_ticket: &mut UpgradeTicket, new_values: vector<u16>) {
    hero::edit_fields<u16>(&mut upgrade_ticket.main_hero, string::utf8(b"skill"), new_values);
  }

  public fun upgrade_appearance_by_ticket(upgrade_ticket: &mut UpgradeTicket, new_values: vector<u16>) {
    hero::edit_fields<u16>(&mut upgrade_ticket.main_hero, string::utf8(b"appearance"), new_values);
  }

  public fun upgrade_growth_by_ticket(upgrade_ticket: &mut UpgradeTicket, new_values: vector<u16>) {
    hero::edit_fields<u16>(&mut upgrade_ticket.main_hero, string::utf8(b"growth"), new_values);
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
  public fun open_gacha_ball(gacha_ball: GachaBall, game_config: &GameConfig, ctx: &mut TxContext){

    assert!(VERSION == 1, EIncorrectVersion); 

    let gacha_ball_id = gacha::id(&gacha_ball);
    let user = tx_context::sender(ctx);
    //let type = *gacha::type(&gacha_ball);
    let token_type = *gacha::tokenType(&gacha_ball);

    let ticket = BoxTicket{
      id: object::new(ctx),
      gacha_ball,
    };

    // create and emit an event
    let open_evt = GachaBallOpened { id: gacha_ball_id, user,ticket_id: object::uid_to_inner(&ticket.id), token_type };
    event::emit(open_evt);

    transfer::transfer(ticket, game_config.game_address);
  }

  // appearance_index is the index of the part inside the appearance vector
  // eg: eye is 0, appearance[0]
  public fun makeover_hero(
    main_hero: Hero,
    to_burn: Hero,
    appearance_index: u64,
    upgrader: &mut Upgrader,
    ctx: &mut TxContext) {
    assert!(VERSION == 1, EIncorrectVersion);
    assert!(
      appearance_index != 0 &&
      appearance_index != 4 &&
      appearance_index != 7 &&
      appearance_index <=9,
      EBodyPartCannotBeExchanged
    );

    let main_hero_part= vector::borrow(hero::appearance_values(&main_hero), appearance_index);
    let burn_hero_part= vector::borrow(hero::appearance_values(&to_burn), appearance_index);
    assert!(*main_hero_part != *burn_hero_part, ESameAppearancePart);

    let main_hero_gender= vector::borrow(hero::base_values(&main_hero), 2);
    let burn_hero_gender= vector::borrow(hero::base_values(&to_burn), 2);
    assert!(*main_hero_gender == *burn_hero_gender, EGenderismatch);
    let main_address = object::id_address(&main_hero);

    let ticket =  UpgradeTicket{
      id: object::new(ctx),
      main_hero,
      burn_heroes: vector::empty<Hero>(),
      user_address: tx_context::sender(ctx)
    };

    let evt = MakeoverRequest {
      hero_id: main_address,
      user_address: tx_context::sender(ctx),
      burned_hero_id: object::id_address(&to_burn),
      ticket_id: object::uid_to_inner(&ticket.id),
      hero_part: appearance_index
    };
    event::emit(evt);

    vector::push_back(&mut ticket.burn_heroes, to_burn);

    transfer::transfer(ticket, upgrader.upgrade_address);
  }

  public fun upgrade_hero(
    main_hero: Hero,
    to_burn: vector<Hero>,
    upgrader: &mut Upgrader,
    ctx: &mut TxContext)
  {
    assert!(VERSION == 1, EIncorrectVersion);

    let l = vector::length<Hero>(&to_burn);
    assert!(l > 0, EMustBurnAtLeastOneHero);
    let main_rarity = *hero::rarity(&main_hero);
    let i: u64 = 0;
    let burn_addresses: vector<address> = vector::empty<address>();
    let main_address = object::id_address(&main_hero);
    let ticket =  UpgradeTicket{
      id: object::new(ctx),
      main_hero,
      burn_heroes: vector::empty<Hero>(),
      user_address: tx_context::sender(ctx)
    };
    while (i < l) {
      let burnable = vector::pop_back<Hero>(&mut to_burn);
      assert!(main_rarity == *hero::rarity(& burnable), ERarityMismatch);
      // hero::burn(burnable);
      let burn_hero_address = object::id_address(&burnable);
      vector::push_back(&mut burn_addresses, burn_hero_address);
      vector::push_back(&mut ticket.burn_heroes, burnable);
      //put_burn_hero(burnable, burn_hero_address, obj_burn);
      i = i + 1;
    };
    vector::destroy_empty<Hero>(to_burn);


    // events
    let evt = UpgradeRequest {
      hero_id: main_address,
      user_address: tx_context::sender(ctx),
      burned_heroes: burn_addresses,
      ticket_id: object::uid_to_inner(&ticket.id),
    };
    event::emit(evt);
    transfer::transfer(ticket, upgrader.upgrade_address);
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
    let main_rarity = *hero::rarity(&main_hero);
    let correct_price: u64 = *table::borrow<String, u64>(&mut upgrader.power_prices, main_rarity) * l;
    let fee_value: u64 = coin::value(&fee);
    assert!(fee_value >= correct_price, EWrongPowerUpgradeFee);
    if (fee_value > correct_price) {
      transfer::public_transfer(coin::split(&mut fee, fee_value - correct_price, ctx), tx_context::sender(ctx));
    };
    balance::join<ARCA>(&mut upgrader.profits, coin::into_balance<ARCA>(fee));

    let i: u64 = 0;
    let main_address = object::id_address(&main_hero);
    let burn_addresses: vector<address> = vector::empty<address>();
    let ticket =  UpgradeTicket{
      id: object::new(ctx),
      main_hero,
      burn_heroes: vector::empty<Hero>(),
      user_address: tx_context::sender(ctx)
    };
    while (i < l) {
      let burnable = vector::pop_back<Hero>(&mut to_burn);
      assert!(main_rarity == *hero::rarity(& burnable), ERarityMismatch);
      let burn_hero_address = object::id_address(&burnable);
      vector::push_back(&mut burn_addresses, burn_hero_address);
      vector::push_back(&mut ticket.burn_heroes, burnable);
      i = i + 1;
    };
    vector::destroy_empty<Hero>(to_burn);

    let evt = PowerUpgradeRequest {
      hero_id: main_address,
      user: tx_context::sender(ctx),
      burned_heroes: burn_addresses,
      ticket_id: object::uid_to_inner(&ticket.id),
      arca_payed: correct_price
    };

    event::emit(evt);

    //put_power_hero(main_hero, tx_context::sender(ctx), l, fee, upgrader);
    transfer::transfer(ticket, upgrader.upgrade_address);
  }

  public fun charge_hero(to_burn: vector<Hero>, obj_burn: &mut ObjBurn, ctx: &mut TxContext){
    let l = vector::length<Hero>(&to_burn);
    let i: u64 = 0;
    let burn_addresses: vector<address> = vector::empty<address>();
    while (i < l) {
      let burnable = vector::pop_back<Hero>(&mut to_burn);
      let burn_hero_address = object::id_address(&burnable);
      vector::push_back(&mut burn_addresses, burn_hero_address);
      put_burn_hero(burnable, burn_hero_address, obj_burn);
      i = i + 1;
    };
    vector::destroy_empty<Hero>(to_burn);

    let evt = ChargeRequest {
      user: tx_context::sender(ctx),
      burned_heroes: burn_addresses
    };

    event::emit(evt);
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


  public fun deposit(payment: Coin<ARCA>, arca_counter: &mut ArcaCounter, ctx: &mut TxContext) {
    let amount = coin::value(&payment);
    assert!(amount > 0, 1);
    balance::join(&mut arca_counter.arca_balance, coin::into_balance<ARCA>(payment));

    event::emit(UserDeposit{depositer: tx_context::sender(ctx), amount});
  }

  public fun withdraw(
    arca_counter: &mut ArcaCounter,
    amount: u64,
    expire_at: u64,
    salt: u64,
    fee: u64,
    chain_id: u64,
    package_address: address,
    signed_message: vector<u8>,
    seen_messages: &mut SeenMessages,
    clock: & Clock,
    ctx: &mut TxContext,
  ): Coin<ARCA> {
    assert!(expire_at >= clock::timestamp_ms(clock) / 1000, ETimeExpired);
    let user_address = tx_context::sender(ctx);
    let msg: vector<u8> = address::to_bytes(user_address);
    vector::append(&mut msg, bcs::to_bytes<u64>(&amount));
    vector::append(&mut msg, bcs::to_bytes<u64>(&expire_at));
    vector::append(&mut msg, bcs::to_bytes<u64>(&salt));
    vector::append(&mut msg, bcs::to_bytes<u64>(&fee));
    vector::append(&mut msg, bcs::to_bytes<u64>(&chain_id));
    vector::append(&mut msg, address::to_bytes(package_address));

    // assert that signature verifies
    // 1 is for SHA256 (hash function options in signature)
    assert!(ecdsa_k1::secp256k1_verify(&signed_message, &seen_messages.mugen_pk, &msg, 1), EInvalidSignature);
    assert!(!table::contains(&seen_messages.salt_table, salt), EInvalidSalt);
    table::add(&mut seen_messages.salt_table, salt, true);
    let coin_balance = balance::split<ARCA>(&mut arca_counter.arca_balance, amount - fee);

    event::emit(UserWithdraw{
      user: user_address,
      amount,
      salt,
      fee
    });
    coin::from_balance(coin_balance, ctx)
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
      string::utf8(b"test gacha"),
      ctx
    )
  }
}