CREATE OR REPLACE VIEW sales_revenue_by_category_qtr AS
WITH latest_year_cte AS (
    SELECT MAX(EXTRACT(YEAR FROM payment_date)) AS latest_year
    FROM payment
),
current_quarter_dates AS (
    SELECT
        latest_year,
        CASE
            WHEN EXTRACT(QUARTER FROM CURRENT_DATE) = 1 THEN DATE_TRUNC('year', MAKE_DATE(latest_year::int, 1, 1))
            WHEN EXTRACT(QUARTER FROM CURRENT_DATE) = 2 THEN DATE_TRUNC('quarter', MAKE_DATE(latest_year::int, 4, 1))
            WHEN EXTRACT(QUARTER FROM CURRENT_DATE) = 3 THEN DATE_TRUNC('quarter', MAKE_DATE(latest_year::int, 7, 1))
            ELSE DATE_TRUNC('quarter', MAKE_DATE(latest_year::int, 10, 1))
        END AS start_date,
        CASE
            WHEN EXTRACT(QUARTER FROM CURRENT_DATE) = 1 THEN DATE_TRUNC('quarter', MAKE_DATE(latest_year::int, 4, 1))
            WHEN EXTRACT(QUARTER FROM CURRENT_DATE) = 2 THEN DATE_TRUNC('quarter', MAKE_DATE(latest_year::int, 7, 1))
            WHEN EXTRACT(QUARTER FROM CURRENT_DATE) = 3 THEN DATE_TRUNC('quarter', MAKE_DATE(latest_year::int, 10, 1))
            ELSE DATE_TRUNC('year', MAKE_DATE(latest_year::int + 1, 1, 1))
        END AS end_date
    FROM latest_year_cte
),
category_sales AS (
    SELECT
        c.name AS category,
        SUM(p.amount) AS total_sales_revenue
    FROM
        payment p
    JOIN rental r ON p.rental_id = r.rental_id
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    CROSS JOIN current_quarter_dates cq
    WHERE
        p.payment_date >= cq.start_date AND p.payment_date < cq.end_date
    GROUP BY
        c.name
    HAVING
        SUM(p.amount) > 0
)
SELECT
    category,
    total_sales_revenue
FROM
    category_sales;



CREATE OR REPLACE FUNCTION get_sales_revenue_by_category_qtr(current_date_in date)
RETURNS TABLE (
    category TEXT,
    total_sales_revenue NUMERIC
) AS $$
DECLARE
    start_date DATE;
    end_date DATE;
BEGIN
    start_date := date_trunc('quarter', current_date_in);
    end_date := start_date + interval '3 month';

    RETURN QUERY
    SELECT
        c.name AS category,
        SUM(p.amount) AS total_sales_revenue
    FROM
        payment p
    JOIN rental r ON p.rental_id = r.rental_id
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    WHERE
        r.rental_date >= start_date AND r.rental_date < end_date
    GROUP BY
        c.name
    HAVING
        SUM(p.amount) > 0;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION new_movie(movie_title TEXT)
RETURNS VOID AS $$
DECLARE
    lang_id INT;
    new_film_id INT;
BEGIN
    SELECT language_id INTO lang_id
    FROM language
    WHERE name = 'Klingon';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Language "Klingon" does not exist.';
    END IF;

    SELECT max(film_id) + 1 INTO new_film_id FROM film;

    INSERT INTO film (film_id, title, rental_rate, rental_duration, replacement_cost, release_year, language_id)
    VALUES (new_film_id, movie_title, 4.99, 3, 19.99, EXTRACT(YEAR FROM CURRENT_DATE), lang_id);
END;
$$ LANGUAGE plpgsql;
