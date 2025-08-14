import argv
import clip.{type Command}
import clip/help
import clip/opt.{type Opt}
import given
import gleam/bool
import gleam/dict
import gleam/float
import gleam/function
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/set
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
    buy_fee: Float,
    asset: String,
    date: Date,
    id: String,
    kind: Kind,
    price_each: Float,
    qty: Float,
    sale_fee: Float,
  )
}

pub type TransactionComputed {
  TransactionComputed(
    buy_fee: Float,
    asset: String,
    date: Date,
    id: String,
    kind: Kind,
    price_each: Float,
    price_total: Float,
    qty: Float,
    sale_fee: Float,
    price_total_after_fee: Float,
    price_each_after_fee: Float,
  )
}

fn transaction_input_to_computed(
  transaction: Transaction,
) -> TransactionComputed {
  let price_total = transaction.price_each *. transaction.qty

  let price_total_after_fee = case transaction.kind {
    Buy -> price_total +. transaction.buy_fee
    Sale -> price_total -. transaction.sale_fee
  }

  let price_each_after_fee = price_total_after_fee /. transaction.qty

  TransactionComputed(
    buy_fee: transaction.buy_fee,
    asset: transaction.asset,
    date: transaction.date,
    id: transaction.id,
    kind: transaction.kind,
    price_each: transaction.price_each,
    price_total:,
    qty: transaction.qty,
    sale_fee: transaction.sale_fee,
    price_total_after_fee:,
    price_each_after_fee:,
  )
}

pub type SaleAllocation {
  SaleAllocation(
    buy_date: Date,
    buy_price_each: Float,
    buy_price_total: Float,
    buy_transaction_id: String,
    capital_gain: Float,
    asset: String,
    days_held: Int,
    id: Uuid,
    qty: Float,
    sale_date: Date,
    sale_price_each: Float,
    sale_price_total: Float,
    sale_transaction_id: String,
  )
}

type ReportColumn {
  ColFY
  ColAsset
  ColBuyDate
  ColSaleDate
  ColBuyId
  ColSaleId
  ColQty
  ColBuyPriceEach
  ColBuyPriceTotal
  ColSalePriceEach
  ColSalePriceTotal
  ColCapitalGain
  ColCapitalGainDiscounted
  ColCGTDiscount
}

const report_columns = [
  ColFY,
  ColSaleDate,
  ColAsset,
  ColBuyDate,
  ColBuyId,
  ColSaleId,
  ColQty,
  ColBuyPriceEach,
  ColBuyPriceTotal,
  ColSalePriceEach,
  ColSalePriceTotal,
  ColCapitalGain,
  ColCapitalGainDiscounted,
  ColCGTDiscount,
]

pub fn with_context(error_context, next) {
  next()
  |> outcome.context(error_context)
}

pub type Acc {
  Acc(allocations: List(SaleAllocation))
}

fn calculate_sale_allocations(
  transactions: List(TransactionComputed),
) -> Outcome(List(SaleAllocation), String) {
  let #(buy_transactions, sale_transactions) =
    transactions |> list.partition(fn(t) { t.kind == Buy })

  let initial = Acc(allocations: [])

  list.try_fold(
    sale_transactions,
    initial,
    fn(acc: Acc, transaction: TransactionComputed) {
      let relevant_buy_transactions =
        buy_transactions
        |> list.filter(fn(t) { t.asset == transaction.asset })

      let allocations_for_this_asset =
        acc.allocations
        |> list.filter(fn(a) { a.asset == transaction.asset })

      use new_allocations <- result.try(allocate_sale_transaction(
        transaction,
        relevant_buy_transactions,
        allocations_for_this_asset,
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
  TransactionColId
  TransactionColAsset
  TransactionColDate
  TransactionColKind
  TransactionColPriceEach
  TransactionColPriceTotal
  TransactionColQty
  TransactionBuyFee
  TransactionSaleFee
  TransactionPriceEachAfterFee
  TransactionTotalAfterFee
}

const transaction_columns = [
  TransactionColId,
  TransactionColDate,
  TransactionColAsset,
  TransactionColKind,
  TransactionColQty,
  TransactionColPriceEach,
  TransactionColPriceTotal,
  TransactionBuyFee,
  TransactionSaleFee,
  TransactionPriceEachAfterFee,
  TransactionTotalAfterFee,
]

pub fn transactions_table(transactions: List(Transaction)) {
  let transactions = list.map(transactions, transaction_input_to_computed)

  let headers = transaction_columns |> list.map(transaction_col_header_to_label)

  let rows =
    transactions
    |> list.map(transaction_to_table_row)

  gtabler.print_table(table_config(), headers, rows)
}

fn transaction_col_header_to_label(col: TransactionCol) {
  case col {
    TransactionColId -> "Id"
    TransactionColAsset -> "Coin"
    TransactionColDate -> "Date"
    TransactionColKind -> "Kind"
    TransactionColPriceEach -> "Each"
    TransactionColPriceTotal -> "Total"
    TransactionColQty -> "Qty"
    TransactionBuyFee -> "Buy fee"
    TransactionSaleFee -> "Sale fee"
    TransactionPriceEachAfterFee -> "Each after fee"
    TransactionTotalAfterFee -> "Total after fee"
  }
}

fn transaction_to_table_row(transaction: TransactionComputed) {
  transaction_columns
  |> list.map(transaction_to_table_cell(_, transaction))
}

fn transaction_to_table_cell(
  col: TransactionCol,
  transaction: TransactionComputed,
) {
  case col {
    TransactionColId -> transaction.id
    TransactionColAsset -> transaction.asset
    TransactionColDate -> transaction.date |> date_to_label
    TransactionColKind -> transaction.kind |> kind_to_label
    TransactionColPriceEach -> transaction.price_each |> format_amount
    TransactionColPriceTotal -> transaction.price_total |> format_amount
    TransactionColQty -> transaction.qty |> format_amount
    TransactionBuyFee -> {
      case transaction.kind {
        Buy -> transaction.buy_fee |> format_amount
        Sale -> ""
      }
    }
    TransactionSaleFee -> {
      case transaction.kind {
        Buy -> ""
        Sale -> transaction.sale_fee |> format_amount
      }
    }
    TransactionPriceEachAfterFee ->
      transaction.price_each_after_fee |> format_amount
    TransactionTotalAfterFee ->
      transaction.price_total_after_fee |> format_amount
  }
}

fn generic_report(transactions: List(Transaction)) {
  use _ <- result.try(assert_no_duplicate_ids(transactions))

  let transactions = list.map(transactions, transaction_input_to_computed)

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
    ColBuyId -> "Buy Id"
    ColBuyPriceEach -> "Buy unit"
    ColBuyPriceTotal -> "Buy total"
    ColCapitalGain -> "Gain"
    ColCapitalGainDiscounted -> "Gain d."
    ColAsset -> "Coin"
    ColFY -> "FY"
    ColQty -> "Qty"
    ColCGTDiscount -> "CGT Discount"
    ColSaleDate -> "Sale date"
    ColSaleId -> "Sale Id"
    ColSalePriceEach -> "Sale unit"
    ColSalePriceTotal -> "Sale total"
  }
}

fn sale_allocation_to_report_line(allocation: SaleAllocation) {
  list.map(report_columns, sale_allocation_report_cell(_, allocation))
}

fn sale_allocation_report_cell(column: ReportColumn, allocation: SaleAllocation) {
  let gain = allocation.capital_gain
  let has_discount = allocation.days_held > 365

  let gain_after_discount = case has_discount {
    True -> gain /. 2.0
    False -> gain
  }

  case column {
    ColFY -> allocation.sale_date |> date_to_financial_year
    ColBuyDate -> allocation.buy_date |> date_to_label
    ColBuyId -> allocation.buy_transaction_id
    ColBuyPriceEach -> allocation.buy_price_each |> format_amount
    ColBuyPriceTotal ->
      allocation.buy_price_total
      |> format_amount
    ColCapitalGain ->
      gain
      |> format_amount
    ColCapitalGainDiscounted ->
      gain_after_discount
      |> format_amount
    ColAsset -> allocation.asset
    ColQty ->
      allocation.qty
      |> format_amount
    ColCGTDiscount -> {
      case has_discount {
        True -> "Yes"
        False -> ""
      }
    }
    ColSaleDate -> allocation.sale_date |> date_to_label
    ColSaleId -> allocation.sale_transaction_id
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
  sale_transaction: TransactionComputed,
  relevant_buy_transactions: List(TransactionComputed),
  allocations_for_this_asset: List(SaleAllocation),
) -> Outcome(List(SaleAllocation), String) {
  use <- with_context("sale_transaction " <> sale_transaction.id)

  let allocations_for_this_sale_transaction =
    allocations_for_this_asset
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
          allocations_for_this_asset,
        )
      })

      let allocations_for_this_buy_transaction =
        allocations_for_this_asset
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
          allocations_for_this_asset,
        )
      })

      let allocation_qty =
        float.min(remainder_to_allocate_for_buy, remainding_qty_to_allocate)

      // echo "allocation_qty"
      // echo allocation_qty

      let buy_price_each = buy_transaction.price_each_after_fee
      let buy_price_total = allocation_qty *. buy_price_each

      let sale_price_each = sale_transaction.price_each_after_fee
      let sale_price_total = allocation_qty *. sale_price_each

      let capital_gain = sale_price_total -. buy_price_total

      let days_held =
        date.difference(from: buy_transaction.date, to: sale_transaction.date)

      let new_allocation =
        SaleAllocation(
          buy_date: buy_transaction.date,
          buy_price_each:,
          buy_price_total:,
          buy_transaction_id: buy_transaction.id,
          capital_gain:,
          asset: sale_transaction.asset,
          id: uuid.v4(),
          qty: allocation_qty,
          days_held:,
          sale_date: sale_transaction.date,
          sale_transaction_id: sale_transaction.id,
          sale_price_each:,
          sale_price_total:,
        )

      // echo "new_allocation"
      // echo new_allocation

      let next_allocations =
        list.append(allocations_for_this_asset, [new_allocation])

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
  date.parse(input, tempo.CustomDate("DD/MM/YYYY"))
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
    |> outcome,
  )

  use asset <- result.try(
    dict.get(row, "asset")
    |> result.replace_error("Couldn't find asset")
    |> outcome,
  )

  use date_str <- result.try(
    dict.get(row, "date")
    |> result.replace_error("Couldn't find date")
    |> outcome,
  )

  use kind_str <- result.try(
    dict.get(row, "kind")
    |> result.replace_error("Couldn't find kind")
    |> outcome,
  )

  use qty_str <- result.try(
    dict.get(row, "qty")
    |> result.replace_error("Couldn't find qty")
    |> outcome,
  )

  use price_each_str <- result.try(
    dict.get(row, "price_each")
    |> result.replace_error("Couldn't find price_each")
    |> outcome,
  )

  use buy_fee_str <- result.try(
    dict.get(row, "buy_fee")
    |> result.replace_error("Couldn't find buy_fee")
    |> result.try_recover(fn(_) { Ok("0") })
    |> outcome,
  )

  use sale_fee_str <- result.try(
    dict.get(row, "sale_fee")
    |> result.replace_error("Couldn't find sale_fee")
    |> result.try_recover(fn(_) { Ok("0") })
    |> outcome,
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

  use buy_fee <- result.try(
    buy_fee_str
    |> string.replace("$", "")
    |> parse_float
    |> outcome.context("buy_fee"),
  )

  use sale_fee <- result.try(
    sale_fee_str
    |> string.replace("$", "")
    |> parse_float
    |> outcome.context("sale_fee"),
  )

  use qty <- result.try(qty_str |> parse_float |> outcome.context("qty"))

  let transaction =
    Transaction(
      buy_fee:,
      asset:,
      date:,
      id:,
      kind:,
      price_each:,
      qty:,
      sale_fee:,
    )

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

fn assert_no_duplicate_ids(transactions: List(Transaction)) {
  let ids =
    transactions
    |> list.map(fn(t) { t.id })

  let id_count = list.length(ids)
  let id_count_check = set.from_list(ids) |> set.size

  case id_count_check == id_count {
    True -> Ok(transactions)
    False -> Error("Duplicate ids found ") |> outcome
  }
}

fn write_output(report: String, file_path: String) -> Outcome(Nil, String) {
  simplifile.write(to: file_path, contents: report)
  |> result.replace_error("Unable to write to " <> file_path)
  |> outcome
}

fn process_file(in_path: String, out_path: String) {
  use transactions <- result.try(read_input(in_path))
  use report <- result.try(report_csv(transactions))
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

  let in_path = "./.data/" <> args.file <> ".csv"
  let out_path = "./.data/" <> args.file <> "_out.csv"

  case process_file(in_path, out_path) {
    Ok(message) -> io.println(message)
    Error(e) -> io.println_error(outcome.print_line(e, function.identity))
  }
}
