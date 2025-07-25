USE repd_data;

SELECT DISTINCT country FROM locations;
SELECT DISTINCT mounting_type_for_solar FROM projects;
SELECT DISTINCT technology_type FROM technologies;
SELECT DISTINCT status FROM development_statuses;

-- -------------------------- --
-- TEMP tables 
-- -------------------------- --

-- solar projects table
CREATE TEMPORARY TABLE solar_projects AS 
  SELECT project_id, site_name, installed_capacity_mwelec, record_last_updated, mounting_type_for_solar, solar_site_area_sqm, planning_authority, operator_id, technology_id, location_id, status_id
  FROM projects
  WHERE technology_id = 10;
  
  -- wind projects table
CREATE TEMPORARY TABLE wind_projects AS 
SELECT 
    p.project_id,
    p.site_name,
    CASE 
      WHEN t.technology_type = 'Wind Onshore' THEN 'Onshore'
      WHEN t.technology_type = 'Wind Offshore' THEN 'Offshore'
      ELSE 'Unknown'
      END AS 'wind_type',
    p.installed_capacity_mwelec,
    p.record_last_updated,
    p.no_of_turbines,
    p.height_of_turbines_m,
    p.planning_authority,
    p.operator_id,
    p.technology_id,
    p.location_id,
    p.status_id
  FROM projects p
  JOIN technologies t ON p.technology_id = t.tech_id
  WHERE t.tech_id IN (15,16);
  

-- operational projects table
CREATE TEMPORARY TABLE operational_projects AS
SELECT *
FROM projects p
JOIN development_statuses ds USING (status_id)
WHERE ds.status = 'Operational';


-- -------------------------- --
-- GLOBAL TABLES			  --
-- -------------------------- --

-- biggest 50 projects in terms of capacity 
SELECT 
    p.project_id,
    p.site_name,
    p.installed_capacity_mwelec,
    p.planning_authority,
    o.operator_name,
    t.technology_type,
    l.region,
    ds.status
FROM projects p
JOIN development_statuses ds USING (status_id)
JOIN technologies t ON p.technology_id = t.tech_id
JOIN locations l USING (location_id)
JOIN operators o USING (operator_id)
ORDER BY p.installed_capacity_mwelec DESC
LIMIT 50;


-- group all projects by status
SELECT
	ds.status,
	COUNT(*) AS project_count
FROM projects p
JOIN development_statuses ds USING (status_id)
GROUP BY ds.status
ORDER BY project_count DESC;


-- total capacity by region
SELECT
	l.region,
    COUNT(*) AS project_count,
	SUM(p.installed_capacity_mwelec) AS total_capacity
FROM projects p
JOIN locations l USING (location_id)
GROUP BY l.region
ORDER BY total_capacity DESC;

-- stats for technology type per region
SELECT
	l.region,
    t.technology_type,
    COUNT(*) AS project_count,
    SUM(p.installed_capacity_mwelec) AS total_capacity
FROM projects p
JOIN technologies t ON p.technology_id = t.tech_id
JOIN locations l USING (location_id)
GROUP BY l.region, t.technology_type
ORDER BY l.region;


-- stats for tech_types dominence
SELECT 
    t.technology_type,
    COUNT(DISTINCT l.region) AS num_regions,
    COUNT(DISTINCT p.location_id) AS num_sites,
    COUNT(*) AS total_projects,
    SUM(p.installed_capacity_mwelec) AS total_capacity
FROM projects p
JOIN technologies t ON p.technology_id = t.tech_id
JOIN locations l ON p.location_id = l.location_id
GROUP BY t.technology_type
ORDER BY num_regions DESC;

-- future capacity
SELECT 
    t.technology_type,
    COUNT(*) AS projects_in_pipeline,
    SUM(p.installed_capacity_mwelec) AS capacity_pipeline
FROM projects p
JOIN development_statuses ds ON p.status_id = ds.status_id
JOIN technologies t ON p.technology_id = t.tech_id
WHERE ds.status = 'Under Construction'
GROUP BY t.technology_type
ORDER BY capacity_pipeline DESC;


-- Operator Concentration: top 5 best perfoming operators per region
WITH operator_capacity_by_region AS (
  SELECT
    l.region,
    o.operator_name,
    COUNT(*) AS project_count,
    SUM(p.installed_capacity_mwelec) AS total_capacity_mw,
    RANK() OVER (PARTITION BY l.region ORDER BY SUM(p.installed_capacity_mwelec) DESC) AS operator_rank
  FROM projects p
  JOIN operators o ON p.operator_id = o.operator_id
  JOIN locations l ON p.location_id = l.location_id
  GROUP BY l.region, o.operator_name
)

SELECT
  region,
  operator_name,
  total_capacity_mw
FROM operator_capacity_by_region
WHERE operator_rank <= 5
ORDER BY region, total_capacity_mw DESC;



-- Operator Concentration:  top 5 best perfoming operators per tech type
WITH operator_capacity_by_type AS (
  SELECT
    t.technology_type,
    o.operator_name,
    COUNT(*) AS project_count,
    SUM(p.installed_capacity_mwelec) AS total_capacity_mw,
    RANK() OVER (PARTITION BY t.technology_type ORDER BY SUM(p.installed_capacity_mwelec) DESC) AS operator_rank
  FROM projects p
  JOIN operators o ON p.operator_id = o.operator_id
  JOIN technologies t ON p.technology_id = t.tech_id
  GROUP BY t.technology_type, o.operator_name
)

SELECT
  technology_type,
  operator_name,
  total_capacity_mw
FROM operator_capacity_by_type
WHERE operator_rank <= 5
ORDER BY technology_type, total_capacity_mw DESC;

-- recent operational projects
SELECT 
    l.region,
    t.technology_type,
    COUNT(*) AS recent_projects,
    SUM(p.installed_capacity_mwelec) AS recent_capacity
FROM projects p
JOIN planning_events pe ON p.project_id = pe.project_id
JOIN technologies t ON p.technology_id = t.tech_id
JOIN locations l ON p.location_id = l.location_id
WHERE pe.event_type = 'Operational'
  AND pe.event_date >= CURDATE() - INTERVAL 1 YEAR
GROUP BY l.region, t.technology_type
ORDER BY recent_capacity DESC;

-- projects with outdated records, need review
SELECT p.project_id, p.site_name, p.record_last_updated, ds.status
FROM projects p
JOIN development_statuses ds USING (status_id)
WHERE p.record_last_updated < CURDATE() - INTERVAL 5 year
	AND ds.short_status IN ('Awaiting Construction', 'Under Construction')
ORDER BY p.record_last_updated DESC;

-- -------------------------- --
-- SOLAR			  		  --
-- -------------------------- --
-- use solar_projects temp table 

-- stats for mountings per region
SELECT
    l.region,
    SUM(sp.mounting_type_for_solar = 'ground') AS ground_mounting,
    SUM(sp.mounting_type_for_solar = 'roof') AS roof_mounting,
    SUM(sp.mounting_type_for_solar = 'floating') AS floating_mounting,
    SUM(sp.mounting_type_for_solar = 'Ground & Roof') AS ground_and_roof_mounting
FROM solar_projects sp
JOIN locations l ON sp.location_id = l.location_id
GROUP BY l.region;


-- avg solar site area and most common mountings per region

CREATE TEMPORARY TABLE solar_projects2
SELECT * FROM solar_projects;

WITH mounting_counts AS (
  SELECT
    l.region,
    sp.mounting_type_for_solar,
    COUNT(*) AS count_type,
    RANK() OVER (PARTITION BY l.region ORDER BY COUNT(*) DESC) AS rnk
  FROM solar_projects sp
  JOIN locations l ON sp.location_id = l.location_id
    AND sp.mounting_type_for_solar IS NOT NULL
  GROUP BY l.region, sp.mounting_type_for_solar
),
avg_area AS (
  SELECT
    l.region,
    AVG(sp2.solar_site_area_sqm) AS avg_site_area
  FROM solar_projects2 sp2
  JOIN locations l ON sp2.location_id = l.location_id
  GROUP BY l.region
)
SELECT 
  a.region,
  a.avg_site_area,
  m.mounting_type_for_solar AS most_common_mounting
FROM avg_area a
LEFT JOIN mounting_counts m ON a.region = m.region AND m.rnk = 1;


-- mounting types by their total capacity
SELECT
	mounting_type_for_solar,
    SUM(installed_capacity_mwelec) AS total_capacity,
    COUNT(project_id) AS project_count
FROM solar_projects
GROUP BY mounting_type_for_solar
ORDER BY total_capacity DESC;


-- most and least efficient solar sites
SELECT site_name,
       installed_capacity_mwelec,
       solar_site_area_sqm,
       installed_capacity_mwelec / NULLIF(solar_site_area_sqm, 0) AS capacity_per_sqm
FROM solar_projects
ORDER BY capacity_per_sqm DESC
LIMIT 20;


-- -------------------------- --
-- WIND			  			  --
-- -------------------------- --

-- avg number and height of turbines per region
SELECT
	l.region,
    AVG(wp.no_of_turbines),
    AVG(wp.height_of_turbines_m)
FROM wind_projects wp
JOIN locations l ON wp.location_id = l.location_id
GROUP BY l.region
;

SELECT *
FROM wind_projects wp
ORDER BY installed_capacity_mwelec DESC;



-- Show capacity and project count for each wind type
SELECT 
    wind_type,
    COUNT(*) AS project_count,
    SUM(installed_capacity_mwelec) AS total_capacity
FROM wind_projects
GROUP BY wind_type
ORDER BY total_capacity DESC;

-- null values regarding WIND specs
SELECT
	l.region,
    COUNT(CASE WHEN wp.no_of_turbines IS NULL THEN 1 END) as null_no_turbines,
    COUNT(CASE WHEN wp.height_of_turbines_m IS NULL THEN 1 END) as null_height_turbines
FROM wind_projects wp
JOIN locations l ON wp.location_id = l.location_id
GROUP BY l.region;

