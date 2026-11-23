WITH PaymentBySchedule AS
(
SELECT
schedule_id,
SUM(amount_paid) AS TotalPaid
FROM dbo.payments
WHERE payment_date <= CONVERT(date, '20261031')
GROUP BY schedule_id
),
OverdueInstallments AS
(
SELECT
ps.schedule_id,
ps.installation_id,
ps.installment_no,
ps.due_date,
ps.amount_due,
COALESCE(pbs.TotalPaid, 0) AS TotalPaid,
DATEDIFF(DAY, ps.due_date, CONVERT(date, '20261031')) AS DaysOverdue,
ps.amount_due - COALESCE(pbs.TotalPaid, 0) AS RemainingAmount,
CASE
WHEN DATEDIFF(DAY, ps.due_date, CONVERT(date, '20261031')) BETWEEN 1 AND 30 THEN '1-30 Days'
WHEN DATEDIFF(DAY, ps.due_date, CONVERT(date, '20261031')) BETWEEN 31 AND 60 THEN '31-60 Days'
WHEN DATEDIFF(DAY, ps.due_date, CONVERT(date, '20261031')) BETWEEN 61 AND 90 THEN '61-90 Days'
ELSE '91+ Days'
END AS AgeingBucket
FROM dbo.payment_schedule AS ps
LEFT JOIN PaymentBySchedule AS pbs
ON pbs.schedule_id = ps.schedule_id
WHERE ps.due_date < CONVERT(date, '20261031')
AND COALESCE(pbs.TotalPaid, 0) < ps.amount_due
)
SELECT
AgeingBucket,
COUNT(*) AS OverdueInstallments,
SUM(RemainingAmount) AS TotalRemainingAmount
FROM OverdueInstallments
GROUP BY AgeingBucket
ORDER BY MIN(DaysOverdue);

WITH DailyPayments AS
(
SELECT
installation_id,
payment_date,
SUM(amount_paid) AS PaidOnDate
FROM dbo.payments
WHERE payment_date <= CONVERT(date, '20261031')
GROUP BY installation_id, payment_date
),
CumulativePayments AS
(
SELECT
installation_id,
payment_date,
SUM(PaidOnDate) OVER(
PARTITION BY installation_id
ORDER BY payment_date
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
) AS CumulativePaid
FROM DailyPayments
),
FullPaymentDates AS
(
SELECT
i.installation_id,
MIN(cp.payment_date) AS FullPaymentDate
FROM dbo.installations AS i
INNER JOIN CumulativePayments AS cp
ON cp.installation_id = i.installation_id
WHERE i.status = 'Completed'
AND cp.CumulativePaid >= i.total_contract_value
GROUP BY i.installation_id
),
FinalDueDates AS
(
SELECT
installation_id,
MAX(due_date) AS FinalDueDate
FROM dbo.payment_schedule
GROUP BY installation_id
),
MaturedContracts AS
(
SELECT
i.installation_id,
i.financing_plan_id,
fdd.FinalDueDate,
fpd.FullPaymentDate
FROM dbo.installations AS i
INNER JOIN FinalDueDates AS fdd
ON fdd.installation_id = i.installation_id
LEFT JOIN FullPaymentDates AS fpd
ON fpd.installation_id = i.installation_id
WHERE i.status = 'Completed'
AND fdd.FinalDueDate <= CONVERT(date, '20261031')
)
SELECT
fp.plan_name AS FinancingPlan,
fp.months AS PlanMonths,
COUNT(mc.installation_id) AS MaturedContracts,
SUM(CASE WHEN mc.FullPaymentDate IS NOT NULL THEN 1 ELSE 0 END) AS FullyPaidContracts,
CAST(ROUND(100.0 * SUM(CASE WHEN mc.FullPaymentDate IS NOT NULL THEN 1 ELSE 0 END)
/NULLIF(COUNT(mc.installation_id), 0), 2) AS decimal(6, 2)) AS PercentMaturedContractsFullyPaid,
AVG(CAST(DATEDIFF(DAY, mc.FinalDueDate, mc.FullPaymentDate) AS decimal(10, 2)
)) AS AverageDaysFromFinalDueToPayment
FROM dbo.financing_plans AS fp
LEFT JOIN MaturedContracts AS mc
ON mc.financing_plan_id = fp.plan_id
GROUP BY fp.plan_id, fp.plan_name, fp.months
ORDER BY fp.months, fp.plan_name;