module loa_game::game{

  use std::string::{Self, String};
  use std::vector;
  use std::option;
  use std::type_name::{Self, TypeName};

  use sui::balance::{Self, Balance};
  use sui::coin::{Self, Coin};
  use sui::event;
  use sui::object::{Self, ID, UID};
  use sui::dynamic_field as df;
  use sui::dynamic_object_field as dof;
  use sui::table::{Self, Table};
  use sui::tx_context::{Self, TxContext};
  use sui::bcs;
  use sui::ecdsa_k1;
  use sui::clock::{Self, Clock};
  use sui::address;
  use sui::transfer::{Self, public_transfer};
  use sui::vec_map::{Self, VecMap};

  use loa_game::hero::{Self, Hero};
  use loa_game::gacha::{Self, GachaBall};
  use loa::arca::ARCA;
  use multisig::multisig::{Self, MultiSignature};

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
  const EGenderMismatch:u64 = 13;
  const EInvalidSignature: u64 = 14;
  const EInvalidSalt: u64 = 15;
  const ETimeExpired: u64 = 16;
  const ENotParticipant: u64 = 17;
  const ENotInMultiSigScope: u64 = 18;
  const ENeedVote: u64 = 19;
  const EInvalidAmount: u64 = 20;
  const EWrongDiscountExchagePayment: u64 = 21;
  const ECoinTypeNoExist: u64 = 22;
  const ECurrentTimeLTStartTime: u64 = 23;
  const ECurrentTimeGEEndTime: u64 = 24;
  const EInvalidType: u64 = 25;
  const EPriceEQZero: u64 = 26;
  const ECoinTypeMismatch: u64 = 27;


  //multisig type
  const WithdrawArca: u64 = 0;
  const WithdrawUpgradeProfits: u64 = 1;
  const WithdrawDiscountProfits: u64 = 2;

  // gacha type
  const Box: u64 = 1;
  const Voucher: u64 = 5;
  const Discount: u64 = 6;

  const Base:u64 = 10000;


  // config struct
  struct GameConfig has key, store {
    id: UID,
    game_address: address,
    mint_address: address,
    for_multi_sign: ID,
  }

  struct GachaConfigTable has key, store {
    id: UID,
    config: Table<u64, GachaConfig>,
    profits: Balance<ARCA>
  }

  struct GachaConfig has store, drop {
    gacha_token_type: vector<u64>,
    gacha_name: vector<String>,
    gacha_type: vector<String>,
    gacha_collction: vector<String>,
    gacha_description: vector<String>,

    coin_prices: VecMap<TypeName, u64>,
    start_time: u64,
    end_time: u64
  }

  //airdrop
  struct BoxTicket has key {
    id: UID,
    gacha_ball: GachaBall,
  }

  struct HeroTicket has key {
    id: UID,
    main_hero: Hero,
    burn_heroes: vector<Hero>,
    user: address
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

  struct WithdrawArcaQequest has key, store {
    id: UID,
    amount: u64,
    to: address
  }

  struct WithdrawUpgradeProfitsQequest has key, store {
    id: UID,
    to: address
  }

  struct WithdrawDiscountProfitsQequest has key, store {
    id: UID,
    coin_type: TypeName,
    to: address
  }

  // events
  struct GachaBallOpened has copy, drop {
    id: ID,
    user: address,
    ticket_id: ID,
    token_type: u64
  }

  struct UpgradeRequest has copy, drop {
    hero_id: address,
    user: address,
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
    user: address,
    burned_hero: address,
    ticket_id: ID,
    hero_part: u64
  }

  struct ChargeRequest has copy, drop {
    user: address,
    burned_heroes: vector<address>
  }

  struct AbandonNftEvent has copy, drop {
    user: address,
    nft:  address
  }

  struct VoucherExchanged has copy, drop {
    id: ID,
    token_type: u64,
    user: address,
    ticket_id: ID,
  }

  struct DiscountExchanged has copy, drop {
    id: ID,
    token_type: u64,
    user: address,
    ticket_id: ID,
    coin_type: TypeName,
    price: u64,
  }

  struct TicketBurned has copy, drop {
    ticket_id: ID,
  }

  struct UserDeposit has copy, drop {
    user: address,
    amount: u64
  }

  struct UserWithdraw has copy, drop {
    user: address,
    amount: u64,
    fee: u64,
    salt: u64
  }

  struct SetDiscountPriceEvent has copy, drop {
    token_type: u64,
    coin_type: TypeName,
    price: u64
  }

  struct RemoveDiscountPriceEvent has copy, drop {
    token_type: u64,
    coin_type: TypeName
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

    let multi_sig = multisig::create_multisig(ctx);
    let config = GameConfig {
      id: object::new(ctx),
      game_address: tx_context::sender(ctx),
      mint_address: tx_context::sender(ctx),
      for_multi_sign: object::id(&multi_sig)
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

    let gacha_config = GachaConfigTable{
      id: object::new(ctx),
      config: table::new<u64, GachaConfig>(ctx),
      profits: balance::zero<ARCA>(),
    };

    transfer::public_share_object(multi_sig);
    transfer::public_share_object(config);
    transfer::public_share_object(upgrader);
    transfer::public_share_object(objBurn);
    transfer::public_share_object(seen_messages);
    transfer::public_share_object(arca_counter);
    transfer::public_share_object(gacha_config);
    transfer::transfer(game_cap, tx_context::sender(ctx));
  }

  // === Game-only function ===
 
  /// set address that will claim gacha sell profits
  public fun set_game_address(_: &GameCap, new_address: address, config: &mut GameConfig) {
    config.game_address = new_address;
  }

  public fun set_mint_address(_: &GameCap, new_address: address, config: &mut GameConfig) {
    config.mint_address = new_address;
  }

  public fun set_upgrade_address(_: &GameCap, new_address: address, upgrader: &mut Upgrader) {
    upgrader.upgrade_address = new_address;
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

  public fun burn_box_ticket(box_ticket: BoxTicket) {
    let BoxTicket {id, gacha_ball} = box_ticket;
    gacha::burn(gacha_ball);

    event::emit(TicketBurned {ticket_id: object::uid_to_inner(&id)});
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
    event::emit(TicketBurned {ticket_id: object::uid_to_inner(&id)});
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

  fun withdraw_acra(amount: u64, to:address, arca_counter: &mut ArcaCounter, ctx: &mut TxContext) {
    let coin_balance = balance::split<ARCA>(&mut arca_counter.arca_balance, amount);

    transfer::public_transfer(coin::from_balance(coin_balance, ctx), to);
  }

  /// withdraw upgrade profits
  fun withdraw_upgrade_profits(upgrader: &mut Upgrader , to: address, ctx: &mut TxContext) {
    let total: Balance<ARCA> = balance::withdraw_all<ARCA>(&mut upgrader.profits);
    transfer::public_transfer(coin::from_balance(total, ctx), to);
  }

  /// withdraw discount profits
  fun withdraw_discount_profits<COIN>(config: &mut GachaConfigTable , to: address, ctx: &mut TxContext) {
    let coin_type = type_name::get<COIN>();
    let coin_balance = df::borrow_mut<TypeName, Balance<COIN>>(&mut config.id, coin_type);
    let balance_all = balance::withdraw_all<COIN>(coin_balance);
    transfer::public_transfer(coin::from_balance<COIN>(balance_all, ctx), to);
  }

  /// configure mugen_pk field of SeenMessages
  public fun set_mugen_pk(_: &GameCap, mugen_pk: vector<u8>, seen_messages: &mut SeenMessages) {
    seen_messages.mugen_pk = mugen_pk;
  }

  public fun add_gacha_config(
    _: &GameCap, gacha_config_tb: &mut GachaConfigTable, token_type:u64, gacha_token_type: vector<u64>,
    gacha_name: vector<String>, gacha_type: vector<String>, gacha_collction: vector<String>,
    gacha_description: vector<String>, start_time: u64, end_time: u64) {

    let config = GachaConfig {
      gacha_token_type,
      gacha_name,
      gacha_type,
      gacha_collction,
      gacha_description,
      coin_prices: vec_map::empty<TypeName, u64>(),
      start_time,
      end_time
    };

    table::add(&mut gacha_config_tb.config, token_type, config);
  }

  public fun remove_gacha_config(_: &GameCap, gacha_config_tb: &mut GachaConfigTable, token_type: u64) {
    if (table::contains(&gacha_config_tb.config, token_type)) {
      table::remove(&mut gacha_config_tb.config, token_type);
    };
  }

  public entry fun set_discount_price<COIN>(
    _: &GameCap,
    gacha_config_tb: &mut GachaConfigTable,
    token_type: u64,
    price: u64,
  ) {
    assert_price_gt_zero(price);
    let config = table::borrow_mut(&mut gacha_config_tb.config, token_type);
    let coin_type = type_name::get<COIN>();
    if (vec_map::contains(&config.coin_prices, &coin_type)) {
      let previous = vec_map::get_mut(&mut config.coin_prices, &coin_type);
      *previous = price;
    } else {
      vec_map::insert(&mut config.coin_prices, coin_type, price);
    };

    event::emit(SetDiscountPriceEvent {
      token_type,
      coin_type,
      price,
    });
  }

  public entry fun remove_discount_price<COIN>(
    _: &GameCap,
    gacha_config_tb: &mut GachaConfigTable,
    token_type: u64,
  ) {
    let config = table::borrow_mut(&mut gacha_config_tb.config, token_type);
    let coin_type = type_name::get<COIN>();
    if (vec_map::contains(&config.coin_prices, &coin_type)) {
      vec_map::remove(&mut config.coin_prices, &coin_type);
    };
    event::emit(RemoveDiscountPriceEvent {
      token_type,
      coin_type,
    });
  }

  public fun withdraw_arca_request(game_config:&mut GameConfig, multi_signature : &mut MultiSignature, amount: u64, to: address, ctx: &mut TxContext) {
    // Only multi sig guardian
    only_multi_sig_scope(multi_signature, game_config);
    // Only participant
    only_participant(multi_signature, ctx);

    let request = WithdrawArcaQequest{
      id: object::new(ctx),
      amount,
      to
    };

    let desc = sui::address::to_string(object::id_address(&request));

    multisig::create_proposal(multi_signature, *string::bytes(&desc), WithdrawArca, request, ctx);
  }

  public fun withdraw_arca_execute(
    game_config:&mut GameConfig,
    multi_signature : &mut MultiSignature,
    proposal_id: u256,
    is_approve: bool,
    arca_counter: &mut ArcaCounter,
    ctx: &mut TxContext): bool {

    only_multi_sig_scope(multi_signature, game_config);
    // Only participant
    only_participant(multi_signature, ctx);

    if (is_approve) {
      let (approved, _ ) = multisig::is_proposal_approved(multi_signature, proposal_id);
      if (approved) {
        let request = multisig::borrow_proposal_request<WithdrawArcaQequest>(multi_signature, &proposal_id, ctx);

        withdraw_acra(request.amount, request.to, arca_counter, ctx);
        multisig::multisig::mark_proposal_complete(multi_signature, proposal_id, ctx);
        return true
      };
    }else {
      let (rejected, _ ) = multisig::is_proposal_rejected(multi_signature, proposal_id);
      if (rejected) {
        multisig::multisig::mark_proposal_complete(multi_signature, proposal_id, ctx);
        return true
      }
    };

    abort ENeedVote
  }

  public fun withdraw_upgrade_profits_request(game_config:&mut GameConfig, multi_signature : &mut MultiSignature, to: address, ctx: &mut TxContext) {
    // Only multi sig guardian
    only_multi_sig_scope(multi_signature, game_config);
    // Only participant
    only_participant(multi_signature, ctx);

    let request = WithdrawUpgradeProfitsQequest{
      id: object::new(ctx),
      to
    };

    let desc = sui::address::to_string(object::id_address(&request));

    multisig::create_proposal(multi_signature, *string::bytes(&desc), WithdrawUpgradeProfits, request, ctx);
  }

  public fun withdraw_upgrade_profits_execute(
    game_config:&mut GameConfig,
    multi_signature : &mut MultiSignature,
    proposal_id: u256,
    is_approve: bool,
    upgrader: &mut Upgrader,
    ctx: &mut TxContext): bool {

    only_multi_sig_scope(multi_signature, game_config);
    // Only participant
    only_participant(multi_signature, ctx);

    if (is_approve) {
      let (approved, _ ) = multisig::is_proposal_approved(multi_signature, proposal_id);
      if (approved) {
        let request = multisig::borrow_proposal_request<WithdrawUpgradeProfitsQequest>(multi_signature, &proposal_id, ctx);

        withdraw_upgrade_profits(upgrader, request.to, ctx);
        multisig::multisig::mark_proposal_complete(multi_signature, proposal_id, ctx);
        return true
      };
    }else {
      let (rejected, _ ) = multisig::is_proposal_rejected(multi_signature, proposal_id);
      if (rejected) {
        multisig::multisig::mark_proposal_complete(multi_signature, proposal_id, ctx);
        return true
      }
    };

    abort ENeedVote
  }

  public fun withdraw_discount_profits_request<COIN>(game_config:&mut GameConfig, multi_signature : &mut MultiSignature, to: address, ctx: &mut TxContext) {
    // Only multi sig guardian
    only_multi_sig_scope(multi_signature, game_config);
    // Only participant
    only_participant(multi_signature, ctx);

    let coin_type = type_name::get<COIN>();
    let request = WithdrawDiscountProfitsQequest{
      id: object::new(ctx),
      coin_type,
      to
    };

    let desc = sui::address::to_string(object::id_address(&request));

    multisig::create_proposal(multi_signature, *string::bytes(&desc), WithdrawDiscountProfits, request, ctx);
  }

  public fun withdraw_discount_profits_execute<COIN>(
    game_config:&mut GameConfig,
    multi_signature : &mut MultiSignature,
    proposal_id: u256,
    is_approve: bool,
    gacha_config_tb: &mut GachaConfigTable,
    ctx: &mut TxContext): bool {

    only_multi_sig_scope(multi_signature, game_config);
    // Only participant
    only_participant(multi_signature, ctx);

    if (is_approve) {
      let (approved, _ ) = multisig::is_proposal_approved(multi_signature, proposal_id);
      if (approved) {
        let request = multisig::borrow_proposal_request<WithdrawDiscountProfitsQequest>(multi_signature, &proposal_id, ctx);

        assert!(request.coin_type == type_name::get<COIN>(), ECoinTypeMismatch);
        withdraw_discount_profits<COIN>(gacha_config_tb, request.to, ctx);
        multisig::multisig::mark_proposal_complete(multi_signature, proposal_id, ctx);
        return true
      };
    }else {
      let (rejected, _ ) = multisig::is_proposal_rejected(multi_signature, proposal_id);
      if (rejected) {
        multisig::multisig::mark_proposal_complete(multi_signature, proposal_id, ctx);
        return true
      }
    };

    abort ENeedVote
  }
  /// === Upgrader functions ===
  // place an upgraded hero

  // Admins return upgraded heroes
  public fun return_upgraded_hero_by_ticket(ticket: HeroTicket) {
    let HeroTicket {id, main_hero, burn_heroes, user} = ticket;
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
    
    transfer::public_transfer(main_hero, user);

    event::emit(TicketBurned {ticket_id: object::uid_to_inner(&id)});
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

  public fun upgrade_base_by_ticket(ticket: &mut HeroTicket, new_values: vector<u16>) {
    hero::edit_fields<u16>(&mut ticket.main_hero, string::utf8(b"base"), new_values);
  }

  public fun upgrade_skill_by_ticket(ticket: &mut HeroTicket, new_values: vector<u16>) {
    hero::edit_fields<u16>(&mut ticket.main_hero, string::utf8(b"skill"), new_values);
  }

  public fun upgrade_appearance_by_ticket(ticket: &mut HeroTicket, new_values: vector<u16>) {
    hero::edit_fields<u16>(&mut ticket.main_hero, string::utf8(b"appearance"), new_values);
  }

  public fun upgrade_growth_by_ticket(ticket: &mut HeroTicket, new_values: vector<u16>) {
    hero::edit_fields<u16>(&mut ticket.main_hero, string::utf8(b"growth"), new_values);
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
  public entry fun open_gacha_ball(gacha_ball: GachaBall, game_config: &GameConfig, ctx: &mut TxContext){

    assert!(VERSION == 1, EIncorrectVersion); 

    let gacha_ball_id = gacha::id(&gacha_ball);
    let user = tx_context::sender(ctx);
    //let type = *gacha::type(&gacha_ball);
    let token_type = *gacha::tokenType(&gacha_ball);
    assert!(token_type / Base == Box, EInvalidType);

    let ticket = BoxTicket{
      id: object::new(ctx),
      gacha_ball,
    };

    // create and emit an event
    let open_evt = GachaBallOpened { id: gacha_ball_id, user,ticket_id: object::uid_to_inner(&ticket.id), token_type };
    event::emit(open_evt);

    transfer::transfer(ticket, game_config.mint_address);
  }

  /// user can abandon garbage gacha ball
  public fun abandon_gacha_ball(gacha_ball: GachaBall, obj_burn: &mut ObjBurn, ctx: &mut TxContext){
    let nft = object::id_address(&gacha_ball);
    event::emit(AbandonNftEvent {user: tx_context::sender(ctx), nft});
    put_gacha(gacha_ball, nft, obj_burn);
  }

  /// user can abandon garbage hero
  public fun abandon_hero(hero: Hero, obj_burn: &mut ObjBurn,ctx: &mut TxContext){
    let nft = object::id_address(&hero);
    event::emit(AbandonNftEvent {user: tx_context::sender(ctx), nft});
    put_burn_hero(hero, nft, obj_burn);
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

    let main_hero_gender= vector::borrow(hero::base_values(&main_hero), 0);
    let burn_hero_gender= vector::borrow(hero::base_values(&to_burn), 0);
    assert!(*main_hero_gender == *burn_hero_gender, EGenderMismatch);
    let main_address = object::id_address(&main_hero);

    let ticket =  HeroTicket {
      id: object::new(ctx),
      main_hero,
      burn_heroes: vector::empty<Hero>(),
      user: tx_context::sender(ctx)
    };

    let evt = MakeoverRequest {
      hero_id: main_address,
      user: tx_context::sender(ctx),
      burned_hero: object::id_address(&to_burn),
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
    let ticket =  HeroTicket {
      id: object::new(ctx),
      main_hero,
      burn_heroes: vector::empty<Hero>(),
      user: tx_context::sender(ctx)
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


    // events
    let evt = UpgradeRequest {
      hero_id: main_address,
      user: tx_context::sender(ctx),
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
    let ticket =  HeroTicket {
      id: object::new(ctx),
      main_hero,
      burn_heroes: vector::empty<Hero>(),
      user: tx_context::sender(ctx)
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

  public fun voucher_exchange(
    voucher: GachaBall,
    gacha_config: &GachaConfigTable,
    clock: & Clock,
    game_config: &GameConfig,
    ctx: &mut TxContext)
  {
    let token_type = *gacha::tokenType(&voucher);
    assert!(token_type / Base == Voucher, EInvalidType);
    let config = table::borrow(&gacha_config.config, token_type);
    mint_gachas_by_config(config, tx_context::sender(ctx), clock, ctx);
    let id = object::id(&voucher);

    let ticket = BoxTicket{
      id: object::new(ctx),
      gacha_ball: voucher,
    };
    event::emit(VoucherExchanged{id, token_type, user: tx_context::sender(ctx), ticket_id: object::id(&ticket)});

    transfer::transfer(ticket, game_config.mint_address)
  }

  public fun discount_exchange<COIN>(
    discount: GachaBall,
    gacha_config_tb: &mut GachaConfigTable,
    payment: Coin<COIN>,
    clock: & Clock,
    game_config: &GameConfig,
    ctx: &mut TxContext)
  {
    let token_type = *gacha::tokenType(&discount);
    assert!(token_type / Base == Discount, EInvalidType);
    let config = table::borrow(&gacha_config_tb.config, token_type);

    let coin_type = type_name::get<COIN>();
    let (contain, price) = (false, 0);
    let priceVal = vec_map::try_get(&config.coin_prices, &coin_type);
    if (option::is_some(&priceVal)) {
      contain = true;
      price = *option::borrow(&priceVal);
    };
    assert_coin_type_exist(contain);
    assert_price_gt_zero(price);
    let coin_value: u64 = coin::value(&payment);
    assert!(coin_value >= price, EWrongDiscountExchagePayment);
    if (coin_value > price) {
      transfer::public_transfer(coin::split(&mut payment, coin_value - price, ctx), tx_context::sender(ctx));
    };
    if (df::exists_with_type<TypeName, Balance<COIN>>(&mut gacha_config_tb.id, coin_type)) {
      let coin_balance = df::borrow_mut<TypeName, Balance<COIN>>(&mut gacha_config_tb.id, coin_type);
      balance::join<COIN>(coin_balance, coin::into_balance<COIN>(payment));
    } else {
      df::add<TypeName, Balance<COIN>>(&mut gacha_config_tb.id, coin_type, coin::into_balance<COIN>(payment));
    };

    mint_gachas_by_config(config, tx_context::sender(ctx), clock, ctx);
    let id = object::id(&discount);

    let ticket = BoxTicket{
      id: object::new(ctx),
      gacha_ball: discount,
    };

    event::emit(DiscountExchanged{
      id,
      token_type,
      user: tx_context::sender(ctx),
      ticket_id: object::id(&ticket),
      coin_type,
      price,
    });

    transfer::transfer(ticket, game_config.mint_address)
  }

  fun mint_gachas_by_config(config: &GachaConfig, to: address, clock: &Clock, ctx: &mut TxContext) {
    let current_time = clock::timestamp_ms(clock) / 1000;

    assert_current_time_ge_start_time(current_time, config.start_time);
    assert_current_time_lt_end_time(current_time, config.end_time);

    let gacha_length = vector::length(&config.gacha_token_type);
    let i = 0;
    while (i < gacha_length) {
      let gacha_token_type = *vector::borrow(&config.gacha_token_type, i);
      let gacha_name = *vector::borrow(&config.gacha_name, i);
      let gacha_type = *vector::borrow(&config.gacha_type, i);
      let gacha_collction = *vector::borrow(&config.gacha_collction, i);
      let gacha_description = *vector::borrow(&config.gacha_description, i);
      let gacha_ball = gacha::mint(
        gacha_token_type,
        gacha_name,
        gacha_type,
        gacha_collction,
        gacha_description,
        ctx,
      );
      public_transfer(gacha_ball, to);
      i = i + 1;
    };
  }

  public fun deposit(payment: Coin<ARCA>, arca_counter: &mut ArcaCounter, ctx: &mut TxContext) {
    let amount = coin::value(&payment);
    assert!(amount > 0, EInvalidAmount);
    balance::join(&mut arca_counter.arca_balance, coin::into_balance<ARCA>(payment));

    event::emit(UserDeposit{user: tx_context::sender(ctx), amount});
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

  // === check permission functions ===

  public fun only_participant (multi_signature: &MultiSignature, tx: &mut TxContext) {
    assert!(multisig::is_participant(multi_signature, tx_context::sender(tx)), ENotParticipant);
  }

  public fun only_multi_sig_scope (multi_signature: &MultiSignature, game_congif: &GameConfig) {
    assert!(object::id(multi_signature) == game_congif.for_multi_sign, ENotInMultiSigScope);
  }

  // === assert ===
  fun assert_coin_type_exist(contain: bool) {
    assert!(contain, ECoinTypeNoExist);
  }

  fun assert_current_time_ge_start_time(current_time: u64, start_time: u64) {
    if (start_time > 0) {
      assert!(current_time >= start_time, ECurrentTimeLTStartTime);
    };
  }

  fun assert_current_time_lt_end_time(current_time: u64, end_time: u64) {
    if (end_time > 0) {
      assert!(current_time < end_time, ECurrentTimeGEEndTime);
    };
  }

  fun assert_price_gt_zero(price: u64) {
    assert!(price > 0, EPriceEQZero);
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
      10000,
      string::utf8(b"Halloween"),
      string::utf8(b"Grandia"),
      string::utf8(b"VIP"),
      string::utf8(b"test gacha"),
      ctx
    )
  }

  #[test_only]
  public fun mint_test_voucher(cap: &GameCap, ctx: &mut TxContext): GachaBall {
    mint_gacha(
      cap,
      50000,
      string::utf8(b"Halloween"),
      string::utf8(b"Voucher"),
      string::utf8(b"Voucher"),
      string::utf8(b"test Voucher"),
      ctx
    )
  }

  #[test_only]
  public fun mint_test_discount(cap: &GameCap, ctx: &mut TxContext): GachaBall {
    mint_gacha(
      cap,
      69999,
      string::utf8(b"Halloween"),
      string::utf8(b"Discount"),
      string::utf8(b"Discount"),
      string::utf8(b"test Discount"),
      ctx
    )
  }
}