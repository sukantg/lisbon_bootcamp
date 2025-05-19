
module contracts::challenge {

    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::clock::Clock;
    use sui::display;
    use sui::package;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::table::Table;
    use sui::sui::SUI;

    /// Error codes
    const EWrongAmount: u64 = 0;
    const ENoSuchAddress: u64 = 1;
    const ETooLate: u64 = 2;

    /// NFT Collection Marker
    public struct COLLECTION has drop {}

    /// Dropout NFT definition
    public struct Dropout has key, store {
        id: UID,
        name: String,
        rarity: String,
        minted_at: u64,
        image_url: String,
        description: String
    }

    /// Admin capabilities
    public struct AdminCap has key {
        id: UID,
    }

    /// Collection state
    public struct State has key {
        id: UID,
        whitelist: Table<address, bool>,
        pre_paid: Table<address, bool>,
        income: Balance<SUI>,
        initial_price: u64,
        expiration: u64,
    }

    /// RONALDO Coin phantom type
    struct RONALDO_COIN has drop {}

    /// Escrow structure
    public struct Escrow has key {
        id: UID,
        seller: address,
        nft: Dropout,
        price: u64
    }

    /// Initialize collection and display
    public entry fun init(otw: COLLECTION, ctx: &mut TxContext) {
        let publisher = package::claim(otw, ctx);
        let keys = vector[
            b"name".to_string(),
            b"image_url".to_string(),
            b"description".to_string()
        ];
        let values = vector[
            b"{name}".to_string(),
            b"{image_url}".to_string(),
            b"{description}".to_string()
        ];
        let mut disp = display::new_with_fields<Dropout>(&publisher, keys, values, ctx);
        disp.update_version();

        let cap = AdminCap {
            id: object::new(ctx)
        };

        let sender = ctx.sender();
        transfer::public_transfer(disp, sender);
        transfer::public_transfer(publisher, sender);
        transfer::transfer(cap, sender);
    }

    /// Mint NFT
    public entry fun admin_mint(
        _: &AdminCap,
        name: String,
        description: String,
        image_url: String,
        rarity: String,
        clock: &Clock,
        ctx: &mut TxContext
    ): Dropout {
        let now = clock.timestamp_ms();
        Dropout {
            id: object::new(ctx),
            name,
            description,
            image_url,
            rarity,
            minted_at: now
        }
    }

    /// Airdrop NFT
    public entry fun admin_airdrop(
        _: &AdminCap,
        state: &mut State,
        recipient: address,
        name: String,
        description: String,
        image_url: String,
        rarity: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(state.pre_paid.contains(recipient), ENoSuchAddress);
        let now = clock.timestamp_ms();
        let nft = Dropout {
            id: object::new(ctx),
            name,
            description,
            image_url,
            rarity,
            minted_at: now
        };
        state.pre_paid.remove(recipient);
        transfer::public_transfer(nft, recipient);
    }

    /// Add users to whitelist
    public entry fun admin_add_whitelisted(state: &mut State, _: &AdminCap, mut users: vector<address>) {
        while (!vector::is_empty(&users)) {
            let user = vector::pop_back(&mut users);
            state.whitelist.add(user, true);
        }
    }

    /// Pre-pay with SUI
    public entry fun pre_pay(state: &mut State, coin: Coin<SUI>, clock: &Clock, ctx: &TxContext) {
        assert!(coin::value(&coin) == state.initial_price, EWrongAmount);
        assert!(clock.timestamp_ms() < state.expiration, ETooLate);
        let user = ctx.sender();
        state.income.join(coin.into_balance());
        state.pre_paid.add(user, true);
    }

    /// Airdrop RONALDO coin to recipients
    public entry fun airdrop_ronaldo_to_nfts(
        _: &AdminCap,
        mut coin: Coin<RONALDO_COIN>,
        recipients: vector<address>,
        ctx: &mut TxContext
    ) {
        let amount_per_user = coin::value(&coin) / vector::length(&recipients);
        for user in &recipients {
            let each = coin::split(&mut coin, amount_per_user, ctx);
            transfer::public_transfer(each, *user);
        }
    }

    /// Create escrow
    public entry fun create_escrow(
        nft: Dropout,
        price: u64,
        ctx: &mut TxContext
    ): Escrow {
        Escrow {
            id: object::new(ctx),
            seller: tx_context::sender(ctx),
            nft,
            price
        }
    }

    /// Cancel escrow
    public entry fun cancel_escrow(
        esc: Escrow,
        ctx: &mut TxContext
    ) {
        assert!(esc.seller == tx_context::sender(ctx), 100);
        transfer::public_transfer(esc.nft, esc.seller);
        object::delete(esc.id);
    }

    /// Buy from escrow
    public entry fun buy(
        esc: Escrow,
        mut payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let buyer = tx_context::sender(ctx);
        assert!(coin::value(&payment) >= esc.price, 101);
        let change = coin::split(&mut payment, esc.price, ctx);
        transfer::public_transfer(payment, esc.seller);
        transfer::public_transfer(esc.nft, buyer);
        transfer::public_transfer(change, buyer);
        object::delete(esc.id);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        let one_time_w = COLLECTION {};
        init(one_time_w, ctx);
    }
}
