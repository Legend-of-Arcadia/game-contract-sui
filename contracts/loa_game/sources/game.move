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
  const ETimeSet: u64 = 8;
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
  const EVectorLen: u64 = 28;
  const ENotUpgrade: u64 = 29;



  //multisig type
  const WithdrawArca: u64 = 0;
  const WithdrawUpgradeProfits: u64 = 1;
  const WithdrawDiscountProfits: u64 = 2;

  // gacha type
  // const Box: u64 = 1;
  // const Voucher: u64 = 5;
  // const Discount: u64 = 6;

  const Base:u64 = 10000;


  // config struct
  struct GameConfig has key, store {
    id: UID,
    game_address: address,
    mint_address: address,
    for_multi_sign: ID,
    version: u64,
  }

  struct GachaConfigTable has key, store {
    id: UID,
    config: Table<u64, GachaConfig>,
    profits: Balance<ARCA>,
    gacha_info: Table<u64, GachaInfo>,
    version: u64,
  }

  struct GachaInfo has store, drop {
    gacha_name: String,
    gacha_type: String,
    gacha_collction: String,
    gacha_description: String,
  }

  struct GachaConfig has store, drop {
    gacha_token_types: vector<u64>,
    gacha_amounts: vector<u64>,
    coin_prices: VecMap<TypeName, u64>,
    start_time: u64,
    end_time: u64
  }

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
    profits: Balance<ARCA>,
    version: u64,
  }

  // At present, the blind boxes and heroes that I need to destroy are all stored in this object
  struct ObjBurn has key, store {
    id: UID,
    version: u64,
  }

  struct SeenMessages has key, store {
    id: UID,
    mugen_pk: vector<u8>,
    salt_table: Table<u64, bool>,
    version: u64,
  }

  struct ArcaCounter has key, store {
    id: UID,
    arca_balance : Balance<ARCA>,
    version: u64,
  }

  struct WhitelistRewards has store {
    heroes: vector<Hero>,
    gacha_balls: vector<GachaBall>
  }

  struct WithdrawArcaRequest has key, store {
    id: UID,
    amount: u64,
    to: address
  }

  struct WithdrawUpgradeProfitsRequest has key, store {
    id: UID,
    to: address
  }

  struct WithdrawDiscountProfitsRequest has key, store {
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

  struct UserWithdrawGacha has copy, drop {
    user: address,
    token_type: u64,
    amount: u64,
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

  struct SetGameAddressEvent has copy, drop {
    new_address: address
  }

  struct SetMintAddressEvent has copy, drop {
    new_address: address
  }

  struct SetUpgradeAddressEvent has copy, drop {
    new_address: address
  }

  struct SetMugenPkEvent has copy, drop {
    mugen_pk: vector<u8>
  }

  struct AddGachaConfigEvent has copy, drop {
    token_type:u64,
    gacha_token_types: vector<u64>,
    gacha_amounts: vector<u64>,
    start_time: u64,
    end_time: u64
  }

  struct RemoveGachaConfigEvent has copy, drop {
    token_type: u64
  }

  struct AddGachaInfoEvent has copy, drop {
    token_type:u64,
    gacha_name: String,
    gacha_type: String,
    gacha_collction: String,
    gacha_description: String
  }

  struct RemoveGachaInfoEvent has copy, drop {
    token_type: u64
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
      profits: balance::zero<ARCA>(),
      version: VERSION,
    };

    let multi_sig = multisig::create_multisig(ctx);
    let config = GameConfig {
      id: object::new(ctx),
      game_address: tx_context::sender(ctx),
      mint_address: tx_context::sender(ctx),
      for_multi_sign: object::id(&multi_sig),
      version: VERSION,
    };

    let objBurn = ObjBurn {
      id: object::new(ctx),
      version: VERSION,
    };

    let seen_messages = SeenMessages {
      id: object::new(ctx),
      mugen_pk: vector::empty<u8>(),
      salt_table: table::new<u64, bool>(ctx),
      version: VERSION,
    };

    let arca_counter = ArcaCounter{
      id: object::new(ctx),
      arca_balance: balance::zero<ARCA>(),
      version: VERSION,
    };

    let gacha_config = GachaConfigTable{
      id: object::new(ctx),
      config: table::new<u64, GachaConfig>(ctx),
      profits: balance::zero<ARCA>(),
      gacha_info: table::new<u64, GachaInfo>(ctx),
      version: VERSION,
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
  public entry fun set_game_address(_: &GameCap, new_address: address, config: &mut GameConfig) {
    assert!(VERSION == config.version, EIncorrectVersion);
    config.game_address = new_address;

    event::emit(SetGameAddressEvent{new_address});
  }

  public entry fun set_mint_address(_: &GameCap, new_address: address, config: &mut GameConfig) {
    assert!(VERSION == config.version, EIncorrectVersion);
    config.mint_address = new_address;

    event::emit(SetMintAddressEvent{new_address});
  }

  public entry fun set_upgrade_address(_: &GameCap, new_address: address, upgrader: &mut Upgrader) {
    assert!(VERSION == upgrader.version, EIncorrectVersion);
    upgrader.upgrade_address = new_address;

    event::emit(SetUpgradeAddressEvent{new_address});
  }

  // TODO: Each address can get more than one rewards
  /// whitelist add addresses and corresponding rewards
  public entry fun whitelist_add(
    _: &GameCap,
    user_address: address,
    hero_rewards: vector<Hero>,
    gacha_rewards:vector<GachaBall>,
    config: &mut GameConfig)
  {
    assert!(VERSION == config.version, EIncorrectVersion);
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

  public entry fun burn_box_ticket(box_ticket: BoxTicket) {
    let BoxTicket {id, gacha_ball} = box_ticket;
    gacha::burn(gacha_ball);

    event::emit(TicketBurned {ticket_id: object::uid_to_inner(&id)});
    object::delete(id);
  }

  public entry fun create_game_cap_by_admin(config: &GameConfig, ctx: &mut TxContext){
    assert!(VERSION == config.version, EIncorrectVersion);
    assert!(config.game_address == tx_context::sender(ctx), ENoGameAdmin);
    let game_cap = GameCap { id: object::new(ctx) };
    transfer::transfer(game_cap, config.game_address);
  }

  // burn the game cap
  public entry fun burn_game_cap(game_cap: GameCap){
    let GameCap { id } = game_cap;
    event::emit(TicketBurned {ticket_id: object::uid_to_inner(&id)});
    object::delete(id); 
  }

  // Set the cost of power upgrades
  public entry fun set_upgrade_price(_: &GameCap, upgrader: &mut Upgrader , keys: vector<String>, values: vector<u64>){
    assert!(VERSION == upgrader.version, EIncorrectVersion);
    let i = 0;
    let len = vector::length(&keys);
    assert!(len == vector::length(&values), EVectorLen);
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

  public entry fun add_arca(_: &GameCap, payment: Coin<ARCA>, arca_counter: &mut ArcaCounter) {
    assert!(VERSION == arca_counter.version, EIncorrectVersion);
    balance::join(&mut arca_counter.arca_balance, coin::into_balance<ARCA>(payment));
  }

  fun withdraw_arca(amount: u64, to:address, arca_counter: &mut ArcaCounter, ctx: &mut TxContext) {
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
  public entry fun set_mugen_pk(_: &GameCap, mugen_pk: vector<u8>, seen_messages: &mut SeenMessages) {
    assert!(VERSION == seen_messages.version, EIncorrectVersion);
    seen_messages.mugen_pk = mugen_pk;

    event::emit(SetMugenPkEvent{mugen_pk});
  }

  /// add or update config
  public entry fun add_gacha_config(
    _: &GameCap, gacha_config_tb: &mut GachaConfigTable, token_type:u64, gacha_token_types: vector<u64>,
    gacha_amounts: vector<u64>, start_time: u64, end_time: u64) {

    assert!(VERSION == gacha_config_tb.version, EIncorrectVersion);
    if(start_time > 0 && end_time > 0){
      assert!(end_time >= start_time, ETimeSet);
    };

    assert!(vector::length(&gacha_token_types) == vector::length(&gacha_token_types), EVectorLen);
    if (table::contains(&mut gacha_config_tb.config, token_type)) {
      let config = table::borrow_mut(&mut gacha_config_tb.config, token_type);
      config.gacha_token_types = gacha_token_types;
      config.gacha_amounts = gacha_amounts;
      config.start_time = start_time;
      config.end_time = end_time;
    } else {
      let config = GachaConfig {
        gacha_token_types,
        gacha_amounts,
        coin_prices: vec_map::empty<TypeName, u64>(),
        start_time,
        end_time
      };

      table::add(&mut gacha_config_tb.config, token_type, config);
    };

    event::emit(AddGachaConfigEvent{
      token_type,
      gacha_token_types,
      gacha_amounts,
      start_time,
      end_time
    });
  }

  // admin remove gacha config
  public entry fun remove_gacha_config(_: &GameCap, gacha_config_tb: &mut GachaConfigTable, token_type: u64) {
    assert!(VERSION == gacha_config_tb.version, EIncorrectVersion);
    if (table::contains(&gacha_config_tb.config, token_type)) {
      table::remove(&mut gacha_config_tb.config, token_type);

      event::emit(RemoveGachaConfigEvent{token_type});
    };
  }

  // admin add or apdate gacha info
  public entry fun add_gacha_info(
    _: &GameCap, gacha_config_tb: &mut GachaConfigTable, token_type:u64,
    gacha_name: String, gacha_type: String, gacha_collction: String, gacha_description: String,
  ) {

    assert!(VERSION == gacha_config_tb.version, EIncorrectVersion);
    if (table::contains(&mut gacha_config_tb.gacha_info, token_type)) {
      let gacha_info = table::borrow_mut(&mut gacha_config_tb.gacha_info, token_type);
      gacha_info.gacha_name = gacha_name;
      gacha_info.gacha_type = gacha_type;
      gacha_info.gacha_collction = gacha_collction;
      gacha_info.gacha_description = gacha_description;
    } else {

      let gacha_info = GachaInfo{
        gacha_name,
        gacha_type,
        gacha_collction,
        gacha_description,
      };
      table::add(&mut gacha_config_tb.gacha_info, token_type, gacha_info);
    };

    event::emit(AddGachaInfoEvent{
      token_type,
      gacha_name,
      gacha_type,
      gacha_collction,
      gacha_description
    });
  }

  // remove gacha info
  public entry fun remove_gacha_info(_: &GameCap, gacha_config_tb: &mut GachaConfigTable, token_type: u64) {
    assert!(VERSION == gacha_config_tb.version, EIncorrectVersion);
    if (table::contains(&gacha_config_tb.gacha_info, token_type)) {
      table::remove(&mut gacha_config_tb.gacha_info, token_type);

      event::emit(RemoveGachaInfoEvent{token_type});
    };
  }

  public entry fun set_discount_price<COIN>(
    _: &GameCap,
    gacha_config_tb: &mut GachaConfigTable,
    token_type: u64,
    price: u64,
  ) {
    assert!(VERSION == gacha_config_tb.version, EIncorrectVersion);
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
    assert!(VERSION == gacha_config_tb.version, EIncorrectVersion);
    let config = table::borrow_mut(&mut gacha_config_tb.config, token_type);
    let coin_type = type_name::get<COIN>();
    if (vec_map::contains(&config.coin_prices, &coin_type)) {
      vec_map::remove(&mut config.coin_prices, &coin_type);
      event::emit(RemoveDiscountPriceEvent {
        token_type,
        coin_type,
      });
    };
  }

  public entry fun withdraw_arca_request(game_config:&mut GameConfig, multi_signature : &mut MultiSignature, amount: u64, to: address, ctx: &mut TxContext) {
    // Only multi sig guardian
    only_multi_sig_scope(multi_signature, game_config);
    // Only participant
    only_participant(multi_signature, ctx);

    let request = WithdrawArcaRequest{
      id: object::new(ctx),
      amount,
      to
    };

    let desc = sui::address::to_string(object::id_address(&request));

    multisig::create_proposal(multi_signature, *string::bytes(&desc), WithdrawArca, request, ctx);
  }

  public entry fun withdraw_arca_execute(
    game_config:&mut GameConfig,
    multi_signature : &mut MultiSignature,
    proposal_id: u256,
    is_approve: bool,
    arca_counter: &mut ArcaCounter,
    ctx: &mut TxContext): bool {

    assert!(VERSION == arca_counter.version, EIncorrectVersion);
    only_multi_sig_scope(multi_signature, game_config);
    // Only participant
    only_participant(multi_signature, ctx);

    if (is_approve) {
      let (approved, _ ) = multisig::is_proposal_approved(multi_signature, proposal_id);
      if (approved) {
        let request = multisig::borrow_proposal_request<WithdrawArcaRequest>(multi_signature, &proposal_id, ctx);

        withdraw_arca(request.amount, request.to, arca_counter, ctx);
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

  public entry fun withdraw_upgrade_profits_request(game_config:&mut GameConfig, multi_signature : &mut MultiSignature, to: address, ctx: &mut TxContext) {
    // Only multi sig guardian
    only_multi_sig_scope(multi_signature, game_config);
    // Only participant
    only_participant(multi_signature, ctx);

    let request = WithdrawUpgradeProfitsRequest{
      id: object::new(ctx),
      to
    };

    let desc = sui::address::to_string(object::id_address(&request));

    multisig::create_proposal(multi_signature, *string::bytes(&desc), WithdrawUpgradeProfits, request, ctx);
  }

  public entry fun withdraw_upgrade_profits_execute(
    game_config:&mut GameConfig,
    multi_signature : &mut MultiSignature,
    proposal_id: u256,
    is_approve: bool,
    upgrader: &mut Upgrader,
    ctx: &mut TxContext): bool {

    assert!(VERSION == upgrader.version, EIncorrectVersion);
    only_multi_sig_scope(multi_signature, game_config);
    // Only participant
    only_participant(multi_signature, ctx);

    if (is_approve) {
      let (approved, _ ) = multisig::is_proposal_approved(multi_signature, proposal_id);
      if (approved) {
        let request = multisig::borrow_proposal_request<WithdrawUpgradeProfitsRequest>(multi_signature, &proposal_id, ctx);

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

  public entry fun withdraw_discount_profits_request<COIN>(game_config:&mut GameConfig, multi_signature : &mut MultiSignature, to: address, ctx: &mut TxContext) {
    // Only multi sig guardian
    only_multi_sig_scope(multi_signature, game_config);
    // Only participant
    only_participant(multi_signature, ctx);

    let coin_type = type_name::get<COIN>();
    let request = WithdrawDiscountProfitsRequest{
      id: object::new(ctx),
      coin_type,
      to
    };

    let desc = sui::address::to_string(object::id_address(&request));

    multisig::create_proposal(multi_signature, *string::bytes(&desc), WithdrawDiscountProfits, request, ctx);
  }

  public entry fun withdraw_discount_profits_execute<COIN>(
    game_config:&mut GameConfig,
    multi_signature : &mut MultiSignature,
    proposal_id: u256,
    is_approve: bool,
    gacha_config_tb: &mut GachaConfigTable,
    ctx: &mut TxContext): bool {

    assert!(VERSION == gacha_config_tb.version, EIncorrectVersion);
    only_multi_sig_scope(multi_signature, game_config);
    // Only participant
    only_participant(multi_signature, ctx);

    if (is_approve) {
      let (approved, _ ) = multisig::is_proposal_approved(multi_signature, proposal_id);
      if (approved) {
        let request = multisig::borrow_proposal_request<WithdrawDiscountProfitsRequest>(multi_signature, &proposal_id, ctx);

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
  // Admins return upgraded heroes
  public entry fun return_upgraded_hero_by_ticket(ticket: HeroTicket) {
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
  }

  // admin burn hero
  public entry fun get_hero_and_burn(_: &GameCap, hero_address: address, obj_burn: &mut ObjBurn) {
    let burn_hero = dof::remove<address, Hero>(&mut obj_burn.id, hero_address);
    hero::burn(burn_hero);
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

  public entry fun upgrade_base_by_ticket(ticket: &mut HeroTicket, new_values: vector<u16>) {
    hero::edit_fields<u16>(&mut ticket.main_hero, string::utf8(b"base"), new_values);
  }

  public entry fun upgrade_skill_by_ticket(ticket: &mut HeroTicket, new_values: vector<u16>) {
    hero::edit_fields<u16>(&mut ticket.main_hero, string::utf8(b"skill"), new_values);
  }

  public entry fun upgrade_appearance_by_ticket(ticket: &mut HeroTicket, new_values: vector<u16>) {
    hero::edit_fields<u16>(&mut ticket.main_hero, string::utf8(b"appearance"), new_values);
  }

  public entry fun upgrade_growth_by_ticket(ticket: &mut HeroTicket, new_values: vector<u16>) {
    hero::edit_fields<u16>(&mut ticket.main_hero, string::utf8(b"growth"), new_values);
  }

  /// === Open gacha functions ===
  // Place the destroyed blind box
  // fun put_gacha(gacha: GachaBall, gacha_ball_address: address, obj_burn: &mut ObjBurn) {
  //   dof::add<address, GachaBall>(&mut obj_burn.id, gacha_ball_address, gacha);
  //   // event
  // }

  // The administrator destroys the blind box
  public entry fun get_gacha_and_burn(_: &GameCap, gacha_ball_address: address, obj_burn: &mut ObjBurn) {
    let gacha_ball = dof::remove<address, GachaBall>(&mut obj_burn.id, gacha_ball_address);
    gacha::burn(gacha_ball);
    // event
  }
  /// === Player functions ===

  /// open a gacha ball
  // User opens blind box
  public entry fun open_gacha_ball(gacha_ball: GachaBall, game_config: &GameConfig, ctx: &mut TxContext){

    assert!(VERSION == game_config.version, EIncorrectVersion);

    let gacha_ball_id = gacha::id(&gacha_ball);
    let user = tx_context::sender(ctx);
    //let type = *gacha::type(&gacha_ball);
    let token_type= *gacha::tokenType(&gacha_ball);
    let collection = *gacha::collection(&gacha_ball);
    assert!(collection == string::utf8(b"Boxes"), EInvalidType);

    let ticket = BoxTicket{
      id: object::new(ctx),
      gacha_ball,
    };

    // create and emit an event
    let open_evt = GachaBallOpened { id: gacha_ball_id, user,ticket_id: object::uid_to_inner(&ticket.id), token_type };
    event::emit(open_evt);

    transfer::transfer(ticket, game_config.mint_address);
  }

  public entry fun abandon_gacha_ball(_: &GameCap, gacha_ball: GachaBall){
    gacha::burn(gacha_ball);
  }


  // appearance_index is the index of the part inside the appearance vector
  // eg: eye is 0, appearance[0]
  public entry fun makeover_hero(
    main_hero: Hero,
    to_burn: Hero,
    appearance_index: u64,
    upgrader: &mut Upgrader,
    ctx: &mut TxContext) {
    assert!(VERSION == upgrader.version, EIncorrectVersion);
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

  public entry fun upgrade_hero(
    main_hero: Hero,
    to_burn: vector<Hero>,
    upgrader: &mut Upgrader,
    ctx: &mut TxContext)
  {
    assert!(VERSION == upgrader.version, EIncorrectVersion);

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

  public entry fun power_upgrade_hero(
    main_hero: Hero,
    to_burn: vector<Hero>,
    fee: Coin<ARCA>,
    upgrader: &mut Upgrader,
    ctx: &mut TxContext
  )
  {
    assert!(VERSION == upgrader.version, EIncorrectVersion);

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

    transfer::transfer(ticket, upgrader.upgrade_address);
  }

  public entry fun charge_hero(to_burn: vector<Hero>, obj_burn: &mut ObjBurn, ctx: &mut TxContext){
    assert!(VERSION == obj_burn.version, EIncorrectVersion);

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
  public entry fun whitelist_claim(
    config: &mut GameConfig,
    ctx: &mut TxContext
  )
  {
    assert!(VERSION == config.version, EIncorrectVersion);

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

  public entry fun voucher_exchange(
    voucher: GachaBall,
    gacha_config: &GachaConfigTable,
    clock: & Clock,
    game_config: &GameConfig,
    ctx: &mut TxContext)
  {
    assert!(VERSION == gacha_config.version, EIncorrectVersion);

    let collection = *gacha::collection(&voucher);
    assert!(collection == string::utf8(b"Voucher"), EInvalidType);
    let token_type = *gacha::tokenType(&voucher);
    let config = table::borrow(&gacha_config.config, token_type);
    mint_gachas_by_config(gacha_config, config, tx_context::sender(ctx), clock, ctx);
    let id = object::id(&voucher);

    let ticket = BoxTicket{
      id: object::new(ctx),
      gacha_ball: voucher,
    };
    event::emit(VoucherExchanged{id, token_type, user: tx_context::sender(ctx), ticket_id: object::id(&ticket)});

    transfer::transfer(ticket, game_config.mint_address)
  }

  public entry fun discount_exchange<COIN>(
    discount: GachaBall,
    gacha_config_tb: &mut GachaConfigTable,
    payment: Coin<COIN>,
    clock: & Clock,
    game_config: &GameConfig,
    ctx: &mut TxContext)
  {
    assert!(VERSION == gacha_config_tb.version, EIncorrectVersion);

    let collection = *gacha::collection(&discount);
    assert!(collection == string::utf8(b"Coupon"), EInvalidType);
    let token_type = *gacha::tokenType(&discount);
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

    mint_gachas_by_config(gacha_config_tb, config, tx_context::sender(ctx), clock, ctx);
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

  fun mint_gachas_by_config(gacha_config_tb: &GachaConfigTable, config: &GachaConfig, to: address, clock: &Clock, ctx: &mut TxContext) {
    let current_time = clock::timestamp_ms(clock) / 1000;

    assert_current_time_ge_start_time(current_time, config.start_time);
    assert_current_time_lt_end_time(current_time, config.end_time);

    let gacha_length = vector::length(&config.gacha_token_types);
    let i = 0;
    while (i < gacha_length) {
      let gacha_token_type = *vector::borrow(&config.gacha_token_types, i);
      let gacha_amount = *vector::borrow(&config.gacha_amounts, i);
      let x = 0;
      while (x < gacha_amount) {
        let gacha_ball = mint_by_token_type(gacha_config_tb, gacha_token_type, ctx);
        public_transfer(gacha_ball, to);
        x = x + 1;
      };
      i = i + 1;
    };
  }

  fun mint_by_token_type(gacha_config_tb: &GachaConfigTable, token_type: u64, ctx: &mut TxContext): GachaBall {
    let gacha_info = table::borrow(&gacha_config_tb.gacha_info, token_type);
    let gacha_ball = gacha::mint(
      token_type,
      gacha_info.gacha_name,
      gacha_info.gacha_type,
      gacha_info.gacha_collction,
      gacha_info.gacha_description,
      ctx,
    );
    gacha_ball
  }

  // user deposit arca
  public entry fun deposit(payment: Coin<ARCA>, arca_counter: &mut ArcaCounter, ctx: &mut TxContext) {
    assert!(VERSION == arca_counter.version, EIncorrectVersion);

    let amount = coin::value(&payment);
    assert!(amount > 0, EInvalidAmount);
    balance::join(&mut arca_counter.arca_balance, coin::into_balance<ARCA>(payment));

    event::emit(UserDeposit{user: tx_context::sender(ctx), amount});
  }

  // user withdraw arca by admin signature
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
    assert!(VERSION == seen_messages.version, EIncorrectVersion);
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

  // user withdraw gacha by admin signature
  public entry fun withdraw_gacha(
    gacha_config: &GachaConfigTable,
    token_type: u64,
    amount: u64,
    expire_at: u64,
    salt: u64,
    chain_id: u64,
    package_address: address,
    signed_message: vector<u8>,
    seen_messages: &mut SeenMessages,
    clock: & Clock,
    ctx: &mut TxContext,
  ) {
    assert!(VERSION == seen_messages.version, EIncorrectVersion);
    assert!(VERSION == gacha_config.version, EIncorrectVersion);
    assert!(expire_at >= clock::timestamp_ms(clock) / 1000, ETimeExpired);
    let user_address = tx_context::sender(ctx);
    let msg: vector<u8> = address::to_bytes(user_address);
    vector::append(&mut msg, bcs::to_bytes<u64>(&token_type));
    vector::append(&mut msg, bcs::to_bytes<u64>(&amount));
    vector::append(&mut msg, bcs::to_bytes<u64>(&expire_at));
    vector::append(&mut msg, bcs::to_bytes<u64>(&salt));
    vector::append(&mut msg, bcs::to_bytes<u64>(&chain_id));
    vector::append(&mut msg, address::to_bytes(package_address));

    // assert that signature verifies
    // 1 is for SHA256 (hash function options in signature)
    assert!(ecdsa_k1::secp256k1_verify(&signed_message, &seen_messages.mugen_pk, &msg, 1), EInvalidSignature);
    assert!(!table::contains(&seen_messages.salt_table, salt), EInvalidSalt);
    table::add(&mut seen_messages.salt_table, salt, true);
    //let coin_balance = balance::split<ARCA>(&mut arca_counter.arca_balance, amount - fee);

    let i = 0;
    while (i < amount){
      let gacha_ball = mint_by_token_type(gacha_config, token_type, ctx);
      transfer::public_transfer(gacha_ball, user_address);
      i = i + 1;
    };
    event::emit(UserWithdrawGacha{
      user: user_address,
      token_type,
      amount,
      salt,
    });
  }

  // === check permission functions ===

  public fun only_participant (multi_signature: &MultiSignature, tx: &mut TxContext) {
    assert!(multisig::is_participant(multi_signature, tx_context::sender(tx)), ENotParticipant);
  }

  public fun only_multi_sig_scope (multi_signature: &MultiSignature, game_config: &GameConfig) {
    assert!(VERSION == game_config.version, EIncorrectVersion);
    assert!(object::id(multi_signature) == game_config.for_multi_sign, ENotInMultiSigScope);
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

  // === Accessors ===
  public fun check_salt(sm: &SeenMessages, expire_at: u64, clock: &Clock,salt: u64): vector<bool> {
    let v_bool = vector::empty<bool>();
    vector::push_back(&mut v_bool, table::contains(&sm.salt_table, salt));

    if (expire_at >= clock::timestamp_ms(clock) / 1000) {
      vector::push_back(&mut v_bool, true);
    } else {
      vector::push_back(&mut v_bool, false);
    };

    v_bool
  }

  public fun get_upgrade_profits(upgrade: &Upgrader):u64 {
    balance::value(&upgrade.profits)
  }

  public fun get_counter_amount(arca_counter: &ArcaCounter):u64 {
    balance::value(&arca_counter.arca_balance)
  }

  public fun get_discount_profits<COIN>(config_tb: &GachaConfigTable):u64 {
    let coin_type = type_name::get<COIN>();
    balance::value(df::borrow<TypeName, Balance<COIN>>(&config_tb.id, coin_type))
  }

  public fun get_power_prices(upgrader: &Upgrader, key: String):u64 {
    *table::borrow(&upgrader.power_prices, key)
  }

  // package upgrade
  entry fun migrate_game_config(config: &mut GameConfig, _: &GameCap) {
    assert!(config.version < VERSION, ENotUpgrade);
    config.version = VERSION;
  }

  entry fun migrate_upgrader(upgrader: &mut Upgrader, _: &GameCap) {
    assert!(upgrader.version < VERSION, ENotUpgrade);
    upgrader.version = VERSION;
  }

  entry fun migrate_obj_burn(obj_burn: &mut ObjBurn, _: &GameCap) {
    assert!(obj_burn.version < VERSION, ENotUpgrade);
    obj_burn.version = VERSION;
  }

  entry fun migrate_garca_counter(arca_counter: &mut ArcaCounter, _: &GameCap) {
    assert!(arca_counter.version < VERSION, ENotUpgrade);
    arca_counter.version = VERSION;
  }

  entry fun migrate_gacha_config_table(config: &mut GachaConfigTable, _: &GameCap) {
    assert!(config.version < VERSION, ENotUpgrade);
    config.version = VERSION;
  }

  entry fun migrate_seen_messages(seen_messages: &mut SeenMessages, _: &GameCap) {
    assert!(seen_messages.version < VERSION, ENotUpgrade);
    seen_messages.version = VERSION;
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
      string::utf8(b"Boxes"),
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
      string::utf8(b"Voucher"),
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
      string::utf8(b"Coupon"),
      string::utf8(b"Discount"),
      string::utf8(b"Discount"),
      string::utf8(b"test Discount"),
      ctx
    )
  }
}