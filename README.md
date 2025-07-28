# renewable_energy_sql_project

This project uses the UK Government's Renewable Energy Planning Dataset (REPD) to explore trends in renewable energy projects by region, technology, status, and capacity. 

🔧 **Tools:** SQL (for data modeling & queries), Tableau (for visualisation)


📁 **Files included:**

- Renewable Energy Planning Dataset (REPD) I found on https://www.gov.uk/government/publications/renewable-energy-planning-database-monthly-extract and perfomed light cleaning on(converted to UTF-8 and handled misaligned values)

- DDL/DML script (schema_and_load.sql) to create fact and dimension tables from the csv

- EER diagram (for visual representation of the schema used)

- queries.sql and views.sql files 

-  Tableau dashboard - `repd_insights.twbx` 

📊 **Tableau Workbook Key features:**
- Installed and planned capacity by region and tech
- Operator-level insights
- Geographic and temporal trends

🗒️**SQL Tables:**
Table: locations (dimension)
* location_id
* county
* region
* country
* post_code
* x_coordinate
* y_coordinate

Table: development_statuses (dimension)
* status_id
* status
* short_status

Table: technologies (dimension)
* tech_id
* technology_type
* storage_type

Table: operators (dimension)
* operator_id
* operator_name

Table: projects (fact table)
* project_id
* site_name
* installed_capacity_mwelec
* record_last_updated
* no_of_turbines
* height_of_turbines_m
* mounting_type_for_solar
* solar_site_area_sqm
* planning_authority
* operator_id
* technology_id
* location_id
* status_id

Table: planning_events
* event_id
* project_id
* event_type
* event_date


Next steps for the project:
 ML forecasting / Adding external_data (UK emissions, previous and future UK REPD)/ Analysis over time...
