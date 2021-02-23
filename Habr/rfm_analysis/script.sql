--������� ��� rfm-�������
create function func_recency(days integer) returns integer as $$
    select case when days<90 then 1
           when (days>=90) and (days<=180) then 2
          else 3
          end;
$$ language sql;

create function func_frequency(transactions integer) returns integer as $$
    select case when transactions>50 then 1
           when (transactions>=10) and (transactions<=50) then 2
          else 3
          end;
$$ language sql;

create function func_monetary(amount integer) returns integer as $$
    select case when amount>10000 then 1
           when (amount>=1000) and (amount<=10000) then 2
          else 3
          end;
$$ language sql;

-- ������������ ��� ������
create function func_day_of_week(number_day integer) returns text as $$
    select case 
           when number_day = 1 then 'sunday'
           when number_day = 2 then 'monday'
           when number_day = 3 then 'tuesday'
           when number_day = 4 then 'wednesday'
           when number_day = 5 then 'thursday'
           when number_day = 6 then 'friday'
           when number_day = 7 then 'saturday'
          end;
$$ language sql;

-- rfm-������
select d3.*, d3.rfm_recency*100 + d3.rfm_frequency*10 + d3.rfm_monetary as rfm
from 
	(select d2.customerid,
			date('2011-11-01')- max(d2.invoicedate) as recency,
			cast(count(distinct(d2.invoiceno)) as integer) as frequency,
			cast(sum(d2.amount) as integer) as monetary,
			func_recency(date('2011-11-01')- max(d2.invoicedate)) as rfm_recency,
			func_frequency(cast(count(distinct(d2.invoiceno))as integer)) as rfm_frequency,
			func_monetary(cast(sum(d2.amount)as integer)) as rfm_monetary
	from
	    (select d.*, d.quantity * d.unitprice as amount
	     from public.dataset as d 
	     where d.invoicedate < date('2011-11-01')) as d2 
	group by d2.customerid
	order by d2.customerid) as d3;

-- ��������� ������� � ��������, ���������� ��������, ������� ���
select r.rfm, 
	   sum(r.monetary) as total_amount,
	   count(r.rfm) as count_customer,
	   cast(avg(r.monetary/r.frequency) as integer) as avg_check
from public.report_rfm_analysis as r 
group by r.rfm;

-- ��������� ������ �� ������� � ���������� � ������������� ���������
select d2.rfm,
		d2.country,
		cast(sum(d2.amount) as integer) as amount_country,
		round(cast(sum(d2.amount)/sum(sum(d2.amount))over(partition by d2.rfm)*100 as numeric),2) as percent_total_amount
from 
(select d.*, d.quantity * d.unitprice as amount, r.rfm 
	     from public.dataset as d left join 
	                               public.report_rfm_analysis as r on d.customerid = r.customerid 
	     where d.invoicedate < date('2011-11-01')) as d2
group by d2.rfm, d2.country
order by d2.rfm, sum(d2.amount)desc;

-- ���-3 ��� �� ������ ������ � ������� �������-������
select d4.rfm, d4.country, max(d4.top) as top_3_days
from 
	  (select d3.rfm, d3.country, string_agg(d3.day_of_week,', ')over(partition by d3.rfm, d3.country) as top
	   from 
		(select d2.rfm, d2.country, d2.day_of_week,sum(d2.amount) as total_amount,
		     row_number ()over(partition by d2.rfm, d2.country order by d2.rfm, d2.country, sum(d2.amount)desc)
		from 
		     (select r.rfm, 
		             d.country,	             
		             func_day_of_week(cast(to_char(d.invoicedate, 'D') as integer)) as day_of_week,
		             d.quantity * d.unitprice as amount
		      from public.dataset as d left join public.report_rfm_analysis as r on d.customerid = r.customerid
		      where d.invoicedate < date('2011-11-01')) as d2
		group by d2.rfm, d2.country, d2.day_of_week
		order by d2.rfm, d2.country, sum(d2.amount) desc) as d3
	  where d3.row_number <= 3) as d4
group by d4.rfm, d4.country