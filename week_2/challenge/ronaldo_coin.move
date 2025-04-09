module ronaldo_coin::ronaldo_coin {
    use sui::coin::{Self, Coin, CoinMetadata, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;

    /// The Ronaldo Coin token
    struct RONALDO_COIN has drop {}

    /// Stores the treasury cap for the RONALDO_COIN
    struct CoinCreator has key {
        id: UID,
        treasury_cap: TreasuryCap<RONALDO_COIN>,
        fee_balance: Balance<SUI>,
    }

    /// Exchange rate constants
    const RONALDO_PER_SUI: u64 = 7; // 7 RONALDO_COIN per 1 SUI 
    
    /// Fee percentage in basis points (1/100 of 1%)
    /// 50 basis points = 0.5%
    const FEE_BASIS_POINTS: u64 = 50;
    
    /// Basis points denominator
    const BASIS_POINTS_DENOMINATOR: u64 = 10000;

    // Error codes
    const ERR_ZERO_AMOUNT: u64 = 0;

    /// Module initializer called once when the module is published
    fun init(witness: RONALDO_COIN, ctx: &mut TxContext) {
        // Create the RONALDO_COIN with an initial supply of 0
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            7, // 7 decimals 
            b"RONALDO", // Symbol
            b"Ronaldo Coin", // Name
            b"A digital coin celebrating Cristiano Ronaldo, Portugal's football legend", // Description
            option::some(b"https://imageio.forbes.com/specials-images/imageserve/645ea1c4fce09061884bd21c/0x0.jpg"), 
            ctx
        );

        // Freeze the metadata to prevent future changes
        transfer::public_freeze_object(metadata);

        // Create the CoinCreator object to hold the TreasuryCap
        let coin_creator = CoinCreator {
            id: object::new(ctx),
            treasury_cap,
            fee_balance: balance::zero(),
        };

        // Transfer the CoinCreator object to the transaction sender
        transfer::transfer(coin_creator, tx_context::sender(ctx));
    }

    /// Swap SUI for RONALDO_COIN at the fixed exchange rate
    public fun swap(
        coin_creator: &mut CoinCreator,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ): Coin<RONALDO_COIN> {
        let payment_amount = coin::value(&payment);
        assert!(payment_amount > 0, ERR_ZERO_AMOUNT);

        // Calculate the fee amount
        let fee_amount = (payment_amount * FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        
        // Calculate the net amount after fee
        let net_amount = payment_amount - fee_amount;
        
        // Calculate the amount of RONALDO_COIN to mint based on the exchange rate
        let ronaldo_amount = net_amount * RONALDO_PER_SUI;

        // Extract the fee and add it to the fee balance
        let fee_coin = coin::split(&mut payment, fee_amount, ctx);
        let fee_balance = coin::into_balance(fee_coin);
        balance::join(&mut coin_creator.fee_balance, fee_balance);

        // Deposit the remaining SUI to the treasury
        let sui_balance = coin::into_balance(payment);
        
        // Mint the RONALDO_COIN
        let minted_coin = coin::mint(&mut coin_creator.treasury_cap, ronaldo_amount, ctx);
        
        // Destroy the SUI balance (effectively locking it in the contract)
        balance::destroy_for_testing(sui_balance);
        
        minted_coin
    }

    /// Burn RONALDO_COIN to get SUI back at the fixed exchange rate
    public fun burn(
        coin_creator: &mut CoinCreator,
        token: Coin<RONALDO_COIN>,
        ctx: &mut TxContext
    ): Coin<SUI> {
        let token_amount = coin::value(&token);
        assert!(token_amount > 0, ERR_ZERO_AMOUNT);

        // Calculate the SUI amount based on the exchange rate
        let sui_amount = token_amount / RONALDO_PER_SUI;
        
        // Calculate the fee amount
        let fee_amount = (sui_amount * FEE_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        
        // Calculate the net amount after fee
        let net_amount = sui_amount - fee_amount;

        // Burn the RONALDO_COIN
        coin::burn(&mut coin_creator.treasury_cap, token);
        
        // Create a new SUI coin with the calculated amount minus fee
        let return_coin = coin::take(&mut coin_creator.fee_balance, net_amount, ctx);
        
        // The fee stays in the fee_balance
        return_coin
    }

    /// Allow the creator to withdraw the accumulated fees
    public entry fun withdraw_fees(
        coin_creator: &mut CoinCreator, 
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(amount > 0, ERR_ZERO_AMOUNT);
        assert!(balance::value(&coin_creator.fee_balance) >= amount, 0);
        
        let fee_coin = coin::take(&mut coin_creator.fee_balance, amount, ctx);
        transfer::public_transfer(fee_coin, tx_context::sender(ctx));
    }

    /// Check the current fee balance
    public fun fee_balance(coin_creator: &CoinCreator): u64 {
        balance::value(&coin_creator.fee_balance)
    }
}