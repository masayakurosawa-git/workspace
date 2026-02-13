・employeesテーブルのidが5の人の名前を「坂本龍馬」に、年齢を「31」歳に更新する
UPDATE employees
SET name = '坂本龍馬', age = 31
WHERE id = 5
;


・employeesテーブルの全員の年齢に1を加える
UPDATE employees
SET age = age + 1
;



・employeesテーブルのdepartment_idが1のデータを削除する
DELETE FROM employees
WHERE department_id = 1
;


INSERT INTO users (id, name, age, email, created_at) VALUES (NULL);

INSERT INTO users (id, name, age, email, created_at) VALUES (NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);