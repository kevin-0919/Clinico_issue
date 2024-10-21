-- step1 | 建立發票本清單
CREATE TABLE invoice_books (
    id SERIAL PRIMARY KEY,
    track VARCHAR(2) NOT NULL,
    begin_number BIGINT NOT NULL,
    end_number BIGINT NOT NULL,
    year INT NOT NULL,
    month INT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    update_at TIMESTAMP NOT NULL
)
INSERT INTO invoice_books (track, begin_number, end_number, year, month, created_at, update_at)
VALUES 
    ('AA', 12345600, 12345649, 113, 3, '2024-03-01 00:00:00', '2024-03-10 12:00:00'),
    ('AB', 98765400, 98765449, 113, 3, '2024-03-01 00:00:00', '2024-03-15 12:00:00'),
    ('AC', 45678900, 45678999, 113, 3, '2024-03-01 00:00:00', '2024-03-20 12:00:00');




-- step2 |建立發票config(後續用來對照未開出發票)
CREATE TABLE invoices_config (
    id SERIAL PRIMARY KEY,  -- 自動遞增的 id
    invoice_number VARCHAR(50) NOT NULL,
    invoice_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL,
    update_at TIMESTAMP NOT NULL,
    remark BOOLEAN NOT NULL DEFAULT True  -- 設置預設值為 True
)


-- 生成每個 invoice_number 的序號並寫入invoices_config
WITH RECURSIVE invoice_series AS (
    -- 生成每個 invoice_number 的序號
    SELECT
        b.track,
        b.begin_number AS invoice_number,
        b.end_number,
        '2024-03-01'::date AS invoice_date_start,
        '2024-03-31'::date AS invoice_date_end,
        '2024-03-01 00:00:00'::timestamp AS created_at_start,
        '2024-03-31 23:59:59'::timestamp AS created_at_end
    FROM invoice_books b
    UNION ALL
    -- 不斷生成下一個號碼直到 end_number
    SELECT
        s.track,
        s.invoice_number + 1,
        s.end_number,
        s.invoice_date_start,
        s.invoice_date_end,
        s.created_at_start,
        s.created_at_end
    FROM invoice_series s
    WHERE s.invoice_number < s.end_number
)
-- 插入資料到 invoices 表
INSERT INTO invoices_config (invoice_number, invoice_date, created_at, update_at, remark)
SELECT 
    s.track || '-' || s.invoice_number::text AS invoice_number,
    -- 隨機選擇一個日期範圍內的日期
    (s.invoice_date_start + (random() * (s.invoice_date_end - s.invoice_date_start))::int)::date AS invoice_date,
    -- 隨機生成 created_at 和 update_at
    (s.created_at_start + (random() * (s.created_at_end - s.created_at_start))) AS created_at,
    (s.created_at_start + (random() * (s.created_at_end - s.created_at_start))) AS update_at,
    -- 根據條件設定 remark 欄位
    CASE 
        WHEN s.track = 'AC' AND s.invoice_number >= 45678988 THEN False
        ELSE True
    END AS remark
FROM invoice_series s

-- step3 |製造測資
---若測試資料存在則先刪除測試資料
DROP TABLE IF EXISTS invoices_test;

---複製config檔，並製造測資
CREATE TABLE invoices_test AS
SELECT * FROM invoices_config;

DELETE FROM invoices_test
WHERE remark IS NOT false
AND id IN (
    SELECT id
    FROM invoices_test
    WHERE remark IS NOT false
    ORDER BY random()
    LIMIT 10  --- 可以調整 LIMIT 數量來隨機刪除多筆資料
);

-- step4 |利用LEFT JOIN方式，比對config及測資，並回傳id, invoice_number, track, year, month, begin_number, end_number
SELECT 
    config.id, 
    config.invoice_number, 
    b.track, 
    b.year, 
    b.month, 
    b.begin_number, 
    b.end_number
FROM invoices_config config
LEFT JOIN invoice_books b ON  config.invoice_number LIKE b.track || '%'
WHERE config.id NOT IN (
    SELECT id
    FROM invoices_test
)
ORDER BY config.id