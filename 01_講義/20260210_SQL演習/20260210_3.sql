・employeesテーブルから全員の全フィールドを抽出
SELECT * FROM employees;

・employeesテーブルから25歳以上の人の名前と年齢だけを抽出
SELECT * FROM employees
WHERE age >= 25
;

・employeesテーブルから全員の全フィールドを年齢で昇順にソートして抽出
SELECT * FROM employees
ORDER BY age ASC
;

・employeesテーブルから25歳以上の男性だけを全フィールド抽出
SELECT * FROM employees
WHERE age >= 25
AND gender = '男性'
;

