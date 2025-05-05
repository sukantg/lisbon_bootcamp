#[test_only]
module ronaldo_coin::ronaldo_coin_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::TxContext;
    
    use ronaldo_coin::ronaldo_coin::{Self, RONALDO_COIN, CoinCreator};

    const ADMIN: address = @0xAD;
    const USER: address = @0xB0B;

    // Test the creation of the RONALDO_COIN
    #[test]
    fun test_coin_creation() {
        let scenario = test_scenario::begin(ADMIN);
        
        // Publish the module
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            ronaldo_coin::init(RONALDO_COIN {}, test_scenario::ctx(&mut scenario));
        };

        // Check if CoinCreator was created and sent to ADMIN
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            assert!(test_scenario::has_most_recent_for_sender<CoinCreator>(&scenario), 0);
        };

        test_scenario::end(scenario);
    }

    // Test swapping SUI for RONALDO_COIN
    #[test]
    fun test_swap() {
        let scenario = test_scenario::begin(ADMIN);
        
        // Publish the module
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            ronaldo_coin::init(RONALDO_COIN {}, test_scenario::ctx(&mut scenario));
        };

        // Create some SUI for USER
        let sui_amount = 1_000_000_000; // 1 SUI
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            let coin = coin::mint_for_testing<SUI>(sui_amount, ctx);
            transfer::public_transfer(coin, USER);
        };

        // USER swaps SUI for RONALDO_COIN
        test_scenario::next_tx(&mut scenario, USER);
        {
            let coin_creator = test_scenario::take_from_sender<CoinCreator>(&scenario);
            let sui_coin = test_scenario::take_from_sender<Coin<SUI>>(&scenario);
            
            let ctx = test_scenario::ctx(&mut scenario);
            
            // Expected amount: 1 SUI * 7 RONALDO per SUI * (1 - 0.005 fee) = 6.965 RONALDO
            let expected_ronaldo_amount = 6_965_000_000; // 6.965 RONALDO with 7 decimals
            
            let ronaldo_coin = ronaldo_coin::swap(&mut coin_creator, sui_coin, ctx);
            assert!(coin::value(&ronaldo_coin) == expected_ronaldo_amount, 0);
            
            transfer::public_transfer(ronaldo_coin, USER);
            test_scenario::return_to_sender(&scenario, coin_creator);
        };

        test_scenario::end(scenario);
    }

    // Test burning RONALDO_COIN to get SUI back
    #[test]
    fun test_burn() {
        let scenario = test_scenario::begin(ADMIN);
        
        // Publish the module
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            ronaldo_coin::init(RONALDO_COIN {}, test_scenario::ctx(&mut scenario));
        };

        // Create some SUI for USER
        let sui_amount = 1_000_000_000; // 1 SUI
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            let coin = coin::mint_for_testing<SUI>(sui_amount, ctx);
            transfer::public_transfer(coin, USER);
        };

        // USER swaps SUI for RONALDO_COIN
        let ronaldo_amount = 0;
        test_scenario::next_tx(&mut scenario, USER);
        {
            let coin_creator = test_scenario::take_from_sender<CoinCreator>(&scenario);
            let sui_coin = test_scenario::take_from_sender<Coin<SUI>>(&scenario);
            
            let ctx = test_scenario::ctx(&mut scenario);
            
            let ronaldo_coin = ronaldo_coin::swap(&mut coin_creator, sui_coin, ctx);
            ronaldo_amount = coin::value(&ronaldo_coin);
            
            transfer::public_transfer(ronaldo_coin, USER);
            test_scenario::return_to_sender(&scenario, coin_creator);
        };

        // USER burns RONALDO_COIN to get SUI back
        test_scenario::next_tx(&mut scenario, USER);
        {
            let coin_creator = test_scenario::take_from_sender<CoinCreator>(&scenario);
            let ronaldo_coin = test_scenario::take_from_sender<Coin<RONALDO_COIN>>(&scenario);
            
            let ctx = test_scenario::ctx(&mut scenario);
            
            // After burning, should get back approximately 0.995 SUI (accounting for both swap and burn fees)
            let sui_coin = ronaldo_coin::burn(&mut coin_creator, ronaldo_coin, ctx);
            
            // Each operation has a 0.5% fee, so after two operations:
            // 1 SUI * (1 - 0.005) * (1 - 0.005) ≈ 0.99 SUI
            let returned_sui = coin::value(&sui_coin);
            assert!(returned_sui > 0, 0);
            assert!(returned_sui < sui_amount, 0); // Should be less than original due to fees
            
            transfer::public_transfer(sui_coin, USER);
            test_scenario::return_to_sender(&scenario, coin_creator);
        };

        test_scenario::end(scenario);
    }

    // Test fee withdrawal by admin
    #[test]
    fun test_fee_withdrawal() {
        let scenario = test_scenario::begin(ADMIN);
        
        // Publish the module
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            ronaldo_coin::init(RONALDO_COIN {}, test_scenario::ctx(&mut scenario));
        };

        // Create some SUI for USER
        let sui_amount = 10_000_000_000; // 10 SUI
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            let coin = coin::mint_for_testing<SUI>(sui_amount, ctx);
            transfer::public_transfer(coin, USER);
        };

        // USER swaps SUI for RONALDO_COIN to generate fees
        test_scenario::next_tx(&mut scenario, USER);
        {
            let coin_creator = test_scenario::take_from_sender<CoinCreator>(&scenario);
            let sui_coin = test_scenario::take_from_sender<Coin<SUI>>(&scenario);
            
            let ctx = test_scenario::ctx(&mut scenario);
            
            let ronaldo_coin = ronaldo_coin::swap(&mut coin_creator, sui_coin, ctx);
            transfer::public_transfer(ronaldo_coin, USER);
            
            // Check that we have fees accumulated
            let fee_balance = ronaldo_coin::fee_balance(&coin_creator);
            assert!(fee_balance > 0, 0);
            
            test_scenario::return_to_sender(&scenario, coin_creator);
        };

        // ADMIN withdraws fees
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let coin_creator = test_scenario::take_from_sender<CoinCreator>(&scenario);
            
            // Get current fee balance
            let fee_balance = ronaldo_coin::fee_balance(&coin_creator);
            
            let ctx = test_scenario::ctx(&mut scenario);
            ronaldo_coin::withdraw_fees(&mut coin_creator, fee_balance, ctx);
            
            // Check that fee balance is now zero
            assert!(ronaldo_coin::fee_balance(&coin_creator) == 0, 0);
            
            // Check that ADMIN received the fees
            assert!(test_scenario::has_most_recent_for_sender<Coin<SUI>>(&scenario), 0);
            
            test_scenario::return_to_sender(&scenario, coin_creator);
        };

        test_scenario::end(scenario);
    }
}