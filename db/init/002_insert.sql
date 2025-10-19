SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- Tipos de producto
INSERT INTO product_types (code, name) VALUES
('INTERNET','Internet'),
('TV','TV & Streaming'),
('PHONE','Telefonía Fija')
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Productos
INSERT INTO products (type_id, name, description) VALUES
((SELECT id FROM product_types WHERE code='INTERNET'),'XTRIM INTERNET','Planes de internet hogar'),
((SELECT id FROM product_types WHERE code='TV'),'XTRIM TV&STREAMING','Contenido y streaming'),
((SELECT id FROM product_types WHERE code='PHONE'),'XTRIM TELEFONÍA','Telefonía fija')
ON DUPLICATE KEY UPDATE description=VALUES(description);

-- Planes
INSERT INTO plans (product_id, name, speed_mbps, data_quota_mb, minutes_quota, monthly_fee, active) VALUES
((SELECT id FROM products WHERE name='XTRIM INTERNET'),'Plan Internet 100',100,NULL,NULL,20.00,1),
((SELECT id FROM products WHERE name='XTRIM INTERNET'),'Plan Internet 300',300,NULL,NULL,30.00,1),
((SELECT id FROM products WHERE name='XTRIM TELEFONÍA'),'Plan 6.20 Ilimitado',NULL,NULL,250,6.20,1),
((SELECT id FROM products WHERE name='XTRIM TELEFONÍA'),'Plan 8 Ilimitado',   NULL,NULL,350,8.00,1),
((SELECT id FROM products WHERE name='XTRIM TELEFONÍA'),'Plan 10 Ilimitado',  NULL,NULL,650,10.00,1),
((SELECT id FROM products WHERE name='XTRIM TV&STREAMING'),'Plan TV Base', NULL, NULL, NULL, 12.00, 1) 
ON DUPLICATE KEY UPDATE monthly_fee=VALUES(monthly_fee);

-- Addons
INSERT INTO addons (product_id, name, description, monthly_fee, active) VALUES
((SELECT id FROM products WHERE name='XTRIM TV&STREAMING'),'HBO Max','Paquete HBO Max',6.99,1),
((SELECT id FROM products WHERE name='XTRIM TV&STREAMING'),'Disney+','Paquete Disney+',5.99,1)
ON DUPLICATE KEY UPDATE monthly_fee=VALUES(monthly_fee);

-- Usuarios
INSERT INTO users (first_name,last_name,email,password,active) VALUES
('Andrés','Gómez','andres.gomez@example.com','admin',1),
('Carla','Ramos','carla.ramos@example.com','admin',1),
('Jesús','Rosales','jesus.rosales@example.com','admin',1)
ON DUPLICATE KEY UPDATE first_name=VALUES(first_name), last_name=VALUES(last_name);


INSERT INTO user_subscriptions (user_id, plan_id, balance_usd, status)
SELECT u.id, p100.id, 10.00, 'ACTIVE'
FROM users u
JOIN plans p100 ON p100.name='Plan Internet 100'
WHERE u.email='andres.gomez@example.com'
  AND NOT EXISTS (
    SELECT 1 FROM user_subscriptions x WHERE x.user_id=u.id AND x.plan_id=p100.id
  );


INSERT INTO user_subscriptions (user_id, plan_id, balance_usd, status)
SELECT u.id, p300.id, 8.50, 'ACTIVE'
FROM users u
JOIN plans p300 ON p300.name='Plan Internet 300'
WHERE u.email='carla.ramos@example.com'
  AND NOT EXISTS (SELECT 1 FROM user_subscriptions x WHERE x.user_id=u.id AND x.plan_id=p300.id);
INSERT INTO user_subscriptions (user_id, plan_id, balance_usd, status)
SELECT u.id, p8.id, 2.00, 'ACTIVE'
FROM users u
JOIN plans p8 ON p8.name='Plan 8 Ilimitado'
WHERE u.email='carla.ramos@example.com'
  AND NOT EXISTS (SELECT 1 FROM user_subscriptions x WHERE x.user_id=u.id AND x.plan_id=p8.id);

-- Internet + Telefonía 10 + TV 
INSERT INTO user_subscriptions (user_id, plan_id, balance_usd, status)
SELECT u.id, p100.id, 15.00, 'ACTIVE'
FROM users u
JOIN plans p100 ON p100.name='Plan Internet 100'
WHERE u.email='jesus.rosales@example.com'
  AND NOT EXISTS (SELECT 1 FROM user_subscriptions x WHERE x.user_id=u.id AND x.plan_id=p100.id);

INSERT INTO user_subscriptions (user_id, plan_id, balance_usd, status)
SELECT u.id, p10.id, 5.00, 'ACTIVE'
FROM users u
JOIN plans p10 ON p10.name='Plan 10 Ilimitado'
WHERE u.email='jesus.rosales@example.com'
  AND NOT EXISTS (SELECT 1 FROM user_subscriptions x WHERE x.user_id=u.id AND x.plan_id=p10.id);

INSERT INTO user_subscriptions (user_id, plan_id, balance_usd, status)
SELECT u.id, ptv.id, 0.00, 'ACTIVE'
FROM users u
JOIN plans ptv ON ptv.name='Plan TV Base'
WHERE u.email='jesus.rosales@example.com'
  AND NOT EXISTS (SELECT 1 FROM user_subscriptions x WHERE x.user_id=u.id AND x.plan_id=ptv.id);

-- Addons suscripción de TV
INSERT INTO subscription_addons (subscription_id, addon_id)
SELECT tvsub.id, a.id
FROM addons a
JOIN (
  SELECT us.id
  FROM user_subscriptions us
  JOIN users u ON u.id=us.user_id
  JOIN plans pl ON pl.id=us.plan_id
  WHERE u.email='jesus.rosales@example.com' AND pl.name='Plan TV Base'
  LIMIT 1
) tvsub
WHERE a.name IN ('HBO Max','Disney+')
  AND NOT EXISTS (
    SELECT 1 FROM subscription_addons sa WHERE sa.subscription_id=tvsub.id AND sa.addon_id=a.id
  );

-- Consumos (Minutos)
INSERT INTO usage_counters (subscription_id, metric, used_value)
SELECT us.id, 'MINUTES', 120
FROM user_subscriptions us
JOIN users u ON u.id=us.user_id
JOIN plans pl ON pl.id=us.plan_id
JOIN products pr ON pr.id=pl.product_id
WHERE u.email='carla.ramos@example.com'
  AND pr.name='XTRIM TELEFONÍA'
  AND pl.name='Plan 8 Ilimitado'
  AND NOT EXISTS (SELECT 1 FROM usage_counters uc WHERE uc.subscription_id=us.id AND uc.metric='MINUTES');

INSERT INTO usage_counters (subscription_id, metric, used_value)
SELECT us.id, 'MINUTES', 180
FROM user_subscriptions us
JOIN users u ON u.id=us.user_id
JOIN plans pl ON pl.id=us.plan_id
JOIN products pr ON pr.id=pl.product_id
WHERE u.email='jesus.rosales@example.com'
  AND pr.name='XTRIM TELEFONÍA'
  AND pl.name='Plan 10 Ilimitado'
  AND NOT EXISTS (SELECT 1 FROM usage_counters uc WHERE uc.subscription_id=us.id AND uc.metric='MINUTES');

INSERT INTO invoices (user_id, subscription_id, amount, issue_date, due_date, status, notes)
SELECT u.id, us.id, 20.00,
       DATE_SUB(CURDATE(), INTERVAL 30 DAY),  -- emisión hace 30 días
       DATE_SUB(CURDATE(), INTERVAL 15 DAY),  -- venció hace 15 días
       'PAID', 'Internet 100'
FROM users u
JOIN user_subscriptions us ON us.user_id = u.id
JOIN plans p ON p.id = us.plan_id
JOIN products pr ON pr.id = p.product_id
WHERE u.email = 'andres.gomez@example.com'
  AND pr.name = 'XTRIM INTERNET'
  AND p.name = 'Plan Internet 100'
  AND NOT EXISTS (
    SELECT 1 FROM invoices i WHERE i.subscription_id = us.id AND i.issue_date = DATE_SUB(CURDATE(), INTERVAL 30 DAY)
  );

INSERT INTO invoices (user_id, subscription_id, amount, issue_date, due_date, status, notes)
SELECT u.id, us.id, 30.00,
       DATE_SUB(CURDATE(), INTERVAL 5 DAY),
       DATE_ADD(CURDATE(), INTERVAL 10 DAY),
       'PENDING', 'Internet 300'
FROM users u
JOIN user_subscriptions us ON us.user_id = u.id
JOIN plans p ON p.id = us.plan_id
JOIN products pr ON pr.id = p.product_id
WHERE u.email = 'carla.ramos@example.com'
  AND pr.name = 'XTRIM INTERNET'
  AND p.name = 'Plan Internet 300'
  AND NOT EXISTS (
    SELECT 1 FROM invoices i WHERE i.subscription_id = us.id AND i.issue_date = DATE_SUB(CURDATE(), INTERVAL 5 DAY)
  );

INSERT INTO invoices (user_id, subscription_id, amount, issue_date, due_date, status, notes)
SELECT u.id, us.id, 8.00,
       DATE_SUB(CURDATE(), INTERVAL 3 DAY),
       DATE_ADD(CURDATE(), INTERVAL 12 DAY),
       'PENDING', 'Telefonía 8'
FROM users u
JOIN user_subscriptions us ON us.user_id = u.id
JOIN plans p ON p.id = us.plan_id
JOIN products pr ON pr.id = p.product_id
WHERE u.email = 'carla.ramos@example.com'
  AND pr.name = 'XTRIM TELEFONÍA'
  AND p.name = 'Plan 8 Ilimitado'
  AND NOT EXISTS (
    SELECT 1 FROM invoices i WHERE i.subscription_id = us.id AND i.issue_date = DATE_SUB(CURDATE(), INTERVAL 3 DAY)
  );

INSERT INTO invoices (user_id, subscription_id, amount, issue_date, due_date, status, notes)
SELECT u.id, us.id, 20.00,
       DATE_SUB(CURDATE(), INTERVAL 20 DAY),
       DATE_SUB(CURDATE(), INTERVAL 5 DAY),
       'PAID', 'Internet 100'
FROM users u
JOIN user_subscriptions us ON us.user_id = u.id
JOIN plans p ON p.id = us.plan_id
JOIN products pr ON pr.id = p.product_id
WHERE u.email = 'jesus.rosales@example.com'
  AND pr.name = 'XTRIM INTERNET'
  AND p.name = 'Plan Internet 100'
  AND NOT EXISTS (
    SELECT 1 FROM invoices i WHERE i.subscription_id = us.id AND i.issue_date = DATE_SUB(CURDATE(), INTERVAL 20 DAY)
  );

INSERT INTO invoices (user_id, subscription_id, amount, issue_date, due_date, status, notes)
SELECT u.id, us.id, 10.00,
       DATE_SUB(CURDATE(), INTERVAL 2 DAY),
       DATE_ADD(CURDATE(), INTERVAL 15 DAY),
       'PENDING', 'Telefonía 10'
FROM users u
JOIN user_subscriptions us ON us.user_id = u.id
JOIN plans p ON p.id = us.plan_id
JOIN products pr ON pr.id = p.product_id
WHERE u.email = 'jesus.rosales@example.com'
  AND pr.name = 'XTRIM TELEFONÍA'
  AND p.name = 'Plan 10 Ilimitado'
  AND NOT EXISTS (
    SELECT 1 FROM invoices i WHERE i.subscription_id = us.id AND i.issue_date = DATE_SUB(CURDATE(), INTERVAL 2 DAY)
  );

INSERT INTO invoices (user_id, subscription_id, amount, issue_date, due_date, status, notes)
SELECT u.id, us.id, 12.00,
       CURDATE(),
       DATE_ADD(CURDATE(), INTERVAL 15 DAY),
       'PENDING', 'TV Base'
FROM users u
JOIN user_subscriptions us ON us.user_id = u.id
JOIN plans p ON p.id = us.plan_id
JOIN products pr ON pr.id = p.product_id
WHERE u.email = 'jesus.rosales@example.com'
  AND pr.name = 'XTRIM TV&STREAMING'
  AND p.name = 'Plan TV Base'
  AND NOT EXISTS (
    SELECT 1 FROM invoices i WHERE i.subscription_id = us.id AND i.issue_date = CURDATE()
  );

-- INTERNET HISTORICO (DATA_MB)
INSERT INTO usage_counters (subscription_id, metric, used_value, quota_value, last_update)
SELECT us.id, 'DATA_MB', t.used_mb, pl.data_quota_mb, t.mdate
FROM (
  SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 5 MONTH), '%Y-%m-01') AS mdate,  120000 AS used_mb UNION ALL
  SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 4 MONTH), '%Y-%m-01'), 150000 UNION ALL
  SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 3 MONTH), '%Y-%m-01'),  95000 UNION ALL
  SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 2 MONTH), '%Y-%m-01'), 110000 UNION ALL
  SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 MONTH), '%Y-%m-01'), 130000 UNION ALL
  SELECT DATE_FORMAT(CURDATE(),                                 '%Y-%m-01'),  80000
) t
JOIN users u            ON u.email='jesus.rosales@example.com'
JOIN user_subscriptions us ON us.user_id=u.id
JOIN plans pl           ON pl.id=us.plan_id
JOIN products pr        ON pr.id=pl.product_id
WHERE pr.name='XTRIM INTERNET'
  AND NOT EXISTS (
    SELECT 1 FROM usage_counters uc
    WHERE uc.subscription_id=us.id AND uc.metric='DATA_MB'
      AND DATE_FORMAT(uc.last_update,'%Y-%m-01') = t.mdate
  );

-- PHONE (MINUTES)
INSERT INTO usage_counters (subscription_id, metric, used_value, quota_value, last_update)
SELECT us.id, 'MINUTES', t.used_min, pl.minutes_quota, t.mdate
FROM (
  SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 5 MONTH), '%Y-%m-01') AS mdate, 420 AS used_min UNION ALL
  SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 4 MONTH), '%Y-%m-01'), 390 UNION ALL
  SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 3 MONTH), '%Y-%m-01'), 520 UNION ALL
  SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 2 MONTH), '%Y-%m-01'), 610 UNION ALL
  SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 MONTH), '%Y-%m-01'), 585 UNION ALL
  SELECT DATE_FORMAT(CURDATE(),                                 '%Y-%m-01'), 180
) t
JOIN users u            ON u.email='jesus.rosales@example.com'
JOIN user_subscriptions us ON us.user_id=u.id
JOIN plans pl           ON pl.id=us.plan_id
JOIN products pr        ON pr.id=pl.product_id
WHERE pr.name='XTRIM TELEFONÍA'
  AND NOT EXISTS (
    SELECT 1 FROM usage_counters uc
    WHERE uc.subscription_id=us.id AND uc.metric='MINUTES'
      AND DATE_FORMAT(uc.last_update,'%Y-%m-01') = t.mdate
  );
