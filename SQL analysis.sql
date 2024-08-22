create database sublime;

use sublime;

#PIERWSZY TASK

SELECT
    pv.product_id AS 'Product ID',
    product_name AS 'Name of the product',
    COUNT(cdm.coupon_id) AS 'Count of how many times a product was discounted',
    AVG(value) AS 'Average coupon value per product',
    RANK() OVER (ORDER BY COUNT(cdm.coupon_id) DESC) AS 'Rank based on how many time a product was discounted'
FROM
    coupon_order_mapping cdm
        JOIN
    order_items oi ON cdm.order_id = oi.order_id
        JOIN
    product_variants pv ON pv.product_variant_id = oi.product_variant_id
        JOIN
    coupons c ON c.coupon_id = cdm.coupon_id
		JOIN
	products pi ON pv.product_id = pi.product_id
GROUP BY pv.product_id
ORDER BY COUNT(coupon_id) DESC;

#DRUGI TASK, początkowo wyczyszczenie danych ze znaków specjalnych takich jak - i #, pózniej na ich podstawie policzenie 90-cio dniowego LTV.

WITH Cleaned_IDs AS (
    SELECT
        DISTINCT(REPLACE(order_id, '-', '')) AS cleaned_order_id,
        (REPLACE(ga_transaction_id, '#', '')) AS cleaned_ga_transaction_id,
        customer_id,
        wt.session_id,
        ws.utm_campaign,
        total_order_gross_value,
        order_timestamp
    FROM
        orders o
    JOIN
        web_transactions wt ON REPLACE(wt.ga_transaction_id, '#', '') = REPLACE(o.order_id, '-', '')
	JOIN
		web_sessions ws ON REPLACE(ws.session_id, '.', '') =  REPLACE(wt.session_id, '.', '')
),

LTV AS (
    SELECT
        customer_id,
        (
            SELECT MIN(order_timestamp)
            FROM Cleaned_IDs sub
            WHERE sub.customer_id = Cleaned_IDs.customer_id
        ) AS first_paid_order_timestamp
    FROM
        Cleaned_IDs
)

SELECT
    c.customer_id AS "Customer ID",
    utm_campaign AS "Campaign",
    ROUND(AVG(c.total_order_gross_value), 2) AS "Average 90 day consumer LTV"
FROM
    Cleaned_IDs c
JOIN
    LTV ON c.customer_id = LTV.customer_id
WHERE
    c.order_timestamp BETWEEN LTV.first_paid_order_timestamp AND DATE_ADD(LTV.first_paid_order_timestamp, INTERVAL 90 DAY)
    
GROUP BY
	utm_campaign;
    

#TRZECI TASK

# Zapytanie do sprawdzenia, którzy klienci najczęściej kupują ponownie wraz z uwzględnieniem dat (lojalność).
    SELECT
        customer_id,
        order_id,
        order_timestamp,
        is_order_from_subscription,
        total_order_gross_value,
        RANK() OVER (PARTITION BY customer_id ORDER BY DATE(order_timestamp) ASC) AS rnk
    FROM
        orders
	WHERE total_order_gross_value != 0
	ORDER BY rnk desc;

# Zapytanie do sprawdzenia rozkładu zakupów z subskrypcją i bez na podstawie przyjętego thresholdu (rnk > 10).

SELECT
    count(customer_id) AS customer_count,
    is_order_from_subscription
FROM
    (SELECT
        customer_id,
        is_order_from_subscription,
        order_id,
        total_order_gross_value,
        RANK() OVER (PARTITION BY customer_id ORDER BY DATE(order_timestamp) ASC) as rnk
    FROM
        orders) AS x
WHERE
    rnk >= 10 
    AND
    total_order_gross_value != 0
GROUP BY
    is_order_from_subscription;
    
# Zapytanie do sprawdzenia, która kampania przekonwertowała najwięcej klientów na wykupienie subskrypcji. Ważnym szczegółem przy tym zapytaniu jest to, że zakupy za pomocą subskrypcji nie mają swojego session_id.

SELECT 
	utm_campaign AS 'Presumably, source of migration from online shopping to a subscription',
    count(*) AS 'Customers that ordered at least once from web, and subscription'
    FROM(
	SELECT
		A.customer_id,
		A.ga_transaction_id AS ga_transaction_id_1,
		A.is_order_from_subscription AS is_order_from_subscription_1,
		B.is_order_from_subscription AS is_order_from_subscription_2,
		A.utm_campaign
	FROM
		(
			SELECT
				customer_id,
				ga_transaction_id,
				is_order_from_subscription,
				utm_campaign
			FROM
				orders o
			LEFT JOIN
				web_transactions wt ON REPLACE(wt.ga_transaction_id, '#', '') = REPLACE(o.order_id, '-', '')
			LEFT JOIN
				web_sessions ws ON REPLACE(ws.session_id, '.', '') =  REPLACE(wt.session_id, '.', '')
			WHERE 
				total_order_gross_value != 0
		) AS A
	JOIN
		(
			SELECT
				customer_id,
				ga_transaction_id,
				is_order_from_subscription
			FROM
				orders o
			LEFT JOIN
				web_transactions wt ON REPLACE(wt.ga_transaction_id, '#', '') = REPLACE(o.order_id, '-', '')
			LEFT JOIN
				web_sessions ws ON REPLACE(ws.session_id, '.', '') =  REPLACE(wt.session_id, '.', '')
			WHERE 
				total_order_gross_value != 0
		) AS B
	ON A.customer_id = B.customer_id) sub
where is_order_from_subscription_1 = 'false'
AND is_order_from_subscription_2 = 'true'
AND utm_campaign IS NOT NULL
GROUP BY utm_campaign 
ORDER BY count(*) DESC;





    
