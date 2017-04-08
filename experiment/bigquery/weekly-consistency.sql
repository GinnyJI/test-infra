select /* Calculate the probability a commit flaked */
  wk,
  round(1-sum(flaked)/count(flaked),3) consistency,
  count(flaked) commits
from ( /* For each week, count whether a (num, commit) flaked */
  select
    wk,
    num,
    commit,
    max(if(passed == runs or passed == 0, 0, 1)) flaked,
    max(runs) builds
  from (
    select /* For each week, count runs and passes for a (job, num, commit) */
      wk,
      max(stamp) stamp,
      num,
      if(kind = "pull", commit, version) commit,
        sum(if(result=='SUCCESS',1,0)) passed,
        count(result) runs
    from (
      SELECT /* Find jobs for the past quarter, noting its commit, week it ran, and whether it passed */
        job,
        regexp_extract(path, r'pull/(\d+|batch)') as num, /* pr number */
        if(left(job, 3) == "pr:", "pull", "ci") kind,
        version,
        regexp_extract(metadata.value, r'^[^,]+,\d+:([^,"]+)') commit, /* git hash of pr */
        date(started) stamp,
        date(date_add(date(started), -dayofweek(started), "day")) wk, /* group by week */
        result
      FROM [k8s-gubernator:build.all]
      where
        started > date_add(current_timestamp(), -90, "DAY")
        and version != "unknown"
        and (metadata.key = 'repos' or left(job, 3) == "ci-")
      having kind=='pull'
    )
    group by wk, job, num, commit
  )
  group by wk, num, commit
)
group by wk
order by wk
