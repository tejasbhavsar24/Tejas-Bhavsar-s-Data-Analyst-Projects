WITH 
monthly AS
(
SELECT 
	order_year,
    order_month,
    COUNT(order_id) AS order_count,
    SUM(total_price) AS revenue,
    ROUND(AVG(0.30 * (total_price - delivery_fee_paid)), 2) AS inferred_platform_revenue_per_order
    FROM orders
    GROUP BY order_year,order_month
),

monthly_prev AS
( 
	SELECT
	order_year,
    order_month,
    order_count,
    revenue,
    inferred_platform_revenue_per_order,
    LAG(order_count) OVER(order by order_year, order_month) AS prev_order_count,
    LAG(revenue) OVER(order by order_year, order_month) AS prev_revenue,
    LAG(inferred_platform_revenue_per_order) OVER (order by order_year, order_month) AS prev_zomato_platform_rev
    FROM monthly
)

SELECT
order_year,
order_month,
order_count,
revenue,
inferred_platform_revenue_per_order,
ROUND((order_count - prev_order_count) *100 
/ NULLIF(prev_order_count,0),2) AS mom_orders_pct,
ROUND((revenue - prev_revenue) * 100
/ NULLIF(prev_revenue,0), 2) AS mom_revenue_pct,
ROUND((inferred_platform_revenue_per_order - prev_zomato_platform_rev) * 100
/ NULLIF(prev_zomato_platform_rev,0), 2) AS mom_zomato_revenue_pct,

# --- 3 month rolling totals for orders
SUM(order_count) OVER(order by order_year, order_month
ROWS between 2 PRECEDING AND CURRENT ROW) AS 3m_order_rollingtotal,
SUM(revenue) OVER(order by order_year, order_month 
ROWS between 2 PRECEDING AND CURRENT ROW) AS 3m_revenue_rollingtotal,
SUM(inferred_platform_revenue_per_order) OVER(order by order_year, order_month 
ROWS between 2 PRECEDING AND CURRENT ROW) AS 3m_platform_revenue_rollingtotal
FROM monthly_prev 
ORDER BY order_year, order_month;


