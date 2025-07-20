import given
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/time/calendar.{type Date}
import gsv
import gtabler
import youid/uuid.{type Uuid}

pub type Kind {
  Buy
  Sale
}

pub type Transaction {
  Transaction(
    date: calendar.Date,
    id: Uuid,
    coin: String,
    kind: Kind,
    qty: Float,
    price_each: Float,
    price_total: Float,
  )
}

pub fn make_transaction(
  date date: Date,
  coin coin: String,
  kind kind: Kind,
  qty qty: Float,
  price_each price_each: Float,
) {
  Transaction(
    id: uuid.v4(),
    date:,
    coin:,
    kind:,
    qty:,
    price_each:,
    price_total: qty *. price_each,
  )
}

pub fn make_buy(
  date date: Date,
  coin coin: String,
  qty qty: Float,
  price_each price_each: Float,
) {
  make_transaction(date:, coin:, kind: Buy, qty:, price_each:)
}

pub fn make_sale(
  date date: Date,
  coin coin: String,
  qty qty: Float,
  price_each price_each: Float,
) {
  make_transaction(date:, coin:, kind: Sale, qty:, price_each:)
}

pub type SaleAllocation {
  SaleAllocation(
    buy_date: calendar.Date,
    buy_price_each: Float,
    buy_price_total: Float,
    buy_transaction_id: Uuid,
    capital_gain: Float,
    coin: String,
    id: Uuid,
    qty: Float,
    sale_date: calendar.Date,
    sale_transaction_id: Uuid,
    sale_price_each: Float,
    sale_price_total: Float,
  )
}

type ReportColumn {
  ColCoin
  ColBuyDate
  ColSaleDate
  ColQty
  ColBuyPriceEach
  ColBuyPriceTotal
  ColSalePriceEach
  ColSalePriceTotal
  ColCapitalGain
}

const report_columns = [
  ColCoin,
  ColBuyDate,
  ColSaleDate,
  ColQty,
  ColBuyPriceEach,
  ColBuyPriceTotal,
  ColSalePriceEach,
  ColSalePriceTotal,
  ColCapitalGain,
]

pub type Acc {
  Acc(allocations: List(SaleAllocation))
}

pub type Error {
  NoBuyTransactionsLeft
}

fn error_to_string(_e: Error) {
  "No Buy Transactions Left"
}

fn calculate_sale_allocations(transactions: List(Transaction)) {
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
  |> result.map(fn(acc) { acc.allocations })
}

type GenericReport {
  GenericReport(headers: List(String), rows: List(List(String)))
}

fn generic_report(transactions: List(Transaction)) {
  use allocations <- result.try(calculate_sale_allocations(transactions))

  let headers = report_columns |> list.map(header_to_label)

  let rows =
    allocations
    |> list.map(sale_allocation_to_report_line)

  let report = GenericReport(headers:, rows:)

  Ok(report)
}

pub fn report(transactions: List(Transaction)) {
  let result = generic_report(transactions)

  case result {
    Ok(report) -> {
      list.append([report.headers], report.rows)
      |> gsv.from_lists(separator: ",", line_ending: gsv.Unix)
    }
    Error(err) -> {
      error_to_string(err)
    }
  }
}

pub fn report_table(transactions: List(Transaction)) {
  let result = generic_report(transactions)

  case result {
    Ok(report) -> {
      let config =
        gtabler.TableConfig(
          separator: "|",
          border_char: "-",
          header_color: fn(text) { text },
          cell_color: fn(text) { text },
        )

      gtabler.print_table(config, report.headers, report.rows)
    }
    Error(err) -> {
      error_to_string(err)
    }
  }
}

fn header_to_label(column: ReportColumn) {
  case column {
    ColBuyDate -> "Buy date"
    ColBuyPriceEach -> "Buy unit"
    ColBuyPriceTotal -> "Buy total"
    ColCapitalGain -> "Gain"
    ColCoin -> "Coin"
    ColQty -> "Qty"
    ColSaleDate -> "Sale date"
    ColSalePriceEach -> "Sale unit"
    ColSalePriceTotal -> "Sale total"
  }
}

fn sale_allocation_to_report_line(allocation: SaleAllocation) {
  list.map(report_columns, sale_allocation_report_cell(_, allocation))
}

fn sale_allocation_report_cell(column: ReportColumn, allocation: SaleAllocation) {
  case column {
    ColBuyDate -> allocation.buy_date |> date_to_label
    ColBuyPriceEach -> allocation.buy_price_each |> float.to_string
    ColBuyPriceTotal ->
      allocation.buy_price_total
      |> float.to_string
    ColCapitalGain ->
      allocation.capital_gain
      |> float.to_string
    ColCoin -> allocation.coin
    ColQty ->
      allocation.qty
      |> float.to_string
    ColSaleDate -> allocation.sale_date |> date_to_label
    ColSalePriceEach ->
      allocation.sale_price_each
      |> float.to_string
    ColSalePriceTotal ->
      allocation.sale_price_total
      |> float.to_string
  }
}

fn date_to_label(date: Date) {
  let year = int.to_string(date.year)

  let month =
    int.to_string(calendar.month_to_int(date.month))
    |> string.pad_start(2, "0")

  let day =
    int.to_string(date.day)
    |> string.pad_start(2, "0")

  year <> "-" <> month <> "-" <> day
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

  echo "remainding_qty_to_allocate"
  echo remainding_qty_to_allocate

  use <- given.that(remainding_qty_to_allocate >. 0.0, else_return: fn() {
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

      echo "qty_allocated_so_far_for_buy_transaction"
      echo qty_allocated_so_far_for_buy_transaction

      let remainder_to_allocate_for_buy =
        buy_transaction.qty -. qty_allocated_so_far_for_buy_transaction

      echo "remainder_to_allocate_for_buy"
      echo remainder_to_allocate_for_buy

      use <- given.that(remainder_to_allocate_for_buy >. 0.0, else_return: fn() {
        allocate_sale_transaction(
          sale_transaction,
          rest_buy_transactions,
          allocations_for_this_coin,
        )
      })

      let allocation_qty =
        float.min(remainder_to_allocate_for_buy, remainding_qty_to_allocate)

      echo "allocation_qty"
      echo allocation_qty

      let buy_price_each = buy_transaction.price_each
      let buy_price_total = allocation_qty *. buy_price_each

      let sale_price_each = sale_transaction.price_each
      let sale_price_total = allocation_qty *. sale_price_each

      let capital_gain = sale_price_total -. buy_price_total

      let new_allocation =
        SaleAllocation(
          buy_date: buy_transaction.date,
          buy_price_each:,
          buy_price_total:,
          buy_transaction_id: buy_transaction.id,
          capital_gain:,
          coin: sale_transaction.coin,
          id: uuid.v4(),
          qty: allocation_qty,
          sale_date: sale_transaction.date,
          sale_transaction_id: sale_transaction.id,
          sale_price_each:,
          sale_price_total:,
        )

      echo "new_allocation"
      echo new_allocation

      let next_allocations =
        list.append(allocations_for_this_coin, [new_allocation])

      allocate_sale_transaction(
        sale_transaction,
        rest_buy_transactions,
        next_allocations,
      )
    }
    _ -> {
      let error = NoBuyTransactionsLeft
      Error(error)
    }
  }
}

pub fn main() -> Nil {
  io.println("Hello from transactions!")
}
