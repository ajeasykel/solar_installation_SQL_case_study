WITH RollupRows AS
(
SELECT
COUNT(*) AS InstalledSystems,
SUM(sp.capacity_kw) AS InstalledCapacityKW,
l.zone,
l.state,
sp.system_type,
GROUPING(l.zone) AS GroupingZone,
GROUPING(l.state) AS GroupingState,
GROUPING(sp.system_type) AS GroupingSystemType,
CASE
WHEN GROUPING(l.zone) = 1
AND GROUPING(l.state) = 1
AND GROUPING(sp.system_type) = 1 THEN 'Grand Total'
WHEN GROUPING(l.zone) = 0
AND GROUPING(l.state) = 1
AND GROUPING(sp.system_type) = 1 THEN 'Zone Subtotal'
WHEN GROUPING(l.zone) = 0
AND GROUPING(l.state) = 0
AND GROUPING(sp.system_type) = 1 THEN 'State Subtotal'
WHEN GROUPING(l.zone) = 1
AND GROUPING(l.state) = 1
AND GROUPING(sp.system_type) = 0 THEN 'System Type Total'
ELSE 'Detail'
END AS RowCategory
FROM dbo.installations AS i
INNER JOIN dbo.customers AS c
ON c.customer_id = i.customer_id
INNER JOIN dbo.locations AS l
ON l.location_id = c.location_id
INNER JOIN dbo.solar_packages AS sp
ON sp.package_id = i.package_id
WHERE i.status = 'Completed'
GROUP BY GROUPING SETS
(
(l.zone, l.state, sp.system_type),
(l.zone, l.state),
(l.zone),
(),
(sp.system_type)
)
),
RowsWithTotals AS
(
SELECT
rr.*,
MAX(CASE WHEN RowCategory = 'Grand Total' THEN InstalledSystems END)
OVER () AS GrandTotalSystems,
MAX(CASE WHEN RowCategory = 'Grand Total' THEN InstalledCapacityKW END)
OVER () AS GrandTotalCapacityKW,
MAX(CASE WHEN RowCategory = 'State Subtotal' THEN InstalledSystems END)
OVER (PARTITION BY zone, state) AS StateSubtotalSystems,
MAX(CASE WHEN RowCategory = 'State Subtotal' THEN InstalledCapacityKW END)
OVER (PARTITION BY zone, state) AS StateSubtotalCapacityKW,
MAX(CASE WHEN RowCategory = 'Zone Subtotal' THEN InstalledSystems END)
OVER (PARTITION BY zone) AS ZoneSubtotalSystems,
MAX(CASE WHEN RowCategory = 'Zone Subtotal' THEN InstalledCapacityKW END)
OVER (PARTITION BY zone) AS ZoneSubtotalCapacityKW
FROM RollupRows AS rr
)
SELECT
CASE WHEN GroupingZone = 1 THEN 'All zones' ELSE zone END AS Zone,
CASE WHEN GroupingState = 1 THEN 'All states' ELSE state END AS State,
CASE WHEN GroupingSystemType = 1 THEN 'All system types' ELSE system_type END AS SystemType,
RowCategory,
InstalledSystems,
InstalledCapacityKW,
CAST(ROUND(100.0 * InstalledSystems / NULLIF(GrandTotalSystems, 0), 2) AS decimal(10, 2))
AS PercentOfGrandTotalSystems,
CAST(ROUND(100.0 * InstalledCapacityKW / NULLIF(GrandTotalCapacityKW, 0), 2) AS decimal(10, 2))
AS PercentOfGrandTotalCapacity,
CAST(ROUND(100.0 * InstalledSystems
/NULLIF(
CASE
WHEN RowCategory = 'Detail' THEN StateSubtotalSystems
WHEN RowCategory = 'State Subtotal' THEN ZoneSubtotalSystems
ELSE GrandTotalSystems
END,
0), 2) AS decimal(10, 2)) AS PercentWithinParentSystems,
CAST(ROUND(100.0 * InstalledCapacityKW
/NULLIF(
CASE
WHEN RowCategory = 'Detail' THEN StateSubtotalCapacityKW
WHEN RowCategory = 'State Subtotal' THEN ZoneSubtotalCapacityKW
ELSE GrandTotalCapacityKW
END, 0), 2) AS decimal(10, 2)) AS PercentWithinParentCapacity
FROM RowsWithTotals
ORDER BY
CASE
WHEN RowCategory IN ('System Type Total', 'Grand Total') THEN 1 ELSE 0 END,
zone,
CASE WHEN RowCategory = 'Zone Subtotal' THEN 1 ELSE 0 END,
state,
CASE WHEN RowCategory = 'State Subtotal' THEN 1 ELSE 0 END,
CASE WHEN RowCategory = 'Grand Total' THEN 1 ELSE 0 END,
system_type;