-- =============================================================================
-- Carbon Emissions Tracker — Database Schema & Sample Data
-- =============================================================================
-- Project   : Carbon Emissions Tracker (Django / SQLite)
-- Database  : carbon_emissions.db
-- Purpose   : Human-readable SQL file for DBMS project demonstration.
--             Contains table definitions, relationships, sample data, views,
--             and example queries.
-- =============================================================================

PRAGMA foreign_keys = ON;

-- -----------------------------------------------------------------------------
-- SECTION 1 — DROP (for clean re-creation in demo environments)
-- -----------------------------------------------------------------------------

DROP VIEW  IF EXISTS v_monthly_summary;
DROP VIEW  IF EXISTS v_activity_summary;
DROP VIEW  IF EXISTS v_goal_vs_actual;

DROP TABLE IF EXISTS emission_app_emissionrecord;
DROP TABLE IF EXISTS emission_app_emissiongoal;
DROP TABLE IF EXISTS emission_app_activitytype;
DROP TABLE IF EXISTS auth_user_user_permissions;
DROP TABLE IF EXISTS auth_user_groups;
DROP TABLE IF EXISTS auth_group_permissions;
DROP TABLE IF EXISTS auth_permission;
DROP TABLE IF EXISTS auth_group;
DROP TABLE IF EXISTS auth_user;
DROP TABLE IF EXISTS django_admin_log;
DROP TABLE IF EXISTS django_session;
DROP TABLE IF EXISTS django_migrations;
DROP TABLE IF EXISTS django_content_type;


-- =============================================================================
-- SECTION 2 — TABLE DEFINITIONS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 2.1  ActivityType
--      Lookup table for every kind of carbon-emitting activity.
--      emission_factor: kg of CO₂ emitted per 1 unit of the activity.
-- -----------------------------------------------------------------------------
CREATE TABLE emission_app_activitytype (
    id              INTEGER  NOT NULL PRIMARY KEY AUTOINCREMENT,
    activity_name   VARCHAR(100) NOT NULL UNIQUE,
    emission_factor REAL         NOT NULL,   -- kg CO₂ per unit
    unit            VARCHAR(20)  NOT NULL    -- e.g. km, kWh, kg, m³
);

-- -----------------------------------------------------------------------------
-- 2.2  EmissionRecord
--      Each row is one logged activity by a user.
--      emission_amount = quantity × emission_factor (computed on save).
-- -----------------------------------------------------------------------------
CREATE TABLE emission_app_emissionrecord (
    id              INTEGER  NOT NULL PRIMARY KEY AUTOINCREMENT,
    activity_id     BIGINT   NOT NULL REFERENCES emission_app_activitytype (id)
                             DEFERRABLE INITIALLY DEFERRED,
    quantity        REAL     NOT NULL,           -- amount of the activity unit
    emission_amount REAL     NOT NULL,           -- kg CO₂ produced
    date            DATE     NOT NULL,           -- date of the activity
    description     TEXT     NOT NULL DEFAULT '', -- optional user note
    created_at      DATETIME NOT NULL            -- record creation timestamp
);

CREATE INDEX idx_emissionrecord_activity ON emission_app_emissionrecord (activity_id);
CREATE INDEX idx_emissionrecord_date     ON emission_app_emissionrecord (date);

-- -----------------------------------------------------------------------------
-- 2.3  EmissionGoal
--      Personal targets: reduce emissions to ≤ target_emission kg CO₂
--      within the given period (daily / weekly / monthly).
-- -----------------------------------------------------------------------------
CREATE TABLE emission_app_emissiongoal (
    id               INTEGER      NOT NULL PRIMARY KEY AUTOINCREMENT,
    title            VARCHAR(100) NOT NULL,
    target_emission  REAL         NOT NULL,          -- kg CO₂ limit per period
    period           VARCHAR(10)  NOT NULL            -- 'daily','weekly','monthly'
                     CHECK (period IN ('daily','weekly','monthly')),
    start_date       DATE         NOT NULL,
    end_date         DATE         NULL,               -- NULL = ongoing goal
    notes            TEXT         NOT NULL DEFAULT '',
    created_at       DATETIME     NOT NULL
);

-- -----------------------------------------------------------------------------
-- 2.4  Django Auth & Session tables (required by the Django framework)
-- -----------------------------------------------------------------------------
CREATE TABLE django_content_type (
    id        INTEGER      NOT NULL PRIMARY KEY AUTOINCREMENT,
    app_label VARCHAR(100) NOT NULL,
    model     VARCHAR(100) NOT NULL,
    UNIQUE (app_label, model)
);

CREATE TABLE auth_permission (
    id              INTEGER      NOT NULL PRIMARY KEY AUTOINCREMENT,
    content_type_id INTEGER      NOT NULL REFERENCES django_content_type (id)
                                 DEFERRABLE INITIALLY DEFERRED,
    codename        VARCHAR(100) NOT NULL,
    name            VARCHAR(255) NOT NULL,
    UNIQUE (content_type_id, codename)
);

CREATE TABLE auth_group (
    id   INTEGER      NOT NULL PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE auth_group_permissions (
    id            INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    group_id      INTEGER NOT NULL REFERENCES auth_group      (id) DEFERRABLE INITIALLY DEFERRED,
    permission_id INTEGER NOT NULL REFERENCES auth_permission (id) DEFERRABLE INITIALLY DEFERRED,
    UNIQUE (group_id, permission_id)
);

CREATE TABLE auth_user (
    id           INTEGER      NOT NULL PRIMARY KEY AUTOINCREMENT,
    password     VARCHAR(128) NOT NULL,
    last_login   DATETIME     NULL,
    is_superuser BOOLEAN      NOT NULL DEFAULT 0,
    username     VARCHAR(150) NOT NULL UNIQUE,
    first_name   VARCHAR(150) NOT NULL DEFAULT '',
    last_name    VARCHAR(150) NOT NULL DEFAULT '',
    email        VARCHAR(254) NOT NULL DEFAULT '',
    is_staff     BOOLEAN      NOT NULL DEFAULT 0,
    is_active    BOOLEAN      NOT NULL DEFAULT 1,
    date_joined  DATETIME     NOT NULL
);

CREATE TABLE auth_user_groups (
    id       INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    user_id  INTEGER NOT NULL REFERENCES auth_user  (id) DEFERRABLE INITIALLY DEFERRED,
    group_id INTEGER NOT NULL REFERENCES auth_group (id) DEFERRABLE INITIALLY DEFERRED,
    UNIQUE (user_id, group_id)
);

CREATE TABLE auth_user_user_permissions (
    id            INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    user_id       INTEGER NOT NULL REFERENCES auth_user      (id) DEFERRABLE INITIALLY DEFERRED,
    permission_id INTEGER NOT NULL REFERENCES auth_permission (id) DEFERRABLE INITIALLY DEFERRED,
    UNIQUE (user_id, permission_id)
);

CREATE TABLE django_session (
    session_key  VARCHAR(40) NOT NULL PRIMARY KEY,
    session_data TEXT        NOT NULL,
    expire_date  DATETIME    NOT NULL
);

CREATE TABLE django_migrations (
    id      INTEGER      NOT NULL PRIMARY KEY AUTOINCREMENT,
    app     VARCHAR(255) NOT NULL,
    name    VARCHAR(255) NOT NULL,
    applied DATETIME     NOT NULL
);

CREATE TABLE django_admin_log (
    id             INTEGER          NOT NULL PRIMARY KEY AUTOINCREMENT,
    action_time    DATETIME         NOT NULL,
    object_id      TEXT             NULL,
    object_repr    VARCHAR(200)     NOT NULL,
    action_flag    SMALLINT         NOT NULL CHECK (action_flag >= 0),
    change_message TEXT             NOT NULL,
    content_type_id INTEGER         NULL REFERENCES django_content_type (id) DEFERRABLE INITIALLY DEFERRED,
    user_id         INTEGER         NOT NULL REFERENCES auth_user        (id) DEFERRABLE INITIALLY DEFERRED
);


-- =============================================================================
-- SECTION 3 — SAMPLE DATA
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 3.1  Activity Types  (10 rows)
-- -----------------------------------------------------------------------------
INSERT INTO emission_app_activitytype (id, activity_name, emission_factor, unit) VALUES
    (1,  'Car Travel',         0.210,  'km'),
    (2,  'Bus Travel',         0.089,  'km'),
    (3,  'Train Travel',       0.041,  'km'),
    (4,  'Air Travel',         0.255,  'km'),
    (5,  'Electricity Usage',  0.475,  'kWh'),
    (6,  'Natural Gas',        2.000,  'm³'),
    (7,  'Coal Burning',       2.860,  'kg'),
    (8,  'Waste Production',   0.500,  'kg'),
    (9,  'Water Usage',        0.344,  'm³'),
    (10, 'Paper Usage',        1.320,  'kg');

-- -----------------------------------------------------------------------------
-- 3.2  Emission Records  (12 rows spanning ~1 week of activity)
--      emission_amount = quantity × emission_factor
-- -----------------------------------------------------------------------------
INSERT INTO emission_app_emissionrecord
    (id, activity_id, quantity, emission_amount, date, description, created_at)
VALUES
    -- 2026-02-28
    (1,  1,  25.5,  5.355,   '2026-02-28', 'Daily commute to office',        '2026-02-28 20:47:59'),
    (2,  5, 150.0, 71.250,   '2026-02-28', 'Home electricity usage',         '2026-02-28 20:47:59'),
    -- 2026-02-27
    (3,  2,  12.0,  1.068,   '2026-02-27', 'Bus commute to downtown',        '2026-02-28 20:47:59'),
    (4,  1,  45.0,  9.450,   '2026-02-27', 'Weekend road trip',              '2026-02-28 20:47:59'),
    -- 2026-02-26
    (5,  4, 350.0, 89.250,   '2026-02-26', 'Business flight to conference',  '2026-02-28 20:47:59'),
    (6,  5, 200.0, 95.000,   '2026-02-26', 'Apartment electricity',          '2026-02-28 20:47:59'),
    -- 2026-02-25
    (7,  3,  30.0,  1.230,   '2026-02-25', 'Train commute',                  '2026-02-28 20:47:59'),
    (8,  6,  15.5, 31.000,   '2026-02-25', 'Heating – natural gas',          '2026-02-28 20:47:59'),
    -- 2026-02-24
    (9,  8,   5.0,  2.500,   '2026-02-24', 'Household waste',                '2026-02-28 20:47:59'),
    -- 2026-02-23
    (10, 10,  2.5,  3.300,   '2026-02-23', 'Office paper usage',             '2026-02-28 20:47:59'),
    (11,  9,  8.0,  2.752,   '2026-02-23', 'Household water usage',          '2026-02-28 20:47:59'),
    -- 2026-02-22
    (12,  1, 60.0, 12.600,   '2026-02-22', 'Long drive to countryside',      '2026-02-28 20:47:59');

-- -----------------------------------------------------------------------------
-- 3.3  Emission Goals  (3 rows)
-- -----------------------------------------------------------------------------
INSERT INTO emission_app_emissiongoal
    (id, title, target_emission, period, start_date, end_date, notes, created_at)
VALUES
    (1, 'Reduce Monthly Transport', 80.0,  'monthly', '2026-05-01', NULL,
        'Target lower car and air travel',  '2026-05-01 07:34:39'),
    (2, 'Weekly Electricity Cap',   20.0,  'weekly',  '2026-04-27', NULL,
        'Keep home energy use in check',    '2026-05-01 07:34:39'),
    (3, 'Daily Commute Goal',        5.0,  'daily',   '2026-05-01', NULL,
        'Prefer bus or train over car',     '2026-05-01 07:34:39');

-- -----------------------------------------------------------------------------
-- 3.4  Demo user  (password = "demo" hashed with PBKDF2-SHA256)
-- -----------------------------------------------------------------------------
INSERT INTO auth_user
    (id, username, password, is_superuser, is_staff, is_active, date_joined, email)
VALUES
    (1, 'demo',
     'pbkdf2_sha256$600000$Pb4LZY1RpIDSFgHUVmbifk$5JngYxzlQjZJP86GhQ2xITb7Y1oGIgJ42zdQHQsvNnU=',
     1, 1, 1, '2026-02-28 20:47:58', 'demo@example.com');


-- =============================================================================
-- SECTION 4 — VIEWS  (pre-built queries for reporting)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 4.1  v_activity_summary
--      Total emissions and number of records per activity type.
-- -----------------------------------------------------------------------------
CREATE VIEW v_activity_summary AS
SELECT
    a.id                                          AS activity_id,
    a.activity_name,
    a.emission_factor,
    a.unit,
    COUNT(r.id)                                   AS total_records,
    ROUND(SUM(r.quantity),        2)              AS total_quantity,
    ROUND(SUM(r.emission_amount), 2)              AS total_emission_kg
FROM emission_app_activitytype  a
LEFT JOIN emission_app_emissionrecord r ON r.activity_id = a.id
GROUP BY a.id, a.activity_name, a.emission_factor, a.unit;

-- -----------------------------------------------------------------------------
-- 4.2  v_monthly_summary
--      Total emissions rolled up by calendar month.
-- -----------------------------------------------------------------------------
CREATE VIEW v_monthly_summary AS
SELECT
    STRFTIME('%Y-%m', date)         AS month,
    COUNT(id)                       AS num_records,
    ROUND(SUM(emission_amount), 2)  AS total_emission_kg
FROM emission_app_emissionrecord
GROUP BY STRFTIME('%Y-%m', date)
ORDER BY month DESC;

-- -----------------------------------------------------------------------------
-- 4.3  v_goal_vs_actual
--      Compares each emission goal's target against the actual emissions
--      recorded during the goal's active period for the matching period type.
--      NOTE: This view demonstrates goal tracking logic; the period bucketing
--      is simplified for readability (monthly → calendar month of start_date).
-- -----------------------------------------------------------------------------
CREATE VIEW v_goal_vs_actual AS
SELECT
    g.id                                               AS goal_id,
    g.title,
    g.period,
    g.target_emission                                  AS target_kg,
    ROUND(
        COALESCE(
            CASE g.period
                WHEN 'monthly' THEN (
                    SELECT SUM(r.emission_amount)
                    FROM emission_app_emissionrecord r
                    WHERE STRFTIME('%Y-%m', r.date) = STRFTIME('%Y-%m', g.start_date)
                )
                WHEN 'weekly' THEN (
                    SELECT SUM(r.emission_amount)
                    FROM emission_app_emissionrecord r
                    WHERE r.date BETWEEN g.start_date
                              AND DATE(g.start_date, '+6 days')
                )
                WHEN 'daily' THEN (
                    SELECT SUM(r.emission_amount)
                    FROM emission_app_emissionrecord r
                    WHERE r.date = g.start_date
                )
            END
        , 0)
    , 2)                                               AS actual_kg,
    g.notes,
    g.start_date,
    g.end_date
FROM emission_app_emissiongoal g;


-- =============================================================================
-- SECTION 5 — EXAMPLE QUERIES  (uncomment to run)
-- =============================================================================

-- -- 5.1  All activity types ordered by emission factor (highest first)
-- SELECT activity_name, emission_factor, unit
-- FROM   emission_app_activitytype
-- ORDER  BY emission_factor DESC;

-- -- 5.2  Top 5 highest-emission records
-- SELECT r.date, a.activity_name, r.quantity, a.unit, r.emission_amount, r.description
-- FROM   emission_app_emissionrecord r
-- JOIN   emission_app_activitytype   a ON a.id = r.activity_id
-- ORDER  BY r.emission_amount DESC
-- LIMIT  5;

-- -- 5.3  Use the monthly summary view
-- SELECT * FROM v_monthly_summary;

-- -- 5.4  Use the activity summary view
-- SELECT * FROM v_activity_summary;

-- -- 5.5  Goal vs actual emissions
-- SELECT title, period, target_kg, actual_kg,
--        CASE WHEN actual_kg <= target_kg THEN 'ON TARGET' ELSE 'OVER TARGET' END AS status
-- FROM   v_goal_vs_actual;

-- -- 5.6  Total emissions by category (transport vs energy vs other)
-- SELECT
--     CASE
--         WHEN a.activity_name IN ('Car Travel','Bus Travel','Train Travel','Air Travel')
--             THEN 'Transport'
--         WHEN a.activity_name IN ('Electricity Usage','Natural Gas','Coal Burning')
--             THEN 'Energy'
--         ELSE 'Other'
--     END                            AS category,
--     ROUND(SUM(r.emission_amount),2) AS total_emission_kg
-- FROM emission_app_emissionrecord r
-- JOIN emission_app_activitytype   a ON a.id = r.activity_id
-- GROUP BY category
-- ORDER BY total_emission_kg DESC;

-- =============================================================================
-- END OF FILE
-- =============================================================================
