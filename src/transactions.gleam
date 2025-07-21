import argv
import clip.{type Command}
import clip/help
import clip/opt.{type Opt}
import given
import gleam/dict
import gleam/float
import gleam/function
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gsv
import gtabler
import outcome.{type Outcome, outcome}
import simplifile
import tempo.{type Date}
import youid/uuid.{type Uuid}

pub type Kind {
  Buy
  Sale
}

fn kind_to_label(kind: Kind) {
  case kind {
    Buy -> "Buy"
    Sale -> "Sale"
  }
}

fn kind_from_code(code: String) {
  case string.uppercase(code) {
    "BUY" -> Ok(Buy)
    "SALE" -> Ok(Sale)
    _ -> Error("Invalid transaction code " <> code)
  }
}

pub type Transaction {
  Transaction(
    date: Date,
    id: String,
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
    id: uuid.v4() |> uuid.to_string,
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
    buy_date: Date,
    buy_price_each: Float,
    buy_price_total: Float,
    buy_transaction_id: String,
    capital_gain: Float,
    coin: String,
    id: Uuid,
    qty: Float,
    sale_date: Date,
    sale_transaction_id: String,
    sale_price_each: Float,
    sale_price_total: Float,
  )
}

type ReportColumn {
  ColFY
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
  ColFY,
  ColSaleDate,
  ColCoin,
  ColBuyDate,
  ColQty,
  ColBuyPriceEach,
  ColBuyPriceTotal,
  ColSalePriceEach,
  ColSalePriceTotal,
  ColCapitalGain,
]

pub fn with_context(error_context, next) {
  next()
  |> outcome.context(error_context)
}

pub type Acc {
  Acc(allocations: List(SaleAllocation))
}

fn calculate_sale_allocations(
  transactions: List(Transaction),
) -> Outcome(List(SaleAllocation), String) {
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

type TransactionCol {
  TransactionColCoin
  TransactionColDate
  TransactionColKind
  TransactionColPriceEach
  TransactionColPriceTotal
  TransactionColQty
}

const transaction_columns = [
  TransactionColDate,
  TransactionColCoin,
  TransactionColKind,
  TransactionColQty,
  TransactionColPriceEach,
  TransactionColPriceTotal,
]

pub fn transactions_table(transactions: List(Transaction)) {
  let headers = transaction_columns |> list.map(transaction_col_header_to_label)

  let rows =
    transactions
    |> list.map(transaction_to_table_row)

  gtabler.print_table(table_config(), headers, rows)
}

fn transaction_col_header_to_label(col: TransactionCol) {
  case col {
    TransactionColCoin -> "Coin"
    TransactionColDate -> "Date"
    TransactionColKind -> "Kind"
    TransactionColPriceEach -> "Each"
    TransactionColPriceTotal -> "Total"
    TransactionColQty -> "Qty"
  }
}

fn transaction_to_table_row(transaction: Transaction) {
  transaction_columns
  |> list.map(transaction_to_table_cell(_, transaction))
}

fn transaction_to_table_cell(col: TransactionCol, transaction: Transaction) {
  case col {
    TransactionColCoin -> transaction.coin
    TransactionColDate -> transaction.date |> date_to_label
    TransactionColKind -> transaction.kind |> kind_to_label
    TransactionColPriceEach -> transaction.price_each |> format_amount
    TransactionColPriceTotal -> transaction.price_total |> format_amount
    TransactionColQty -> transaction.qty |> format_amount
  }
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

pub fn report_csv(transactions: List(Transaction)) {
  use report <- result.try(generic_report(transactions))

  list.append([report.headers], report.rows)
  |> gsv.from_lists(separator: ",", line_ending: gsv.Unix)
  |> Ok
}

pub fn report_table(transactions: List(Transaction)) {
  use report <- result.try(generic_report(transactions))

  gtabler.print_table(table_config(), report.headers, report.rows)
  |> Ok
}

fn table_config() {
  gtabler.TableConfig(
    separator: "|",
    border_char: "-",
    header_color: fn(text) { text },
    cell_color: fn(text) { text },
  )
}

fn header_to_label(column: ReportColumn) {
  case column {
    ColBuyDate -> "Buy date"
    ColBuyPriceEach -> "Buy unit"
    ColBuyPriceTotal -> "Buy total"
    ColCapitalGain -> "Gain"
    ColCoin -> "Coin"
    ColFY -> "FY"
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
    ColFY -> allocation.sale_date |> date_to_financial_year
    ColBuyDate -> allocation.buy_date |> date_to_label
    ColBuyPriceEach -> allocation.buy_price_each |> format_amount
    ColBuyPriceTotal ->
      allocation.buy_price_total
      |> format_amount
    ColCapitalGain ->
      allocation.capital_gain
      |> format_amount
    ColCoin -> allocation.coin
    ColQty ->
      allocation.qty
      |> format_amount
    ColSaleDate -> allocation.sale_date |> date_to_label
    ColSalePriceEach ->
      allocation.sale_price_each
      |> format_amount
    ColSalePriceTotal ->
      allocation.sale_price_total
      |> format_amount
  }
}

fn date_to_label(date: Date) {
  date.to_string(date)
}

import tempo/month

fn date_to_financial_year(date: Date) {
  let month = date.get_month(date) |> month.to_int
  let year = date.get_year(date)

  let fy = case month > 6 {
    True -> year + 1
    False -> year
  }

  "FY" <> int.to_string(fy)
}

fn allocate_sale_transaction(
  sale_transaction: Transaction,
  relevant_buy_transactions: List(Transaction),
  allocations_for_this_coin: List(SaleAllocation),
) -> Outcome(List(SaleAllocation), String) {
  use <- with_context("sale_transaction " <> sale_transaction.id)

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

  // echo "remainding_qty_to_allocate"
  // echo remainding_qty_to_allocate

  use <- given.that(remainding_qty_to_allocate >. 0.0, else_return: fn() {
    Ok(allocations_for_this_sale_transaction)
  })

  // Try the next buy transaction
  case relevant_buy_transactions {
    [buy_transaction, ..rest_buy_transactions] -> {
      // buy transaction must be before sale transaction

      let buy_is_earlier_or_equal =
        date.is_earlier_or_equal(buy_transaction.date, sale_transaction.date)

      use <- given.that(buy_is_earlier_or_equal, else_return: fn() {
        allocate_sale_transaction(
          sale_transaction,
          rest_buy_transactions,
          allocations_for_this_coin,
        )
      })

      let allocations_for_this_buy_transaction =
        allocations_for_this_coin
        |> list.filter(fn(alloc) {
          alloc.buy_transaction_id == buy_transaction.id
        })

      let qty_allocated_so_far_for_buy_transaction =
        allocations_for_this_buy_transaction
        |> list.map(fn(alloc) { alloc.qty })
        |> float.sum

      // echo "qty_allocated_so_far_for_buy_transaction"
      // echo qty_allocated_so_far_for_buy_transaction

      let remainder_to_allocate_for_buy =
        buy_transaction.qty -. qty_allocated_so_far_for_buy_transaction

      // echo "remainder_to_allocate_for_buy"
      // echo remainder_to_allocate_for_buy

      use <- given.that(remainder_to_allocate_for_buy >. 0.0, else_return: fn() {
        allocate_sale_transaction(
          sale_transaction,
          rest_buy_transactions,
          allocations_for_this_coin,
        )
      })

      let allocation_qty =
        float.min(remainder_to_allocate_for_buy, remainding_qty_to_allocate)

      // echo "allocation_qty"
      // echo allocation_qty

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

      // echo "new_allocation"
      // echo new_allocation

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
      |> outcome
      |> outcome.context(
        "qty_allocated_so_far " <> float.to_string(qty_allocated_so_far),
      )
      |> outcome.context(
        "remainding_qty_to_allocate "
        <> float.to_string(remainding_qty_to_allocate),
      )
    }
  }
}

// Qty or currency
pub fn format_amount(amount: Float) -> String {
  let left =
    float.truncate(amount)
    |> int.to_string

  let absolute_value = amount |> float.absolute_value
  let integer = float.floor(absolute_value)

  let decimals =
    absolute_value -. integer
    |> float.to_precision(3)
    |> float.to_string
    |> string.drop_start(2)

  left <> "." <> decimals
}

import tempo/date
import tempo/error.{type DateParseError}

fn date_parse_error_to_label(error: DateParseError) {
  case error {
    error.DateInvalidFormat(input) -> "Invalid date format " <> input
    error.DateOutOfBounds(input, _) -> "Date out of bounds " <> input
  }
}

fn parse_date(input: String) -> outcome.Outcome(Date, String) {
  date.parse(input, tempo.CustomDate("YYYY-MM-DD"))
  |> result.map_error(date_parse_error_to_label)
  |> outcome
  |> outcome.context("When parsing " <> input)
}

fn parse_input(content: String) {
  use csv <- result.try(
    gsv.to_dicts(content, ",")
    |> result.replace_error("Unable to parse CSV")
    |> outcome,
  )

  csv
  |> list.index_map(fn(line, ix) { #(ix + 2, line) })
  |> list.try_map(parse_input_line)
}

fn parse_input_line(tuple: #(Int, dict.Dict(String, String))) {
  let #(line_index, row) = tuple

  use <- with_context("line " <> int.to_string(line_index))

  use id <- result.try(
    dict.get(row, "id")
    |> result.replace_error("Couldn't find id")
    |> outcome
    |> outcome.context("id"),
  )

  use coin <- result.try(
    dict.get(row, "coin")
    |> result.replace_error("Couldn't find coin")
    |> outcome
    |> outcome.context("coin"),
  )

  use date_str <- result.try(
    dict.get(row, "date")
    |> result.replace_error("Couldn't find date")
    |> outcome
    |> outcome.context("date"),
  )

  use kind_str <- result.try(
    dict.get(row, "kind")
    |> result.replace_error("Couldn't find kind")
    |> outcome
    |> outcome.context("kind"),
  )

  use qty_str <- result.try(
    dict.get(row, "qty")
    |> result.replace_error("Couldn't find qty")
    |> outcome
    |> outcome.context("qty"),
  )

  use price_each_str <- result.try(
    dict.get(row, "price_each")
    |> result.replace_error("Couldn't find price_each")
    |> outcome
    |> outcome.context("price_each"),
  )

  use price_total_str <- result.try(
    dict.get(row, "price_total")
    |> result.replace_error("Couldn't find price_total")
    |> outcome
    |> outcome.context("price_total"),
  )

  use date <- result.try(
    parse_date(date_str)
    |> outcome.context("date"),
  )

  use kind <- result.try(
    kind_from_code(kind_str) |> outcome |> outcome.context("kind"),
  )

  use price_each <- result.try(
    price_each_str
    |> string.replace("$", "")
    |> parse_float
    |> outcome.context("price_each"),
  )

  use price_total <- result.try(
    price_total_str
    |> string.replace("$", "")
    |> parse_float
    |> outcome.context("price_total"),
  )

  use qty <- result.try(qty_str |> parse_float |> outcome.context("qty"))

  let transaction =
    Transaction(coin:, date:, id:, kind:, price_each:, price_total:, qty:)

  Ok(transaction)
}

fn parse_int(input: String) {
  input
  |> string.trim
  |> string.replace(",", "")
  |> int.parse
  |> result.replace_error("Unable to parse int " <> input)
  |> outcome
}

fn parse_float(input: String) {
  let result =
    input
    |> string.trim
    |> string.replace(",", "")
    |> float.parse
    |> result.replace_error("Unable to parse float " <> input)
    |> outcome

  case result {
    Ok(float) -> Ok(float)
    Error(float_err) -> {
      case parse_int(input) {
        Ok(int) -> Ok(int.to_float(int))
        Error(_) -> Error(float_err)
      }
    }
  }
}

fn read_input(file_path: String) -> Outcome(List(Transaction), String) {
  use content <- result.try(
    simplifile.read(from: file_path)
    |> result.replace_error("Unable to read " <> file_path)
    |> outcome,
  )

  parse_input(content)
}

fn write_output(report: String, file_path: String) -> Outcome(Nil, String) {
  simplifile.write(to: file_path, contents: report)
  |> result.replace_error("Unable to write to " <> file_path)
  |> outcome
}

fn process_file(in_path: String, out_path: String) {
  use input <- result.try(read_input(in_path))
  use report <- result.try(report_csv(input))
  use _ <- result.try(write_output(report, out_path))
  Ok("Done")
}

type CliArgs {
  CliArgs(file: String)
}

fn file_opt() -> Opt(String) {
  opt.new("file") |> opt.help("File to process")
}

fn command() -> Command(CliArgs) {
  clip.command({
    use file <- clip.parameter

    CliArgs(file)
  })
  |> clip.opt(file_opt())
}

pub fn main() -> Nil {
  let result =
    command()
    |> clip.help(help.simple("file", "Process a file"))
    |> clip.run(argv.load().arguments)

  use args <- given.ok(result, else_return: fn(e) { io.println_error(e) })

  let in_path = "./.input/" <> args.file
  let out_path = "./.output/" <> args.file

  case process_file(in_path, out_path) {
    Ok(message) -> io.println(message)
    Error(e) -> io.println_error(outcome.print_line(e, function.identity))
  }
}
