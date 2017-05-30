set nocount on;
--- ^Gets rid of messages in output

--- Declare our variables based on input from sqlcmd -v 
DECLARE @SiteID NVARCHAR(1000) = 'aces.dbo.aces_bpi_csp'
DECLARE @loadRevisionTable NVARCHAR(1000) = CONCAT(@SiteID, '_load_fcst_r')
DECLARE @loadFcstTable NVARCHAR(1000) = CONCAT(@SiteID, '_load_fcst')
DECLARE @myDate NVARCHAR(30) = CONVERT(varchar(8), GETDATE(), 112) 
DECLARE @daysOffset INT = 1	
DECLARE @hrStop INT = 9	


EXEC 
('
---get the load_fcst_r table for just todays date then toss them into temp table

if object_ID (''tempdb..#UnionAll'')is NOT NULL drop table #UnionAll
select date, time, load_fcst, revision
	into #UnionAll
	from  ' +@loadRevisionTable +' 
	where date = ' +@myDate +' 

---
if object_ID (''tempdb..#MaxDateTime'')is NOT NULL drop table #MaxDateTime
select	date, time, max(revision) as maxRevisionTime
	into #MaxDateTime
	from #UnionAll
	where revision <  DATEADD(hour,'+@hrStop+', DATEDIFF(DAY, '+@daysOffset+', GETDATE()))
	group by date, time
	having max(revision) < DATEADD(hour, '+@hrStop+', DATEDIFF(DAY, '+@daysOffset+', GETDATE()))

---
if object_ID (''tempdb..#MightMissHours'')is NOT NULL drop table #MightMissHours
select mdt.date, mdt.time, u.load_fcst, mdt.maxRevisionTime
	into #MightMissHours
	from #MaxDateTime mdt
	join #UnionAll u
	on mdt.date = u.date and mdt.time = u.time and mdt.maxRevisionTime = u.revision
	order by 1, 2

--- rinse and repeat above for forecasts made today (instead of yesterday), notice no offset
if object_ID (''tempdb..#CurrentFcst'')is NOT NULL drop table #CurrentFcst
select	date, time, max(revision) as maxRevisionTime
	into #CurrentFcst
	from #UnionAll
	where revision <  DATEADD(hour, '+@hrStop+', DATEDIFF(DAY, 0, GETDATE()))
	group by date, time
	having max(revision) < DATEADD(hour, '+@hrStop+', DATEDIFF(DAY, 0, GETDATE()))

---
if object_ID (''tempdb..#MightMissHours2'')is NOT NULL drop table #MightMissHours2
select mdt.date, mdt.time, u.load_fcst, mdt.maxRevisionTime
	into #MightMissHours2
	from #CurrentFcst mdt
	join #UnionAll u
	on mdt.date = u.date and mdt.time = u.time and mdt.maxRevisionTime = u.revision
	order by 1, 2
--- we do make the assumption that forecasts are complete series...to make this script better we would create a custom time series instead
--- combine todays before 9 AM forecasts with yesterdays on date,time, take the difference between them
if object_ID (''tempdb..#NoSums'')is NOT NULL drop table #NoSums
select a.date, a.time, Round(a.load_fcst,2) as "current_load_fcst", Round(m.load_fcst,2) AS "original_load_fcst" ,  Round(a.load_fcst-m.load_fcst,2) AS "Difference", Abs(Round(a.load_fcst-m.load_fcst,2)) as "Absolute_Difference"
into #NoSums
from #MightMissHours2 a
left join #MightMissHours m
on a.date = m.date and a.time = m.time
order by 1, 2



select * from
        (
        select cast(date as Varchar) as date, time, current_load_fcst, original_load_fcst, Difference, Absolute_Difference
        from #NoSums
        UNION
        (select ''Total'' as date, Null as time, 
            Sum(current_load_fcst) As current_load_fcst, 
            Sum(original_load_fcst) As original_load_fcst, 
            Sum(Difference) As Difference,
			Sum(Absolute_Difference) as Absolute Difference
        from #NoSums) 
        ) a

')
--- optional, a.maxRevisionTime AS "todaysRtime", m.maxRevisionTime AS "yesterdaysRtime" to the end of line 58 to dubcheck reivison times

