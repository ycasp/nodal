require "test_helper"

class Dashboard::MetricsTest < ActiveSupport::TestCase
  setup do
    @org = Organisation.create!(name: "Health Test Org")
  end

  def build_customer(label)
    Customer.create!(organisation: @org, company_name: label, contact_name: label,
                     email: "#{label}@empresa.local", active: true)
  end

  def build_user(customer, label, **attrs)
    CustomerUser.create!(
      organisation: @org,
      customer: customer,
      email: "#{label}@test.local",
      password: "pass1234",
      password_confirmation: "pass1234",
      contact_name: label,
      active: true,
      **attrs
    )
  end

  test "counts invitation states at the customer (empresa) level" do
    c_active = build_customer("c_active")
    build_user(c_active, "a", invitation_sent_at: 10.days.ago, invitation_accepted_at: 5.days.ago)

    c_pending = build_customer("c_pending")
    build_user(c_pending, "b", invitation_sent_at: 3.days.ago)

    c_stale = build_customer("c_stale")
    build_user(c_stale, "c", invitation_sent_at: 15.days.ago)

    c_uninvited = build_customer("c_uninvited")
    build_user(c_uninvited, "d")

    health = Dashboard::Metrics.customer_health(organisation: @org)

    assert_equal 1, health[:active_users]
    assert_equal 2, health[:pending_users]
    assert_equal 1, health[:stale_pending_users]
    assert_equal 1, health[:uninvited_users]
  end

  test "online_now reflects empresas with at least one user seen in 5 min" do
    c = build_customer("c1")
    build_user(c, "online", invitation_sent_at: 1.day.ago, invitation_accepted_at: 1.day.ago,
               last_seen_at: 1.minute.ago)
    build_user(c, "offline", invitation_sent_at: 1.day.ago, invitation_accepted_at: 1.day.ago,
               last_seen_at: 10.minutes.ago)

    assert_equal 1, Dashboard::Metrics.customer_health(organisation: @org)[:online_now]
  end

  test "accepted_no_return counts empresas that accepted but never came back" do
    c = build_customer("c1")
    build_user(c, "x", invitation_sent_at: 10.days.ago, invitation_accepted_at: 9.days.ago,
               sign_in_count: 1, current_sign_in_at: 9.days.ago)

    assert_equal 1, Dashboard::Metrics.customer_health(organisation: @org)[:accepted_no_return]
  end

  test "dormant requires returning users (sign_in_count > 1) without recent login" do
    c_dormant = build_customer("c_dormant")
    build_user(c_dormant, "d", invitation_sent_at: 60.days.ago, invitation_accepted_at: 60.days.ago,
               sign_in_count: 5, current_sign_in_at: 45.days.ago)

    # one-time acceptor — NOT dormant (counts as accepted_no_return instead)
    c_one_time = build_customer("c_one_time")
    build_user(c_one_time, "o", invitation_sent_at: 60.days.ago, invitation_accepted_at: 60.days.ago,
               sign_in_count: 1, current_sign_in_at: 60.days.ago)

    health = Dashboard::Metrics.customer_health(organisation: @org)
    assert_equal 1, health[:dormant]
    assert_equal 1, health[:accepted_no_return]
  end

  test "engaged_no_orders counts returning, recently-active empresas without orders" do
    c = build_customer("c1")
    cu = build_user(c, "eng", invitation_sent_at: 10.days.ago, invitation_accepted_at: 9.days.ago,
                    sign_in_count: 5, current_sign_in_at: 1.day.ago)

    assert_equal 1, Dashboard::Metrics.customer_health(organisation: @org)[:engaged_no_orders]

    product = Product.create!(organisation: @org, name: "P", unit_price: 1000, published: true)
    placed = Order.create!(customer: c, customer_user: cu, organisation: @org)
    placed.order_items.create!(product: product, quantity: 1)
    placed.update!(placed_at: Time.current)

    assert_equal 0, Dashboard::Metrics.customer_health(organisation: @org)[:engaged_no_orders]
  end

  # --- time_series ---

  def build_basic_setup
    c = build_customer("ts_c")
    cu = build_user(c, "ts_u", invitation_sent_at: 1.day.ago, invitation_accepted_at: 1.day.ago)
    product = Product.create!(organisation: @org, name: "P", unit_price: 1000, published: true)
    [c, cu, product]
  end

  def place(customer, cu, product, qty:, when_at:)
    o = Order.create!(customer: customer, customer_user: cu, organisation: @org)
    o.order_items.create!(product: product, quantity: qty)
    o.update!(placed_at: when_at)
    o
  end

  test "time_series :sales sums revenue per bucket" do
    c, cu, product = build_basic_setup
    place(c, cu, product, qty: 2, when_at: 1.day.ago)  # 2 * 10€ = 20€

    series = Dashboard::Metrics.time_series(organisation: @org, metric: :sales,
                                             from: 7.days.ago, to: Time.current, granularity: :day)
    assert_equal 20.0, series[:series].first[:data].sum.round(2)
  end

  test "time_series :orders counts placed orders" do
    c, cu, product = build_basic_setup
    3.times { place(c, cu, product, qty: 1, when_at: 1.day.ago) }

    series = Dashboard::Metrics.time_series(organisation: @org, metric: :orders,
                                             from: 7.days.ago, to: Time.current, granularity: :day)
    assert_equal 3, series[:series].first[:data].sum
  end

  test "time_series :carts returns two series (created + placed)" do
    c, cu, product = build_basic_setup
    draft = Order.create!(customer: c, customer_user: cu, organisation: @org)
    draft.order_items.create!(product: product, quantity: 1)
    place(c, cu, product, qty: 1, when_at: Time.current)

    series = Dashboard::Metrics.time_series(organisation: @org, metric: :carts,
                                             from: 7.days.ago, to: Time.current, granularity: :day)
    assert_equal 2, series[:series].size
    assert_equal "carts_created", series[:series][0][:label]
    assert_equal "carts_placed",  series[:series][1][:label]
    assert_equal 2, series[:series][0][:data].sum
    assert_equal 1, series[:series][1][:data].sum
  end

  test "time_series :avg_interval averages gaps between orders" do
    c, cu, product = build_basic_setup
    [30.days.ago, 20.days.ago, 10.days.ago].each { |t| place(c, cu, product, qty: 1, when_at: t) }

    series = Dashboard::Metrics.time_series(organisation: @org, metric: :avg_interval,
                                             from: 35.days.ago, to: Time.current, granularity: :month)
    non_zero = series[:series].first[:data].reject(&:zero?)
    assert non_zero.any?, "expected at least one bucket with avg interval"
    non_zero.each { |v| assert_in_delta 10.0, v, 1.0 }
  end

  test "time_series respects granularity" do
    series_day  = Dashboard::Metrics.time_series(organisation: @org, metric: :orders,
                                                  from: 30.days.ago, to: Time.current, granularity: :day)
    series_week = Dashboard::Metrics.time_series(organisation: @org, metric: :orders,
                                                  from: 30.days.ago, to: Time.current, granularity: :week)
    series_month = Dashboard::Metrics.time_series(organisation: @org, metric: :orders,
                                                   from: 30.days.ago, to: Time.current, granularity: :month)
    assert series_day[:labels].size  > series_week[:labels].size
    assert series_week[:labels].size > series_month[:labels].size
  end
end
