module contracts::arca {

    use std::option;

    use sui::coin;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    const DECIMALS: u64 = 1_000_000_000;
    const TOTAL_SUPPLY_ARCA: u64 = 1_000_000_000;
    const TOTAL_SUPPLY_ARCA_DEVISION: u64 = 1_000_000_000_000_000_000;

    struct ARCA has drop {}

    fun init(witness: ARCA, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 9, b"ARCA", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }
}