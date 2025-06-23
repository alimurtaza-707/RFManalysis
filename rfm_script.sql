SELECT * FROM rfm.retail_transactions;

select Location, count(CustomerID), Sum(Amount) as Revenue
from retail_transactions
group by Location
order by Revenue desc; -- can be plotted

select Category, count(CustomerID), Sum(Amount) as Revenue
from retail_transactions
group by Category
order by Revenue desc; -- can be plotted

select Payment_Method, count(CustomerID), Sum(Amount) as Revenue
from retail_transactions
group by Payment_Method
order by Revenue desc; -- can be plotted



with rfm as (
SELECT 
    CustomerID,
    SUM(Amount) AS MonetaryValue,
    COUNT(CustomerID) AS Frequency,
    ABS(timestampdiff(Month, MAX(Date), MIN(Date)))+1 AS months,
    MAX(Date) AS last_order_date,
    (SELECT MAX(Date) FROM retail_transactions) AS max_order_date,
    DATEDIFF((SELECT MAX(Date) FROM retail_transactions), MAX(Date)) AS Recency
FROM retail_transactions
GROUP BY CustomerID),


rfm_calcone as(
	select r.*,
    MonetaryValue/months as AvgMonetaryValue,
    Frequency/months as AvgFrequency
    from rfm r
),


-- RFM calculation with NTILE 
rfm_calc as
(
SELECT 
    r.*,
    NTILE(5) OVER (ORDER BY Recency DESC) AS rfm_recency,
    NTILE(5) OVER (ORDER BY AvgFrequency) AS rfm_frequency,
    NTILE(5) OVER (ORDER BY AvgMonetaryValue) AS rfm_monetary
FROM rfm_calcone r),


-- Final RFM score

rfm_score as (SELECT 
    *, 
    rfm_recency + rfm_frequency + rfm_monetary AS rfm_score
FROM rfm_calc),


segmented_rfm as (
select *,
CASE 
  WHEN rfm_score BETWEEN 13 AND 15 THEN 'Best Customers'
  WHEN rfm_score BETWEEN 11 AND 12 
       AND rfm_frequency >= 3 THEN 'Loyal Customers'
  WHEN rfm_score BETWEEN 11 AND 12 
       AND rfm_frequency < 3 THEN 'New Big Customers'
  WHEN rfm_score BETWEEN 9 AND 10 
       AND rfm_recency >= 3 THEN 'Potential Loyalists'
 WHEN rfm_score BETWEEN 9 AND 10 
       AND rfm_recency < 3 THEN 'Need Attention'
  WHEN rfm_score BETWEEN 7 AND 8 
       AND rfm_recency BETWEEN 2 AND 3 THEN 'Need Attention'
WHEN rfm_score BETWEEN 7 AND 8 
       AND rfm_recency >3 Then 'New small Customers'
  WHEN rfm_score BETWEEN 4 AND 7 
       AND rfm_recency <= 3 THEN 'Potential Churners'
WHEN rfm_score BETWEEN 4 AND 6 
       AND rfm_recency > 3 THEN 'New Small Customers'
  WHEN rfm_score < 4 THEN 'Lost Customers'
  ELSE 'Unclassified'
END AS rfm_segment
from rfm_score)


select 
	CustomerID, 
	Recency, 
    MonetaryValue,
	AvgFrequency, 
    AvgMonetaryValue,
	months, 
	last_order_date, 
	rfm_recency, 
	rfm_frequency, 
	rfm_monetary, 
	rfm_score, 
	rfm_segment
from segmented_rfm
where AvgMonetaryValue>0;