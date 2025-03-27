drop table if exists #cr;
drop table if exists #ct_cohort;
drop table if exists #final_cohort;

select B.person_id, B.measurement_datetime, B.measurement_date, B.value_as_number into #cr 
from @target_database_schema.@target_cohort_table A, @cdm_database_schema.measurement B
where A.subject_id = B.person_id
and b.measurement_date between dateadd(day, -2, a.cohort_start_date) and dateadd(day, 7, a.cohort_start_date) --temporary 3
and measurement_concept_id IN (3016723,3051825)
and value_as_number is not null and A.cohort_definition_id in (119,120); -- serum creatinine

select A.subject_id as person_id, A.cohort_start_date as ct_date,
       avg(value_as_number) as base_cr -- median value of CT -3~0 days creatinin
       into #ct_cohort
from @target_database_schema.@target_cohort_table A, #cr B, (select * from @target_database_schema.@target_cohort_table where cohort_definition_id= 121) C -- using target, compartor cohorts
where a.subject_id = B.person_id and A.cohort_definition_id in (119,120) and (C.cohort_start_date between a.cohort_start_date and dateadd(day, 7, a.cohort_start_date)) and 
(b.measurement_date between dateadd(day, -2, a.cohort_start_date) and a.cohort_start_date)
group by A.subject_id, A.cohort_start_date;

select distinct A.person_id, b.measurement_date as start_date, dateadd(day, 1, b.measurement_date) as end_date
into #final_cohort
from #ct_cohort A, #cr B, (select * from @target_database_schema.@target_cohort_table where cohort_definition_id=122) C
where A.person_id = B.person_id and b.measurement_date between a.ct_date and  dateadd(day, 7, a.ct_date)
  and ((A.base_cr * 3 < B.value_as_number) or (B.value_as_number>4)  -- 3 times or 4mg/dl 
  or (C.subject_id=A.person_id and C.cohort_start_date between dateadd(day, 4, a.ct_date) and  dateadd(day, 7, a.ct_date))) -- dialysis
  ; --> Cr in 1~7 days

DELETE FROM @target_database_schema.@target_cohort_table where cohort_definition_id = @target_cohort_id; -- target_cohort_id
INSERT INTO @target_database_schema.@target_cohort_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
select @target_cohort_id as cohort_definition_id, person_id, start_date, end_date
FROM #final_cohort CO;

drop table if exists #final_cohort;
