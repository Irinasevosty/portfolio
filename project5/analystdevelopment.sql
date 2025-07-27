/* Анализ данных для агентства недвижимости
 * 
 * Автор: Ирина Севостьянова
 * Дата: 05/04/2025
*/

-- Пример фильтрации данных от аномальных значений
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
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- 1. Время активности объявлений
-- 1.1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений.
-- 1.2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений.
--    Как эти зависимости варьируют между регионами.
-- 1.3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам.

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
-- Выведем объявления без выбросов:
category_id AS (
    SELECT f.id
        , CASE WHEN f.city_id IN ('6X8I') THEN 'Saint-Petersburg'
          ELSE 'LenOblast' END AS category
        , CASE WHEN a.days_exposition BETWEEN 1 AND 30 THEN 'month'
          WHEN a.days_exposition BETWEEN 31 AND 90 THEN 'up to three month'
          WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'six month'
          WHEN a.days_exposition >=181 then 'more than six month' 
          else 'non category' END AS segment_activ_days
    FROM real_estate.advertisement a
    JOIN real_estate.flats f USING (id)
    WHERE f.id IN (SELECT * FROM filtered_id) and f.type_id = 'F8EM'
    GROUP BY f.id, a.days_exposition)
SELECT 
    ci.category
    , ci.segment_activ_days
    , COUNT(f.id) AS count_advertisement
    , ROUND(AVG(a.last_price::NUMERIC/ f.total_area::NUMERIC),2) AS avg_square
    , PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.rooms) AS mediana_room
    , PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.balcony) AS mediana_balcony
    , PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.floors_total) AS mediana_floor
    , ROUND(AVG(f.living_area::NUMERIC),2) AS avg_area
FROM category_id ci
JOIN real_estate.flats f using (id)
JOIN real_estate.advertisement a using (id)
WHERE f.id IN (SELECT * FROM filtered_id)
GROUP BY ci.category, ci.segment_activ_days
ORDER BY ci.category DESC, count_advertisement, ci.segment_activ_days;


-- 2. Сезонность объявлений
-- 2.1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости.
-- 2.2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений.
-- 2.3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир.
--    Что можно сказать о зависимости этих параметров от месяца.

WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
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
statuses_id AS (
    SELECT id
        ,  CASE WHEN a.days_exposition IS NULL THEN 'closed'
           WHEN a.days_exposition IS NOT NULL THEN 'open sales' END AS statuses
        ,  TO_CHAR(a.first_day_exposition, 'FMMonth') AS month_public -- выделите месяцы публикации объявления 
        ,  TO_CHAR((a.first_day_exposition + (INTERVAL '1 day' * days_exposition)), 'FMMonth') AS month_closed -- снятия недвижимости с продажи
    FROM real_estate.flats f
    left join real_estate.advertisement a USING (id)
    WHERE id IN (SELECT * FROM filtered_id) and f.type_id = 'F8EM'
),
month_activity AS (
    SELECT month_public
        ,  COUNT(id) FILTER (WHERE statuses = 'open sales') AS count_open_sales
        ,  COUNT(id) FILTER (WHERE statuses = 'closed') AS count_closed
        ,  ROUND(AVG(a.last_price::numeric / f.total_area::numeric)FILTER (WHERE statuses = 'open sales'), 2) AS avg_square_open
        ,  ROUND(AVG(a.last_price::numeric / f.total_area::numeric)FILTER (WHERE statuses = 'closed'), 2) AS avg_square_closed
        ,  ROUND(AVG(f.living_area::numeric) FILTER (WHERE statuses = 'open sales'), 2) AS avg_area_open
        ,  ROUND(AVG(f.living_area::numeric) FILTER (WHERE statuses = 'closed'), 2) AS avg_area_closed
    FROM statuses_id sid
    LEFT JOIN real_estate.advertisement a USING (id)
    LEFT JOIN real_estate.flats f USING (id)
    WHERE first_day_exposition BETWEEN '2015-01-01' AND '2018-12-01'
    GROUP BY month_public
),
rank_activity AS (
    SELECT month_public
        ,  count_open_sales
        ,  count_closed
        ,  avg_square_open
        ,  avg_square_closed
        ,  avg_area_open
        ,  avg_area_closed
        ,  RANK() OVER (ORDER BY count_open_sales DESC) AS rank_open_sales
        ,  RANK() OVER (ORDER BY count_closed DESC) AS rank_closed
    FROM month_activity)
select month_public
    , count_open_sales
    , count_closed
    , avg_square_open
    , avg_square_closed
    , avg_area_open
    , avg_area_closed
    , rank_open_sales
    , rank_closed
FROM rank_activity
ORDER BY rank_open_sales, rank_closed;

-- 3. Анализ рынка недвижимости Ленобласти
-- 3.1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости.
-- 3.2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений.
--    Это может указывать на высокую долю продажи недвижимости.
-- 3.3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах. 
--    Есть ли вариация значений по этим метрикам.
-- 3.4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений.

WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
select c.city
    , STRING_AGG(distinct t.type, ', ') as type_name
    , COUNT(f.id) AS count_advertisement
    , ROUND(COUNT(days_exposition)::NUMERIC / COUNT(*)*100.0,2) as share_closed_sales
    , ROUND(AVG(a.last_price::NUMERIC/ f.total_area::NUMERIC),2) AS avg_square
    , ceil(avg(days_exposition::numeric)) as avg_days
    , PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.rooms) AS mediana_room
    , PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.balcony) AS mediana_balcony
    , PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.floors_total) AS mediana_floor
    , ROUND(AVG(f.living_area::NUMERIC),2) AS avg_area
FROM real_estate.flats f
left join real_estate.city c using(city_id)
left join real_estate.type t using(type_id)
left join real_estate.advertisement a using(id)
WHERE id IN (SELECT * FROM filtered_id) and c.city <>'Санкт-Петербург'
group by c.city
order by count_advertisement desc;