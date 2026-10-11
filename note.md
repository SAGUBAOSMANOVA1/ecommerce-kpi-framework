# E-Commerce KPI Framework — Analysis Notes

## 1. Data Model and ER Relationships

- `customers` (1) → (many) `orders` through `customer_id`.
- `orders` (1) → (many) `order_items` through `order_id`.
- `products` (1) → (many) `order_items` through `product_id`.
- `sellers` (1) → (many) `order_items` through `seller_id`.
- `products` → `category_translation` through `product_category_name`.
- `orders` (1) → (many) `reviews` through `order_id`.

Primary keys uniquely identify records. `order_items` uses the composite primary key `(order_id, order_item_id)`. `reviews` uses `review_row_id` as its technical primary key because `review_id` contains duplicate values.

## 2. Join Strategy

- `INNER JOIN` between orders and order items includes orders that contain product line items.
- `INNER JOIN` between order items and products ensures product details are available for included items.
- `LEFT JOIN` to category translations preserves products even when an English category translation is missing.
- Reviews are aggregated by `order_id` before joining to avoid multiplying product rows when an order has multiple review records.
- Delivered-order KPIs use `order_status = 'delivered'`.
- Delivery-time calculations use purchase and delivery timestamps; records with missing timestamps are excluded from the average.

## 3. Revenue Reconciliation

- Direct revenue from `order_items`: **13,591,643.70 BRL**
- Revenue from `analytical_base`: **13,591,643.70 BRL**
- Difference: **0.00 BRL**

The reconciliation confirms that the analytical view does not inflate total item revenue. Reviews are aggregated at order level before joining, preventing review records from multiplying item rows.

For delivered orders:

- Delivered revenue: **13,221,498.11 BRL**
- Average order value: **137.04 BRL**

## 4. Key Operational Insights

1. **Health & Beauty leads revenue:** 1,233,131.72 BRL. Review inventory and product availability for this important category.
2. **Security & Services has the lowest revenue:** 283.29 BRL. Investigate demand, assortment and sales opportunities before deciding whether to expand the category.
3. **Books General Interest has the highest average review score:** 4.53/5 across 492 orders. Investigate which product and service practices may contribute to customer satisfaction.
4. **Office Furniture has the lowest average review score:** 3.64/5 across 1,244 orders. Review customer complaints, product quality and delivery issues.
5. **Delivery time and review score show a negative association:** Pearson correlation is -0.5756 across categories with at least 100 delivered orders. Investigate delivery delays as a possible contributor to lower satisfaction; correlation alone does not prove causation.

## 5. Overall KPIs

- Delivered orders: 96,478
- Delivered revenue: 13,221,498.11 BRL
- Average order value: 137.04 BRL
- Average delivery time: 12.56 days
- Average review score: 4.16/5

## 6. Analytical View

The reusable `analytical_base` SQL VIEW combines order, item, product, category translation and order-level review information. It retains all order statuses so that individual KPI queries can explicitly filter delivered orders where required.
