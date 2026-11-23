/* =====================================================================
   SunGrid Nigeria | Solar installer database (FICTIONAL, SYNTHETIC DATA)
   Script 01: create the database, tables, keys and constraints.
   Target: SQL Server 2016 or later, run in SSMS. Re-running this script
   drops and recreates every table, so it also works as a reset.
   Azure SQL Database users: create the database in the portal, connect to it,
   and delete the CREATE DATABASE / USE lines below.
   ===================================================================== */
IF DB_ID(N'SunGridNigeria') IS NULL CREATE DATABASE SunGridNigeria;
GO
USE SunGridNigeria;
GO

-- Drop in reverse dependency order so the script can be re-run
DROP TABLE IF EXISTS dbo.maintenance_tickets;
DROP TABLE IF EXISTS dbo.monthly_generation;
DROP TABLE IF EXISTS dbo.payments;
DROP TABLE IF EXISTS dbo.payment_schedule;
DROP TABLE IF EXISTS dbo.installations;
DROP TABLE IF EXISTS dbo.leads;
DROP TABLE IF EXISTS dbo.customers;
DROP TABLE IF EXISTS dbo.marketing_spend;
DROP TABLE IF EXISTS dbo.installer_teams;
DROP TABLE IF EXISTS dbo.financing_plans;
DROP TABLE IF EXISTS dbo.solar_packages;
DROP TABLE IF EXISTS dbo.energy_prices;
DROP TABLE IF EXISTS dbo.energy_sources;
DROP TABLE IF EXISTS dbo.marketing_channels;
DROP TABLE IF EXISTS dbo.customer_types;
DROP TABLE IF EXISTS dbo.locations;
GO

/* ---------- reference tables ---------- */
CREATE TABLE dbo.locations (
    location_id   INT         NOT NULL CONSTRAINT PK_locations PRIMARY KEY,
    state         VARCHAR(30) NOT NULL,
    city          VARCHAR(40) NOT NULL,
    zone          VARCHAR(20) NOT NULL
);

CREATE TABLE dbo.customer_types (
    customer_type_id INT         NOT NULL CONSTRAINT PK_customer_types PRIMARY KEY,
    segment          VARCHAR(20) NOT NULL CONSTRAINT CK_customer_types_segment CHECK (segment IN ('Residential','Business')),
    type_name        VARCHAR(40) NOT NULL
);

CREATE TABLE dbo.marketing_channels (
    channel_id   INT         NOT NULL CONSTRAINT PK_marketing_channels PRIMARY KEY,
    channel_name VARCHAR(50) NOT NULL,
    channel_type VARCHAR(20) NOT NULL
);

CREATE TABLE dbo.energy_sources (
    energy_source_id INT          NOT NULL CONSTRAINT PK_energy_sources PRIMARY KEY,
    source_name      VARCHAR(30)  NOT NULL,
    co2_kg_per_kwh   DECIMAL(6,3) NOT NULL   -- illustrative emission factor
);

CREATE TABLE dbo.energy_prices (
    price_id         INT           NOT NULL CONSTRAINT PK_energy_prices PRIMARY KEY,
    energy_source_id INT           NOT NULL CONSTRAINT FK_energy_prices_source REFERENCES dbo.energy_sources(energy_source_id),
    effective_from   DATE          NOT NULL,
    cost_per_kwh     DECIMAL(10,2) NOT NULL,  -- NGN per kWh, illustrative; valid until the next effective_from
    CONSTRAINT UQ_energy_prices UNIQUE (energy_source_id, effective_from)
);

CREATE TABLE dbo.solar_packages (
    package_id   INT           NOT NULL CONSTRAINT PK_solar_packages PRIMARY KEY,
    package_name VARCHAR(60)   NOT NULL,
    capacity_kw  DECIMAL(7,1)  NOT NULL CONSTRAINT CK_packages_capacity CHECK (capacity_kw > 0),
    battery_kwh  DECIMAL(7,1)  NOT NULL CONSTRAINT CK_packages_battery CHECK (battery_kwh >= 0),
    system_type  VARCHAR(20)   NOT NULL,
    list_price   DECIMAL(14,2) NOT NULL,
    unit_cost    DECIMAL(14,2) NOT NULL
);

CREATE TABLE dbo.financing_plans (
    plan_id      INT          NOT NULL CONSTRAINT PK_financing_plans PRIMARY KEY,
    plan_name    VARCHAR(40)  NOT NULL,
    months       INT          NOT NULL,       -- number of monthly instalments after the deposit (0 = cash)
    deposit_pct  DECIMAL(5,2) NOT NULL,
    interest_pct DECIMAL(5,2) NOT NULL        -- flat finance charge on the net price
);

CREATE TABLE dbo.installer_teams (
    team_id          INT         NOT NULL CONSTRAINT PK_installer_teams PRIMARY KEY,
    team_name        VARCHAR(50) NOT NULL,
    base_location_id INT         NOT NULL CONSTRAINT FK_teams_location REFERENCES dbo.locations(location_id)
);

CREATE TABLE dbo.marketing_spend (
    spend_id      INT           NOT NULL CONSTRAINT PK_marketing_spend PRIMARY KEY,
    channel_id    INT           NOT NULL CONSTRAINT FK_spend_channel REFERENCES dbo.marketing_channels(channel_id),
    spend_month   DATE          NOT NULL,     -- first day of the month
    amount_spent  DECIMAL(14,2) NOT NULL,
    CONSTRAINT UQ_marketing_spend UNIQUE (channel_id, spend_month)
);

/* ---------- customers and leads ---------- */
CREATE TABLE dbo.customers (
    customer_id            INT         NOT NULL CONSTRAINT PK_customers PRIMARY KEY,
    customer_code          VARCHAR(12) NOT NULL CONSTRAINT UQ_customers_code UNIQUE,
    customer_type_id       INT         NOT NULL CONSTRAINT FK_customers_type REFERENCES dbo.customer_types(customer_type_id),
    location_id            INT         NOT NULL CONSTRAINT FK_customers_location REFERENCES dbo.locations(location_id),
    acquisition_channel_id INT         NOT NULL CONSTRAINT FK_customers_channel REFERENCES dbo.marketing_channels(channel_id),
    prev_energy_source_id  INT         NOT NULL CONSTRAINT FK_customers_prev_source REFERENCES dbo.energy_sources(energy_source_id),
    signup_date            DATE        NOT NULL
);

CREATE TABLE dbo.leads (
    lead_id          INT         NOT NULL CONSTRAINT PK_leads PRIMARY KEY,
    lead_date        DATE        NOT NULL,
    channel_id       INT         NOT NULL CONSTRAINT FK_leads_channel REFERENCES dbo.marketing_channels(channel_id),
    customer_type_id INT         NOT NULL CONSTRAINT FK_leads_type REFERENCES dbo.customer_types(customer_type_id),
    location_id      INT         NOT NULL CONSTRAINT FK_leads_location REFERENCES dbo.locations(location_id),
    lead_status      VARCHAR(12) NOT NULL CONSTRAINT CK_leads_status CHECK (lead_status IN ('Converted','Lost','Open')),
    customer_id      INT         NULL     CONSTRAINT FK_leads_customer REFERENCES dbo.customers(customer_id)  -- NULL unless converted
);

/* ---------- sales, finance, operations ---------- */
CREATE TABLE dbo.installations (
    installation_id      INT           NOT NULL CONSTRAINT PK_installations PRIMARY KEY,
    customer_id          INT           NOT NULL CONSTRAINT FK_install_customer REFERENCES dbo.customers(customer_id),
    package_id           INT           NOT NULL CONSTRAINT FK_install_package  REFERENCES dbo.solar_packages(package_id),
    financing_plan_id    INT           NOT NULL CONSTRAINT FK_install_plan     REFERENCES dbo.financing_plans(plan_id),
    team_id              INT           NOT NULL CONSTRAINT FK_install_team     REFERENCES dbo.installer_teams(team_id),
    install_date         DATE          NOT NULL,   -- scheduled date when status = 'Scheduled'
    status               VARCHAR(12)   NOT NULL CONSTRAINT CK_install_status CHECK (status IN ('Completed','Scheduled','Cancelled')),
    list_price           DECIMAL(14,2) NOT NULL,
    discount_amount      DECIMAL(14,2) NOT NULL,
    finance_charge       DECIMAL(14,2) NOT NULL,
    total_contract_value DECIMAL(14,2) NOT NULL    -- list_price - discount_amount + finance_charge
);

CREATE TABLE dbo.payment_schedule (
    schedule_id     INT           NOT NULL CONSTRAINT PK_payment_schedule PRIMARY KEY,
    installation_id INT           NOT NULL CONSTRAINT FK_schedule_install REFERENCES dbo.installations(installation_id),
    installment_no  INT           NOT NULL,        -- 0 = deposit / cash payment
    due_date        DATE          NOT NULL,
    amount_due      DECIMAL(14,2) NOT NULL,
    CONSTRAINT UQ_payment_schedule UNIQUE (installation_id, installment_no)
);

CREATE TABLE dbo.payments (
    payment_id      INT           NOT NULL CONSTRAINT PK_payments PRIMARY KEY,
    installation_id INT           NOT NULL CONSTRAINT FK_payments_install  REFERENCES dbo.installations(installation_id),
    schedule_id     INT           NOT NULL CONSTRAINT FK_payments_schedule REFERENCES dbo.payment_schedule(schedule_id),
    payment_date    DATE          NOT NULL,
    amount_paid     DECIMAL(14,2) NOT NULL CONSTRAINT CK_payments_amount CHECK (amount_paid > 0),
    payment_method  VARCHAR(20)   NOT NULL
);

CREATE TABLE dbo.monthly_generation (
    generation_id    INT           NOT NULL CONSTRAINT PK_monthly_generation PRIMARY KEY,
    installation_id  INT           NOT NULL CONSTRAINT FK_generation_install REFERENCES dbo.installations(installation_id),
    generation_month DATE          NOT NULL,       -- first day of the month
    kwh_generated    DECIMAL(12,2) NOT NULL,
    CONSTRAINT UQ_monthly_generation UNIQUE (installation_id, generation_month)
);

CREATE TABLE dbo.maintenance_tickets (
    ticket_id       INT           NOT NULL CONSTRAINT PK_maintenance_tickets PRIMARY KEY,
    installation_id INT           NOT NULL CONSTRAINT FK_tickets_install REFERENCES dbo.installations(installation_id),
    opened_date     DATE          NOT NULL,
    closed_date     DATE          NULL,            -- NULL = still open
    issue_type      VARCHAR(30)   NOT NULL,
    severity        VARCHAR(10)   NOT NULL,
    repair_cost     DECIMAL(12,2) NOT NULL,
    CONSTRAINT CK_tickets_dates CHECK (closed_date IS NULL OR closed_date >= opened_date)
);
GO

/* ---------- supporting indexes on the columns queries filter and join on ---------- */
CREATE INDEX IX_leads_lead_date            ON dbo.leads(lead_date);
CREATE INDEX IX_leads_channel              ON dbo.leads(channel_id);
CREATE INDEX IX_customers_type             ON dbo.customers(customer_type_id);
CREATE INDEX IX_installations_install_date ON dbo.installations(install_date) INCLUDE (status, package_id);
CREATE INDEX IX_installations_customer     ON dbo.installations(customer_id);
CREATE INDEX IX_schedule_installation      ON dbo.payment_schedule(installation_id);
CREATE INDEX IX_payments_installation      ON dbo.payments(installation_id);
CREATE INDEX IX_payments_schedule          ON dbo.payments(schedule_id);
CREATE INDEX IX_generation_installation    ON dbo.monthly_generation(installation_id);
CREATE INDEX IX_tickets_installation       ON dbo.maintenance_tickets(installation_id);
GO

PRINT 'SunGridNigeria schema created. Next: run scripts 02 to 05, then 06 to verify.';
