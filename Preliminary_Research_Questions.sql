--List the top 3 and bottom 3 makers for the fiscal years 2023 and 2024 in terms of the number of 2-wheelers sold.
--Top 3
with cte as(
select *,row_number() over(partition by YEAR(date) order by electric_vehicles_sold) as top3
from electric_vehicle_sales_by_makers 
where YEAR(date) in (2023,2024) and vehicle_category = '2-Wheelers')
select YEAR(date) as year,maker,electric_vehicles_sold,top3
from cte
where top3 <= 3;



--Bottom 3
with cte as(
select *,row_number() over(partition by YEAR(date) order by electric_vehicles_sold desc) as bottom3
from electric_vehicle_sales_by_makers 
where YEAR(date) in (2023,2024) and vehicle_category = '2-Wheelers')
select YEAR(date) as year,maker,electric_vehicles_sold,bottom3
from cte
where bottom3 <= 3;



---Identify the top 5 states with the highest penetration rate in 2-wheeler and 4-wheeler EV sales in FY 2024.

update electric_vehicle_sales_by_state
set state = 'Andaman & Nicobar Island'
where state = 'Andaman & Nicobar';

select top 5 state,SUM(electric_vehicles_sold) as electric_vehicles_sold ,SUM(total_vehicles_sold) as total_vehicles_sold,
SUM(electric_vehicles_sold)*100/SUM(total_vehicles_sold) as Penetration_Rate
from electric_vehicle_sales_by_state
where YEAR(date) = 2024 
group by state
order by Penetration_Rate desc;


--List the states with negative penetration (decline) in EV sales from 2022 to 2024?

select state,SUM(electric_vehicles_sold) as electric_vehicles_sold ,SUM(total_vehicles_sold) as total_vehicles_sold,
SUM(electric_vehicles_sold)*100/SUM(total_vehicles_sold) as Penetration_Rate
from electric_vehicle_sales_by_state
where YEAR(date) between 2022 and 2024 
group by state
order by Penetration_Rate,electric_vehicles_sold;



--How do the EV sales and penetration rates in Delhi compare to Karnataka for 2024?

with cte_delhi as(
select state,vehicle_category,
sum(electric_vehicles_sold) as electric_vehicles_sold,sum(total_vehicles_sold) as total_vehicles_sold,
SUM(electric_vehicles_sold)*100/SUM(total_vehicles_sold) as Penetration_Rate
from electric_vehicle_sales_by_state
where YEAR(date) = 2024 and state ='Delhi'
group by state,vehicle_category),
cte_Karnataka as(
select state,vehicle_category,
sum(electric_vehicles_sold) as electric_vehicles_sold,sum(total_vehicles_sold) as total_vehicles_sold,
SUM(electric_vehicles_sold)*100/SUM(total_vehicles_sold) as Penetration_Rate
from electric_vehicle_sales_by_state
where YEAR(date) = 2024 and state ='Karnataka'
group by state,vehicle_category)
select a.state,a.vehicle_category,a.electric_vehicles_sold,a.total_vehicles_sold,a.Penetration_Rate,
b.state,b.vehicle_category,b.electric_vehicles_sold,b.total_vehicles_sold,b.Penetration_Rate
from cte_delhi a join cte_Karnataka b
on a.vehicle_category = b.vehicle_category;


--List down the compounded annual growth rate (CAGR) in 4-wheeler units for the top 5 makers from 2022 to 2024

select * from electric_vehicle_sales_by_makers;

with cte as(
select *,sum(electric_vehicles_sold) over(partition by maker order by maker,date) as growth_rate
from electric_vehicle_sales_by_makers
where vehicle_category = '4-Wheelers' and YEAR(date) between 2022 and 2024
),cte1 as(
select maker, MIN(growth_rate) as Beginning_Value ,MAX(growth_rate) as Ending_Value
from cte
where electric_vehicles_sold != 0
group by maker)
select top 5 maker,(power((Ending_Value/Beginning_Value),0.33))-1 as CAGR
from cte1
order by CAGR desc;


---List down the top 10 states that had the highest compounded annual growth rate (CAGR) from 2022 to 2024 in total vehicles sold

with cte as(
select *,SUM(total_vehicles_sold) over(partition by state order by state,date) as running_sales
from electric_vehicle_sales_by_state
where  YEAR(date) between 2022 and 2024)
,cte1 as(
select state,MIN(running_sales) as Beginning_Value, MAX(running_sales) as Ending_Value
from cte
group by state)
select top 10 state,(power((Ending_Value/Beginning_Value),0.33))-1 as CAGR
from cte1
order by CAGR desc;


---What are the peak and low season months for EV sales based on the data from 2022 to 2024?

---top 3 best months where sales are peak
with cte_top as(
select *,DATEPART(MONTH,date) as months
from electric_vehicle_sales_by_makers
where YEAR(date) between 2022 and 2024)
select top 3 months,SUM(electric_vehicles_sold) as sales
from cte_top
group by months
order by sales desc;

---bottom 3 best months where sales are not peak
with cte_bottom as(
select *,DATEPART(MONTH,date) as months
from electric_vehicle_sales_by_makers
where YEAR(date) between 2022 and 2024)
select top 3 months,SUM(electric_vehicles_sold) as sales
from cte_bottom
group by months
order by sales;



--What is the projected number of EV sales (including 2-wheelers and 4-wheelers) 
--for the top 10 states by penetration rate in 2030, based on the 
--compounded annual growth rate (CAGR) from previous years

with cte as(
select state,vehicle_category,electric_vehicles_sold,total_vehicles_sold,
SUM(electric_vehicles_sold) over(partition by state order by date) as sales
from electric_vehicle_sales_by_state
),cte1 as(
select state,MIN(sales) as Beginning_Value ,MAX(sales) as Ending_Value,
SUM(electric_vehicles_sold)*100.0/SUM(total_vehicles_sold) as Penetration_Rate
from cte
where sales != 0
group by state),cte2 as(
select state, (power(cast(Ending_Value as decimal)/Beginning_Value,0.44))-1 as cagr,  ---Cagr calculated on the basis of previous 4 years
Penetration_Rate
from cte1)
select top 10 state,cagr,Penetration_Rate,cagr*Penetration_Rate*0.6 as growth_by_2030
from cte2
order by growth_by_2030 desc;


--Estimate the revenue growth rate of 4-wheeler and 2-wheelers EVs in India for 2022 vs 2024 and 2023 vs 2024, assuming an average unit price. 
--2 Wheelers average price   $85,000
--4 Wheelers average price   $15,00,000

--Revenue growth rate of 4-wheeler and 2-wheelers EVs in India for 2022 vs 2024
with sales_2022 as(
select year(date) as yearss,vehicle_category,
case when vehicle_category = '2-Wheelers' then SUM(cast(electric_vehicles_sold as bigint) * 85000) 
     when vehicle_category = '4-Wheelers' then SUM(cast(electric_vehicles_sold as bigint) * 1500000) end as sales
from electric_vehicle_sales_by_state
where YEAR(date) = 2022
group by year(date),vehicle_category),
sales_2024 as(
select year(date) as yearss,vehicle_category,
case when vehicle_category = '2-Wheelers' then SUM(cast(electric_vehicles_sold as bigint) * 85000)
     when vehicle_category = '4-Wheelers' then SUM(cast(electric_vehicles_sold as bigint) * 1500000) end as sales
from electric_vehicle_sales_by_state
where YEAR(date) = 2024
group by year(date),vehicle_category)
select sales_2022.yearss,sales_2022.vehicle_category,sales_2022.sales,
	   sales_2024.yearss,sales_2024.vehicle_category,sales_2024.sales, sales_2024.sales-sales_2022.sales as revenue_growth
from sales_2022 join sales_2024 
on sales_2022.vehicle_category = sales_2024.vehicle_category;

--Revenue growth rate of 4-wheeler and 2-wheelers EVs in India for 2023 vs 2024
with sales_2023 as(
select year(date) as yearss,vehicle_category,
case when vehicle_category = '2-Wheelers' then SUM(cast(electric_vehicles_sold as bigint) * 85000) 
     when vehicle_category = '4-Wheelers' then SUM(cast(electric_vehicles_sold as bigint) * 1500000) end as sales
from electric_vehicle_sales_by_state
where YEAR(date) = 2023
group by year(date),vehicle_category),
sales_2024 as(
select year(date) as yearss,vehicle_category,
case when vehicle_category = '2-Wheelers' then SUM(cast(electric_vehicles_sold as bigint) * 85000)
     when vehicle_category = '4-Wheelers' then SUM(cast(electric_vehicles_sold as bigint) * 1500000) end as sales
from electric_vehicle_sales_by_state
where YEAR(date) = 2024
group by year(date),vehicle_category)
select sales_2023.yearss,sales_2023.vehicle_category,sales_2023.sales,
	   sales_2024.yearss,sales_2024.vehicle_category,sales_2024.sales, sales_2024.sales-sales_2023.sales as revenue_growth
from sales_2023 join sales_2024 
on sales_2023.vehicle_category = sales_2024.vehicle_category;

