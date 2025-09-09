-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- объявления по населенному пункту/периоду публикации/стоимости за квадратный метр
advertise_categories AS (SELECT f.id,
	   CASE 
	       WHEN c.city = 'Санкт-Петербург'
	       	   THEN 'Санкт-Петербург'
	       ELSE 'ЛенОбл'
	   END AS area,
	   CASE
	   	   WHEN a.days_exposition <= 30
	   	   	   THEN 'до месяца'
	   	   WHEN a.days_exposition <= 90
	   	   	   THEN 'до квартала'
	   	   WHEN a.days_exposition <= 180
	   	   	   THEN 'до полугода'
	   	   WHEN a.days_exposition > 180
	   	   	   THEN 'год и более'
	   	   ELSE 'активные объявления'   
	   END AS publication_period,
	   round(a.last_price::numeric/f.total_area::numeric, 2) AS meter_cost
FROM real_estate.flats f 
LEFT JOIN real_estate.city c USING(city_id)
LEFT JOIN real_estate.advertisement a USING(id)
LEFT JOIN real_estate."type" t USING(type_id)
WHERE f.id IN (SELECT * FROM filtered_id) AND
	  t.TYPE = 'город'),
adv_count AS (
	SELECT COUNT(id)
	FROM real_estate.advertisement)
SELECT area,
	   publication_period,
	   COUNT(ac.id) AS adv_count,
	   ROUND(COUNT(ac.id)::decimal * 100 / (SELECT COUNT(*) FROM advertise_categories), 2) AS adv_percent,
	   ROUND(AVG(meter_cost), 2) AS avg_meter_cost,
	   ROUND(AVG(f.total_area::decimal),2) AS avg_area,
	   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS rooms_mediana,
	   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS balcony_mediana,
	   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS floor_mediana
FROM advertise_categories AS ac
LEFT JOIN real_estate.flats f USING(id)
GROUP BY area, publication_period


WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
--количество объявлений по месяцу публикации
    adv_publication AS (
    	SELECT EXTRACT(MONTH FROM a.first_day_exposition) AS publication_month,
    		   COUNT(id) AS publication_count,
--средняя стоимость квадратного метра по месяцу публикации
    		   AVG(a.last_price::numeric/f.total_area) AS avg_meter_cost,
--соедняя площадь
    		   AVG(f.total_area) AS avg_area
    	FROM real_estate.advertisement AS a
    	LEFT JOIN  real_estate.flats f USING(id)
    	WHERE id IN (SELECT * FROM filtered_id)
    	GROUP BY publication_month),
-- количество объявлений по месяцу снятия
    adv_remove AS(
    	SELECT EXTRACT(MONTH FROM a.first_day_exposition + (a.days_exposition || 'days')::INTERVAL) AS removing_month,
    		   COUNT(id) AS remove_count,
--средняя стоимость квадратного метра по месяцу снятия объявления
    		   AVG(a.last_price::numeric/f.total_area) AS avg_meter_cost,
--средняя площадь
    		   AVG(f.total_area) AS avg_area
    	FROM real_estate.advertisement AS a
    	LEFT JOIN  real_estate.flats f USING(id)
    	WHERE id IN (SELECT * FROM filtered_id)
    	GROUP BY removing_month)
SELECT ap.publication_month AS month,
	   ap.publication_count,
	   ar.remove_count,
--ранги по публикации и снятию
	   DENSE_RANK() OVER(ORDER BY publication_count DESC) AS public_rank,
	   DENSE_RANK() OVER(ORDER BY remove_count DESC) AS remove_rank,
	   ROUND(ap.avg_meter_cost::decimal, 2) AS publ_avg_meter_cost,
	   ROUND(ar.avg_meter_cost::decimal, 2) AS remove_avg_meter_cost,
	   ROUND(ap.avg_area::decimal, 2) AS publ_avg_area,
	   ROUND(ar.avg_area::decimal, 2) AS remove_avg_area
FROM adv_publication AS ap
LEFT JOIN adv_remove AS ar ON ap.publication_month = ar.removing_month
ORDER BY ap.publication_month 

--Рейтинг населенных пунктов ТОП-15
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
cities_detalisation AS (
    SELECT city_id,
           COUNT(id) AS adv_count,
           ROUND(AVG(total_area)::numeric,2) AS avg_area,
           ROUND(AVG(rooms)::NUMERIC,2) AS avg_rooms,
           ROUND(AVG(a.last_price::numeric/f.total_area)::numeric,2) AS avg_meter_cost,
           ROUND((COUNT(a.days_exposition)::numeric / COUNT(a.id) * 100),2) AS removed_percent
    FROM real_estate.flats AS f
    LEFT JOIN real_estate.advertisement a USING(id)
    WHERE id IN (SELECT * FROM filtered_id)
    GROUP BY city_id),
-- среднее кол-во дней экспозиции по городам
exposition AS (
	SELECT f.city_id,
		   AVG(a.days_exposition) AS avg_exposition
	FROM real_estate.flats AS f
	LEFT JOIN real_estate.advertisement AS a USING(id)
	GROUP BY f.city_id),
 cities_rank AS (
 	SELECT *,
 		   DENSE_RANK() OVER(ORDER BY adv_count DESC) AS city_rank
 	FROM cities_detalisation)
-- ТОП-15 населенных пунктов по количеству объявлений
    SELECT c.city,
    	   cr.adv_count,
    	   ROUND(e.avg_exposition::decimal, 2) AS avg_exposition,
    	   cr.avg_meter_cost,
    	   cr.avg_area,
    	   cr.avg_rooms,
    	   cr.removed_percent
    FROM cities_rank AS cr
    LEFT JOIN real_estate.city AS c USING(city_id)
    LEFT JOIN exposition AS e USING(city_id)
    WHERE city_rank <=16 AND city <> 'Санкт-Петербург'
           
    