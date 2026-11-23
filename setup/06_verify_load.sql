/* SunGrid Nigeria | Script 06: verify the load.
   Every row in both result sets should say PASS. */
USE SunGridNigeria;
GO

-- 1. Row counts
SELECT t.table_name,
       t.expected_rows,
       c.actual_rows,
       CASE WHEN t.expected_rows = c.actual_rows THEN 'PASS' ELSE 'FAIL' END AS result
FROM (VALUES
    (N'locations', 17),
    (N'customer_types', 12),
    (N'marketing_channels', 7),
    (N'energy_sources', 3),
    (N'energy_prices', 9),
    (N'solar_packages', 14),
    (N'financing_plans', 5),
    (N'installer_teams', 8),
    (N'marketing_spend', 182),
    (N'customers', 4534),
    (N'leads', 14500),
    (N'installations', 4721),
    (N'payment_schedule', 41609),
    (N'payments', 24758),
    (N'monthly_generation', 42164),
    (N'maintenance_tickets', 1091)
) AS t(table_name, expected_rows)
JOIN (
    SELECT o.name AS table_name, SUM(p.rows) AS actual_rows
    FROM sys.objects o
    JOIN sys.partitions p ON p.object_id = o.object_id AND p.index_id IN (0, 1)
    WHERE o.type = 'U' AND SCHEMA_NAME(o.schema_id) = 'dbo'
    GROUP BY o.name
) AS c ON c.table_name = t.table_name
ORDER BY t.table_name;

-- 2. Control totals
SELECT x.check_name, x.expected_value, x.actual_value,
       CASE WHEN x.expected_value = x.actual_value THEN 'PASS' ELSE 'FAIL' END AS result
FROM (
    SELECT N'Completed installations' AS check_name, CAST(4277 AS DECIMAL(20,2)) AS expected_value,
           CAST((SELECT COUNT(*) FROM dbo.installations WHERE status = 'Completed') AS DECIMAL(20,2)) AS actual_value
    UNION ALL
    SELECT N'Sum of total_contract_value, completed (NGN)', CAST(35494110800.00 AS DECIMAL(20,2)),
           CAST((SELECT SUM(total_contract_value) FROM dbo.installations WHERE status = 'Completed') AS DECIMAL(20,2))
    UNION ALL
    SELECT N'Sum of amount_paid (NGN)', CAST(28247485301.57 AS DECIMAL(20,2)),
           CAST((SELECT SUM(amount_paid) FROM dbo.payments) AS DECIMAL(20,2))
    UNION ALL
    SELECT N'Sum of kwh_generated', CAST(40338762.42 AS DECIMAL(20,2)),
           CAST((SELECT SUM(kwh_generated) FROM dbo.monthly_generation) AS DECIMAL(20,2))
) AS x;
