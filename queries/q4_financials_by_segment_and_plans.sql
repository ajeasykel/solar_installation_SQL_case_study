WITH PaymentTotals AS
(
SELECT
installation_id,
SUM(amount_paid) AS TotalPaid
FROM dbo.payments
WHERE payment_date <= CONVERT(date, '20261031')
GROUP BY installation_id
)
SELECT
ct.segment AS Segment,
fp.plan_name AS FinancingPlan,
fp.months AS PlanMonths,
COUNT(*) AS InstallationCount,
SUM(i.list_price - i.discount_amount) AS NetPrice,
SUM(i.discount_amount) AS TotalDiscounts,
SUM(i.finance_charge) AS FinanceIncome,
SUM(COALESCE(pt.TotalPaid, 0)) AS Collected,
SUM(i.total_contract_value - COALESCE(pt.TotalPaid, 0)) AS Outstanding
FROM dbo.installations AS i
INNER JOIN dbo.customers AS c
ON c.customer_id = i.customer_id
INNER JOIN dbo.customer_types AS ct
ON ct.customer_type_id = c.customer_type_id
INNER JOIN dbo.financing_plans AS fp
ON fp.plan_id = i.financing_plan_id
LEFT JOIN PaymentTotals AS pt
ON pt.installation_id = i.installation_id
WHERE i.status = 'Completed'
GROUP BY
ct.segment,
fp.plan_id,
fp.plan_name,
fp.months
ORDER BY
ct.segment,
fp.months,
fp.plan_name;