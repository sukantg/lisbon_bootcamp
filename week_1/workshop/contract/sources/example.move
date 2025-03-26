module contract::example;
// Imports
use std::string::String;

// Structs
public struct SuperNFT has key, store{
    id: UID,
    name: String,
    color: vector<u8>,
}


// functions

public fun mint(name: String, color: vector<u8>, ctx: &mut TxContext): SuperNFT {

    let new_nft = SuperNFT {
        id: object::new(ctx),
        name,
        color,
    };

    new_nft
}

public fun burn(nft: SuperNFT) {
    let SuperNFT { id: unique_id, name: _, color: _} = nft;
    object::delete(unique_id);
}

public fun edit_name (nft: &mut SuperNFT, new_name: String) {
    nft.name = new_name;
}

