# Backoffice Dashboard SQL Queries

This document describes the key SQL queries used by the dashboard metrics service (`Dashboard::Metrics`).

## Indexes

The following indexes have been added to optimize dashboard queries:

```sql
-- Orders by organisation and date range
CREATE INDEX index_orders_on_organisation_id_and_placed_at
ON orders (organisation_id, placed_at);

-- Orders by organisation and customer
CREATE INDEX index_orders_on_organisation_id_and_customer_id
ON orders (organisation_id, customer_id);

-- Order items by order and product
CREATE INDEX index_order_items_on_order_id_and_product_id
ON order_items (order_id, product_id);
```

## Core Queries

### Total Sales

Sum of all order item revenues (after line-item discounts):

```sql
SELECT SUM(
  order_items.unit_price * order_items.quantity *
  (1 - COALESCE(order_items.discount_percentage, 0))
) / 100.0 AS total_sales
FROM orders
INNER JOIN order_items ON order_items.order_id = orders.id
WHERE orders.organisation_id = :org_id
  AND orders.placed_at IS NOT NULL
  AND orders.placed_at BETWEEN :from AND :to;
```

### Order Count

```sql
SELECT COUNT(*)
FROM orders
WHERE organisation_id = :org_id
  AND placed_at IS NOT NULL
  AND placed_at BETWEEN :from AND :to;
```

### Average Order Value (AOV)

```sql
SELECT
  SUM(order_items.unit_price * order_items.quantity *
      (1 - COALESCE(order_items.discount_percentage, 0))) / 100.0 / COUNT(DISTINCT orders.id)
FROM orders
INNER JOIN order_items ON order_items.order_id = orders.id
WHERE orders.organisation_id = :org_id
  AND orders.placed_at IS NOT NULL
  AND orders.placed_at BETWEEN :from AND :to;
```

### Customer Sales (for Top Clients)

```sql
SELECT
  orders.customer_id,
  SUM(order_items.unit_price * order_items.quantity *
      (1 - COALESCE(order_items.discount_percentage, 0))) AS total_cents
FROM orders
INNER JOIN order_items ON order_items.order_id = orders.id
WHERE orders.organisation_id = :org_id
  AND orders.placed_at IS NOT NULL
  AND orders.placed_at BETWEEN :from AND :to
GROUP BY orders.customer_id
ORDER BY total_cents DESC
LIMIT 10;
```

### Retention Rate

```sql
-- Previous period customers
SELECT DISTINCT customer_id
FROM orders
WHERE organisation_id = :org_id
  AND placed_at IS NOT NULL
  AND placed_at BETWEEN :prev_from AND :prev_to;

-- Current period customers
SELECT DISTINCT customer_id
FROM orders
WHERE organisation_id = :org_id
  AND placed_at IS NOT NULL
  AND placed_at BETWEEN :from AND :to;

-- Retention = COUNT(intersection) / COUNT(previous period)
```

### Open Carts

```sql
SELECT orders.*, customers.company_name
FROM orders
LEFT JOIN customers ON customers.id = orders.customer_id
WHERE orders.organisation_id = :org_id
  AND orders.placed_at IS NULL
ORDER BY orders.updated_at DESC
LIMIT 10;
```

### Orders per Product

```sql
SELECT
  order_items.product_id,
  COUNT(DISTINCT order_items.order_id) AS order_count
FROM order_items
INNER JOIN orders ON orders.id = order_items.order_id
WHERE orders.organisation_id = :org_id
  AND orders.placed_at IS NOT NULL
  AND orders.placed_at BETWEEN :from AND :to
GROUP BY order_items.product_id
ORDER BY order_count DESC
LIMIT 20;
```

### Revenue per Product (with Discount Breakdown)

```sql
SELECT
  order_items.product_id,
  products.name AS product_name,
  SUM(order_items.unit_price * order_items.quantity) AS gross_cents,
  SUM(order_items.unit_price * order_items.quantity *
      COALESCE(order_items.discount_percentage, 0)) AS discount_cents
FROM order_items
INNER JOIN orders ON orders.id = order_items.order_id
INNER JOIN products ON products.id = order_items.product_id
WHERE orders.organisation_id = :org_id
  AND orders.placed_at IS NOT NULL
  AND orders.placed_at BETWEEN :from AND :to
GROUP BY order_items.product_id, products.name
ORDER BY gross_cents DESC
LIMIT 20;
```

### Discount Analytics

#### Usage Rate

```sql
SELECT
  COUNT(DISTINCT orders.id) FILTER (
    WHERE COALESCE(order_items.discount_percentage, 0) > 0
       OR orders.discount_type IS NOT NULL
       OR orders.auto_discount_type IS NOT NULL
  )::float / COUNT(DISTINCT orders.id) AS usage_rate
FROM orders
LEFT JOIN order_items ON order_items.order_id = orders.id
WHERE orders.organisation_id = :org_id
  AND orders.placed_at IS NOT NULL
  AND orders.placed_at BETWEEN :from AND :to;
```

#### Top Discounted Products

```sql
SELECT
  order_items.product_id,
  products.name AS product_name,
  SUM(order_items.unit_price * order_items.quantity *
      order_items.discount_percentage) AS discount_cents
FROM order_items
INNER JOIN orders ON orders.id = order_items.order_id
INNER JOIN products ON products.id = order_items.product_id
WHERE orders.organisation_id = :org_id
  AND orders.placed_at IS NOT NULL
  AND orders.placed_at BETWEEN :from AND :to
  AND COALESCE(order_items.discount_percentage, 0) > 0
GROUP BY order_items.product_id, products.name
ORDER BY discount_cents DESC
LIMIT 5;
```

#### Top Clients by Discount

```sql
SELECT
  orders.customer_id AS client_id,
  customers.company_name AS client_name,
  SUM(order_items.unit_price * order_items.quantity *
      order_items.discount_percentage) AS discount_cents
FROM order_items
INNER JOIN orders ON orders.id = order_items.order_id
INNER JOIN customers ON customers.id = orders.customer_id
WHERE orders.organisation_id = :org_id
  AND orders.placed_at IS NOT NULL
  AND orders.placed_at BETWEEN :from AND :to
  AND COALESCE(order_items.discount_percentage, 0) > 0
GROUP BY orders.customer_id, customers.company_name
ORDER BY discount_cents DESC
LIMIT 5;
```

## Daily Sparkline Data

### Daily Sales

```sql
SELECT
  DATE(orders.placed_at) AS date,
  SUM(order_items.unit_price * order_items.quantity *
      (1 - COALESCE(order_items.discount_percentage, 0))) / 100.0 AS daily_sales
FROM orders
INNER JOIN order_items ON order_items.order_id = orders.id
WHERE orders.organisation_id = :org_id
  AND orders.placed_at IS NOT NULL
  AND orders.placed_at BETWEEN :from AND :to
GROUP BY DATE(orders.placed_at)
ORDER BY date;
```

### Daily Orders

```sql
SELECT
  DATE(placed_at) AS date,
  COUNT(*) AS daily_count
FROM orders
WHERE organisation_id = :org_id
  AND placed_at IS NOT NULL
  AND placed_at BETWEEN :from AND :to
GROUP BY DATE(placed_at)
ORDER BY date;
```

## Performance Considerations

1. **Use the indexes**: All queries filter by `organisation_id` first, which leverages the composite indexes.

2. **Date range filtering**: Always include `placed_at` date range to limit data scanned.

3. **Avoid N+1**: The service preloads related records (products, customers) in batch rather than per-row.

4. **Integer arithmetic**: Calculations use integer cents (`unit_price * quantity`) and only divide by 100.0 at the end.

## Future Optimizations

For high-volume organisations, consider:

1. **Materialized views** for daily/weekly aggregates
2. **Background job** to pre-compute KPIs and cache results
3. **Partitioning** orders table by `placed_at` date
