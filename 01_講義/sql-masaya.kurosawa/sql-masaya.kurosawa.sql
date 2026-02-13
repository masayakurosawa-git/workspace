-- 問題１
INSERT INTO items (id, category_id, name, price) VALUES 
(13, 1, '鰯', 150),
(14, 2, '羊', 650)
;


-- 問題２
UPDATE items
SET price = price * 0.9
;


-- 問題３
DELETE FROM employees
WHERE end_date <= '2013-03-31'
;


-- 問題４
SELECT * FROM employees
WHERE end_date IS NULL
ORDER BY start_date
LIMIT 1
;


-- 問題５
SELECT 
	r.name AS region,
	p.name AS prefecture
FROM regions r
JOIN prefectures p ON r.code = p.region_code
ORDER BY r.code, p.code
;


-- 問題６
SELECT SUM(population) AS population
FROM populations
;


-- 問題7
SELECT 
	prefecture.name AS prefecture,
	gender.name AS gender,
	SUM(population.population) AS population

FROM populations population 
JOIN prefectures prefecture ON population.prefecture_code = prefecture.code
JOIN genders gender ON population.gender_code = gender.code
JOIN regions region ON prefecture.region_code = region.code

WHERE region.code = '80'

GROUP BY prefecture.code, prefecture, gender
ORDER BY prefecture.code, prefecture, gender DESC
;


-- 問題8
SELECT 
	region.name AS "地域",
	SUM(CASE WHEN generation.code = '1' AND gender.code = 'm' THEN population.population ELSE 0 END) AS "15歳未満(男)",
	SUM(CASE WHEN generation.code = '2' AND gender.code = 'm' THEN population.population ELSE 0 END) AS "15歳～64歳(男)",
	SUM(CASE WHEN generation.code = '3' AND gender.code = 'm' THEN population.population ELSE 0 END) AS "65歳以上(男)",
	SUM(CASE WHEN generation.code = '1' AND gender.code = 'f' THEN population.population ELSE 0 END) AS "15歳未満(女)",
	SUM(CASE WHEN generation.code = '2' AND gender.code = 'f' THEN population.population ELSE 0 END) AS "15歳～64歳(女)",
	SUM(CASE WHEN generation.code = '3' AND gender.code = 'f' THEN population.population ELSE 0 END) AS "65歳以上(女)"
	
FROM populations population 
JOIN prefectures prefecture ON population.prefecture_code = prefecture.code
JOIN generations generation ON population.generation_code = generation.code
JOIN genders gender ON population.gender_code = gender.code
JOIN regions region ON prefecture.region_code = region.code

GROUP BY region.code, "地域"
ORDER BY region.code
;









