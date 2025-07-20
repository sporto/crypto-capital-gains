import birdie
import gleam/time/calendar.{Date}
import gleeunit
import transactions.{type Transaction, make_buy, make_sale}
import youid/uuid.{v4}

pub fn main() -> Nil {
  gleeunit.main()
}

fn assert_report(transactions: List(Transaction), label: String) {
  let transaction_table = transactions.transactions_table(transactions)

  let report = transactions.report_table(transactions)

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
    make_buy(
      date: Date(2020, calendar.February, 1),
      coin: "XRP",
      qty: 100.0,
      price_each: 0.5,
    ),
    make_sale(
      date: Date(2020, calendar.February, 4),
      coin: "XRP",
      qty: 60.0,
      price_each: 0.6,
    ),
  ]
  |> assert_report("Simple sale with less")
}

pub fn two_sales_have_less_test() {
  [
    make_buy(
      date: Date(2020, calendar.February, 1),
      coin: "XRP",
      qty: 100.0,
      price_each: 0.5,
    ),
    make_sale(
      date: Date(2020, calendar.February, 4),
      coin: "XRP",
      qty: 60.0,
      price_each: 0.6,
    ),
    make_sale(
      date: Date(2020, calendar.February, 4),
      coin: "XRP",
      qty: 30.0,
      price_each: 0.9,
    ),
  ]
  |> assert_report("Two sales have less")
}

pub fn two_sales_have_exact_test() {
  [
    make_buy(
      date: Date(2020, calendar.February, 1),
      coin: "XRP",
      qty: 100.0,
      price_each: 0.5,
    ),
    make_sale(
      date: Date(2020, calendar.February, 4),
      coin: "XRP",
      qty: 60.0,
      price_each: 0.6,
    ),
    make_sale(
      date: Date(2020, calendar.February, 4),
      coin: "XRP",
      qty: 40.0,
      price_each: 0.9,
    ),
  ]
  |> assert_report("Two sales have exact")
}

pub fn two_sales_have_too_much_test() {
  [
    make_buy(
      date: Date(2020, calendar.February, 1),
      coin: "XRP",
      qty: 100.0,
      price_each: 0.5,
    ),
    make_sale(
      date: Date(2020, calendar.February, 4),
      coin: "XRP",
      qty: 60.0,
      price_each: 0.6,
    ),
    make_sale(
      date: Date(2020, calendar.February, 4),
      coin: "XRP",
      qty: 50.0,
      price_each: 0.9,
    ),
  ]
  |> assert_report("Two sales have too much")
}

pub fn two_buys_one_sale_test() {
  [
    make_buy(
      date: Date(2020, calendar.February, 1),
      coin: "XRP",
      qty: 100.0,
      price_each: 0.5,
    ),
    make_buy(
      date: Date(2020, calendar.February, 2),
      coin: "XRP",
      qty: 100.0,
      price_each: 0.6,
    ),
    make_sale(
      date: Date(2020, calendar.February, 4),
      coin: "XRP",
      qty: 150.0,
      price_each: 1.0,
    ),
  ]
  |> assert_report("Two buys one sale")
}

pub fn two_buys_two_sales_test() {
  [
    make_buy(
      date: Date(2020, calendar.February, 1),
      coin: "XRP",
      qty: 100.0,
      price_each: 0.5,
    ),
    make_buy(
      date: Date(2020, calendar.February, 2),
      coin: "XRP",
      qty: 100.0,
      price_each: 0.5,
    ),
    make_sale(
      date: Date(2020, calendar.February, 4),
      coin: "XRP",
      qty: 150.0,
      price_each: 1.0,
    ),
    make_sale(
      date: Date(2020, calendar.February, 5),
      coin: "XRP",
      qty: 50.0,
      price_each: 2.0,
    ),
  ]
  |> assert_report("Two buys, two sales")
}

pub fn order_matters_test() {
  [
    make_sale(
      date: Date(2020, calendar.February, 1),
      coin: "XRP",
      qty: 100.0,
      price_each: 0.5,
    ),
    make_buy(
      date: Date(2020, calendar.February, 2),
      coin: "XRP",
      qty: 100.0,
      price_each: 0.5,
    ),
  ]
  |> assert_report("Buy must be before")
}
