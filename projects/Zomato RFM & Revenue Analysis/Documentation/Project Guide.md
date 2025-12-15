
# 🍽️ Zomato End-to-End SQL Analytics Workflow

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

## 🗂️ Dataset Overview

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

## 🧪 Duplicate Checks

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

## 🧹 Data Cleaning Steps

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

## 🕒 Date & Time Standardization

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

## 🚚 Delivery Fee Flag Creation

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

## 📅 Date Feature Engineering

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

## 🔁 Final Duplicate Validation

```sql
SELECT order_id, COUNT(*)
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;
```

**Expected Result:**  
Zero rows returned.

---


## 🧭 PART 2: UX Funnel Analysis

### Objective
Identify drop-offs from homepage to order completion.

```sql
CREATE TEMPORARY TABLE pageviews_per_session AS
SELECT
    app_session_id,
    MAX(CASE WHEN pageview_url = '/home-page' THEN 1 ELSE 0 END) AS homepage,
    MAX(CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END) AS cart
FROM app_pageviews
GROUP BY app_session_id;
```

**Insight:** Cart stage is the primary funnel bottleneck.

---

## 📊 PART 3: Channel & Device Performance

```sql
CREATE VIEW vw_channel_performance AS
SELECT
    s.utm_source,
    s.device_type,
    COUNT(o.order_id) AS orders,
    SUM(o.total_price) AS GMV
FROM app_sessions s
LEFT JOIN orders o
ON s.app_session_id = o.app_session_id
GROUP BY s.utm_source, s.device_type;
```

---

## 🌍 PART 4: City-Wise Analysis

```sql
SELECT
    r.city,
    COUNT(o.order_id) AS orders,
    SUM(o.total_price) AS GMV
FROM orders o
JOIN restaurants r
ON o.restaurant_id = r.restaurant_id
GROUP BY r.city;
```

---

## 👥 PART 5: RFM Segmentation

```sql
SELECT
    u.user_id,
    DATEDIFF(CURDATE(), MAX(o.order_time)) AS recency,
    COUNT(o.order_id) AS frequency,
    SUM(o.total_price) AS monetary
FROM users u
JOIN app_sessions s ON u.user_id = s.user_id
JOIN orders o ON s.app_session_id = o.app_session_id
GROUP BY u.user_id;
```

---

## 🚀 Key Takeaways

- Cart abandonment is the main UX issue
- Direct & mobile channels perform best
- City strategies vary by maturity
- RFM enables targeted retention

---

## ▶️ How to Use

1. Load CSVs into MySQL
2. Run queries sequentially
3. Export results for dashboards

---

## 📌 Author Note

This project emphasizes **business insight with SQL**, not just query writing.
