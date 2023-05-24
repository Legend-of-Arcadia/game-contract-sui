module contracts::arca {
    use std::option;
    use sui::coin;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct ARCA has drop {}

    fun init(witness: ARCA, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 6, b"ARCA", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }


}