import birdie
import gleam/time/calendar.{Date}
import gleeunit
import transactions.{make_buy, make_sale}
import youid/uuid.{v4}

pub fn main() -> Nil {
  gleeunit.main()
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
  |> transactions.report_table()
  |> birdie.snap("Simple sale with less")
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
  |> transactions.report_table()
  |> birdie.snap("Two sales have less")
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
  |> transactions.report_table()
  |> birdie.snap("Two sales have exact")
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
  |> transactions.report_table
  |> birdie.snap("Two sales have too much")
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
      price_each: 0.5,
    ),
    make_sale(
      date: Date(2020, calendar.February, 4),
      coin: "XRP",
      qty: 150.0,
      price_each: 1.0,
    ),
  ]
  |> transactions.report_table
  |> birdie.snap("Two buys one sale")
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
  |> transactions.report_table
  |> birdie.snap("Two buys, two sales")
}
