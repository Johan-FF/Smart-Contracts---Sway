contract;

pub mod marketplace;
use marketplace::*;

use std::{
    auth::{
        AuthError,
        msg_sender,
    },
    asset::*,
    call_frames::msg_asset_id,
    constants::BASE_ASSET_ID,
    context::{
        msg_amount,
        this_balance,
    },
    identity::Identity,
    storage::{
        storage_vec::*,
        storage_map::*,
    },
    asset::transfer_to_address,
    hash::Hash,
};

storage {
    item_counter: u64 = 0,
    item_map: StorageMap<u64, Item> = StorageMap::<u64, Item> {},
    purchases: StorageVec<(u64, Identity)> = StorageVec {},
    owner: Option<Identity> = Option::None,
}

enum InvalidError {
    IncorrectAssetId: (),
    NotEnoughTokens: u64,
    OnlyOwner: (),
    OwnerNotInitialized:(),
    OwnerAlreadyInitialized: (),
    IncorrectItemID: (),
}

impl Marketplace for Contract {
    #[storage(read, write)]
    fn list_item(price:u64, metadata: str[20]) {
        storage.item_counter.write(storage.item_counter.read()+1);
        let sender: Result<Identity, AuthError> = msg_sender();
        let new_item: Item =  Item {
            id: storage.item_counter.read(),
            price: price,
            owner: sender.unwrap(),
            metadata: metadata,
            total_bought: 0,
        };
        storage.item_map.insert(storage.item_counter.read(), new_item);
    }

    #[storage(read, write)]
    fn buy_item(item_id: u64) {
        let asset_id = msg_asset_id();
        require(
            asset_id==BASE_ASSET_ID,
            InvalidError::IncorrectAssetId
        );

        let amount: u64 = msg_amount();
        let mut item: Item = storage.item_map.get(item_id).try_read().unwrap();

        require(
            item.id>0,
            InvalidError::IncorrectItemID
        );
        require(
            amount>=item.price,
            InvalidError::NotEnoughTokens(amount)
        );

        item.total_bought+=1;
        storage.item_map.insert(item_id, item);

        let sender: Result<Identity, AuthError> = msg_sender();
        storage.purchases.push((item_id, sender.unwrap()));

        let amount_to_send = if item.total_bought<6 { amount } else { amount - (amount*(5/100)) };
        match item.owner {
            Identity::Address(address) => transfer_to_address(address, asset_id, amount_to_send),
            Identity::ContractId(contract_id) => force_transfer_to_contract(contract_id, asset_id, amount_to_send),
        };
    }

    #[storage(read, write)]
    fn initialize_owner() -> Identity {
        let owner: Option<Identity> = storage.owner.read();
        require(
            owner.is_none(),
            InvalidError::OwnerAlreadyInitialized
        );

        let sender: Result<Identity, AuthError> = msg_sender();
        storage.owner.write(Option::Some(sender.unwrap()));
        sender.unwrap()
    }

    #[storage(read)]
    fn withdraw_funds() {
        let owner = storage.owner;
        require(
            owner.read().is_some(),
            InvalidError::OwnerNotInitialized
        );

        let sender: Result<Identity, AuthError> = msg_sender();
        require(
            sender.unwrap()==owner.read().unwrap(),
            InvalidError::OnlyOwner
        );

        let amount = this_balance(BASE_ASSET_ID);
        require(
            amount>0,
            InvalidError::NotEnoughTokens(amount)
        );

        match owner.read().unwrap() {
            Identity::Address(address) => transfer_to_address(address, BASE_ASSET_ID, amount),
            Identity::ContractId(contract_id) => force_transfer_to_contract(contract_id, BASE_ASSET_ID, amount),
        };
    }

    #[storage(read)]
    fn get_item(item_id: u64) -> Item {
        storage.item_map.get(item_id).try_read().unwrap()
    }

    #[storage(read)]
    fn get_user_purchases() -> Vec<Item>{
        let sender = msg_sender().unwrap();
        let mut items: Vec<Item> = Vec::new();
        let mut i = 0;
        while i < storage.purchases.len() {
            let sale = storage.purchases.get(i).unwrap().read();
            if sale.1==sender {
                let item = storage.item_map.get(sale.0).try_read().unwrap();
                items.push(item);
            }

            i += 1;
        }
        items
    }
}