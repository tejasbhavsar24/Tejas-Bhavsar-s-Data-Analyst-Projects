
# Zomato End-to-End SQL Analytics Workflow

An end-to-end **SQL analytics case study** built on Zomato-style transactional data.  
This project demonstrates how a data analyst approaches **raw data validation, funnel analysis, revenue drivers, geographic performance, and customer segmentation** using MySQL.

---

## Problem Statement

Food delivery platforms generate high-volume transactional and behavioral data, but business decisions require:
- Clean and reliable data
- Clear visibility into user drop-offs
- Identification of high-performing channels, cities, and customers
- Actionable segmentation for retention and monetization

This project answers:
- Where do users drop in the app journey?
- Which channels and devices drive the most value?
- Which cities are mature vs growth markets?
- Who are the most valuable customers, and who is at risk of churn?

---

## Key Assumptions

- Data represents a single historical snapshot
- All monetary values are in INR (₹)
- Platform commission assumed at 30% of order value
- One `app_session_id` equals one continuous session
- Orders may be completed or cancelled with refunds at item level
- Funnel analysis is session-based, not user-based
- RFM scores are relative to this dataset

---

##  Dataset Overview

| Table | Description |
|------|------------|
| users | User demographics and membership |
| app_sessions | Traffic source and device |
| app_pageviews | Page-level navigation |
| orders | Order-level transactions |
| order_items | Item-level details |
| order_items_cancelled | Refund data |
| restaurants | City mapping |
| menu | Food catalog |

---

## 🧩 PART 1: Database Setup & Data Cleaning

### Objective
## 🔍 Initial Data Checks

### User & Order Counts

```sql
SELECT COUNT(*) AS total_orders FROM orders;

SELECT COUNT(DISTINCT user_id) AS unique_users FROM users;
```

**Observation:**  
- 15,000 total orders  
- 5,000 unique users  
- Indicates repeat ordering behavior (~3 orders per user)

---

##  Duplicate Checks

```sql
SELECT 
    COUNT(*) AS total_orders,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_orders
FROM orders;
```

**Result:**  
No duplicate `order_id` values detected.

---

##  Data Cleaning Steps

### Review App Sessions

```sql
SELECT * FROM app_sessions;
```

---

### NULL UTM Source Handling

Assumption: Missing UTM values represent **Direct traffic**.

```sql
UPDATE app_sessions
SET utm_source = 'Direct'
WHERE utm_source IS NULL;
```

---

##  Date & Time Standardization

To ensure accurate time-based analysis, all date fields were converted to `DATETIME` format.

### Orders Table

```sql
ALTER TABLE orders MODIFY COLUMN order_time DATETIME;
ALTER TABLE orders MODIFY COLUMN delivery_time DATETIME;
```

### Users Table

```sql
ALTER TABLE users MODIFY COLUMN signup_date DATETIME;
```

### Cancelled Orders Table

```sql
ALTER TABLE order_items_cancelled MODIFY COLUMN created_at DATETIME;
```

### App Sessions Table

```sql
ALTER TABLE app_sessions MODIFY COLUMN created_at DATETIME;
```

---

##  Delivery Fee Flag Creation

Adds interpretability for free vs paid deliveries.

```sql
ALTER TABLE orders ADD COLUMN delivery_flag VARCHAR(50);

UPDATE orders
SET delivery_flag =
    CASE
        WHEN delivery_fee_paid = 0 THEN 'Complimentary'
        ELSE 'Paid'
    END;
```

---

##  Date Feature Engineering

Additional columns added to support **time-series and cohort analysis**.

```sql
ALTER TABLE orders
ADD COLUMN order_day INT,
ADD COLUMN order_month INT,
ADD COLUMN order_year INT,
ADD COLUMN order_hour INT,
ADD COLUMN min_time_delivery INT;
```

### Populate Derived Columns

```sql
UPDATE orders SET order_day = DAY(order_time);
UPDATE orders SET order_month = MONTH(order_time);
UPDATE orders SET order_year = YEAR(order_time);
UPDATE orders SET order_hour = HOUR(order_time);
UPDATE orders 
SET min_time_delivery = TIMESTAMPDIFF(MINUTE, order_time, delivery_time);
```

---

##  Final Duplicate Validation

```sql
SELECT order_id, COUNT(*)
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;
```

**Expected Result:**  
Zero rows returned.

---

## Part 2: UX Funnel Analysis

### Step 2.1: Create Cancelled Orders Aggregation

```sql
CREATE TEMPORARY TABLE cancelled_orders AS

SELECT
    order_id,
    SUM(amount_of_refund) AS total_refunds,
    MAX(created_at) as cancelled_at
FROM order_items_cancelled
GROUP BY order_id;
```

---

### Step 2.2: Calculate Net Revenue per Order

```sql
CREATE TEMPORARY TABLE net_GMV_orders AS

SELECT
    o.order_id,
    o.app_session_id,
    o.restaurant_id,
    o.order_time,
    COALESCE(o.delivery_time, c.cancelled_at) AS final_time,
    o.delivery_fee_paid,
    o.total_price,
    c.total_refunds,
    CASE
        WHEN c.order_id IS NOT NULL THEN 'Cancelled'
        ELSE 'Completed'
    END AS order_status,
    CASE
        WHEN c.order_id IS NOT NULL THEN -c.total_refunds
        ELSE o.total_price - o.delivery_fee_paid
    END AS net_revenue
FROM orders o
LEFT JOIN cancelled_orders c
    ON o.order_id = c.order_id;
```

---

### Step 2.3: Create Funnel Stage Flags

```sql
CREATE TEMPORARY TABLE pageviews_per_session AS

SELECT
    app_session_id,
    MAX(CASE WHEN pageview_url = '/home-page' THEN 1 ELSE 0 END) AS homepage_views,
    MAX(CASE WHEN pageview_url = '/search' THEN 1 ELSE 0 END) AS search_views,
    MAX(CASE WHEN pageview_url = '/restaurants' THEN 1 ELSE 0 END) AS restaurants_views,
    MAX(CASE WHEN pageview_url = '/menu' THEN 1 ELSE 0 END) AS menu_views,
    MAX(CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END) AS cart_views
FROM app_pageviews
GROUP BY app_session_id;
```

---

### Step 2.4: Aggregate Orders per Session

```sql
CREATE TEMPORARY TABLE orders_per_sessions AS

SELECT
    app_session_id,
    COUNT(DISTINCT CASE WHEN order_status = 'Completed' THEN order_id END) AS completed_orders,
    COUNT(DISTINCT CASE WHEN order_status = 'Cancelled' THEN order_id END) AS cancelled_orders,
    SUM(CASE WHEN order_status = 'Completed' THEN net_revenue ELSE 0 END) AS net_revenue_completed_orders,
    SUM(CASE WHEN order_status = 'Cancelled' THEN net_revenue ELSE 0 END) AS net_revenue_cancelled_orders,
    SUM(net_revenue) AS net_revenue_all_orders
FROM net_GMV_orders
GROUP BY app_session_id;
```

---

### Step 2.5: Complete Funnel Analysis

```sql
SELECT
    SUM(s.homepage_views) AS homepage_sessions,
    SUM(s.search_views) AS search_sessions,
    ROUND(sum(s.search_views) * 100 / NULLIF(sum(s.homepage_views), 0),2) AS pct_home_to_search_sessions,
    
    SUM(s.restaurants_views) AS restaurants_sessions,
    ROUND(sum(s.restaurants_views) * 100 / NULLIF(sum(s.search_views), 0),2) AS pct_search_to_restaurants_sessions,
    
    SUM(s.menu_views) AS menu_sessions,
    ROUND(sum(s.menu_views) * 100 / NULLIF(sum(s.restaurants_views), 0),2) AS pct_restaurants_to_menu_sessions,
    
    SUM(s.cart_views) AS cart_sessions,
    ROUND(sum(s.cart_views) * 100 / NULLIF(sum(s.menu_views), 0),2) AS pct_menu_to_cart_sessions,
    
    SUM(o.completed_orders) AS placed_orders,
    ROUND(sum(o.completed_orders) * 100 / NULLIF(sum(s.cart_views), 0),2) AS pct_cart_to_order_sessions,
    
    ROUND(100 - (sum(o.completed_orders) * 100 / NULLIF(sum(s.cart_views), 0)), 2) AS cart_abandonment_rate,
    
    SUM(o.net_revenue_completed_orders) AS total_revenue,
    (-1 * SUM(o.net_revenue_cancelled_orders)) AS total_refunds,
    SUM(o.net_revenue_all_orders) AS net_revenue_all_orders,
    avg(o.net_revenue_all_orders) AS net_revenue_per_order
FROM pageviews_per_session as s
LEFT JOIN orders_per_sessions as o
    ON s.app_session_id = o.app_session_id;
```

---

## Part 3: Channel & Device Performance Analysis

### Step 3.1: Create Channel Performance View

```sql
create view vw_channel_performance AS

SELECT s.utm_source,s.device_type,

count(o.order_id) AS total_orders,

COUNT(DISTINCT s.app_session_id) AS unique_sessions,

COUNT(DISTINCT s.user_id) AS unique_users,

SUM(o.total_price) AS GMV,

ROUND(count(o.order_id) * 100 / count(DISTINCT s.app_session_id),2) AS conversion_rate,

AVG(o.total_price) AS AOV

from app_sessions s

left join orders o

on s.app_session_id = o.app_session_id

group by s.utm_source, s.device_type

order by GMV DESC;
```

---

### Step 3.2: Query Channel Performance

```sql
SELECT s.utm_source,

count(o.order_id) AS total_orders,

COUNT(DISTINCT s.app_session_id) AS unique_sessions,

COUNT(DISTINCT s.user_id) AS unique_users,

SUM(o.total_price) AS GMV,

ROUND(count(o.order_id) * 100 / count(DISTINCT s.app_session_id),2) AS conversion_rate,

AVG(o.total_price) AS AOV

from app_sessions s

left join orders o

on s.app_session_id = o.app_session_id

group by s.utm_source

order by GMV DESC;
```

---

### Step 3.3: Query Device Performance

```sql
CREATE TEMPORARY TABLE net_order_sessions AS

SELECT
    o.order_id,
    o.app_session_id,
    o.restaurant_id,
    o.order_time,
    COALESCE(o.delivery_time, c.cancelled_at) AS final_time,
    o.delivery_fee_paid,
    o.total_price,
    c.total_refunds,
    CASE
        WHEN c.order_id IS NOT NULL THEN 'Cancelled'
        ELSE 'Completed'
    END AS order_status,
    CASE
        WHEN c.order_id IS NOT NULL THEN -c.total_refunds
        ELSE o.total_price - o.delivery_fee_paid
    END AS net_revenue
FROM orders o
LEFT JOIN cancelled_orders c
    ON o.order_id = c.order_id;

SELECT s.device_type,

count(n.order_id) AS total_orders,

COUNT(DISTINCT s.app_session_id) AS unique_sessions,

COUNT(DISTINCT s.user_id) AS unique_users,

SUM(n.total_price) AS GMV,

ROUND(count(n.order_id) * 100 / count(DISTINCT s.app_session_id),2) AS Conversion_Rate,

ROUND(COALESCE(sum(n.net_revenue) / count(DISTINCT s.app_session_id)),2) AS Average_Revenue_Per_Session

from app_sessions s

left join net_order_sessions n

on s.app_session_id = n.app_session_id

group by s.device_type

order by GMV DESC;
```

---

## Part 4: City-Wise Revenue Analysis

### Step 4.1: City Performance Aggregation

```sql
CREATE TEMPORARY TABLE city_performance AS

SELECT r.city,

COUNT(o.order_id) AS total_orders,

COUNT(oc.order_id) AS cancelled_orders,

ROUND((COUNT(oc.order_id)*100) / COUNT(o.order_id), 2) AS cancellation_rate,

ROUND(SUM(o.total_price), 2) AS GMV,

ROUND(SUM(o.total_price) / COUNT(o.order_id),2) AS AOV,

SUM(o.delivery_fee_paid) AS total_delivery_fee,

ROUND(SUM((0.30*o.total_price) + o.delivery_fee_paid), 2) AS zomato_gross_revenue,

ROUND(SUM(COALESCE(oc.amount_of_refund, 0)),2) AS refund_loss,

SUM(CASE

WHEN oc.order_id IS NULL THEN (0.30*o.total_price + o.delivery_fee_paid)

ELSE (0.30*o.total_price + o.delivery_fee_paid - oc.amount_of_refund)

END) AS zomato_net_revenue,

ROUND(SUM((0.30*o.total_price) + o.delivery_fee_paid) / COUNT(DISTINCT s.app_session_id), 2) AS ARPS,

AVG(TIMESTAMPDIFF(MINUTE, o.order_time, o.delivery_time)) AS avg_delivery_time,

AVG(o.delivery_fee_paid) AS avg_delivery_fee

FROM orders o

LEFT JOIN order_items_cancelled oc

ON o.order_id = oc.order_id

LEFT JOIN restaurants r

ON o.restaurant_id = r.restaurant_id

LEFT JOIN app_sessions s

ON o.app_session_id = s.app_session_id

GROUP BY r.city

ORDER BY zomato_net_revenue DESC;

SELECT *,

ROUND((zomato_net_revenue * 100 / GMV),2) AS margin_pct

FROM city_performance;
```

---

### Step 4.2: Top Foods by City

```sql
WITH food_city_zomato AS(

SELECT

r.city,

TRIM(LOWER(m.fooditem_name)) AS foodname, sum(oi.quantity) AS total_orders,

DENSE_RANK() OVER(PARTITION BY r.city ORDER BY SUM(oi.quantity) DESC) AS most_ordered_food

FROM order_items oi

JOIN menu m

ON oi.food_item_id = m.food_item_id

JOIN restaurants r

ON r.restaurant_id = m.restaurant_id

GROUP BY r.city, TRIM(LOWER(m.fooditem_name))

)

SELECT city, foodname, total_orders

FROM food_city_zomato

WHERE most_ordered_food <= 4

ORDER BY city, total_orders DESC;
```

---

## Part 5: RFM Customer Segmentation

### Step 5.1: Calculate RFM Metrics

```sql
CREATE view customer_rfm_analysis AS

SELECT

u.user_id,

u.city,

u.age,

u.gender,

u.gold_member,

datediff(CURDATE(), MAX(STR_TO_DATE(o.order_time, '%Y-%m-%d %H:%i:%s'))) as recency,

COUNT(o.order_id) as frequency,

SUM(o.total_price) AS monetary,

AVG(o.total_price) as avg_order_value

FROM users u

JOIN app_sessions a

ON u.user_id = a.user_id

JOIN orders o

ON o.app_session_id = a.app_session_id

GROUP BY u.user_id, u.city, u.age,u.gender,u.gold_member;
```

---

### Step 5.2: Create RFM Scoring

```sql
CREATE VIEW rfm_analysis_score AS

SELECT *,

CASE

WHEN recency BETWEEN 155 AND 228 THEN 5

WHEN recency BETWEEN 229 AND 302 THEN 4

WHEN recency BETWEEN 303 AND 376 THEN 3

WHEN recency BETWEEN 377 AND 450 THEN 2

ELSE 1

END AS recency_score,

CASE

WHEN frequency <= 10 THEN 5

WHEN frequency <= 7 THEN 4

WHEN frequency <= 5 THEN 3

WHEN frequency <= 3 THEN 2

ELSE 1

END AS frequency_score,

CASE

WHEN monetary BETWEEN 104 AND 1590 THEN 1

WHEN monetary BETWEEN 1591 AND 3076 THEN 2

WHEN monetary BETWEEN 3077 AND 4562 THEN 3

WHEN monetary BETWEEN 4563 AND 6048 THEN 4

ELSE 5

END AS monetary_score

FROM customer_rfm_analysis;
```

---

### Step 5.3: Create RFM Segments

```sql
CREATE VIEW rfm_segments AS

SELECT

user_id,

city,

gold_member,

recency,

frequency,

monetary,

recency_score,

frequency_score,

monetary_score,

CASE

WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'

WHEN recency_score >= 3 AND frequency_score >= 3 THEN 'Loyal Customers'

WHEN recency_score >= 4 AND frequency_score < 3 THEN 'Potential Loyalists'

WHEN frequency_score > 2 AND recency_score < 3 THEN 'At-Risk'

ELSE 'Lost'

END AS rfm_segment

FROM rfm_analysis_score;
```

---

### Step 5.4: Aggregate RFM Segments

```sql
SELECT

rfm_segment,

COUNT(DISTINCT user_id) AS num_customers,

ROUND(COUNT(DISTINCT user_id) * 100 / SUM(COUNT(DISTINCT user_id)) OVER (), 2) AS pct_of_customer_base,

ROUND(AVG(recency), 1) AS avg_recency_days,

ROUND(AVG(frequency), 1) AS avg_frequency_orders,

ROUND(AVG(monetary), 2) AS avg_lifetime_value,

ROUND(SUM(monetary), 2) AS segment_total_revenue,

ROUND(SUM(monetary) * 100 / SUM(SUM(monetary)) OVER (), 2) AS pct_of_total_revenue,

ROUND(

    SUM(CASE WHEN gold_member = 1 THEN 1 ELSE 0 END) * 100 / NULLIF(COUNT(DISTINCT user_id), 0),

    2

) AS gold_member_adoption_pct

FROM rfm_segments

GROUP BY rfm_segment

ORDER BY segment_total_revenue DESC;
```

---

### Step 5.5: RFM by City

```sql
SELECT

rfm_segment,

city,

COUNT(DISTINCT user_id) AS no_of_customers,

ROUND(AVG(monetary), 2) AS avg_AOV,

ROUND(AVG(monetary), 2) AS avg_total_spend,

ROUND(SUM(monetary), 2) AS total_revenue_by_segment_city,

ROUND(SUM(monetary) * 100 / SUM(SUM(monetary)) OVER (PARTITION BY rfm_segment), 2) AS pct_revenue_within_segment,

ROUND(SUM(monetary) * 100 / SUM(SUM(monetary)) OVER (), 2) AS pct_revenue_of_company

FROM rfm_segments

GROUP BY rfm_segment, city

ORDER BY rfm_segment, total_revenue_by_segment_city DESC;
```

---

### Step 5.6: RFM by Gold Membership

```sql
SELECT

rfm_segment,

gold_member,

CASE WHEN gold_member = 1 THEN 'Gold' ELSE 'Non-Gold' END AS membership,

COUNT(DISTINCT user_id) AS num_customers,

ROUND(AVG(monetary), 2) AS avg_lifetime_value,

ROUND(SUM(monetary), 2) AS total_segment_revenue

FROM rfm_segments

GROUP BY rfm_segment, gold_member

ORDER BY rfm_segment, gold_member DESC;
```

--
