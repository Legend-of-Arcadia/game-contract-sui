module contracts::arca {

    use std::option;

    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::UID;
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::object;
    use std::vector;
    use sui::event;
    use sui::clock::{Self, Clock};
    use sui::address;
    use sui::bcs;
    use sui::ecdsa_k1;

    const DECIMALS: u64 = 1_000_000_000;
    const TOTAL_SUPPLY_ARCA: u64 = 1_000_000_000;
    const TOTAL_SUPPLY_ARCA_DEVISION: u64 = 1_000_000_000_000_000_000;

    const EInvalidSignature: u64 = 1;
    const EInvalidSalt: u64 = 2;
    const ETimeExpired: u64 = 3;

    struct ARCA has drop {}

    struct SeenMessages has key, store {
        id: UID,
        mugen_pk: vector<u8>,
        salt_table: Table<u64, bool>
    }

    struct ArcaCounter has key, store {
        id: UID,
        arca_balance : Balance<ARCA>
    }

    // events
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

    fun init(witness: ARCA, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 9, b"ARCA", b"", b"", option::none(), ctx);

        let seen_messages = SeenMessages {
            id: object::new(ctx),
            mugen_pk: vector::empty<u8>(),
            salt_table: table::new<u64, bool>(ctx)
        };

        let arca_counter = ArcaCounter{
            id: object::new(ctx),
            arca_balance: balance::zero<ARCA>()
        };


        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
        transfer::public_share_object(seen_messages);
        transfer::public_share_object(arca_counter);
    }

    public fun add_acra(_: &TreasuryCap<ARCA>, payment: Coin<ARCA>, arca_counter: &mut ArcaCounter) {
        balance::join(&mut arca_counter.arca_balance, coin::into_balance<ARCA>(payment));
    }

    public fun withdraw_acra(_: &TreasuryCap<ARCA>, amoount: u64, arca_counter: &mut ArcaCounter, ctx: &mut TxContext) : Coin<ARCA> {
        let coin_balance = balance::split<ARCA>(&mut arca_counter.arca_balance, amoount);
        coin::from_balance(coin_balance, ctx)
    }

    /// configure mugen_pk field of SeenMessages
    public fun set_mugen_pk(_: &TreasuryCap<ARCA>, mugen_pk: vector<u8>, seen_messages: &mut SeenMessages) {
        seen_messages.mugen_pk = mugen_pk;
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


    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        let witness = ARCA{};
        init(witness, ctx);
    }
}