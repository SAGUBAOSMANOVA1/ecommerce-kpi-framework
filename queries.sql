
-- 1. Customers: hər müştəri üçün unikal customer_id
CREATE TABLE IF NOT EXISTS customers (
    customer_id TEXT PRIMARY KEY,
    customer_unique_id TEXT,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state TEXT
);

-- 2. Orders: hər sifariş üçün unikal order_id
CREATE TABLE IF NOT EXISTS orders (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    order_status TEXT,
    order_purchase_timestamp TEXT,
    order_approved_at TEXT,
    order_delivered_carrier_date TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- 3. Sellers: hər satıcı üçün unikal seller_id
CREATE TABLE IF NOT EXISTS sellers (
    seller_id TEXT PRIMARY KEY,
    seller_zip_code_prefix TEXT,
    seller_city TEXT,
    seller_state TEXT
);

-- 4. Product category translations
CREATE TABLE IF NOT EXISTS category_translation (
    product_category_name TEXT PRIMARY KEY,
    product_category_name_english TEXT
);

-- 5. Products: hər məhsul üçün unikal product_id
CREATE TABLE IF NOT EXISTS products (
    product_id TEXT PRIMARY KEY,
    product_category_name TEXT,
    product_name_lenght INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty INTEGER,
    product_height_cm REAL,
    product_width_cm REAL
);


-- 6. Order items: bir sifarişdə bir neçə məhsul ola bilər
CREATE TABLE IF NOT EXISTS order_items (
    order_id TEXT NOT NULL,
    order_item_id INTEGER NOT NULL,
    product_id TEXT NOT NULL,
    seller_id TEXT NOT NULL,
    shipping_limit_date TEXT,
    price REAL,
    freight_value REAL,
    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (seller_id) REFERENCES sellers(seller_id)
);

-- 7. Reviews: review_id təkrarlandığı üçün texniki ID istifadə edirik
CREATE TABLE IF NOT EXISTS reviews (
    review_row_id INTEGER PRIMARY KEY AUTOINCREMENT,
    review_id TEXT,
    order_id TEXT NOT NULL,
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TEXT,
    review_answer_timestamp TEXT,
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);



-- Q10: Bonus KPI - Orders without reviews
-- Anti-join identifies orders with no matching review rows.

WITH orders_without_reviews AS (
    SELECT o.order_id
    FROM orders o
    LEFT JOIN reviews r
        ON o.order_id = r.order_id
    WHERE r.order_id IS NULL
)
SELECT
    (SELECT COUNT(*) FROM orders) AS total_orders,
    (SELECT COUNT(*) FROM orders_without_reviews)
        AS orders_without_reviews,
    ROUND(
        100.0 * (SELECT COUNT(*) FROM orders_without_reviews)
        / NULLIF((SELECT COUNT(*) FROM orders), 0),
        2
    ) AS no_review_share_pct;


-- Q1: Row counts and average items per order
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'reviews', COUNT(*) FROM reviews
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation;

SELECT
    COUNT(*) AS total_items,
    COUNT(DISTINCT order_id) AS orders_with_items,
    ROUND(1.0 * COUNT(*) / COUNT(DISTINCT order_id), 2) AS avg_items_per_order
FROM order_items;

-- Q2: Reusable analytical view
CREATE VIEW IF NOT EXISTS analytical_base AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.price,
    oi.freight_value,
    p.product_category_name,
    ct.product_category_name_english,
    r.review_score
FROM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
LEFT JOIN (
    SELECT order_id, AVG(review_score) AS review_score
    FROM reviews
    GROUP BY order_id
) r ON o.order_id = r.order_id;

-- Q3: Revenue reconciliation
SELECT 'order_items' AS source, ROUND(SUM(price), 2) AS revenue
FROM order_items
UNION ALL
SELECT 'analytical_base', ROUND(SUM(price), 2)
FROM analytical_base;

-- Q4: Overall delivered-order KPIs
SELECT
    COUNT(DISTINCT order_id) AS delivered_orders,
    ROUND(SUM(price), 2) AS revenue_brl,
    ROUND(SUM(price) / COUNT(DISTINCT order_id), 2) AS avg_order_value_brl,
    ROUND(AVG(
        julianday(order_delivered_customer_date) -
        julianday(order_purchase_timestamp)
    ), 2) AS avg_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM analytical_base
WHERE order_status = 'delivered';

-- Q5: KPIs by product category
SELECT
    COALESCE(product_category_name_english, 'unknown') AS category,
    ROUND(SUM(price), 2) AS revenue_brl,
    ROUND(SUM(price) / COUNT(DISTINCT order_id), 2) AS avg_order_value_brl,
    ROUND(AVG(
        julianday(order_delivered_customer_date) -
        julianday(order_purchase_timestamp)
    ), 2) AS avg_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    COUNT(DISTINCT order_id) AS order_count
FROM analytical_base
WHERE order_status = 'delivered'
GROUP BY COALESCE(product_category_name_english, 'unknown')
ORDER BY revenue_brl DESC;

-- Q6: KPIs by purchase month
SELECT
    strftime('%Y-%m', order_purchase_timestamp) AS month,
    ROUND(SUM(price), 2) AS revenue_brl,
    ROUND(SUM(price) / COUNT(DISTINCT order_id), 2) AS avg_order_value_brl,
    ROUND(AVG(
        julianday(order_delivered_customer_date) -
        julianday(order_purchase_timestamp)
    ), 2) AS avg_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM analytical_base
WHERE order_status = 'delivered'
GROUP BY strftime('%Y-%m', order_purchase_timestamp)
ORDER BY month;

-- Q7: Top 5 and bottom 5 categories by revenue
WITH category_revenue AS (
    SELECT
        COALESCE(product_category_name_english, 'unknown') AS category,
        SUM(price) AS revenue
    FROM analytical_base
    WHERE order_status = 'delivered'
    GROUP BY COALESCE(product_category_name_english, 'unknown')
),
ranked AS (
    SELECT *,
        RANK() OVER (ORDER BY revenue DESC) AS top_rank,
        RANK() OVER (ORDER BY revenue ASC) AS bottom_rank
    FROM category_revenue
)
SELECT category, ROUND(revenue, 2) AS revenue_brl,
       'TOP' AS group_type, top_rank AS category_rank
FROM ranked WHERE top_rank <= 5
UNION ALL
SELECT category, ROUND(revenue, 2),
       'BOTTOM', bottom_rank
FROM ranked WHERE bottom_rank <= 5
ORDER BY group_type, category_rank;

-- Q8: Top and bottom categories by review score; minimum 100 orders
WITH category_reviews AS (
    SELECT
        COALESCE(product_category_name_english, 'unknown') AS category,
        AVG(review_score) AS avg_review_score,
        COUNT(DISTINCT order_id) AS order_count
    FROM analytical_base
    WHERE order_status = 'delivered'
      AND review_score IS NOT NULL
    GROUP BY COALESCE(product_category_name_english, 'unknown')
    HAVING COUNT(DISTINCT order_id) >= 100
),
ranked AS (
    SELECT *,
        RANK() OVER (ORDER BY avg_review_score DESC) AS top_rank,
        RANK() OVER (ORDER BY avg_review_score ASC) AS bottom_rank
    FROM category_reviews
)
SELECT category, ROUND(avg_review_score, 2) AS avg_review_score,
       order_count, 'TOP' AS group_type, top_rank AS category_rank
FROM ranked WHERE top_rank <= 5
UNION ALL
SELECT category, ROUND(avg_review_score, 2),
       order_count, 'BOTTOM', bottom_rank
FROM ranked WHERE bottom_rank <= 5
ORDER BY group_type, category_rank;

-- Q9: Seller performance and revenue ranking
WITH seller_kpis AS (
    SELECT
        seller_id,
        SUM(price) AS revenue,
        COUNT(DISTINCT order_id) AS order_count,
        AVG(review_score) AS avg_review_score,
        AVG(
            julianday(order_delivered_customer_date) -
            julianday(order_purchase_timestamp)
        ) AS avg_delivery_days
    FROM analytical_base
    WHERE order_status = 'delivered'
    GROUP BY seller_id
)
SELECT
    seller_id,
    ROUND(revenue, 2) AS revenue_brl,
    order_count,
    ROUND(avg_review_score, 2) AS avg_review_score,
    ROUND(avg_delivery_days, 2) AS avg_delivery_days,
    RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM seller_kpis
ORDER BY revenue_rank;

-- Q10: Category delivery time and review score for correlation analysis
SELECT
    COALESCE(product_category_name_english, 'unknown') AS category,
    ROUND(AVG(
        julianday(order_delivered_customer_date) -
        julianday(order_purchase_timestamp)
    ), 2) AS avg_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    COUNT(DISTINCT order_id) AS order_count
FROM analytical_base
WHERE order_status = 'delivered'
  AND review_score IS NOT NULL
GROUP BY COALESCE(product_category_name_english, 'unknown')
HAVING COUNT(DISTINCT order_id) >= 100
ORDER BY order_count DESC;

-- BONUS 1: On-time delivery rate
SELECT
    COUNT(*) AS delivered_orders_with_dates,
    SUM(CASE
        WHEN order_delivered_customer_date <= order_estimated_delivery_date
        THEN 1 ELSE 0
    END) AS on_time_orders,
    ROUND(100.0 * SUM(CASE
        WHEN order_delivered_customer_date <= order_estimated_delivery_date
        THEN 1 ELSE 0
    END) / COUNT(*), 2) AS on_time_delivery_rate_pct
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;

-- BONUS 2: Freight cost as a share of revenue by category
SELECT
    COALESCE(product_category_name_english, 'unknown') AS category,
    ROUND(SUM(price), 2) AS revenue_brl,
    ROUND(SUM(freight_value), 2) AS freight_brl,
    ROUND(100.0 * SUM(freight_value) / NULLIF(SUM(price), 0), 2)
        AS freight_to_revenue_pct,
    CASE
        WHEN 100.0 * SUM(freight_value) / NULLIF(SUM(price), 0) >= 15
        THEN 'HIGH SHIPPING COST'
        ELSE 'NORMAL'
    END AS shipping_flag
FROM analytical_base
WHERE order_status = 'delivered'
GROUP BY COALESCE(product_category_name_english, 'unknown')
ORDER BY freight_to_revenue_pct DESC;

-- BONUS 3: Category share of monthly revenue
WITH category_month AS (
    SELECT
        strftime('%Y-%m', order_purchase_timestamp) AS month,
        COALESCE(product_category_name_english, 'unknown') AS category,
        SUM(price) AS category_revenue
    FROM analytical_base
    WHERE order_status = 'delivered'
    GROUP BY strftime('%Y-%m', order_purchase_timestamp),
             COALESCE(product_category_name_english, 'unknown')
)
SELECT
    month,
    category,
    ROUND(category_revenue, 2) AS category_revenue_brl,
    ROUND(100.0 * category_revenue /
        NULLIF(SUM(category_revenue) OVER (PARTITION BY month), 0), 2)
        AS monthly_revenue_share_pct
FROM category_month
ORDER BY month, monthly_revenue_share_pct DESC;
