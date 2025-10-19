SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(80) NOT NULL,
  last_name  VARCHAR(80) NOT NULL,
  email      VARCHAR(120) NOT NULL,
  password   VARCHAR(255) NOT NULL,
  active     TINYINT(1)   NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_users_email UNIQUE (email)
);

CREATE TABLE IF NOT EXISTS product_types (
  id   INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(30) NOT NULL,
  name VARCHAR(80) NOT NULL,
  CONSTRAINT uq_pt_code UNIQUE (code)
);

CREATE TABLE IF NOT EXISTS products (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  type_id     INT NOT NULL,
  name        VARCHAR(120) NOT NULL,
  description VARCHAR(255) NULL,
  active      TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT fk_prod_type FOREIGN KEY (type_id) REFERENCES product_types(id),
  CONSTRAINT uq_product_name UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS plans (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  product_id     INT NOT NULL,
  name           VARCHAR(120) NOT NULL,
  speed_mbps     INT           NULL,      -- INTERNET
  data_quota_mb  INT           NULL,      -- opcional (datos)
  minutes_quota  INT           NULL,      -- PHONE
  monthly_fee    DECIMAL(10,2) NOT NULL,
  active         TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT fk_plan_product FOREIGN KEY (product_id) REFERENCES products(id),
  CONSTRAINT uq_plan_name UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS addons (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  product_id  INT NOT NULL,
  name        VARCHAR(120) NOT NULL,
  description VARCHAR(255) NULL,
  monthly_fee DECIMAL(10,2) NOT NULL,
  active      TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT fk_addon_product FOREIGN KEY (product_id) REFERENCES products(id),
  CONSTRAINT uq_addon_name UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS user_subscriptions (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  user_id      INT NOT NULL,
  plan_id      INT NOT NULL,
  balance_usd  DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  status       ENUM('ACTIVE','SUSPENDED','CANCELLED') NOT NULL DEFAULT 'ACTIVE',
  started_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_us_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_us_plan FOREIGN KEY (plan_id) REFERENCES plans(id),
  INDEX ix_us_user_status (user_id, status)
);

CREATE TABLE IF NOT EXISTS subscription_addons (
  subscription_id INT NOT NULL,
  addon_id        INT NOT NULL,
  started_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (subscription_id, addon_id),
  CONSTRAINT fk_sa_sub FOREIGN KEY (subscription_id) REFERENCES user_subscriptions(id),
  CONSTRAINT fk_sa_add FOREIGN KEY (addon_id) REFERENCES addons(id)
);

CREATE TABLE IF NOT EXISTS usage_counters (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  subscription_id  INT NOT NULL,
  metric           ENUM('DATA_MB','MINUTES') NOT NULL,
  used_value       INT NOT NULL DEFAULT 0,
  quota_value      INT NULL,
  last_update      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_uc_sub FOREIGN KEY (subscription_id) REFERENCES user_subscriptions(id),
  INDEX ix_uc_sub_metric (subscription_id, metric)
);

CREATE TABLE IF NOT EXISTS invoices (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  user_id         INT NOT NULL,
  subscription_id INT NOT NULL,
  amount          DECIMAL(10,2) NOT NULL,
  issue_date      DATE NOT NULL,
  due_date        DATE NOT NULL,
  status          ENUM('PENDING','PAID','OVERDUE') DEFAULT 'PENDING',
  notes           VARCHAR(255) NULL,
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (subscription_id) REFERENCES user_subscriptions(id),
  INDEX ix_inv_user (user_id),
  INDEX ix_inv_sub  (subscription_id)
);


CREATE OR REPLACE VIEW v_dashboard_summary AS
SELECT
  us.id                           AS subscription_id,
  u.id                            AS user_id,
  u.first_name,
  u.last_name,
  u.email,
  pl.id                           AS plan_id,
  pl.name                         AS plan_name,
  pt.code                         AS product_type_code,
  pt.name                         AS product_type_name,
  us.balance_usd,
  us.status,
  MAX(CASE WHEN uc.metric='DATA_MB' THEN uc.used_value END) AS data_used_mb,
  MAX(CASE WHEN uc.metric='MINUTES' THEN uc.used_value END) AS minutes_used,
  MAX(uc.last_update)                                        AS last_update,
  pl.speed_mbps,
  pl.data_quota_mb,
  pl.minutes_quota,
  pl.monthly_fee
FROM user_subscriptions us
JOIN users u         ON u.id  = us.user_id
JOIN plans pl        ON pl.id = us.plan_id
JOIN products p      ON p.id  = pl.product_id
JOIN product_types pt ON pt.id = p.type_id
LEFT JOIN usage_counters uc ON uc.subscription_id = us.id
GROUP BY
  us.id, u.id, u.first_name, u.last_name, u.email,
  pl.id, pl.name, pt.code, pt.name, us.balance_usd, us.status,
  pl.speed_mbps, pl.data_quota_mb, pl.minutes_quota, pl.monthly_fee;
  

CREATE OR REPLACE VIEW v_usage_monthly AS
SELECT
  us.id                                   AS subscription_id,
  pt.code                                 AS product_type_code,   
  DATE_FORMAT(uc.last_update, '%Y-%m-01') AS month_start,
  SUM(CASE WHEN uc.metric='DATA_MB' THEN uc.used_value ELSE 0 END)    AS data_used_mb,
  SUM(CASE WHEN uc.metric='MINUTES' THEN uc.used_value ELSE 0 END)    AS minutes_used
FROM user_subscriptions us
JOIN plans pl        ON pl.id=us.plan_id
JOIN products p      ON p.id=pl.product_id
JOIN product_types pt ON pt.id=p.type_id
LEFT JOIN usage_counters uc ON uc.subscription_id=us.id
GROUP BY us.id, pt.code, DATE_FORMAT(uc.last_update, '%Y-%m-01');
