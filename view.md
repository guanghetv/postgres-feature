
# Materialized views

Use materialized views cautiously
If you’re not familiar with materialized view they’re a query that has been actually created as a table. So it’s a materialized or basically snapshotted version of some query or “view”. In their initial version materialized versions, which were long requested in Postgres, were entirely unusuable because when you it was a locking transaction which could hold up other reads and acticities avainst that view.
They’ve since gotten much better, but there’s no tooling for refreshing them out of the box. This means you have to setup some scheduler job or cron job to regularly refresh your materialized views. If you’re building some reporting or BI app you may undoubtedly need them, but their usability could still be advanced so that Postgres knew how to more automatically refresh them.
