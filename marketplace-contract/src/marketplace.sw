library;

abi Marketplace {
  #[storage(read, write)]
  fn list_item(price: u64, metadata: str[20]);

  #[storage(read, write)]
  fn buy_item(item_id: u64);

  #[storage(read)]
  fn get_item(item_id: u64) -> Item;

  #[storage(read, write)]
  fn initialize_owner() -> Identity;

  #[storage(read)]
  fn withdraw_funds();

  #[storage(read)]
  fn get_user_purchases() -> Vec<Item>;
}

pub struct Item {
  id: u64,
  price: u64,
  owner: Identity,
  metadata: str[20],
  total_bought: u64,
}