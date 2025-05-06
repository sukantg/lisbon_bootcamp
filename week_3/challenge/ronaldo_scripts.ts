import { Transaction } from "@mysten/sui/transactions";
import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { fromBase64 } from "@mysten/sui/utils";
import { packageId, coinCreatorId } from "./constants";
import * as dotenv from "dotenv";
dotenv.config({ path: "./.env" });

// Initialize client and keypair
const privKeyBase64 = process.env.PRIVATE_KEY!;
const privKey = Array.from(fromBase64(privKeyBase64));
privKey.shift();
const keypair = Ed25519Keypair.fromSecretKey(Uint8Array.from(privKey));

const client = new SuiClient({ url: getFullnodeUrl('devnet') });

// 1. Mint and stake RONALDO coins
export const mintAndStake = async () => {
    const tx = new Transaction();
    const amount = 1_000; // arbitrary amount

    const minted = tx.moveCall({
        target: `${packageId}::ronaldo_coin::swap`,
        arguments: [
            tx.object(coinCreatorId),
            tx.splitCoins(tx.gas, [tx.pure.u64(amount)])
        ]
    });

    tx.moveCall({
        target: `${packageId}::ronaldo_staking::stake`, // replace with actual module
        arguments: [minted]
    });

    const result = await client.signAndExecuteTransaction({
        transaction: tx,
        signer: keypair,
        options: { showObjectChanges: true, showEffects: true }
    });
    
    console.dir(result, { depth: 5 });
};

// 2. Use faucet and find a SUI coin
export const getSuiCoin = async () => {
    const faucetUrl = "https://faucet.devnet.sui.io/gas";
    const faucetResp = await fetch(faucetUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ recipient: keypair.toSuiAddress() })
    }).then(res => res.json());
    console.log("Faucet response:", faucetResp);

    const resp = await client.getOwnedObjects({
        owner: keypair.toSuiAddress(),
        filter: { StructType: `0x2::coin::Coin<0x2::sui::SUI>` },
        options: { showContent: true, showType: true }
    });

    const suiCoinId = resp.data?.[0]?.data?.objectId;
    console.log("First SUI coin ID:", suiCoinId);
    return suiCoinId;
};

// 3. Split coin into 4 and calculate total storage rebate
export const splitAndGetStorageRebate = async () => {
    const tx = new Transaction();

    const coinSplits = tx.splitCoins(tx.gas, [
        tx.pure.u64(1_000_000),
        tx.pure.u64(1_000_000),
        tx.pure.u64(1_000_000),
        tx.pure.u64(1_000_000)
    ]);

    const result = await client.signAndExecuteTransaction({
        transaction: tx,
        signer: keypair,
        options: {
            showEffects: true,
            showObjectChanges: true 
        }
    });

    const rebates = result.objectChanges
        ?.filter((change) => change.type === 'created')
        ?.map((change: any) => change.storageRebate || 0);

    const totalRebate = rebates?.reduce((sum, r) => sum + Number(r), 0) || 0;
    console.log("Total storage rebate of split coins:", totalRebate);
};


// 4. Merge coins and check gas used
export const mergeCoins = async (coinIds: string[]) => {
    const tx = new Transaction();
    const [primary, ...others] = coinIds;
    others.forEach(id => tx.mergeCoins(tx.object(primary), [tx.object(id)]));

    const result = await client.signAndExecuteTransaction({
        transaction: tx,
        signer: keypair,
        options: { showEffects: true }
    });

    console.log("Gas used:", result.effects?.gasUsed);
};


// 5. Exchange for RONALDO, unstake and check SUI rewards
export const exchangeAndUnstake = async () => {
    const tx = new Transaction();

    const suiToPay = tx.splitCoins(tx.gas, [tx.pure.u64(1_000_000)]);

    const ronaldo = tx.moveCall({
        target: `${packageId}::ronaldo_coin::swap`,
        arguments: [
            tx.object(coinCreatorId),
            suiToPay
        ]
    });

    const unstake = tx.moveCall({
        target: `${packageId}::ronaldo_staking::unstake`, // replace with actual
        arguments: [ronaldo]
    });

    tx.transferObjects([unstake], tx.pure.address(keypair.toSuiAddress()));

    const result = await client.signAndExecuteTransaction({
        transaction: tx,
        signer: keypair,
        options: {
            showEffects: true,
            showBalanceChanges: true
        }
    });

    const suiReward = result.balanceChanges?.find(b => b.coinType.includes("SUI"))?.amount;
    console.log("SUI reward from unstake:", suiReward);
};