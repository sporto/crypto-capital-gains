import birdie
import gleeunit
import tempo/date
import transactions.{type Transaction, make_buy, make_sale}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn format_amount_test() {
  assert transactions.format_amount(600.1234) == "600.123"
  assert transactions.format_amount(-600.1234) == "-600.123"
}

fn feb_1() {
  date.literal("2020-02-01")
}

fn feb_2() {
  date.literal("2020-02-02")
}

fn feb_4() {
  date.literal("2020-02-04")
}

fn feb_5() {
  date.literal("2020-02-05")
}

fn feb_6() {
  date.literal("2020-02-06")
}

fn assert_report(transactions: List(Transaction), label: String) {
  let transaction_table = transactions.transactions_table(transactions)

  let report = case transactions.report_table(transactions) {
    Ok(report) -> report
    Error(err) -> "Error: " <> err
  }

  let output =
    "# "
    <> label
    <> "\n\n## Transactions\n\n"
    <> transaction_table
    <> "\n\n## Allocations\n\n"
    <> report

  output
  |> birdie.snap(label)
}

pub fn one_sale_has_less_test() {
  [
    make_buy(date: feb_1(), coin: "XRP", qty: 100.0, price_each: 0.5),
    make_sale(date: feb_2(), coin: "XRP", qty: 60.0, price_each: 0.6),
  ]
  |> assert_report("Simple sale with less")
}

pub fn two_sales_have_less_test() {
  [
    make_buy(date: feb_1(), coin: "XRP", qty: 100.0, price_each: 0.5),
    make_sale(date: feb_4(), coin: "XRP", qty: 60.0, price_each: 0.6),
    make_sale(date: feb_4(), coin: "XRP", qty: 30.0, price_each: 0.9),
  ]
  |> assert_report("Two sales have less")
}

pub fn two_sales_have_exact_test() {
  [
    make_buy(date: feb_1(), coin: "XRP", qty: 100.0, price_each: 0.5),
    make_sale(date: feb_4(), coin: "XRP", qty: 60.0, price_each: 0.6),
    make_sale(date: feb_4(), coin: "XRP", qty: 40.0, price_each: 0.9),
  ]
  |> assert_report("Two sales have exact")
}

pub fn two_sales_have_too_much_test() {
  [
    make_buy(date: feb_1(), coin: "XRP", qty: 100.0, price_each: 0.5),
    make_sale(date: feb_4(), coin: "XRP", qty: 60.0, price_each: 0.6),
    make_sale(date: feb_4(), coin: "XRP", qty: 50.0, price_each: 0.9),
  ]
  |> assert_report("Two sales have too much")
}

pub fn two_buys_one_sale_test() {
  [
    make_buy(date: feb_1(), coin: "XRP", qty: 100.0, price_each: 0.5),
    make_buy(date: feb_2(), coin: "XRP", qty: 100.0, price_each: 0.6),
    make_sale(date: feb_4(), coin: "XRP", qty: 150.0, price_each: 1.0),
  ]
  |> assert_report("Two buys one sale")
}

pub fn two_buys_two_sales_test() {
  [
    make_buy(date: feb_1(), coin: "XRP", qty: 100.0, price_each: 0.5),
    make_buy(date: feb_2(), coin: "XRP", qty: 100.0, price_each: 0.5),
    make_sale(date: feb_4(), coin: "XRP", qty: 150.0, price_each: 1.0),
    make_sale(date: feb_5(), coin: "XRP", qty: 50.0, price_each: 2.0),
  ]
  |> assert_report("Two buys, two sales")
}

pub fn order_matters_test() {
  [
    make_sale(date: feb_1(), coin: "XRP", qty: 100.0, price_each: 0.5),
    make_buy(date: feb_2(), coin: "XRP", qty: 100.0, price_each: 0.5),
  ]
  |> assert_report("Buy must be before")
}

pub fn mixed_test() {
  [
    make_buy(date: feb_1(), coin: "XRP", qty: 100.0, price_each: 0.5),
    make_buy(date: feb_2(), coin: "SOL", qty: 100.0, price_each: 50.0),
    make_sale(date: feb_4(), coin: "XRP", qty: 50.0, price_each: 0.75),
    make_buy(date: feb_5(), coin: "XRP", qty: 100.0, price_each: 0.6),
    make_sale(date: feb_6(), coin: "SOL", qty: 50.0, price_each: 40.0),
  ]
  |> assert_report("Mixed coins")
}
