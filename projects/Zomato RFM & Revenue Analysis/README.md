# Zomato SQL Analytics – User Behaviour, Revenue, Funnel & RFM | July 2024 - June 2025 Dataset
## 📌 Table of Contents

- [Project Overview](#1-project-overview)
- [Business Objectives & Research Questions](#2-business-objectives--research-questions)
- [SQL Functions and Key Assumptions](#3-sql-functions-and-key-assumptions)
- [Data Model & Schema](#4-data-model--schema)
- [How to Run the SQL](#5-how-to-run-the-sql)
- [Using Views and Processed Tables](#6-using-views-and-processed-tables)
- [Key Insights (Business Summary)](#7-key-insights-business-summary)
  - [UX Funnel & Channel Performance](#71-ux-funnel--channel-performance)
  - [City, Cuisine & Demand Patterns](#72-city-cuisine--demand-patterns)
  - [RFM & Gold Membership](#73-rfm--gold-membership)
  - [Cancellations, Refunds & Food Rescue](#74-cancellations-refunds--food-rescue)
- [Recommendations for Zomato](#8-recommendations-for-zomato)
- [My Role and Learnings](#9-my-role-and-learnings)


## 1. Project Overview

This project analyses a synthetic Zomato food delivery dataset using SQL and Excel. The analysis covers aspects like RFM Analysis and RFM Modelling, Customer Journey & UX, Food and Order Demand Analytics to improve understanding and growth opportunities for Zomato.

The focus of the project is:

- How users move from sessions to orders across the app funnel
- How revenue, cancellations, and refunds behave across cities and channels
- How customer value differs by RFM segment and Gold membership
- How product and marketing teams can use these insights for decisions

The work is structured as a production‑style analytics project: data cleaning, feature creation, analysis views, and business interpretation.

---

## 2. Business Objectives & Research Questions

**Business objectives**

1. Understand demand patterns, revenue drivers, and cancellation behaviour.
2. Quantify UX funnel performance from app sessions to completed orders.
3. Profile customer value using RFM at city level and by Gold membership.
4. Translate findings into actionable ideas for marketing, product, and operations.

**Key questions**

- Which cities, channels, and devices drive most orders and revenue?
- Where do users drop off in the app funnel (home → search → restaurant → menu → cart → order)?
- How do cancellations, refunds, and delivery times affect net revenue?
- Which customer segments (RFM, Gold vs non‑Gold) contribute most value?
- What practical actions should Zomato take for growth and retention?

---

## 3. SQL Functions and Key Assumptions

In this project, various SQL functions are utilized for finding answers to business queries. The following functions were used for the project:

### **SQL Functions Used**

- **Aggregate functions**
  - `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`
  - Used to compute:
    - Orders and customer counts
    - Revenue, refunds, and AOV
    - Delivery time and other performance metrics

- **Conditional logic**
  - `CASE WHEN`
  - Used to:
    - Classify order status (completed vs cancelled)
    - Identify funnel stages from pageview URLs
    - Segment customers into RFM categories

- **Window functions**
  - `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE`
  - Used for:
    - RFM scoring and segmentation
    - Ranking cities, cuisines, and customers
    - Creating percentiles and cohorts without data loss

- **Date & time functions**
  - `DATE`, `EXTRACT`, `DATEDIFF`, `TIMESTAMPDIFF`, `LAG`
  - Used to:
    - Calculate recency and frequency windows
    - Derive order hour, day, and month trends
    - Measure delivery time and session-to-order latency

- **Joins**
  - `INNER JOIN`, `LEFT JOIN`
  - Used to:
    - Combine user, session, order, item, restaurant, and cancellation data
    - Preserve analytical integrity when handling incomplete or cancelled records

- **Null handling & data safety**
  - `COALESCE`, `NULLIF`
  - Used to:
    - Avoid divide-by-zero errors
    - Handle missing cancellations or refunds cleanly
    - Ensure consistent metric calculation

- **Views and temporary tables**
  - `CREATE VIEW`, `WITH` (CTEs), temporary tables
  - Used to:
    - Modularise complex logic
    - Improve query readability and maintainability
    - Re-use logic across funnel, revenue, and RFM analyses


**Key Assumptions:**

When calculating Revenue of Zomato, the following assumptions are taken for ensuring results and values are comparable:
•  **Completed** : Zomato earns 30% commission + delivery_fee_paid.
•  **Food Rescue**: Only delivery_fee_paid is retained (net-zero profit assumption as per Zomato’s Food Rescue model).
•  **Cancelled and Not Rescued**: No revenue.

**Calculation of Revenue Loss** :
•	Cancelled non-rescued orders are treated as full loss of total_price + delivery_fee_paid.
•	Completed and Food Rescue orders are assigned zero loss.

## 4. Data Model & Schema

The project uses multiple relational tables. Core entities:

- **Users & sessions**
  - `users`: user attributes and Gold membership flag
  - `app_sessions`: session‑level identifiers, UTM source, device type
  - `app_pageviews`: page‑level events with URLs representing funnel stages

- **Orders & items**
  - `orders`: order‑level timestamps, total price, delivery fee, payment mode
  - `order_items`: line‑items by order and menu item
  - `order_items_cancelled`: cancelled line‑items with refund amounts and timestamps

- **Catalogue & network**
  - `restaurants`: city, cuisine, ratings, and review counts
  - `menu`: menu items by restaurant and cuisine
  - `delivery_agents`: delivery partner details


<img width="1403" height="604" alt="image" src="https://github.com/user-attachments/assets/6ecf73d6-1af8-494d-ade4-84815cdd3e47" />

---

## 5. How to Run the SQL

1. **Set up a database**
   - Create a new schema (e.g. `zomato_sql`).
   - Import CSVs from `data_raw/` into tables with matching names.

2. **Run scripts in order**
   - `SQL Files/Zomato-Data-Cleaning.sql`  
   (1) Clean raw tables, fix data types, and create any base views.
    - `SQL Files/City-Wise-Analysis.sql`  
   (2) Build city‑level metrics for orders, GMV, refunds, and delivery time.
    - `SQL Files/Zomato-User-Behaviour.sql`  
   (3) Analyse ordering patterns, time‑of‑day demand, and key food items.
   - `SQL Files/Zomato-Funnel-Analysis.sql` and `Zomato_UX-Funnel-Analysis.sql`  
   (4) Create funnel and channel performance views.
   - `SQL Files/Zomato-RFM-Analysis.sql`  
   (5) Compute RFM segments by user, city, and Gold status.

3. **Outputs**
   - Aggregated outputs are exported into `data_processed/` as CSVs.
   - Narrative explanations for key queries are in `/docs`.

---

## 6. Using Views and Processed Tables

Some important derived objects:

- **Net GMV / revenue tables**
  - Temporary tables that combine `orders` and `order_items_cancelled`.
  - Compute `net_revenue` per order as:
    - Completed: `total_price - delivery_fee`
    - Cancelled: `- total_refunds`

- **Funnel stage table (`pageviews_per_session`)**
  - Aggregates pageviews per `app_session_id` with flags for:
    - home, search, restaurants, menu, cart
  - Used to count how many sessions reached each stage.

- **Order‑per‑session tables**
  - Join sessions with orders to compute:
    - Completed and cancelled orders by session
    - Conversion and cart abandonment per stage

- **Channel and device views**
  - `vw_channel_performance`: metrics by `utm_source` and device
  - Metrics: orders, GMV, unique sessions/users, conversion rate, AOV

- **RFM segment tables**
  - RFM scoring at user level
  - Aggregations by city and Gold membership: number of customers, AOV, total revenue, share of company revenue.

---

## 7. Key Insights (Business Summary)

### 7.1 UX Funnel & Channel Performance

- Funnel exits are modest up to menu selection; drop‑off becomes visible at cart and checkout.
- Checkout friction seems more related to price and discount search than navigation.
- Direct app, notifications, and Google are strong revenue sources with high conversion.
- Social channels drive traffic and orders with slightly lower AOV, suitable for acquisition and campaign bursts.
- Mobile dominates usage and revenue, confirming a mobile‑first product and marketing strategy. Desktop and tablet show weaker performance and can be deprioritized.

### 7.2 City, Cuisine & Demand Patterns

- Bangalore and Hyderabad deliver high GMV, supported by strong order volumes and healthy AOV.
- Delhi and Chennai show higher AOV but more mature demand, suggesting focus on value extraction rather than pure growth.
- Biryani and Mughlai cuisine consistently appear in top combinations across metros, confirming them as “hero categories”.
- Demand peaks between 7 PM and 10 PM, with 8–9 PM as the strongest slots. Weekend evenings show clear uplift versus weekdays.
- Morning hours remain underused, representing a potential growth window for breakfast‑oriented campaigns and tailored landing experiences.

### 7.3 RFM & Gold Membership

- Loyal Customers make up the largest share of users and account for the majority of revenue. They are the core cash‑flow segment.
- Champions are fewer in number but have much higher total spend per user. They need premium, experience‑led retention rather than discount‑heavy tactics.
- Potential Loyalists form a sizable upgrade pipeline with lower current contribution. They respond better to habit‑building nudges, streaks, and gamified milestones.
- Gold members show higher AOV in key segments, but adoption is limited. Most revenue still comes from non‑Gold loyal and champion users, leaving room for targeted membership conversion.

### 7.4 Cancellations, Refunds & Food Rescue

- Cancellation and refund data reveals a meaningful reduction in cancellation rate after introduction of a Food Rescue‑type feature.
- Food Rescue converts what would be full‑refund cancellations into discounted orders with net‑zero or low margin, but reduces refund loss and improves perceived reliability.
- This feature supports operational efficiency and aligns with sustainability and brand positioning around reduced food waste.

---

## 8. Recommendations for Zomato

**Marketing & Growth**

- Prioritise mobile‑led campaigns and app‑first experiences; reduce investment in lower‑performing desktop/tablet inventory.
- Use social channels to drive acquisition, but push users towards higher‑value direct and app journeys over time.
- Build segment‑specific strategies:
  - Champions: premium benefits, exclusive experiences, and personalised milestones.
  - Loyal Customers: AOV‑linked incentives, wallet‑based cashback, and repeat‑order nudges.
  - Potential Loyalists: gamified missions, streaks, and targeted offers to increase frequency.

**Product & UX**

- Keep the existing funnel structure but improve price and discount clarity at cart and checkout.
- Surface “best offer” and savings explanations to reduce last‑minute drop‑offs.
- Test breakfast‑focused homepage layouts and recommendations in underperforming morning slots.

**Membership & Monetisation**

- Run experiments comparing Gold vs non‑Gold cohorts on AOV, frequency, and churn.
- Expand Gold proposition beyond free delivery (tiered rewards, partner perks, exclusive events).
- Target high‑spend non‑Gold users with personalised savings messages and limited‑time free Gold trials.

**Operations**

- Continue investing in Food Rescue‑style features that convert cancellations into partial revenue and protect unit economics.
- Use city‑level insights to tailor fee structures, SLAs, and restaurant onboarding priorities by market maturity.

---

## 9. My Role and Learnings

From this project, I practised:

- Writing production‑style SQL:
  - Temporary tables, views, window functions, and careful use of `COALESCE` and `NULLIF`.
- Designing end‑to‑end analysis:
  - From schema understanding and cleaning to funnel, RFM Model, and cohorts.
- Translating raw metrics into marketing, product, and operations insights:
  - Segment strategies, channel focus, membership design, and feature impact.

This repository is meant to demonstrate how I approach analytics problems in a way that is clear for stakeholders and easy to follow for other analysts.

---



