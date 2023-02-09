select 
	p.name as 'Maintenance Plan'
	,p.[description] as 'Description'
	,j.name as 'Job Name'
from msdb..sysmaintplan_plans p
	inner join msdb..sysmaintplan_subplans sp
	on p.id = sp.plan_id
	inner join msdb..sysjobs j
	on sp.job_id = j.job_id
where j.[enabled] = 1