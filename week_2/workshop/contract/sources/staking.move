module contract::staking;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::sui::SUI;

use contract::gold::GOLD;

// Constant
const PRICE_IN_SUI: u64 = 10_000_000_000;
const ADMIN_ADDRESS: address = @0x38e6bd6c23b8cd9b8ea0e18bd45da43406190df850b1d47614fd573eac41a913;

// Errors 
const ERequestedValueTooHigh: u64 = 0;
const EWrongAmountOfSui: u64 = 1;
const ENotAdmin: u64 = 2;

public struct StakingPool has key, store {
    id: UID,
    coins: Balance<GOLD>,
    profits: Balance<SUI>
}


fun init(ctx: &mut TxContext) {
    let pool = StakingPool {
        id: object::new(ctx),
        coins: balance::zero<GOLD>(),
        profits: balance::zero<SUI>()
    };

    transfer::public_share_object(pool);
}


public fun stake(pool: &mut StakingPool, coin: Coin<GOLD>) {
    let new_balance = coin.into_balance();
    // balance::join(&mut pool.coins, new_balance);
    pool.coins.join(new_balance);
}


public fun unstake(pool: &mut StakingPool, value: u64, ctx: &mut TxContext): Coin<GOLD> {
    assert!(pool.coins.value() >= value, ERequestedValueTooHigh);

    let coin_balance = pool.coins.split(value);
    coin::from_balance(coin_balance, ctx)
}

public fun exchange_for_sui(pool: &mut StakingPool, coin: Coin<SUI>, ctx: &mut TxContext): Coin<GOLD> {
    assert!(coin.value() == PRICE_IN_SUI, EWrongAmountOfSui);
    
    pool.profits.join(coin.into_balance());

    let coin_balance = pool.coins.split(50_000_000_000);
    coin_balance.into_coin(ctx)
}

public fun admin_gather_profits(pool: &mut StakingPool, ctx: &mut TxContext): Coin<SUI> {
    assert!(ctx.sender() == ADMIN_ADDRESS, ENotAdmin);
    let value = pool.profits.value();
    let coin_balance = pool.profits.split(value);

    coin_balance.into_coin(ctx)
}




