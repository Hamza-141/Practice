-- =============================================================================
-- CARBON EMISSIONS TRACKER DATABASE
-- =============================================================================
-- Database : carbon_emissions.db
-- Purpose  : DBMS Project (Clean & Readable Version)
-- =============================================================================

PRAGMA foreign_keys = ON;

-- =============================================================================
-- SECTION 1 — CLEAN SETUP
-- =============================================================================

DROP VIEW  IF EXISTS v_goal_vs_actual;
DROP VIEW  IF EXISTS v_monthly_summary;
DROP VIEW  IF EXISTS v_activity_summary;

DROP TABLE IF EXISTS emission_app_emissionrecord;
DROP TABLE IF EXISTS emission_app_emissiongoal;
DROP TABLE IF EXISTS emission_app_activitytype;

-- =============================================================================
-- SECTION 2 — TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Activity Types
-- -----------------------------------------------------------------------------
CREATE TABLE emission_app_activitytype (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    activity_name   VARCHAR(100) NOT NULL UNIQUE,
    emission_factor REAL         NOT NULL,   -- kg CO₂ per unit
    unit            VARCHAR(20)  NOT NULL
);

-- -----------------------------------------------------------------------------
-- Emission Records
-- -----------------------------------------------------------------------------
CREATE TABLE emission_app_emissionrecord (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    activity_id     INTEGER NOT NULL,
    quantity        REAL    NOT NULL,
    emission_amount REAL    NOT NULL,
    date            DATE    NOT NULL,
    description     TEXT    DEFAULT '',
    created_at      DATETIME NOT NULL,

    FOREIGN KEY (activity_id)
        REFERENCES emission_app_activitytype(id)
);

CREATE INDEX idx_record_activity ON emission_app_emissionrecord(activity_id);
CREATE INDEX idx_record_date     ON emission_app_emissionrecord(date);

-- -----------------------------------------------------------------------------
-- Emission Goals
-- -----------------------------------------------------------------------------
CREATE TABLE emission_app_emissiongoal (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    title            VARCHAR(100) NOT NULL,
    target_emission  REAL         NOT NULL,
    period           TEXT         NOT NULL CHECK (period IN ('daily','weekly','monthly')),
    start_date       DATE         NOT NULL,
    end_date         DATE,
    notes            TEXT         DEFAULT '',
    created_at       DATETIME     NOT NULL
);

-- =============================================================================
-- SECTION 3 — SAMPLE DATA
-- =============================================================================

-- Activity Types
INSERT INTO emission_app_activitytype
    (id, activity_name, emission_factor, unit)
VALUES
    (1,  'Car Travel',        0.210, 'km'),
    (2,  'Bus Travel',        0.089, 'km'),
    (3,  'Train Travel',      0.041, 'km'),
    (4,  'Air Travel',        0.255, 'km'),
    (5,  'Electricity Usage', 0.475, 'kWh'),
    (6,  'Natural Gas',       2.000, 'm³'),
    (7,  'Coal Burning',      2.860, 'kg'),
    (8,  'Waste Production',  0.500, 'kg'),
    (9,  'Water Usage',       0.344, 'm³'),
    (10, 'Paper Usage',       1.320, 'kg');

-- Emission Records
INSERT INTO emission_app_emissionrecord
    (id, activity_id, quantity, emission_amount, date, description, created_at)
VALUES
    (1,  1, 25.5,  5.355,  '2026-02-28', 'Daily commute',        '2026-02-28 20:47:59'),
    (2,  5, 150.0, 71.250, '2026-02-28', 'Electricity usage',    '2026-02-28 20:47:59'),
    (3,  2, 12.0,  1.068,  '2026-02-27', 'Bus commute',          '2026-02-28 20:47:59'),
    (4,  1, 45.0,  9.450,  '2026-02-27', 'Road trip',            '2026-02-28 20:47:59'),
    (5,  4, 350.0, 89.250, '2026-02-26', 'Flight travel',        '2026-02-28 20:47:59'),
    (6,  5, 200.0, 95.000, '2026-02-26', 'Apartment electricity','2026-02-28 20:47:59'),
    (7,  3, 30.0,  1.230,  '2026-02-25', 'Train commute',        '2026-02-28 20:47:59'),
    (8,  6, 15.5,  31.000, '2026-02-25', 'Gas usage',            '2026-02-28 20:47:59'),
    (9,  8, 5.0,   2.500,  '2026-02-24', 'Waste',                '2026-02-28 20:47:59'),
    (10, 10, 2.5,  3.300,  '2026-02-23', 'Paper usage',          '2026-02-28 20:47:59'),
    (11, 9,  8.0,  2.752,  '2026-02-23', 'Water usage',          '2026-02-28 20:47:59'),
    (12, 1, 60.0, 12.600,  '2026-02-22', 'Long drive',           '2026-02-28 20:47:59');

-- Emission Goals
INSERT INTO emission_app_emissiongoal
    (id, title, target_emission, period, start_date, end_date, notes, created_at)
VALUES
    (1, 'Monthly Transport Goal', 80.0, 'monthly', '2026-05-01', NULL, 'Reduce travel', '2026-05-01 07:34:39'),
    (2, 'Weekly Electricity Goal',20.0, 'weekly',  '2026-04-27', NULL, 'Save energy',   '2026-05-01 07:34:39'),
    (3, 'Daily Commute Goal',     5.0,  'daily',   '2026-05-01', NULL, 'Use bus/train', '2026-05-01 07:34:39');

-- =============================================================================
-- SECTION 4 — VIEWS
-- =============================================================================

-- Activity Summary
CREATE VIEW v_activity_summary AS
SELECT
    a.id,
    a.activity_name,
    a.unit,
    COUNT(r.id)                       AS total_records,
    ROUND(SUM(r.quantity), 2)         AS total_quantity,
    ROUND(SUM(r.emission_amount), 2)  AS total_emission_kg
FROM emission_app_activitytype a
LEFT JOIN emission_app_emissionrecord r
       ON r.activity_id = a.id
GROUP BY a.id;

-- Monthly Summary
CREATE VIEW v_monthly_summary AS
SELECT
    STRFTIME('%Y-%m', date)           AS month,
    COUNT(*)                          AS num_records,
    ROUND(SUM(emission_amount), 2)    AS total_emission_kg
FROM emission_app_emissionrecord
GROUP BY month
ORDER BY month DESC;

-- Goal vs Actual
CREATE VIEW v_goal_vs_actual AS
SELECT
    g.id,
    g.title,
    g.period,
    g.target_emission AS target_kg,
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
                    WHERE r.date BETWEEN g.start_date AND DATE(g.start_date, '+6 days')
                )
                WHEN 'daily' THEN (
                    SELECT SUM(r.emission_amount)
                    FROM emission_app_emissionrecord r
                    WHERE r.date = g.start_date
                )
            END, 0
        ), 2
    ) AS actual_kg
FROM emission_app_emissiongoal g;

-- =============================================================================
-- END OF FILE
-- =============================================================================
