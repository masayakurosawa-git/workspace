select * from sales;
select * from products;
select * from employees;
select * from categories;
select * from customers;
select * from customer_classes;
select * from prefectures;





-- 問題1
-- 月ごとに販売額合計を出力してください．結果は年月の降順で並び替えてください．
SELECT
  to_char(date_trunc('month', sale_date), 'YYYY-MM') AS ym,
  SUM(p.price * s.quantity) AS monthly_sales
FROM sales s
JOIN products p
ON s.product_id = p.product_id
GROUP BY ym
ORDER BY ym
;




-- 問題2
-- 社員ごとに月間販売額の一覧を出力してください
-- 結果は年月の降順で月間販売額が多い従業員が上に表示されるように並び替えてください．
-- グループ化で指定する列が２つになります．

SELECT
  to_char(date_trunc('month', sale_date), 'YYYY-MM') AS ym,
  e.employee_name AS employee_name,
  SUM(p.price * s.quantity) AS monthly_sales
FROM sales s
JOIN employees e ON s.employee_id = e.employee_id
JOIN products p ON s.product_id = p.product_id
GROUP BY ym, employee_name
ORDER BY ym DESC;




-- 問題3
-- 商品カテゴリーが魚・肉・野菜の商品ごとに，販売合計額が 5,000 円より大きい商品の月間販売額を出力してください．
-- 結果は年月の降順，商品名の昇順に並べ替えてください
SELECT
  to_char(date_trunc('month', sale_date), 'YYYY-MM') AS ym,
  p.product_name AS product_name,
  SUM(p.price * s.quantity) AS monthly_sales
FROM sales s
JOIN products p ON s.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
WHERE p.category_id IN (1,2,3)
GROUP BY ym, product_name
ORDER BY ym DESC;



-- 問題4
-- 顧客ごと・商品ごとに販売額を出力してください．
-- 結果は顧客名の昇順，商品名の昇順で出力してください．
SELECT
  c.customer_name AS customer_name,
  p.product_name AS product_name,
  SUM(p.price * s.quantity) AS monthly_sales
FROM sales s
JOIN products p ON s.product_id = p.product_id
JOIN customers c ON s.customer_id = c.customer_id

GROUP BY customer_name, product_name
ORDER BY customer_name, product_name
;



-- 問題5
-- 都道府県ごとに商品の販売額を出力してください．
-- 結果は都道府県 ID の昇順，商品名の昇順に並び替えてください．
SELECT
  pre.prefecture_name AS "都道府県",
  p.product_name AS "商品名",
  SUM(p.price * s.quantity) AS "販売額"
FROM sales s
JOIN products p ON s.product_id = p.product_id
JOIN customers c ON s.customer_id = c.customer_id
JOIN prefectures pre ON c.prefecture_id = pre.prefecture_id

GROUP BY pre.prefecture_id, "都道府県", "商品名"
ORDER BY pre.prefecture_id, "商品名"
;


-- 問題6
-- 部署別に月間平均給与を出力してください．結果は部署 ID の昇順，年月の降順に並べ替えてください．
select * from salary;
select * from employees;
select * from departments;
select * from belong_to;


SELECT
  d.department_name AS "部署名",
  to_char(date_trunc('month', sal.pay_date), 'YYYY-MM') AS "年月",
  ROUND(AVG(sal.amount), 0) AS "平均給与"
FROM salary sal
JOIN employees e ON sal.employee_id = e.employee_id
JOIN belong_to b ON e.employee_id = b.employee_id
JOIN departments d ON b.department_id = d.department_id

GROUP BY d.department_id, "部署名", "年月"
ORDER BY d.department_id, "年月"
;




-- 問題7
-- 商品カテゴリーごとに月間販売額を出力してください．
-- その際，月のレコードは 1 行にして出力してください．結果は年月の降順に並び替えてください．
-- 商品カテゴリーを列ごとに出力します

select * from products;
select * from sales;
select * from categories;

SELECT
	to_char(date_trunc('month', s.sale_date), 'YYYY-MM') AS "年月",
	SUM(CASE WHEN c.category_id = 1 THEN p.price * s.quantity ELSE 0 END) AS "魚",
	SUM(CASE WHEN c.category_id = 2 THEN p.price * s.quantity ELSE 0 END) AS "肉",
	SUM(CASE WHEN c.category_id = 3 THEN p.price * s.quantity ELSE 0 END) AS "野菜",
	SUM(CASE WHEN c.category_id = 4 THEN p.price * s.quantity ELSE 0 END) AS "菓子",
	SUM(CASE WHEN c.category_id = 5 THEN p.price * s.quantity ELSE 0 END) AS "乾物",
	SUM(CASE WHEN c.category_id = 6 THEN p.price * s.quantity ELSE 0 END) AS "惣菜",
	SUM(CASE WHEN c.category_id = 7 THEN p.price * s.quantity ELSE 0 END) AS "生活用品",
	SUM(CASE WHEN c.category_id = 8 THEN p.price * s.quantity ELSE 0 END) AS "嗜好品",
	SUM(CASE WHEN c.category_id = 9 THEN p.price * s.quantity ELSE 0 END) AS "玩具",
	SUM(CASE WHEN c.category_id = 10 THEN p.price * s.quantity ELSE 0 END) AS "アクセサリー"
FROM sales s
JOIN products p ON s.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id

GROUP BY "年月"
ORDER BY "年月" DESC
;




-- 問題8
-- 商品別に 2007 年 6-8 月のそれぞれの販売額の遷移を出力してください.
-- また，前月との増減もあわせて出力してください．結果は商品 ID の昇順に並び替えてください．

select * from products;
select * from sales;

SELECT
	t."商品名",
	t."6月販売額",
	t."7月販売額",
	CASE WHEN t."6月販売額" < t."7月販売額" THEN '増' ELSE '減' END AS "対 6月販売増減",
	t."8月販売額",
	CASE WHEN t."7月販売額" < t."8月販売額" THEN '増' ELSE '減' END AS "対 7月販売増減"
FROM (	
	SELECT
		p.product_id AS "商品ID",
		p.product_name AS "商品名",
		SUM(CASE WHEN to_char(date_trunc('month', s.sale_date), 'YYYY-MM') = '2007-06' THEN p.price * s.quantity ELSE 0 END) AS "6月販売額",
		SUM(CASE WHEN to_char(date_trunc('month', s.sale_date), 'YYYY-MM') = '2007-07' THEN p.price * s.quantity ELSE 0 END) AS "7月販売額",
		SUM(CASE WHEN to_char(date_trunc('month', s.sale_date), 'YYYY-MM') = '2007-08' THEN p.price * s.quantity ELSE 0 END) AS "8月販売額"
	FROM products p
	JOIN sales s ON p.product_id = s.product_id
	GROUP BY p.product_id, "商品名"
) t
ORDER BY t."商品ID"
;



