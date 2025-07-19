import gleam/float
import gleam/io
import gleam/list
import gleam/result
import youid/uuid.{type Uuid}

pub type Kind {
  Buy
  Sell
}

pub type Transaction {
  Transaction(
    id: Uuid,
    coin: String,
    kind: Kind,
    qty: Float,
    price_each: Float,
    price_total: Float,
  )
}

pub type BuyLot {
  BuyLot(
    buy_transaction_id: Uuid,
    coin: String,
    id: Uuid,
    price_each: Float,
    price_total: Float,
    qty: Float,
  )
}

pub type SaleAllocation {
  SaleAllocation(
    coin: String,
    id: Uuid,
    price_each: Float,
    price_total: Float,
    qty: Float,
    sale_transaction_id: Uuid,
  )
}

pub type Acc {
  Acc(sale_allocations: List(SaleAllocation))
}

pub fn calculate_taxes(transactions: List(Transaction)) {
  let initial = Acc(sale_allocations: [])

  let #(all_buy_transactions, all_sale_transactions) =
    transactions
    |> list.partition(fn(tra) { tra.kind == Buy })

  list.try_fold(all_sale_transactions, initial, fn(acc, sale_transaction) {
    // We need to inspect each buy lot for this coin, from the beginning
    // For each buy lot, see if there are associated SaleLots
    // See if the Buy Lot is consumed
    // If not consumed, then allocate a new sale lot
    // If there is not enough remainder, the we need to go to the next BuyLot
    //
    let sale_allocations = acc.sale_allocations

    use added_allocations <- result.try(allocate(
      sale_transaction:,
      all_buy_transactions:,
      sale_allocations:,
    ))

    let next_sale_allocations =
      list.append(acc.sale_allocations, added_allocations)

    let next_acc = Acc(sale_allocations: next_sale_allocations)
    Ok(next_acc)
  })
}

pub fn allocate(
  sale_transaction sale_transaction: Transaction,
  all_buy_transactions all_buy_transactions: List(Transaction),
  sale_allocations sale_allocations: List(SaleAllocation),
) {
  // Get the relevant buy transactions for this sale
  let relevant_buy_transactions =
    all_buy_transactions
    |> list.filter(fn(tra) {
      tra.coin == sale_transaction.coin && tra.kind == Buy
    })

  let relevant_sale_allocations =
    sale_allocations
    |> list.filter(fn(allocation) { allocation.coin == sale_transaction.coin })

  // Loop thru relevant buy transactions
  // Trying to find unallocated ones, create allocations until we cover the needed qty
  allocate_do(
    sale_transaction:,
    remainding_qty_to_allocated: sale_transaction.qty,
    relevant_buy_transactions:,
    relevant_sale_allocations:,
    new_allocations: [],
  )
}

fn allocate_do(
  sale_transaction sale_transaction: Transaction,
  remainding_qty_to_allocated remainding_qty_to_allocated: Float,
  relevant_buy_transactions buy_transactions: List(Transaction),
  relevant_sale_allocations sale_allocations: List(SaleAllocation),
  new_allocations new_allocations: List(SaleAllocation),
) {
  case remainding_qty_to_allocated >. 0.0 {
    True -> {
      case buy_transactions {
        [first_buy_transaction, ..rest_buy_transactions] -> {
          // Find sale allocations for this transaction
          let #(sale_allocations_for_buy_transaction, rest_allocations) =
            get_sale_allocations_for_transaction(
              first_buy_transaction,
              sale_allocations,
            )

          let buy_transaction_already_allocated_qty =
            sale_allocations_for_buy_transaction
            |> list.map(fn(acc) { acc.qty })
            |> float.sum

          let buy_transaction_qty_to_allocate =
            first_buy_transaction.qty -. buy_transaction_already_allocated_qty

          case buy_transaction_qty_to_allocate >. 0.0 {
            True -> {
              let can_buy_transaction_cover =
                buy_transaction_qty_to_allocate >=. remainding_qty_to_allocated

              let allocation_qty = case can_buy_transaction_cover {
                True -> remainding_qty_to_allocated
                False -> buy_transaction_qty_to_allocate
              }

              let price_each = sale_transaction.price_each
              let price_total = allocation_qty *. price_each

              let new_allocation =
                SaleAllocation(
                  coin: sale_transaction.coin,
                  id: uuid.v4(),
                  price_each:,
                  price_total:,
                  qty: allocation_qty,
                  sale_transaction_id: sale_transaction.id,
                )
              // create an allocation
              case can_buy_transaction_cover {
                True -> {
                  // This allocation covers the remainder
                  Ok(list.append(new_allocations, [new_allocation]))
                }
                False -> {
                  let remainding_qty_to_allocated =
                    remainding_qty_to_allocated -. allocation_qty
                  // This allocation doesn't cover the remainder, keep going
                  allocate_do(
                    sale_transaction:,
                    remainding_qty_to_allocated:,
                    relevant_buy_transactions: buy_transactions,
                    relevant_sale_allocations: sale_allocations,
                    new_allocations: list.append(new_allocations, [
                      new_allocation,
                    ]),
                  )
                }
              }
            }
            False -> {
              // Fully allocated
              // Try the next transaction
              allocate_do(
                sale_transaction:,
                remainding_qty_to_allocated:,
                relevant_buy_transactions: rest_buy_transactions,
                relevant_sale_allocations: rest_allocations,
                new_allocations:,
              )
            }
          }
        }
        _ -> Error("Not enough buy transactions to cover sale")
      }
    }
    False -> Ok(new_allocations)
  }
}

fn get_sale_allocations_for_transaction(
  transaction: Transaction,
  sale_allocations: List(SaleAllocation),
) {
  case transaction.kind {
    Buy -> #([], sale_allocations)
    Sell -> {
      sale_allocations
      |> list.partition(fn(allocation) {
        allocation.sale_transaction_id == transaction.id
      })
    }
  }
}

pub fn main() -> Nil {
  io.println("Hello from transactions!")
}
