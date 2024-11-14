
SQL history (all SQLs) - 
https://oracleagent.wordpress.com/2021/01/11/sql-history/


imp url - https://confluence.oraclecorp.com/confluence/display/SAAS/DBRM+and+DART+Corrective+Actions+Tracking#DBRMandDARTCorrectiveActionsTracking-DeployBlockingsessionMetrics(DBRMPlus)


Waits - 
-------

  set lines 500 pages 200
  select * from (
    select count(*), ROUND((RATIO_TO_REPORT(COUNT(*)) over())*100, 2) PCT, nvl(event, 'on cpu') event,inst_id 
      from gv$active_session_history 
     where sample_time >sysdate -1/24 
  group by nvl(event, 'on cpu'),inst_id 
  order by count(*) desc
  )
  where rownum<15;


-- Dibya 

col EVENT for a30
SELECT
NVL(ash.event,'CPU') event,
COUNT(1) sample_cnt,
ROUND(100 * ratio_to_report(COUNT(*)) over(), 2) event_sql_pct,
sql_id
FROM gv$active_session_history ash
WHERE 1=1
--and ash.sample_time between to_date'2024/04/25 09:00:00','yyyy/mm/dd hh24:mi:ss') and to_date('2024/04/25 11:00:00','yyyy/mm/dd hh24:mi:ss')
and sample_time > sysdate - interval '10' hour
GROUP BY event,sql_id
ORDER BY event_sql_pct desc
FETCH FIRST 10 ROWS ONLY;


select sql_id,event,count(*) from gv$session where wait_class <> 'Idle' and STATE = 'WAITING' and sql_id is not null group by event,sql_id order by 3 desc;



Average Active Session (AAS) - https://www.dba-scripts.com/scripts/diagnostic-and-tuning/oracle-active-session-history-ash/average-active-sessions-aas/

select round((count(ash.sample_id) / ((CAST(end_time.sample_time AS DATE) - CAST(start_time.sample_time AS DATE))*24*60*60)),2) as AAS
from
  (select min(sample_time) sample_time 
  from  gv$active_session_history ash 
  ) start_time,
  (select max(sample_time) sample_time
  from  v$active_session_history 
  ) end_time,
  gv$active_session_history ash
where ash.sample_time between start_time.sample_time and end_time.sample_time
group by end_time.sample_time,start_time.sample_time;


Average Active Session (AAS) instance wise - 

select INST_ID,round((count(ash.sample_id) / ((CAST(end_time.sample_time AS DATE) - CAST(start_time.sample_time AS DATE))*24*60*60)),2) as AAS
from
  (select min(sample_time) sample_time 
  from  gv$active_session_history ash 
  ) start_time,
  (select max(sample_time) sample_time
  from  gv$active_session_history 
  ) end_time,
  gv$active_session_history ash
where ash.sample_time between start_time.sample_time and end_time.sample_time
group by INST_ID,end_time.sample_time,start_time.sample_time;




HIGH NO OF VERSION COUNT:-  https://ermanarslan.blogspot.com/p/core-dba-scripts.html 

select * from 
   (
  select address, hash_value,sql_id,version_count,users_opening,users_executing,substr(sql_text,1,40) "SQL" 
    FROM v$sqlarea 
   WHERE version_count > 100 
   order by version_count desc
   )
  where rownum<=10;


blocker SQLs-
------

set lines 1000 pages 200
 col MIN(SAMPLE_TIME) for a25
 col MAX(SAMPLE_TIME) for a25
 col P1TEXT for a20
 col P2text for a20
 col EVENT for a30
 col BLOCKER for a15
 col P2 for 9999999999999999
 col P1 for 9999999999999999
 
 Select * from
 (
 select MIN(SAMPLE_TIME),MAX(SAMPLE_TIME),SQL_ID,EVENT,P1TEXT,P1,P2TEXT,P2,BLOCKING_INST_ID||'-'||BLOCKING_SESSION||'-'||BLOCKING_SESSION_SERIAL#  
 as BLOCKER,COUNT(DISTINCT SESSION_ID), count(1) 
 from gv$active_session_history 
 --where sample_time between to_date('18-03-2024 04:17:00','dd-mm-yyyy hh24:mi:ss') and to_date('18-03-2024 05:30:00','dd-mm-yyyy hh24:mi:ss')
 where sample_time >= sysdate - 1/24
 group by SQL_ID,EVENT,P1TEXT,P1,P2TEXT,P2,BLOCKING_INST_ID||'-'||BLOCKING_SESSION||'-'||BLOCKING_SESSION_SERIAL#  
 order by count(1) desc
 )
 Where  blocker <> '--' 
 --and sql_id='f0y010kctnxfr'
 and sql_id is not null
 and rownum<10;


set lines 500 pages 200
select * from (select sql_id,inst_id,event,count(*) from gv$active_session_history where sample_time >= sysdate-1/24 group by sql_id,inst_id,event order by 4 desc) where
rownum<=10;



TO CHECK THE PHV VALUE FOR THOSE ALREADY EXECUTIONS COMPLETED - Dibya
(provide by Dibya)
----------------------------------------------

MEMORY + AWR + STS

select 'MEMORY' location, sql_id,plan_hash_value,
sum(executions) execs,
round(sum(rows_processed)/sum(executions),2) avg_rows,
round(sum(cpu_time/1000000)/sum(executions),2) avg_cpu_time_secs,
round(sum(elapsed_time/1000000)/sum(executions),4) avg_ela_time_secs,
round(sum(user_io_wait_time/1000000)/sum(executions),2) avg_io_wait_secs,
round(sum(io_cell_offload_returned_bytes/1024/1024)/sum(executions),2) avg_offload_returned_mb,
round(sum(io_interconnect_bytes/1024/1024)/sum(executions),2) avg_interconnect_mb,
round(sum(io_cell_offload_eligible_bytes/1024/1024)/sum(executions),2) avg_offload_eligible_mb,
round(sum(physical_read_bytes/1024/1024)/sum(executions),2) avg_physical_read_mb,
round(sum(buffer_gets)/sum(executions),2) avg_buffer_reads
from gv$sql
where sql_id='&sql_id'
and executions>0
and end_of_fetch_count>0
group by sql_id,plan_hash_value
--order by avg_ela_time_secs
union all
select 'AWR' location, sql_id,plan_hash_value,
sum(executions_total) execs,
round(sum(rows_processed_total)/sum(executions_total),2) avg_rows,
round(sum(cpu_time_total/1000000)/sum(executions_total),2) avg_cpu_time_secs,
round(sum(elapsed_time_total/1000000)/sum(executions_total),4) avg_ela_time_secs,
round(sum(iowait_total/1000000)/sum(executions_total),2) avg_io_wait_secs,
round(sum(io_offload_return_bytes_total/1024/1024)/sum(executions_total),2) avg_offload_returned_mb,
round(sum(io_interconnect_bytes_total/1024/1024)/sum(executions_total),2) avg_interconnect_mb,
round(sum(io_offload_elig_bytes_total/1024/1024)/sum(executions_total),2) avg_offload_eligible_mb,
round(sum(physical_read_bytes_total/1024/1024)/sum(executions_total),2) avg_physical_read_mb,
round(sum(buffer_gets_total)/sum(executions_total),2) avg_buffer_reads
from dba_hist_sqlstat
where sql_id='&sql_id'
and executions_total>0
and end_of_fetch_count_total>0
group by sql_id,plan_hash_value
--order by avg_ela_time_secs
union all
select 'STS' location,sql_id,plan_hash_value,
sum(executions) execs,
round(sum(rows_processed)/sum(executions),2) avg_rows,
round(sum(cpu_time/1000000)/sum(executions),2) avg_cpu_time_secs,
round(sum(elapsed_time/1000000)/sum(executions),4) avg_ela_time_secs,
NULL avg_io_wait_secs,
NULL avg_offload_returned_mb,
NULL avg_interconnect_mb,
NULL avg_offload_eligible_mb,
round(sum(disk_reads/1024/1024)/sum(executions),2) avg_physical_read_mb,
round(sum(buffer_gets)/sum(executions),2) avg_buffer_reads
from sys.wri$_sqlset_statements s, sys.wri$_sqlset_definitions d, sys.wri$_sqlset_statistics c
where sql_id = '&sql_id'
and d.id = s.sqlset_id
AND s.id = c.stmt_id
AND s.con_dbid = c.con_dbid
GROUP BY s.sql_id, c.plan_hash_value
order by avg_ela_time_secs;



select 'MEMORY' location, sql_id,plan_hash_value,
sum(executions) execs,
round(sum(rows_processed)/sum(executions),2) avg_rows,
round(sum(cpu_time/1000000)/sum(executions),2) avg_cpu_time_secs,
round(sum(elapsed_time/1000000)/sum(executions),2) avg_ela_time_secs,
round(sum(user_io_wait_time/1000000)/sum(executions),2) avg_io_wait_secs,
round(sum(io_cell_offload_returned_bytes/1024/1024)/sum(executions),2) avg_offload_returned_mb,
round(sum(io_interconnect_bytes/1024/1024)/sum(executions),2) avg_interconnect_mb,
round(sum(io_cell_offload_eligible_bytes/1024/1024)/sum(executions),2) avg_offload_eligible_mb,
round(sum(physical_read_bytes/1024/1024)/sum(executions),2) avg_physical_read_mb,
round(sum(buffer_gets)/sum(executions),2) avg_buffer_reads
from gv$sql
where sql_id='2bqufvfwr8hrj'
and executions>0
--and end_of_fetch_count>0
group by sql_id,plan_hash_value
--order by avg_ela_time_secs
union all
select 'AWR' location, sql_id,plan_hash_value,
sum(executions_total) execs,
round(sum(rows_processed_total)/sum(executions_total),2) avg_rows,
round(sum(cpu_time_total/1000000)/sum(executions_total),2) avg_cpu_time_secs,
round(sum(elapsed_time_total/1000000)/sum(executions_total),2) avg_ela_time_secs,
round(sum(iowait_total/1000000)/sum(executions_total),2) avg_io_wait_secs,
round(sum(io_offload_return_bytes_total/1024/1024)/sum(executions_total),2) avg_offload_returned_mb,
round(sum(io_interconnect_bytes_total/1024/1024)/sum(executions_total),2) avg_interconnect_mb,
round(sum(io_offload_elig_bytes_total/1024/1024)/sum(executions_total),2) avg_offload_eligible_mb,
round(sum(physical_read_bytes_total/1024/1024)/sum(executions_total),2) avg_physical_read_mb,
round(sum(buffer_gets_total)/sum(executions_total),2) avg_buffer_reads
from dba_hist_sqlstat
where sql_id='2bqufvfwr8hrj'
and executions_total>0
--and end_of_fetch_count_total>0
group by sql_id,plan_hash_value
order by avg_ela_time_secs;

MORE FILETERD QUERY FOR PHV : 
----------------------------

select location, sql_id,plan_hash_value,execs,avg_ela_time_secs,avg_buffer_reads
from
(
select 'MEMORY' location, sql_id,plan_hash_value,
sum(executions) execs,
round(sum(rows_processed)/sum(executions),2) avg_rows,
round(sum(cpu_time/1000000)/sum(executions),2) avg_cpu_time_secs,
round(sum(elapsed_time/1000000)/sum(executions),2) avg_ela_time_secs,
round(sum(user_io_wait_time/1000000)/sum(executions),2) avg_io_wait_secs,
round(sum(io_cell_offload_returned_bytes/1024/1024)/sum(executions),2) avg_offload_returned_mb,
round(sum(io_interconnect_bytes/1024/1024)/sum(executions),2) avg_interconnect_mb,
round(sum(io_cell_offload_eligible_bytes/1024/1024)/sum(executions),2) avg_offload_eligible_mb,
round(sum(physical_read_bytes/1024/1024)/sum(executions),2) avg_physical_read_mb,
round(sum(buffer_gets)/sum(executions),2) avg_buffer_reads
from gv$sql
where sql_id='&sql_id'
and executions>0
and end_of_fetch_count>0
group by sql_id,plan_hash_value
--order by avg_ela_time_secs
union all
select 'AWR' location, sql_id,plan_hash_value,
sum(executions_total) execs,
round(sum(rows_processed_total)/sum(executions_total),2) avg_rows,
round(sum(cpu_time_total/1000000)/sum(executions_total),2) avg_cpu_time_secs,
round(sum(elapsed_time_total/1000000)/sum(executions_total),2) avg_ela_time_secs,
round(sum(iowait_total/1000000)/sum(executions_total),2) avg_io_wait_secs,
round(sum(io_offload_return_bytes_total/1024/1024)/sum(executions_total),2) avg_offload_returned_mb,
round(sum(io_interconnect_bytes_total/1024/1024)/sum(executions_total),2) avg_interconnect_mb,
round(sum(io_offload_elig_bytes_total/1024/1024)/sum(executions_total),2) avg_offload_eligible_mb,
round(sum(physical_read_bytes_total/1024/1024)/sum(executions_total),2) avg_physical_read_mb,
round(sum(buffer_gets_total)/sum(executions_total),2) avg_buffer_reads
from dba_hist_sqlstat
where sql_id='&sql_id'
and executions_total>0
and end_of_fetch_count_total>0
group by sql_id,plan_hash_value
order by avg_ela_time_secs);


SYSTEM WIDE TIME MODEL OF ANY DATABASE -  Dibya

select case db_stat_name
   when 'parse time elapsed' then 'soft parse time' else db_stat_name end db_stat_name,
   case db_stat_name
   when 'sql execute elapsed time' then time_secs - plsql_time when 'parse time elapsed' then time_secs - hard_parse_time else time_secs end time_secs,
   case db_stat_name
   when 'sql execute elapsed time' then round(100 * (time_secs - plsql_time) / db_time,2)
   when 'parse time elapsed' then round(100 * (time_secs - hard_parse_time) / db_time,2)
   else round(100 * time_secs / db_time,2) end pct_time
     from
          (select stat_name db_stat_name,round((value / 1000000),3) time_secs from sys.v_$sys_time_model where stat_name not in('DB time','background elapsed time','background cpu time','DB CPU')),
          (select round((value / 1000000),3) db_time from sys.v_$sys_time_model where stat_name = 'DB time'),
          (select round((value / 1000000),3) plsql_time from sys.v_$sys_time_model where stat_name = 'PL/SQL execution elapsed time'),
          (select round((value / 1000000),3) hard_parse_time from sys.v_$sys_time_model where stat_name = 'hard parse elapsed time')
     order by 2 desc;


PSR - imp 
-------

set lines 500 pages 100
col max(sample_time) for a30
col min(sample_time) for a30 
col EVENT for a30
col SQL_PLAN_OPERATION for a30
col SQL_OPNAME for a20
select * from 
(
select min(sample_time),max(sample_time),event,sql_id,SQL_OPNAME,SQL_PLAN_OPERATION,count(distinct session_id),count(1)
  from gv$active_session_history
 where sample_time >= sysdate - 1/24
 and sql_id is not null and event is not null
 group by event,sql_id,SQL_OPNAME,SQL_PLAN_OPERATION
 order by count(1) desc
) where rownum <=10; 


set lines 500 pages 100
col max(sample_time) for a30
col min(sample_time) for a30 
col EVENT for a30
col SQL_PLAN_OPERATION for a30
col SQL_OPNAME for a20
select * from 
(
select min(sample_time),max(sample_time),event,sql_id,SQL_OPNAME,SQL_PLAN_OPERATION,count(distinct session_id),count(1)
  from gv$active_session_history
 where sample_time between to_date('12-09-2024 12:20:00','dd-mm-yyyy hh24:mi:ss') and to_date('12-09-2024 12:40:00','dd-mm-yyyy hh24:mi:ss')
   and sql_id is not null and event is not null
 group by event,sql_id,SQL_OPNAME,SQL_PLAN_OPERATION
 order by count(1) desc
) where rownum <=10; 


set lines 500 pages 100
col max(sample_time) for a30
col min(sample_time) for a30 
col EVENT for a30
col SQL_PLAN_OPERATION for a30
col SQL_OPNAME for a20
select * from 
(
select min(sample_time),max(sample_time),event,sql_id,SQL_OPNAME,SQL_PLAN_OPERATION,count(distinct session_id),count(1)
  from dba_hist_active_sess_history
 where sample_time between to_date('10-10-2024 12:30:00','dd-mm-yyyy hh24:mi:ss') and to_date('10-10-2024 12:45:00','dd-mm-yyyy hh24:mi:ss')
   --where snap_id between 33176 and 33177
   and sql_id is not null
 group by event,sql_id,SQL_OPNAME,SQL_PLAN_OPERATION
 order by count(1) desc
) where rownum <=10; 





TOP SQL -  
--------


Top SQL with waits - 


col MIN(SAMPLE_TIME) for a30
col MAX(SAMPLE_TIME) for a30
col "INST_ID||'-'||SESSION_ID||'-'||SESSION_SERIAL#" for a25
col ACTION for a30
col EVENT for a35
col MODULE for a50
col CLIENT_ID for a45

select * from 
(
select min(sample_time),max(sample_time) , inst_id||'-'||session_id||'-'||session_serial#,SQL_ID,SQL_PLAN_HASH_VALUE, EVENT,MODULE,ACTION,CLIENT_ID,PROGRAM,count(1) 
  from gv$active_session_history 
--where event='enq: RC - Result Cache: Contention'
where sample_time between to_date('09-11-2024 00:28:00','dd-mm-yyyy hh24:mi:ss') and to_date('09-11-2024 01:28:00','dd-mm-yyyy hh24:mi:ss')
group by   inst_id||'-'||session_id||'-'||session_serial#,SQL_ID,SQL_PLAN_HASH_VALUE, EVENT,MODULE,ACTION,CLIENT_ID,PROGRAM
order by count(1) desc
)
where rownum<=10;

ALTERNATE WITH CONSUMER GROUPS - 

col MIN(SAMPLE_TIME) for a30
 col MAX(SAMPLE_TIME) for a30
 col "INST_ID||'-'||SESSION_ID||'-'||SESSION_SERIAL#" for a25
 col ACTION for a30
 col EVENT for a35
 col MODULE for a50
 col CLIENT_ID for a45

 select * from 
 (
 select min(sample_time),max(sample_time) , inst_id||'-'||session_id||'-'||session_serial#,
       SQL_ID,SQL_PLAN_HASH_VALUE, EVENT,MODULE,ACTION,CLIENT_ID,PROGRAM,
     consumer_GROUP_id,
       (SELECT /*+ no_unnest */ consumer_GROUP FROM dba_rsrc_consumer_GROUPs rsrc
         WHERE consumer_GROUP_id=ash.consumer_GROUP_id
       ) consumer_GROUP,
     count(1) 
   from gv$active_session_history ash
 --where event='enq: RC - Result Cache: Contention'
 --where sample_time between to_date('09-11-2024 00:28:00','dd-mm-yyyy hh24:mi:ss') and to_date('09-11-2024 01:28:00','dd-mm-yyyy hh24:mi:ss')
 where sample_time >= sysdate - 1/24
 group by   inst_id||'-'||session_id||'-'||session_serial#,SQL_ID,SQL_PLAN_HASH_VALUE, EVENT,MODULE,ACTION,CLIENT_ID,PROGRAM, consumer_GROUP_id
 order by count(1) desc
 )
 where rownum<=10;








FINDING THE SNAP_ID:::

select snap_id,begin_interval_time,end_interval_time
from dba_hist_snapshot
where to_char(begin_interval_time,'DD-MON-YYYY')='09-NOV-2024'
and EXTRACT(HOUR FROM begin_interval_time) between 1 and 2;


set lines 1000


select snap_id,  to_char(begin_interval_time, 'dd/mm/yy hh24:mi:ss') starting
  from dba_hist_snapshot
 order by begin_interval_time desc;

 Alternate 

SELECT snap_id,  to_char(begin_interval_time, 'dd/mm/yy hh24:mi:ss') starting FROM dba_hist_snapshot
WHERE begin_interval_time >= TO_DATE('09.11.2024 01:30:00', 'DD.MM.YYYY HH24:MI:SS')
AND end_interval_time <= TO_DATE('09.11.2024 01:42:00', 'DD.MM.YYYY HH24:MI:SS')
ORDER BY begin_interval_time desc;





set lines 1000 pages 200
select * from
(
select INST_ID,sql_id,event,count(*) 
 from gv$active_session_history
--where sample_time between to_date('11-11-2024 10:45:00','dd-mm-yyyy hh24:mi:ss') and to_date('11-11-2024 10:48:00','dd-mm-yyyy hh24:mi:ss')
where sample_time >= sysdate - 1/24
and (sql_id is not null and event is not null)
group by INST_ID,sql_id,event 
order by 4 desc
) where rownum <10;


set lines 1000 pages 200
select * from
(
select sql_id,event,count(*) 
 from dba_hist_active_sess_history
where sample_time between to_date('09-11-2024 01:30:00','dd-mm-yyyy hh24:mi:ss') and to_date('09-11-2024 01:42:00','dd-mm-yyyy hh24:mi:ss')
group by sql_id,event 
order by 3 desc
) where rownum <10;    


QUERY BY SNAP_ID - 

set lines 1000 pages 200
select * from
(
select sql_id,event,count(*) 
 from dba_hist_active_sess_history
where snap_id between 53486 and 53487
--and event is not null
group by sql_id,event 
order by 3 desc
) where rownum <10;   


By snap_id - 

set lines 1000 pages 200
select * from
(
select sql_id,event,count(*) 
 from dba_hist_active_sess_history
--where sample_time between to_date('03-06-2024 06:45:00','dd-mm-yyyy hh24:mi:ss') and to_date('03-06-2024 07:00:00','dd-mm-yyyy hh24:mi:ss')
where snap_id between 30331 and 30332
group by sql_id,event 
order by 3 desc
) where rownum <10;   


set lines 1000 pages 200
select * from
(
select instance_number,sql_id,event,count(*) 
 from dba_hist_active_sess_history
where sample_time between to_date('25-11-2023 11:00:37','dd-mm-yyyy hh24:mi:ss') and to_date('25-11-2023 11:15:37','dd-mm-yyyy hh24:mi:ss')
group by instance_number,sql_id,event order by 3 desc
) where rownum <10;



SQL execution times / History - Asim 
-----------------------


set lines 1000 pages 200
col USERNAME for a30
col program format a30

select query_runs.*,
                round ( (end_time - start_time) * 24, 2) as duration_hrs
           from (  select u.username,
                          ash.program,
                          ash.sql_id,
                          ash.sql_plan_hash_value as plan_hash_value,
                          ash.session_id as sess#,
                          ash.session_serial# as sess_ser,
                          min (to_char(ash.sample_time,'dd-mm-yyyy hh24:mi:ss')) start_samp_time,
                          max (to_char(ash.sample_time,'dd-mm-yyyy hh24:mi:ss')) end_samp_time,
                          cast (min (ash.sample_time) as date) as start_time,
                          cast (max (ash.sample_time) as date) as end_time
                     from dba_hist_active_sess_history ash, dba_users u
                    where u.user_id = ash.user_id and ash.sql_id = lower(trim('&sqlid')) 
                    and ash.sample_time>= sysdate-3
                 group by u.username,
                          ash.program,
                          ash.sql_id,
                          ash.sql_plan_hash_value,
                          ash.session_id,
                          ash.session_serial#) query_runs
order by sql_id, start_time;



HARD PARSING SQLS - 
 
select * from 
(
 SELECT TO_CHAR(TRUNC(sn.end_interval_time),'DD-MON-YYYY') dt ,
      st.sql_id ,
        SUM(executions_delta) execs ,
      ROUND(SUM(elapsed_time_delta)/1000/1000) elp ,
      ROUND(SUM(elapsed_time_delta)/1000/1000/NVL(NULLIF(SUM(executions_delta),0),1),2) elpe ,
      ROUND(SUM(iowait_delta)      /1000/1000) io ,
      ROUND(SUM(cpu_time_delta)    /1000/1000) cpu ,
      SUM(buffer_gets_delta) gets ,
      ROUND(SUM(disk_reads_delta)) disk_reads
    FROM dba_hist_snapshot sn ,
      dba_hist_sqlstat st
    WHERE st.snap_id       = sn.snap_id
    AND sn.instance_number = st.instance_number
    AND st.module IN ('hcm.learn.SelfServiceAM')
    and executions_delta>0 
    and SN.END_INTERVAL_TIME>=sysdate-1
    --and sn.snap_id between 33176 and 33177
    GROUP BY TRUNC(SN.END_INTERVAL_TIME),ST.SQL_ID 
   having  ROUND(SUM(elapsed_time_delta)/1000/1000/NVL(NULLIF(SUM(executions_delta),0),1),2) >0.8  
    ORDER BY  5 DESC)
where rownum <=10;



HARD PARSING TIME - 

select sql_id, PLAN_HASH_VALUE , round(ELAPSED_TIME/1e6,3) total_etime, round(AVG_HARD_PARSE_TIME/1e6,3) total_hpt, SHARABLE_MEM shar_mem, buffer_gets total_bfg, executions total_exec
from  GV$SQLSTATS_PLAN_HASH 
where sql_id IN ('gybfhn9v7ffr6')
order by total_hpt desc ;



SQL_TEXT -
-----------

set lines 1000 pages long 200000
col sql_text for a100 
select sql_text from gv$sql where sql_id='&sql_id' and rownum=1;

select sql_text from dba_hist_sqltext where sql_id='&sql_id' and rownum=1;


select prev_sql_id,sql_id,module,action,event from gv$session where sid=&sid and serial#=&ser;
select distinct sql_id,module,action,event from dba_hist_active_sess_history where session_id=&sid and session_serial#=&ser;


select blocking_session, sid,  serial#,wait_class,
seconds_in_wait
from gv$session
where blocking_session is not NULL
order by blocking_session;


CHECK THE DURATION OF A QUERY (RUNTIME) - 
--------------------------------

select * from
(
select * from
(
select query_runs.*,
                round ( (end_time - start_time) * 24, 2) as duration_hrs
           from (  select u.username,
                          ash.program,
                          ash.sql_id,
                          ash.sql_plan_hash_value as plan_hash_value,
                          ash.session_id as sess#,
                          ash.session_serial# as sess_ser,
              min (to_char(ash.sample_time,'dd-mm-yyyy hh24:mi:ss')) start_samp_time,
              max (to_char(ash.sample_time,'dd-mm-yyyy hh24:mi:ss')) end_samp_time,
                          cast (min (ash.sample_time) as date) as start_time,
                          cast (max (ash.sample_time) as date) as end_time
                     from dba_hist_active_sess_history ash, dba_users u
                    where u.user_id = ash.user_id and ash.sql_id = lower(trim('bu856723v3qhc')) 
          and ash.sample_time between to_date('28-08-2023 00:01:00','dd-mm-yyyy hh24:mi:ss') and to_date('29-08-2023 08:30:00','dd-mm-yyyy hh24:mi:ss')
                 group by u.username,
                          ash.program,
                          ash.sql_id,
                          ash.sql_plan_hash_value,
                          ash.session_id,
                          ash.session_serial#) query_runs
)
order by duration_hrs desc
)
where rownum<50;


blocker -
--------

set lines 1000 pages 200
col MIN(SAMPLE_TIME) for a25
col MAX(SAMPLE_TIME) for a25
col P1TEXT for a20
col P2text for a20
col EVENT for a30
col BLOCKER for a15
col P2 for 9999999999999999
col P1 for 9999999999999999
 
 Select * from
 (
 select MIN(SAMPLE_TIME),MAX(SAMPLE_TIME),SQL_ID,EVENT,P1TEXT,P1,P2TEXT,P2,BLOCKING_INST_ID||'-'||BLOCKING_SESSION||'-'||BLOCKING_SESSION_SERIAL#  
 as BLOCKER,COUNT(DISTINCT SESSION_ID), count(1) 
 from gv$active_session_history 
 where sample_time >= sysdate - 15/(60*24)
 group by SQL_ID,EVENT,P1TEXT,P1,P2TEXT,P2,BLOCKING_INST_ID||'-'||BLOCKING_SESSION||'-'||BLOCKING_SESSION_SERIAL#  
 order by count(1) desc
 )
 Where  blocker <> '--' 
 --and sql_id='15kc70s6fgks7'
 and sql_id is not null
 and rownum<10;

 set lines 1000 pages 200
 col MIN(SAMPLE_TIME) for a30 
 col MAX(SAMPLE_TIME) for a30 
 col P1TEXT for a20
 col P2text for a20
 col EVENT for a30
 col BLOCKER for a20
 col P2 for 9999999999999999
 col P1 for 9999999999999999
 
 Select * from
 (
 select MIN(SAMPLE_TIME),MAX(SAMPLE_TIME),SQL_ID,EVENT,P1TEXT,P1,P2TEXT,P2,BLOCKING_INST_ID||'-'||BLOCKING_SESSION||'-'||BLOCKING_SESSION_SERIAL#  
 as BLOCKER,COUNT(DISTINCT SESSION_ID), count(1) 
 from dba_hist_active_sess_history where sample_time between to_date('09-08-2023 08:05:00','dd-mm-yyyy hh24:mi:ss') and to_date('09-08-2023 08:40:00','dd-mm-yyyy hh24:mi:ss')
 group by SQL_ID,EVENT,P1TEXT,P1,P2TEXT,P2,BLOCKING_INST_ID||'-'||BLOCKING_SESSION||'-'||BLOCKING_SESSION_SERIAL#  
 order by count(1) desc
 )
 Where  blocker <> '--' 
 --and sql_id='26x7vsdq2z44b'
 and sql_id is not null
 and rownum<20;



 BLOCKER FOR ROW CACHE LOCK FOR 600 SECS --> 
-------------------
 select count(1),FINAL_BLOCKING_SESSION||':'||FINAL_BLOCKING_INSTANCE,round(WAIT_TIME_MICRO/1e6,6) wait_seconds,event  
   from gv$session 
  where FINAL_BLOCKING_SESSION_STATUS='VALID' 
    and event like 'row cache%' 
    and  round(WAIT_TIME_MICRO/1e6,6) > 600 
    and status='ACTIVE' 
group by FINAL_BLOCKING_SESSION||':'||FINAL_BLOCKING_INSTANCE,event,round(WAIT_TIME_MICRO/1e6,6) order by 1 desc;





Execution Plan-
--------------

SELECT * FROM TABLE(DBMS_XPLAN.display_cursor(sql_id=>' bu856723v3qhc',format=>'ALLSTATS LAST +cost +bytes'));
SELECT * FROM TABLE(DBMS_XPLAN.display_cursor('&sql_id', &child)); 
SELECT * FROM TABLE(DBMS_XPLAN.display_cursor('&sql_id'));
SELECT * FROM TABLE(DBMS_XPLAN.display_awr('&sql_id'));

SELECT * FROM TABLE(DBMS_XPLAN.display_awr(SQL_ID=>'&sql_id',plan_hash_value=>'&phv'));


PHVs-
--------

WITH
p AS (
SELECT plan_hash_value
FROM gv$sql_plan
WHERE sql_id = TRIM('&&sql_id.')
AND other_xml IS NOT NULL
UNION
SELECT plan_hash_value
FROM dba_hist_sql_plan
WHERE sql_id = TRIM('&&sql_id.')
AND other_xml IS NOT NULL ),
m AS (
SELECT plan_hash_value,
SUM(elapsed_time)/SUM(executions) avg_et_secs
FROM gv$sql
WHERE sql_id = TRIM('&&sql_id.')
AND executions > 0
GROUP BY
plan_hash_value ),
a AS (
SELECT plan_hash_value,
SUM(elapsed_time_total)/SUM(executions_total) avg_et_secs
FROM dba_hist_sqlstat
WHERE sql_id = TRIM('&&sql_id.')
AND executions_total > 0
GROUP BY
plan_hash_value )
SELECT p.plan_hash_value,
ROUND(NVL(m.avg_et_secs, a.avg_et_secs)/1e6, 3) avg_et_secs
FROM p, m, a
WHERE p.plan_hash_value = m.plan_hash_value(+)
AND p.plan_hash_value = a.plan_hash_value(+)
ORDER BY
avg_et_secs NULLS LAST;


set lines 500 pages 200
col SQL_PROFILE for a30
col PARSING_SCHEMA_NAME for a20
select PARSING_SCHEMA_NAME, inst_id, sql_id, child_number, plan_hash_value plan_hash, executions execs,
(elapsed_time/1000000)/decode(nvl(executions,0),0,1,executions) avg_etime_secs,
buffer_gets/decode(nvl(executions,0),0,1,executions) avg_lio,
last_active_time,
SQL_PROFILE,
decode(IO_CELL_OFFLOAD_ELIGIBLE_BYTES,0,'No','Yes') Offload,
decode(IO_CELL_OFFLOAD_ELIGIBLE_BYTES,0,0,100*(IO_CELL_OFFLOAD_ELIGIBLE_BYTES-IO_INTERCONNECT_BYTES)
/decode(IO_CELL_OFFLOAD_ELIGIBLE_BYTES,0,1,IO_CELL_OFFLOAD_ELIGIBLE_BYTES)) "IO_SAVED_%"
from gv$sql s
where sql_id like nvl(trim('&sql_id'),sql_id)
order by 1, 2, 3;




Hard Parsing SQLs -
-----------------

col IN_HARD_PARSE for a15
select * from 
(
select INSTANCE_NUMBER,TOP_LEVEL_SQL_ID,SQL_ID,IN_HARD_PARSE,count(*)
from dba_hist_active_sess_history
--where sample_time between to_date('09-08-2023 08:05:00','dd-mm-yyyy hh24:mi:ss') and to_date('09-08-2023 08:30:00','dd-mm-yyyy hh24:mi:ss')
where snap_id between 33176 and 33177
  and sql_id='gybfhn9v7ffr6'
  and IN_HARD_PARSE='Y'
group by INSTANCE_NUMBER,TOP_LEVEL_SQL_ID,SQL_ID,IN_HARD_PARSE
having count(*)>10
order by count(*) desc)
where rownum<=10;

https://jira-sd.mc1.oracleiaas.com/browse/ADB-219546 - Jira 
================

select sql_id, to_char(sql_exec_start, 'YYYY-MM-DD HH24:MI:SS') Start_Time, event, IN_PARSE, IN_HARD_PARSE, IN_SQL_EXECUTION, IN_PLSQL_EXECUTION, IN_PLSQL_COMPILATION, count sample_count
from gv$active_session_history
where sql_id = 'gybfhn9v7ffr6'
-- and sql_exec_start > sysdate - 30/(24*60)
and sql_exec_start > sysdate - 1
group by sql_id, sql_exec_start, event, IN_PARSE, IN_HARD_PARSE, IN_SQL_EXECUTION, IN_PLSQL_EXECUTION, IN_PLSQL_COMPILATION
order by sample_count ;




                                                                  ----- ASH Viewing Locks (https://clarodba.wordpress.com/2023/05/18/how-to-see-locks-from-ash-the-right-way/)



def DATINI="06-09-2023 12:50:00"
def DATFIN="06-09-2023 12:56:00"
 
alter session set nls_date_format='dd-mm-yyyy hh24:mi:ss';
 
clear breaks
col sidqueue for a20 head "SID|QUEUE"
col COMPLETE_SESSION_ID for a14 head "SESSION_ID"
col USERNAME for a15 wrap
col MODULE for a15 wrap
col EVENT for a20 wrap
col OBJ for a30 wrap
col MINUTOS for 999.9
break on sample_time skip page on level
set pages 1000
 
with ash as (
    select a.*,
        O.OWNER || '.' || O.OBJECT_NAME as obj,
        u.username, 
        case when blocking_session is NULL then 'N' else 'Y' end IS_WAITING,
        case
            when
            instr(
                listagg(DISTINCT '.'||blocking_session||'.') 
                    WITHIN GROUP (order by blocking_session) 
                    OVER (partition by sample_id) ,
                '.'||session_id||'.'
                ) = 0 
            then 'N'
            else 'Y'
            end as IS_HOLDING,
        case
            when blocking_session is NULL then NULL
            when instr(
                listagg(DISTINCT '.'||session_id||'.') 
                    WITHIN GROUP (order by session_id) 
                    OVER (partition by sample_id) ,
                '.'||blocking_session||'.'
                ) = 0 
            then 'N'
            else 'Y'
            end as IS_BLOCKING_SID_ACTIVE
    from dba_hist_active_sess_history a
    left join dba_objects o on o.object_id = a.CURRENT_OBJ#
    left join dba_users u on u.user_id = a.user_id
    where SAMPLE_TIME between to_date('06-10-2023 12:50:57','dd-mm-yyyy hh24:mi:ss') and to_date('06-10-2023 12:56:00','dd-mm-yyyy hh24:mi:ss')
),
ash_with_inactive as (
-- I need to include the inactive blocking sessions because ASH does not record INACTIVE
    select
        sample_id, cast(sample_time as date) as sample_time, 
        session_id, session_serial#, instance_number,
        blocking_session, blocking_session_serial#, blocking_inst_id,
        sql_id, sql_exec_start, sql_exec_id, TOP_LEVEL_SQL_ID, XID, 
        username, module, nvl(event,'On CPU') event, 
        sysdate + ( (sample_time - min(sample_time) over (partition by session_id, session_serial#, instance_number, event_id, SEQ#)) * 86400) - sysdate as swait,
        obj, 
        IS_WAITING, IS_HOLDING, 'Y' IS_ACTIVE, IS_BLOCKING_SID_ACTIVE
    from ash
    UNION ALL
    select DISTINCT
        sample_id, cast(sample_time as date) as sample_time, 
        blocking_session as session_id, blocking_session_serial# as session_serial#, blocking_inst_id as instance_number,
        NULL as blocking_session, NULL as blocking_session_serial#, NULL as blocking_instance,
        NULL as sql_id, NULL as sql_exec_start, NULL as sql_exec_id, NULL as TOP_LEVEL_SQL_ID, NULL as XID, 
        NULL as username, NULL as module, '**INACTIVE**' as event, NULL as swait, NULL as obj, 
        'N' as IS_WAITING, 'Y' as IS_HOLDING, 'N' IS_ACTIVE, null as IS_BLOCKING_SID_ACTIVE
    from ash a1
    where IS_BLOCKING_SID_ACTIVE = 'N' 
),
locks as (
    select b.*,
        listagg(DISTINCT '.'||event||'.') within group (order by lock_level) over (partition by sample_id, top_level_sid) event_chain,
        listagg(DISTINCT '.'||username||'.') within group (order by lock_level) over (partition by sample_id, top_level_sid) user_chain,
        listagg(DISTINCT '.'||module||'.') within group (order by lock_level) over (partition by sample_id, top_level_sid) module_chain,
        listagg(DISTINCT '.'||obj||'.') within group (order by lock_level) over (partition by sample_id, top_level_sid) obj_chain,
        listagg(DISTINCT '.'||xid||'.') within group (order by lock_level) over (partition by sample_id, top_level_sid) xid_chain,
        listagg(DISTINCT '.'||session_id||'.') within group (order by lock_level) over (partition by sample_id, top_level_sid) sid_chain,
        listagg(DISTINCT '.'||sql_id||'.') within group (order by lock_level) over (partition by sample_id, top_level_sid) sql_id_chain
    from (
        select a.*,
            rownum rn, level lock_level,
            case when level > 2 then lpad(' ',2*(level-2),' ') end || 
                case when level > 1 then '+-' end || session_id as sidqueue,
            session_id || ',' || session_serial# || '@' || instance_number COMPLETE_SESSION_ID,
            CONNECT_BY_ROOT session_id as top_level_sid
        from ash_with_inactive a
        connect by
            prior sample_id = sample_id
            and prior session_id = blocking_session 
            and prior instance_number = blocking_inst_id 
            and prior session_serial# = blocking_session_serial# 
        start with
            IS_HOLDING = 'Y' and IS_WAITING = 'N'
        order SIBLINGS by sample_time, swait desc
    ) b
)
select
--     sample_id, 
    sample_time, lock_level, sidqueue, COMPLETE_SESSION_ID, 
    username, module, xid,
    event, swait, OBJ,
    sql_id, sql_exec_start, sql_exec_id, top_level_sql_id
from locks
where 1=1
--and event_chain like '%TM%contention%'
--and user_chain like '%PROD_BATCH%'
--and module_chain like '%PB%'
--and obj_chain like '%PGM%'
--and xid_chain like '%1300%'
--and sid_chain like '%7799%'
--and sql_id_chain like '%fmxzsf8gxn0ym%'
order by rn;



BLOCKER/BLOCKED SESSIONS - 


accept bd prompt "BEGIN DATE [sysdate-1]: " default "sysdate-1"
accept ed prompt "END DATE   [sysdate]  : " default "sysdate"
accept hb prompt "HOURS TO LOOK BACK FOR BLOCKING SESSION INFO [1] (use -1 to match SAMPLE_TIME): " default "1"
 
col BLOCKING_SESSION for a14
col BLOCKING_USER for a15 TRUNC
col BLOCKING_MODULE for a15 TRUNC
col BLOCKED_SESSION for a14
col BLOCKED_USER for a15 TRUNC
col BLOCKED_MODULE for a15 TRUNC
col BLOCKED_OBJECT for a30 TRUNC
col EVENT for a30 TRUNC
col WAIT_CLASS for a12 TRUNC
col BLOCKING_LAST_ACTIVE for a30
break on BLOCKING_SESSION skip 1
 
WITH
dbahist0 as (
    select /*+ MATERIALIZE PARALLEL(a 1) */
        SAMPLE_TIME, DBID, INSTANCE_NUMBER, SESSION_ID, SESSION_SERIAL#, USER_ID, MODULE,
        BLOCKING_SESSION, BLOCKING_SESSION_SERIAL#, BLOCKING_INST_ID, BLOCKING_SESSION_STATUS,
        CURRENT_OBJ#, SQL_ID, 
        nvl(a.EVENT,'On CPU') as EVENT,
        nvl(a.WAIT_CLASS,'On CPU') as WAIT_CLASS
    from DBA_HIST_ACTIVE_SESS_HISTORY a
    -- Looking back &hb hours before the time window to try finding blocking session info if they are INACTIVE when blocking
    where SAMPLE_TIME between to_date('09-10-2023 07:40:00','dd-mm-yyyy hh24:mi:ss') and to_date('09-10-2023 07:45:00','dd-mm-yyyy hh24:mi:ss')
    --where SAMPLE_TIME >= sysdate - 1/24
    and DBID = (select DBID from v$database)
),
dbahist as (
    select a.*
    from dbahist0 a
    -- Now refiltering the dates to keep only the real time window
    where SAMPLE_TIME between to_date('09-10-2023 07:40:00','dd-mm-yyyy hh24:mi:ss') and to_date('09-10-2023 07:45:00','dd-mm-yyyy hh24:mi:ss')
    --where SAMPLE_TIME >= sysdate -1/24
    -- Only blocked sessions
    and BLOCKING_SESSION is not null
    and BLOCKING_SESSION_STATUS = 'VALID'
    -- I only want to see events related to applications activity, like 'row lock contention', 
    --    but not instance-related, like 'latch free' or 'log file sync'. Remove if you want to see all.
    --and wait_class = 'Application'
    -- I don't want to see activity from SYS. Remove if you want to see all.
    and user_id != 0
),
blocking as (
    select DBID, INSTANCE_NUMBER,
        SESSION_ID, SESSION_SERIAL#, USER_ID, max(MODULE) as MODULE, max(SAMPLE_TIME) LAST_ACTIVE
    from dbahist0 b
    group by DBID, INSTANCE_NUMBER, SESSION_ID, SESSION_SERIAL#, b.USER_ID
),
q as (
    select cast(a.SAMPLE_TIME as date) SAMPLE_TIME,
        lpad(a.BLOCKING_SESSION || ',' || a.BLOCKING_SESSION_SERIAL# || ',@' || a.BLOCKING_INST_ID, 14, ' ') as BLOCKING_SESSION,
        coalesce(blocking.MODULE,blocking2.MODULE) as BLOCKING_MODULE, 
        coalesce(blocking.USER_ID,blocking2.USER_ID) as BLOCKING_USER_ID, 
        lpad(a.SESSION_ID || ',' || a.SESSION_SERIAL# || ',@' || a.INSTANCE_NUMBER, 14, ' ') as BLOCKED_SESSION, 
        a.MODULE as BLOCKED_MODULE, a.USER_ID as BLOCKED_USER_ID, a.CURRENT_OBJ#,
        a.SQL_ID as BLOCKED_SQLID, a.EVENT, a.WAIT_CLASS, blocking.LAST_ACTIVE
    from dbahist a
    left join blocking
        on '&hb' != '-1'
        and a.DBID = blocking.DBID
        and a.BLOCKING_INST_ID = blocking.INSTANCE_NUMBER
        and a.BLOCKING_SESSION = blocking.SESSION_ID
        and a.BLOCKING_SESSION_SERIAL# = blocking.SESSION_SERIAL#
    left join dbahist0 blocking2
        on '&hb' = '-1'
        and a.DBID = blocking2.DBID
        and a.BLOCKING_INST_ID = blocking2.INSTANCE_NUMBER
        and a.BLOCKING_SESSION = blocking2.SESSION_ID
        and a.BLOCKING_SESSION_SERIAL# = blocking2.SESSION_SERIAL#
        and a.SAMPLE_TIME = blocking2.SAMPLE_TIME
)
select
    BLOCKING_SESSION, nvl(ub.USERNAME,'***NOT FOUND***') as BLOCKING_USER, nvl(BLOCKING_MODULE,'***NOT FOUND***') as BLOCKING_MODULE, 
    BLOCKED_SESSION, u.USERNAME as BLOCKED_USER, BLOCKED_MODULE, BLOCKED_SQLID, 
    o.OWNER || '.' || o.OBJECT_NAME as BLOCKED_OBJECT,
    EVENT, WAIT_CLASS,
    count(1) QTY, min(SAMPLE_TIME) MIN_TIME, max(SAMPLE_TIME) MAX_TIME, LAST_ACTIVE as BLOCKING_LAST_ACTIVE
from q
left join dba_users u on u.USER_ID = q.BLOCKED_USER_ID
left join dba_users ub on ub.USER_ID = q.BLOCKING_USER_ID
left join dba_objects o on o.OBJECT_ID = q.CURRENT_OBJ#
where BLOCKED_SQLID is not null
group by 
    BLOCKING_SESSION, ub.USERNAME, BLOCKING_MODULE, LAST_ACTIVE,
    BLOCKED_SESSION, u.USERNAME, BLOCKED_MODULE,
    BLOCKED_SQLID, o.OWNER, o.OBJECT_NAME, EVENT, WAIT_CLASS
order by BLOCKING_SESSION, BLOCKED_SESSION; 




PSR queries provided by Venkata Ravi - 

alter session set nls_date_format='DD-MON-YYYY HH24:MI:SS';
 
set lines 399
set pages 59999
 
SELECT instance_number||'-'||session_id||'-'||session_serial#
  ||','
  || SAMPLE_ID
  ||','
  || SAMPLE_TIME
  ||','
  || SQL_ID
  ||','
  || SQL_PLAN_HASH_VALUE
  ||','
  || SQL_EXEC_ID
  ||','
  || SQL_EXEC_START
  ||','
  || EVENT
  ||','
  || in_parse
  ||','
  || in_hard_parse
  ||','
  || ECID
  ||','
  ||QC_INSTANCE_ID||'-'||QC_SESSION_ID||'-'||QC_SESSION_SERIAL#
  ||','
  ||P1TEXT||'-'||P1||'-'||P2text||'-'||p2
  ||','
  ||BLOCKING_SESSION||'-'||BLOCKING_SESSION_SERIAL#||'-'||BLOCKING_INST_ID
  ||','
  ||IN_SQL_EXECUTION
  ||','
  || PGA_ALLOCATED
  ||','
  || TEMP_SPACE_ALLOCATED
  ||','
  || PROGRAM
  ||','
  || MODULE
  ||','
  || ACTION
  ||','
  || CLIENT_ID
FROM dba_hist_active_sess_history
where 1=1
and sample_time > to_date('07-Nov-23 09:20:00', 'DD-Mon-YY HH24:MI:SS')
AND sample_time < to_date('07-Nov-23 09:40:00', 'DD-Mon-YY HH24:MI:SS')
ORDER BY sample_time ;





SELECT instance_number||'-'||session_id||'-'||session_serial#
  ||','
  || SAMPLE_ID
  ||','
  || SAMPLE_TIME
  ||','
  || SQL_ID
  ||','
  || SQL_PLAN_HASH_VALUE
  ||','
  || SQL_EXEC_ID
  ||','
  || SQL_EXEC_START
  ||','
  || EVENT
  ||','
  || in_parse
  ||','
  || in_hard_parse
  ||','
  || ECID
  ||','
  ||QC_INSTANCE_ID||'-'||QC_SESSION_ID||'-'||QC_SESSION_SERIAL#
  ||','
  ||P1TEXT||'-'||P1||'-'||P2text||'-'||p2
  ||','
  ||BLOCKING_SESSION||'-'||BLOCKING_SESSION_SERIAL#||'-'||BLOCKING_INST_ID
  ||','
  ||IN_SQL_EXECUTION
  ||','
  || PGA_ALLOCATED
  ||','
  || TEMP_SPACE_ALLOCATED
  ||','
  || PROGRAM
  ||','
  || MODULE
  ||','
  || ACTION
  ||','
  || CLIENT_ID
FROM dba_hist_active_sess_history
where 1=1
and sample_time >= to_date('07-Nov-23 09:20:00', 'DD-Mon-YY HH24:MI:SS')
AND sample_time <= to_date('07-Nov-23 09:40:00', 'DD-Mon-YY HH24:MI:SS')
ORDER BY sample_time ;







9331046156 -- Appointment for Dr Sumit Ghosal (8:45 to 9:30 AM) 



ALERT LOG ERROR CHECKING- 

col MESSAGE_TEXT for a100 
set lines 500 pages 200 
col ORIGINATING_TIMESTAMP for a60 
select * from 
(
select INST_ID,message_text, ORIGINATING_TIMESTAMP
from   x$dbgalertext
where  lower(message_text) like '%force logging%'
order by ORIGINATING_TIMESTAMP desc)
where rownum<=20;





Dibya's SQLs 
============

Current ::
-----------
set lines 1000 pages 200 
set long 20000
col MODULE for a40
col ACTION for a30 
col USERNAME for a30 
col WAIT_OBJ_NAME for a30 
col event for a30

select event,module,action,top_level_sql_id,sql_id,username,wait_obj_name,sql_exec_cnt,tot_cnt
from 
(
select wait_class,event,module,action,top_level_sql_id,sql_id,
      (select username from dba_users where user_id= ash.user_id) username,
              min(sample_time) min_sample,max(sample_time) max_sample,
              min(round(temp_space_allocated/1024/1024,2)) min_temp_mb, max(round(temp_space_allocated/1024/1024,2)) max_temp_mb,
              min(round(pga_allocated/1024/1024,2)) min_pga_mb , max(round(pga_allocated/1024/1024,2)) max_pga_mb,
        case when do.object_name is null then 'X' else do.object_name end wait_obj_name,
        case when do.object_type is null then 'X' else do.object_type end wait_obj_type,
        sum(case when in_parse='Y' then 1 else 0 end) parse_cnt,
        sum(case when in_hard_parse='Y' then 1 else 0 end) hard_parse_cnt,
        sum(case when in_sql_execution='Y' then 1 else 0 end) sql_exec_cnt,
        sum(case when session_state='ON CPU' then 1 else 0 end) sess_state_cpu_cnt,
        sum(case when session_state='WAITING' then 1 else 0 end) sess_state_wait_cnt,
        sum(case when blocking_session_status='VALID' then 1 else 0 end) block_cnt,
        count(1) tot_cnt
        from gv$active_session_history ash, dba_objects do
       where ash.current_obj#=do.object_id(+)
         --and ash.snap_id between 26939 and 26940
         and sample_time >= sysdate - 1/24
         --and sample_time between to_date('04-10-2024 06:30:59','dd-mm-yyyy hh24:mi:ss') and to_date('04-10-2024 07:00:59','dd-mm-yyyy hh24:mi:ss')
         and sql_id is not null
       group by  wait_class,event,module,action,user_id,do.object_name,do.object_type,top_level_sql_id,sql_id
       order by tot_cnt desc)
fetch first 10 rows only;


Historic::
-----------

SELECT THE SNAP_ID FOR A SPECIFIC TIME RANGE :::
================================================

select  snap_id,BEGIN_INTERVAL_TIME,END_INTERVAL_TIME 
from dba_hist_snapshot 
where BEGIN_INTERVAL_TIME  between to_date('2024-10-27 12:00:00','yyyy-mm-dd hh24:mi:ss') and 
to_date('2024-10-27 13:00:00','yyyy-mm-dd hh24:mi:ss')
order by BEGIN_INTERVAL_TIME desc;


select wait_class,event,module,action,top_level_sql_id,sql_id,
      (select username from dba_users where user_id= ash.user_id) username,
              min(sample_time) min_sample,max(sample_time) max_sample,
              min(round(temp_space_allocated/1024/1024,2)) min_temp_mb, max(round(temp_space_allocated/1024/1024,2)) max_temp_mb,
              min(round(pga_allocated/1024/1024,2)) min_pga_mb , max(round(pga_allocated/1024/1024,2)) max_pga_mb,
        case when do.object_name is null then 'X' else do.object_name end wait_obj_name,
        case when do.object_type is null then 'X' else do.object_type end wait_obj_type,
        sum(case when in_parse='Y' then 1 else 0 end) parse_cnt,
        sum(case when in_hard_parse='Y' then 1 else 0 end) hard_parse_cnt,
        sum(case when in_sql_execution='Y' then 1 else 0 end) sql_exec_cnt,
        sum(case when session_state='ON CPU' then 1 else 0 end) sess_state_cpu_cnt,
        sum(case when session_state='WAITING' then 1 else 0 end) sess_state_wait_cnt,
        sum(case when blocking_session_status='VALID' then 1 else 0 end) block_cnt,
        count(1) tot_cnt
        from dba_hist_active_sess_history ash, dba_objects do
       where ash.current_obj#=do.object_id(+)
         and ash.snap_id between 42315 and 42316
         --and sample_time between to_date('08-10-2024 01:30:00','dd-mm-yyyy hh24:mi:ss') and to_date('08-10-2024 01:40:00','dd-mm-yyyy hh24:mi:ss')
       group by  wait_class,event,module,action,user_id,do.object_name,do.object_type,top_level_sql_id,sql_id
       order by tot_cnt desc
fetch first 10 rows only;





Current ::
-----------
select ash.inst_id||'-'||ash.session_id||'-'||ash.session_serial# sess,ash.sql_id,
       min(ash.sample_time) min_sample,max(ash.sample_time) max_sample,module,action,program,
            (select username from dba_users where user_id= ash.user_id) username,
                    min(round(temp_space_allocated/1024/1024,2)) min_temp_mb, max(round(temp_space_allocated/1024/1024,2)) max_temp_mb,
                    min(round(pga_allocated/1024/1024,2)) min_pga_mb , max(round(pga_allocated/1024/1024,2)) max_pga_mb,
                    ash.wait_class||'-'||ash.event||'-'||ash.p1||'-'||ash.p2||'-'||ash.p3 wait_details,
                    case when do.object_name is null then 'X' else do.object_name end wait_obj_name,
                    case when do.object_type is null then 'X' else do.object_type end wait_obj_type,
                    ash.blocking_inst_id||'-'||ash.blocking_session||'-'||ash.blocking_session_serial# blkng_sess,
                    sum(case when in_parse='Y' then 1 else 0 end) parse_cnt,
                    sum(case when in_hard_parse='Y' then 1 else 0 end) hard_parse_cnt,
                    sum(case when in_sql_execution='Y' then 1 else 0 end) sql_exec_cnt,
                    sum(case when session_state='ON CPU' then 1 else 0 end) sess_state_cpu_cnt,
                    sum(case when session_state='WAITING' then 1 else 0 end) sess_state_wait_cnt,
                    sum(case when blocking_session_status='VALID' then 1 else 0 end) block_cnt,
                    count(1) tot_cnt,ash.ecid
              from gv$active_session_history ash, dba_objects do
             where ash.current_obj#=do.object_id(+)
            --and ash.snap_id between 26657 and 26658
            and sample_time >= sysdate - 1/24
            --and sample_time between to_date('27-09-2024 06:26:59','dd-mm-yyyy hh24:mi:ss') and to_date('27-09-2024 07:20:59','dd-mm-yyyy hh24:mi:ss')
              and ash.sql_id = '0nf0ft52tcmkv'
            group by ash.inst_id||'-'||ash.session_id||'-'||ash.session_serial#,ash.sql_id,ash.user_id,module,action,program,ash.wait_class||'-'||ash.event||'-'||ash.p1||'-'||ash.p2||'-'||ash.p3,in_parse,in_hard_parse,ash.blocking_inst_id||'-'||ash.blocking_session||'-'||ash.blocking_session_serial# ,ash.ecid,do.object_name,do.object_type
  order by tot_cnt desc
  fetch first 10 rows only;

  
Historic ::
----------
select ash.instance_number||'-'||ash.session_id||'-'||ash.session_serial# sess,ash.sql_id,
       min(ash.sample_time) min_sample,max(ash.sample_time) max_sample,module,action,program,
            (select username from dba_users where user_id= ash.user_id) username,
                    min(round(temp_space_allocated/1024/1024,2)) min_temp_mb, max(round(temp_space_allocated/1024/1024,2)) max_temp_mb,
                    min(round(pga_allocated/1024/1024,2)) min_pga_mb , max(round(pga_allocated/1024/1024,2)) max_pga_mb,
                    ash.wait_class||'-'||ash.event||'-'||ash.p1||'-'||ash.p2||'-'||ash.p3 wait_details,
                    case when do.object_name is null then 'X' else do.object_name end wait_obj_name,
                    case when do.object_type is null then 'X' else do.object_type end wait_obj_type,
                    ash.blocking_inst_id||'-'||ash.blocking_session||'-'||ash.blocking_session_serial# blkng_sess,
                    sum(case when in_parse='Y' then 1 else 0 end) parse_cnt,
                    sum(case when in_hard_parse='Y' then 1 else 0 end) hard_parse_cnt,
                    sum(case when in_sql_execution='Y' then 1 else 0 end) sql_exec_cnt,
                    sum(case when session_state='ON CPU' then 1 else 0 end) sess_state_cpu_cnt,
                    sum(case when session_state='WAITING' then 1 else 0 end) sess_state_wait_cnt,
                    sum(case when blocking_session_status='VALID' then 1 else 0 end) block_cnt,
                    count(1) tot_cnt,ash.ecid
              from dba_hist_active_sess_history ash, dba_objects do
             where ash.current_obj#=do.object_id(+)
            --and ash.snap_id between 26657 and 26658
              and sample_time between to_date('10-08-2024 09:40:00','dd-mm-yyyy hh24:mi:ss') and to_date('10-08-2024 09:48:00','dd-mm-yyyy hh24:mi:ss')
              and ash.sql_id = '8nfsaatvyrh55'
            group by ash.instance_number||'-'||ash.session_id||'-'||ash.session_serial#,ash.sql_id,ash.user_id,module,action,program,ash.wait_class||'-'||ash.event||'-'||ash.p1||'-'||ash.p2||'-'||ash.p3,in_parse,in_hard_parse,ash.blocking_inst_id||'-'||ash.blocking_session||'-'||ash.blocking_session_serial# ,ash.ecid,do.object_name,do.object_type
  order by tot_cnt desc
  fetch first 10 rows only;




CPU CONSUMING SQLs / SESSIONS - 
===============================

select rownum as rank, a.*
from (
SELECT v.sid,sess.Serial# ,program, v.value / (100 * 60) CPUMins
FROM v$statname s , v$sesstat v, v$session sess
WHERE s.name = 'CPU used by this session'
and sess.sid = v.sid
and v.statistic#=s.statistic#
and v.value>0
ORDER BY v.value DESC) a
where rownum < 11;


select * from
(
select session_id, session_serial#, count(*)
from v$active_session_history
where session_state= 'ON CPU' and
sample_time >= sysdate - interval '10' minute
group by session_id, session_serial#
order by count(*) desc
);


select * from (
select p.spid "ospid",
(se.SID),ss.serial#,ss.SQL_ID,ss.username,substr(ss.program,1,30) "program",
ss.module,ss.osuser,ss.MACHINE,ss.status,
se.VALUE/100 cpu_usage_sec
from v$session ss,v$sesstat se,
v$statname sn,v$process p
where
se.STATISTIC# = sn.STATISTIC#
and NAME like '%CPU used by this session%'
and se.SID = ss.SID
and ss.username !='SYS'
and ss.status='ACTIVE'
and ss.username is not null
and ss.paddr=p.addr and value > 0
order by se.VALUE desc);



------------------------XXXXXXXX---------------



FGA LOGS AUDIT 
 ===============
 
 https://proddev-saas.slack.com/archives/C072FSEFTV1/p1715119642413069 - With Cristian Diaz and Fred Dennis
 
 Bug 36221009 - EXACHK: TABLE AUD$[FGA_LOG$] SHOULD USE AUTOMATIC SEGMENT SPACE MANAGEMENT - Main Bug raised by Fred Dennis
 Bug 36403823 - EXACHK IS FAILING FOF TABLE AUD$[FGA_LOG$]  - Cristian Diaz
 
 
 Check Query - 
 
 SQL> select t.table_name,ts.segment_space_management 
        from dba_tables t, dba_tablespaces ts 
       where ts.tablespace_name = t.tablespace_name 
         and t.table_name in 
           ('AUD$','FGA_LOG$');


Provided by Cristian : 

set serveroutput on 
declare
is_unified_audit varchar2(10) := 'FALSE';
invalid_object_count number := 0;
begin
    BEGIN
        select upper(value) into is_unified_audit  from v$option where parameter = 'Unified Auditing';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            is_unified_audit := 'FALSE';
    END;
    IF ( is_unified_audit = 'TRUE' ) then
        invalid_object_count:=9196;
    ELSE    
        select count(ts.segment_space_management) into invalid_object_count from cdb_tables t, cdb_tablespaces ts where ts.tablespace_name = t.tablespace_name and t.table_name in ('AUD$','FGA_LOG$') and upper(ts.segment_space_management) != upper('AUTO') and ts.con_id=t.con_id;
    END if; 
    dbms_output.put_line('A3367839CF958605E053D498EB0AF7A4 = '||invalid_object_count);
for row in
    (select pdb_name, t.table_name table_name,ts.segment_space_management space_management from cdb_tables t, cdb_tablespaces ts, cdb_pdbs p where ts.tablespace_name = t.tablespace_name and t.table_name in ('AUD$','FGA_LOG$') and t.con_id = ts.con_id and p.con_id=ts.con_id union select 'ROOT', t.table_name,ts.segment_space_management from dba_tables t, dba_tablespaces ts where ts.tablespace_name = t.tablespace_name and t.table_name in ('AUD$','FGA_LOG$') order by 1,2)
    loop    
        dbms_output.put_line('PDB NAME = '||row.pdb_name||'|Table Name = '||row.table_name||'|Space Management Type = '||row.space_management||chr(13)||chr(10));
    end loop;
end;
/


set serveroutput on 
declare
is_unified_audit varchar2(10) := 'FALSE';
invalid_object_count number := 0;
begin
    BEGIN
        select upper(value) into is_unified_audit  from v$option where parameter = 'Unified Auditing';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            is_unified_audit := 'FALSE';
    END;
    IF ( is_unified_audit = 'TRUE' ) then
        invalid_object_count:=9196;
    ELSE
        select count(ts.segment_space_management) into invalid_object_count from dba_tables t, dba_tablespaces ts where ts.tablespace_name = t.tablespace_name and t.table_name in ('AUD$','FGA_LOG$') and upper(ts.segment_space_management) != upper('AUTO');
    END if;
    dbms_output.put_line('CB95A1BF5B1160ACE0431EC0E50A12EE = '||invalid_object_count);
for row in
    (select t.table_name table_name ,ts.segment_space_management space_management from dba_tables t, dba_tablespaces ts where ts.tablespace_name = t.tablespace_name and t.table_name in ('AUD$','FGA_LOG$'))
    loop
        dbms_output.put_line('Table Name = '||row.table_name||'|Space Management Type = '||row.space_management||chr(13)||chr(10));
    end loop;
end;
/


Sample Output 



A3367839CF958605E053D498EB0AF7A4 = 1
PDB NAME = EUFZIYNA_F|Table Name = AUD$|Space Management Type = AUTO

PDB NAME = EUFZIYNA_F|Table Name = FGA_LOG$|Space Management Type = MANUAL <<<----- This should be Auto 

PDB NAME = EUFZIYNA_I|Table Name = AUD$|Space Management Type = AUTO

PDB NAME = EUFZIYNA_I|Table Name = FGA_LOG$|Space Management Type = AUTO

PDB NAME = ROOT|Table Name = AUD$|Space Management Type = AUTO

PDB NAME = ROOT|Table Name = FGA_LOG$|Space Management Type = AUTO


PL/SQL procedure successfully completed.



Consumer Groups related query :
==================================


select (select COMMENTS from DBA_RSRC_PLANS where PLAN='FUSIONAPPS_PLAN') DBRM_VERSION, PLAN,GROUP_OR_SUBPLAN,ACTIVE_SESS_POOL_P1   
  from dba_rsrc_plan_directives where plan='FUSIONAPPS_PLAN' and group_or_subplan in ( 'FUSIONAPPS_ORASDPM');
 
  
select (select COMMENTS from DBA_RSRC_PLANS where PLAN='FUSIONAPPS_PLAN') DBRM_VERSION, PLAN,GROUP_OR_SUBPLAN,ACTIVE_SESS_POOL_P1   
  from dba_rsrc_plan_directives 
 where GROUP_OR_SUBPLAN='FUSIONAPPS_BATCH_GROUP';
 
 
 
 select (select COMMENTS from DBA_RSRC_PLANS where PLAN='FUSIONAPPS_PLAN') DBRM_VERSION, PLAN,GROUP_OR_SUBPLAN,ACTIVE_SESS_POOL_P1   
   from dba_rsrc_plan_directives 
  where GROUP_OR_SUBPLAN='FUSIONAPPS_ORASDPM';
  
  
 
 HOW TO FIND THE CONSUMER GROUP FOR A SQL : 
 
 SQL> select count(1) , CONSUMER_GROUP_ID from gv$active_session_history where sql_id='8s54fgxbqjsfv' group by CONSUMER_GROUP_ID order by 1 desc;

   COUNT(1) CONSUMER_GROUP_ID
 ---------- -----------------
    4337190    503510829

 SQL> select object_name from dba_objects where object_id=503510829;

 OBJECT_NAME
 ----------------------
 FUSIONAPPS_BATCH_GROUP

