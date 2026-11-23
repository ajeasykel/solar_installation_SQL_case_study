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
)
SELECT
mc.MonthStart,
DATENAME(MONTH, mc.MonthStart) AS MonthName,
YEAR(mc.MonthStart) AS InstallYear,
CASE
WHEN mc.MonthStart = DATEFROMPARTS(2024, 9, 1) THEN 'Partial launch month'
ELSE NULL
END AS PeriodNote,
COALESCE(mt.TotalInstalledUnits, 0) AS TotalInstalledUnits,
COALESCE(mt.InstalledCapacityKW, 0) AS InstalledCapacityKW
FROM MonthCalendar AS mc
LEFT JOIN MonthlyTotals AS mt
ON mt.MonthStart = mc.MonthStart
ORDER BY mc.MonthStart
OPTION (MAXRECURSION 100);

WITH WeekCalendar AS
(
SELECT DATEFROMPARTS(2024, 9, 30) AS WeekStartMonday
UNION ALL
SELECT DATEADD(DAY, 7, WeekStartMonday)
FROM WeekCalendar
WHERE WeekStartMonday < DATEFROMPARTS(2026, 10, 26)
),
WeeklyTotals AS
(
SELECT
DATEADD(
DAY,
-(DATEDIFF(DAY, DATEFROMPARTS(1900, 1, 1), i.install_date) % 7),
i.install_date
) AS WeekStartMonday,
COUNT(i.installation_id) AS TotalInstalledUnits,
SUM(sp.capacity_kw) AS InstalledCapacityKW
FROM dbo.installations AS i
INNER JOIN dbo.solar_packages AS sp
ON sp.package_id = i.package_id
WHERE i.status = 'Completed'
AND i.install_date >= DATEFROMPARTS(2024, 9, 30)
AND i.install_date <  DATEFROMPARTS(2026, 11, 1)
GROUP BY DATEADD(
DAY,
-(DATEDIFF(DAY, DATEFROMPARTS(1900, 1, 1), i.install_date) % 7),
i.install_date
)
)
SELECT
wc.WeekStartMonday,
YEAR(DATEADD(DAY, 3, wc.WeekStartMonday)) AS ISOYear,
DATEPART(ISO_WEEK, wc.WeekStartMonday) AS ISOWeekNumber,
COALESCE(wt.TotalInstalledUnits, 0) AS TotalInstalledUnits,
COALESCE(wt.InstalledCapacityKW, 0) AS InstalledCapacityKW
FROM WeekCalendar AS wc
LEFT JOIN WeeklyTotals AS wt
ON wt.WeekStartMonday = wc.WeekStartMonday
ORDER BY wc.WeekStartMonday
OPTION (MAXRECURSION 200);