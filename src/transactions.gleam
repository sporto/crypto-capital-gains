import given
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

pub type SaleAllocation {
  SaleAllocation(
    buy_price_each: Float,
    buy_price_total: Float,
    buy_transaction_id: Uuid,
    coin: String,
    id: Uuid,
    qty: Float,
    sale_transaction_id: Uuid,
    sell_price_each: Float,
    sell_price_total: Float,
  )
}

pub type Acc {
  Acc(allocations: List(SaleAllocation))
}

pub fn calculate_taxes(transactions: List(Transaction)) {
  let #(buy_transactions, sale_transactions) =
    transactions |> list.partition(fn(t) { t.kind == Buy })

  let initial = Acc(allocations: [])

  list.try_fold(
    sale_transactions,
    initial,
    fn(acc: Acc, transaction: Transaction) {
      let relevant_buy_transactions =
        buy_transactions
        |> list.filter(fn(t) { t.coin == transaction.coin })

      let allocations_for_this_coin =
        acc.allocations
        |> list.filter(fn(a) { a.coin == transaction.coin })

      use new_allocations <- result.try(allocate_sale_transaction(
        transaction,
        relevant_buy_transactions,
        allocations_for_this_coin,
      ))

      let next_allocations = list.append(acc.allocations, new_allocations)

      Ok(Acc(next_allocations))
    },
  )
}

fn allocate_sale_transaction(
  sale_transaction: Transaction,
  relevant_buy_transactions: List(Transaction),
  allocations_for_this_coin: List(SaleAllocation),
) {
  let allocations_for_this_sale_transaction =
    allocations_for_this_coin
    |> list.filter(fn(alloc) {
      alloc.sale_transaction_id == sale_transaction.id
    })

  let qty_allocated_so_far =
    allocations_for_this_sale_transaction
    |> list.map(fn(alloc) { alloc.qty })
    |> float.sum

  let remainding_qty_to_allocate = sale_transaction.qty -. qty_allocated_so_far

  use <- given.that(remainding_qty_to_allocate >=. 0.0, else_return: fn() {
    Ok(allocations_for_this_sale_transaction)
  })

  // Try the next buy transaction
  case relevant_buy_transactions {
    [buy_transaction, ..rest_buy_transactions] -> {
      let allocations_for_this_buy_transaction =
        allocations_for_this_coin
        |> list.filter(fn(alloc) {
          alloc.buy_transaction_id == buy_transaction.id
        })

      let qty_allocated_so_far_for_buy_transaction =
        allocations_for_this_buy_transaction
        |> list.map(fn(alloc) { alloc.qty })
        |> float.sum

      let remainder_to_allocate_for_buy =
        buy_transaction.qty -. qty_allocated_so_far_for_buy_transaction

      use <- given.that(remainder_to_allocate_for_buy >. 0.0, else_return: fn() {
        allocate_sale_transaction(
          sale_transaction,
          rest_buy_transactions,
          allocations_for_this_coin,
        )
      })

      let can_buy_cover =
        remainder_to_allocate_for_buy >=. remainding_qty_to_allocate

      let allocation_qty = case can_buy_cover {
        True -> remainding_qty_to_allocate
        False -> remainder_to_allocate_for_buy
      }

      let buy_price_each = buy_transaction.price_each
      let buy_price_total = allocation_qty *. buy_price_each

      let sell_price_each = sale_transaction.price_each
      let sell_price_total = allocation_qty *. buy_price_each

      let new_allocation =
        SaleAllocation(
          buy_price_each:,
          buy_price_total:,
          buy_transaction_id: buy_transaction.id,
          coin: sale_transaction.coin,
          id: uuid.v4(),
          qty: allocation_qty,
          sale_transaction_id: sale_transaction.id,
          sell_price_each:,
          sell_price_total:,
        )

      let next_allocations =
        list.append(allocations_for_this_coin, [new_allocation])

      allocate_sale_transaction(
        sale_transaction,
        rest_buy_transactions,
        next_allocations,
      )
    }
    _ -> {
      Error("No buy transactions left")
    }
  }
}

pub fn main() -> Nil {
  io.println("Hello from transactions!")
}
