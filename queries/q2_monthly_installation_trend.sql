WITH MonthCalendar AS
(
SELECT DATEFROMPARTS(2024, 9, 1) AS MonthStart
UNION ALL
SELECT DATEADD(MONTH, 1, MonthStart)
FROM MonthCalendar
WHERE MonthStart < DATEFROMPARTS(2026, 10, 1)
),
MonthlyTotals AS
(
SELECT
DATEFROMPARTS(YEAR(i.install_date), MONTH(i.install_date), 1) AS MonthStart,
COUNT(i.installation_id) AS TotalInstalledUnits,
SUM(sp.capacity_kw) AS InstalledCapacityKW
FROM dbo.installations AS i
INNER JOIN dbo.solar_packages AS sp
ON sp.package_id = i.package_id
WHERE i.status = 'Completed'
AND i.install_date >= DATEFROMPARTS(2024, 9, 1)
AND i.install_date <  DATEFROMPARTS(2026, 11, 1)
GROUP BY DATEFROMPARTS(YEAR(i.install_date), MONTH(i.install_date), 1)
),
MonthlyData AS
(
SELECT
mc.MonthStart,
COALESCE(mt.TotalInstalledUnits, 0) AS TotalInstalledUnits,
COALESCE(mt.InstalledCapacityKW, 0) AS InstalledCapacityKW,
ROW_NUMBER() OVER (ORDER BY mc.MonthStart) AS MonthSequence
FROM MonthCalendar AS mc
LEFT JOIN MonthlyTotals AS mt
ON mt.MonthStart = mc.MonthStart
),
MonthlyWindows AS
(
SELECT
MonthStart,
TotalInstalledUnits,
InstalledCapacityKW,
MonthSequence,
LAG(InstalledCapacityKW) OVER (ORDER BY MonthStart) AS PreviousCapacityKW,
SUM(InstalledCapacityKW) OVER
(
ORDER BY MonthStart
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
) AS RunningCapacityKW,
AVG(CAST(InstalledCapacityKW AS decimal(18, 2))) OVER
(
ORDER BY MonthStart
ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
) AS ThreeMonthMovingAverageRaw
FROM MonthlyData
)
SELECT
MonthStart,
DATENAME(MONTH, MonthStart) AS MonthName,
YEAR(MonthStart) AS InstallYear,
CASE
WHEN MonthStart = DATEFROMPARTS(2024, 9, 1) THEN 'Partial launch month'
ELSE NULL
END AS PeriodNote,
TotalInstalledUnits,
InstalledCapacityKW,
PreviousCapacityKW,
CASE
WHEN PreviousCapacityKW IS NULL OR PreviousCapacityKW = 0 THEN NULL
ELSE CAST(ROUND(100.0 * (InstalledCapacityKW - PreviousCapacityKW)
/NULLIF(PreviousCapacityKW, 0), 2) AS decimal(12, 2))
END AS MoMChangePct,
RunningCapacityKW,
CASE
WHEN MonthSequence < 3 THEN NULL
ELSE CAST(ROUND(ThreeMonthMovingAverageRaw, 1) AS decimal(18, 1))
END AS ThreeMonthMovingAverageKW
FROM MonthlyWindows
ORDER BY MonthStart
OPTION (MAXRECURSION 100);