-- 1. Database Setup
DROP DATABASE IF EXISTS repd_data;

CREATE DATABASE repd_data CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE repd_data;

-- 2. Staging Table (for initial CSV import)

DROP TABLE IF EXISTS repd_staging;

CREATE TABLE repd_staging (
	    old_ref_id TEXT,
		ref_id TEXT,
		record_last_updated_str TEXT,
		operator_name TEXT,
		site_name TEXT,
		technology_type TEXT,
		storage_type TEXT,
		storage_co_location_repd_ref_id TEXT,
		installed_capacity_mwelec_str TEXT,
		share_community_scheme TEXT,
		chp_enabled TEXT,
		cfd_allocation_round TEXT,
		ro_banding_rocmwh TEXT,
		fit_tariff_p_kwh TEXT,
		cfd_capacity_mw TEXT,
		turbine_capacity TEXT,
		no_of_turbines_str TEXT,
		height_of_turbines_m_str TEXT,
		mounting_type_for_solar TEXT,
		development_status TEXT,
		development_status_short TEXT,
		are_they_re_applying_new_repd_ref TEXT,
		are_they_re_applying_old_repd_ref TEXT,
		address TEXT,
		county TEXT,
		region TEXT,
		country TEXT,
		post_code TEXT,
		x_coordinate_str TEXT,
		y_coordinate_str TEXT,
		planning_authority TEXT,
		planning_application_reference TEXT,
		appeal_reference TEXT,
		secretary_of_state_reference TEXT,
		type_of_secretary_of_state_intervention TEXT,
		judicial_review TEXT,
		offshore_wind_round TEXT,
		planning_application_submitted_str TEXT,
		planning_application_withdrawn TEXT,
		planning_permission_refused TEXT,
		appeal_lodged TEXT,
		appeal_withdrawn TEXT,
		appeal_refused TEXT,
		appeal_granted TEXT,
		planning_permission_granted_str TEXT,
		secretary_of_state_intervened TEXT,
		secretary_of_state_refusal TEXT,
		secretary_of_state_granted TEXT,
		planning_permission_expired TEXT,
		under_construction TEXT,
		operational_str TEXT,
		heat_network_ref TEXT,
		solar_site_area_sqm_str TEXT
)CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- Load data from CSV into the staging table
LOAD DATA LOCAL INFILE 'renewable_energy_sql_project/repd-q1-apr-2025_utf8.csv'
INTO TABLE repd_staging
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS; 

-- 3. Normalised Tables Creation

DROP TABLE IF EXISTS planning_events;
DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS operators;
DROP TABLE IF EXISTS technologies;
DROP TABLE IF EXISTS development_statuses;
DROP TABLE IF EXISTS locations;

CREATE TABLE operators (
	operator_id INT PRIMARY KEY AUTO_INCREMENT,
    operator_name VARCHAR(255) UNIQUE NOT NULL
)CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
    
CREATE TABLE technologies (
	tech_id INT PRIMARY KEY AUTO_INCREMENT,
    technology_type VARCHAR(100) UNIQUE NOT NULL,
    storage_type VARCHAR(100)
)CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE locations (
	location_id INT PRIMARY KEY AUTO_INCREMENT,
    county VARCHAR(100),
    region VARCHAR(100),
    country VARCHAR(50),
    post_code VARCHAR(15),
	x_coordinate DECIMAL(12, 6),
    y_coordinate DECIMAL(12, 6), 
    -- Adding a unique constraint to prevent duplicate locations if all identifying fields are the same
    UNIQUE KEY uq_location (county, region, country, post_code, x_coordinate, y_coordinate)
)CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE development_statuses (
    status_id INT PRIMARY KEY AUTO_INCREMENT,
    status VARCHAR(100) UNIQUE NOT NULL,
    short_status VARCHAR(50)
)CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
    
CREATE TABLE projects (
	project_id INT PRIMARY KEY, -- 'ref id' from CSV table
    site_name VARCHAR(255),
    installed_capacity_mwelec DECIMAL(10,4),
    record_last_updated DATE,
    no_of_turbines INT,
    height_of_turbines_m DECIMAL(7, 2),
    mounting_type_for_solar VARCHAR(100),
    solar_site_area_sqm DECIMAL(12, 2),
    planning_authority VARCHAR(255),
    -- Foreign Keys
    operator_id INT,
    technology_id INT,
    location_id INT,
    status_id INT,
    FOREIGN KEY (operator_id) REFERENCES operators(operator_id),
    FOREIGN KEY (technology_id) REFERENCES technologies(tech_id),
    FOREIGN KEY (location_id) REFERENCES locations(location_id),
    FOREIGN KEY (status_id) REFERENCES development_statuses(status_id)
)CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
    
CREATE TABLE planning_events (
    event_id INT PRIMARY KEY AUTO_INCREMENT,
    project_id INT NOT NULL,
    event_type VARCHAR(100) NOT NULL, -- e.g., 'Submitted', 'Granted', 'Refused', 'Operational'
    event_date DATE,
    FOREIGN KEY (project_id) REFERENCES projects(project_id)
)CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- 4. Populate Normalized Tables from Staging

-- Temporarily disable foreign key checks for bulk inserts
SET FOREIGN_KEY_CHECKS = 0;

-- Populate operators
-- INSERT IGNORE INTO operators (operator_name)
-- SELECT DISTINCT operator_name
-- FROM repd_staging
-- WHERE operator_name IS NOT NULL AND operator_name != '';

INSERT IGNORE INTO operators (operator_name) -- test
SELECT DISTINCT
    TRIM(
        REGEXP_REPLACE(
            LOWER(operator_name),
            '\\b(limited|ltd|plc|group|head office|inc|corp|corporation)\\b',
            '',
            1
        )
    ) AS cleaned_name
FROM repd_staging
WHERE operator_name IS NOT NULL AND TRIM(operator_name) != '';


-- Populate technologies
INSERT IGNORE INTO technologies (technology_type, storage_type)
SELECT DISTINCT
    technology_type,
    NULLIF(storage_type, '')
FROM repd_staging
WHERE technology_type IS NOT NULL AND technology_type != '';

-- Populate development_statuses
INSERT IGNORE INTO development_statuses (status, short_status)
SELECT DISTINCT
    development_status,
    development_status_short
FROM repd_staging
WHERE development_status IS NOT NULL AND development_status != '';

-- Populate locations (with robust string cleaning for coordinates)
INSERT IGNORE INTO locations (county, region, country, post_code, x_coordinate, y_coordinate)
SELECT DISTINCT
    NULLIF(TRIM(county),''),
    NULLIF(TRIM(region),''),
    NULLIF(TRIM(country),''),
    NULLIF(post_code, ''),
    -- Clean and cast coordinates
    CAST(NULLIF(TRIM(x_coordinate_str), '') AS DECIMAL(12,6)),
    CAST(NULLIF(TRIM(y_coordinate_str), '') AS DECIMAL(12,6))
FROM repd_staging
WHERE (county IS NOT NULL AND county != '') OR
      (region IS NOT NULL AND region != '') OR
      (country IS NOT NULL AND country != '') OR
      (post_code IS NOT NULL AND post_code != '') OR
      (x_coordinate_str IS NOT NULL AND x_coordinate_str != '') OR
      (y_coordinate_str IS NOT NULL AND y_coordinate_str != '');

-- Populate projects (Fact Table)
INSERT IGNORE INTO projects (
    project_id, site_name, installed_capacity_mwelec, record_last_updated,
    no_of_turbines, height_of_turbines_m, mounting_type_for_solar,
    solar_site_area_sqm, planning_authority,
    operator_id, technology_id, location_id, status_id
)
SELECT
    CAST(rs.ref_id AS UNSIGNED),
    NULLIF(rs.site_name, ''),
    NULLIF(TRIM(rs.installed_capacity_mwelec_str), ''),
    STR_TO_DATE(NULLIF(rs.record_last_updated_str, ''), '%d/%m/%Y'),
    NULLIF(TRIM(rs.no_of_turbines_str), ''),
    NULLIF(TRIM(rs.height_of_turbines_m_str), ''),
    NULLIF(rs.mounting_type_for_solar, ''),
    NULLIF(TRIM(rs.solar_site_area_sqm_str), ''),
    NULLIF(rs.planning_authority, ''),
    o.operator_id,
    t.tech_id,
    l.location_id,
    ds.status_id
FROM repd_staging rs
LEFT JOIN operators o ON
    TRIM(
        REGEXP_REPLACE(
            LOWER(rs.operator_name),
            '\\b(limited|ltd|plc|group|head office|inc|corp|corporation)\\b',
            '',
            1
        )
    ) = o.operator_name
LEFT JOIN technologies t ON rs.technology_type = t.technology_type
LEFT JOIN development_statuses ds ON rs.development_status = ds.status
LEFT JOIN locations l ON 
    (rs.county IS NULL OR rs.county = l.county)
    AND (rs.region IS NULL OR rs.region = l.region)
    AND (rs.country IS NULL OR rs.country = l.country);

-- Populate planning_events
-- Planning Application Submitted
INSERT INTO planning_events (project_id, event_type, event_date)
SELECT
    CAST(rs.ref_id AS UNSIGNED),
    'Planning Application Submitted',
    STR_TO_DATE(NULLIF(TRIM(rs.planning_application_submitted_str), ''), '%d/%m/%Y')
FROM repd_staging rs
WHERE NULLIF(rs.planning_application_submitted_str, '') IS NOT NULL;

-- Planning Permission Granted
INSERT INTO planning_events (project_id, event_type, event_date)
SELECT
    CAST(rs.ref_id AS UNSIGNED),
    'Planning Permission Granted',
    STR_TO_DATE(NULLIF(TRIM(rs.planning_permission_granted_str), ''), '%d/%m/%Y')
FROM repd_staging rs
WHERE NULLIF(rs.planning_permission_granted_str, '') IS NOT NULL;

-- Operational events
INSERT INTO planning_events (project_id, event_type, event_date)
SELECT
    CAST(rs.ref_id AS UNSIGNED),
    'Operational',
    STR_TO_DATE(NULLIF(TRIM(rs.operational_str), ''), '%d/%m/%Y')
FROM repd_staging rs
WHERE NULLIF(rs.operational_str, '') IS NOT NULL;


-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

