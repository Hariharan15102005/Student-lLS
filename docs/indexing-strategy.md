# Indexing Strategy & Query Performance Optimization

**Candidate**: [MY FULL NAME] | **Email**: [MY EMAIL] | **Phone**: [MY PHONE]  
**Organization**: HabotConnect FZCO  
**Database Engine**: PostgreSQL 14+  

---

## 1.Indexing Philosophy & Strategy

An effective indexing strategy balances **read acceleration** against **write amplification and storage overhead**. Creating indexes on every column degrades `INSERT` and `UPDATE` throughput, especially for high-frequency telemetry ingestion from mobile devices (SD3).

In this architecture:
- Every `FOREIGN KEY` is indexed to eliminate full table scans during joins and parent-child integrity validations.
- Composite covering indexes are tailored specifically to accelerate the **Monthly LSA-Student Match and Payout Report**.
- Partial (filtered) indexes are used to index only active or unverified subsets, reducing index footprint by up to 80%.
- Generalized Inverted Indexes (`GIN`) are deployed on `JSONB` error payloads for schema-agnostic searching.

---

## 2. Comprehensive Index Inventory and  Justification

| # | Index Name | Target Table | Columns Indexed | Index Type | Query / Workload Supported | Tradeoff / Cost Analysis |
| :-: | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `idx_students_location_id` | `students` | `location_id` | B-Tree | Student geographic filtering and local matching lookups. | Minimal write overhead on student intake. |
| 2 | `idx_student_difficulties_diff_id` | `student_difficulties` | `difficulty_id` | B-Tree | Reverse lookup: find all students requiring a specific difficulty tag (e.g. ADHD). | Low write cost; essential for matching engine joins. |
| 3 | `idx_student_schedules_student_id` | `student_schedules` | `student_id` | B-Tree | Cascade validation and retrieving full weekly schedule for matching algorithms. | Maintained during intake. |
| 4 | `idx_lsas_specialization_id` | `lsas` | `specialization_id` | B-Tree | Finding candidate LSAs by competency specialization. | Static LSA table; near-zero overhead. |
| 5 | `idx_matches_student_id` | `match_allocations` | `student_id` | B-Tree | Rapid lookup of active allocations for a given student. | Maintained only during new match creation. |
| 6 | `idx_matches_lsa_id` | `match_allocations` | `lsa_id` | B-Tree | Rapid lookup of all assignments for an LSA. | Maintained only during new match creation. |
| 7 | `idx_sessions_match_id` | `session_attendance` | `match_id` | B-Tree | High-frequency telemetry check-in validation against active matches. | Critical for FK verification during high write traffic. |
| 8 | `idx_sessions_reporting_covering` | `session_attendance` | `(match_id, session_start_time)` `INCLUDE (verified_hours)` `WHERE session_status = 'VERIFIED'` | Partial B-Tree Covering Index | **Accelerates Target ED Report**: Allows index-only scans for monthly hour aggregations without touching heap table. | Covers only verified sessions; small storage footprint. |
| 9 | `idx_matches_status_compatibility` | `match_allocations` | `(match_status, compatibility_score DESC)` | Composite B-Tree | Active match filtering and compatibility ranking in reports and dashboards. | High read efficiency for active records. |
| 10 | `idx_lineage_ledger_trace_id` | `lineage_audit_ledger`| `trace_id` | B-Tree | Universal lineage search across entire distributed pipeline. | Essential for audit and compliance queries. |
| 11 | `idx_exceptions_unresolved` | `system_exception_events`| `(error_type, event_timestamp DESC)` `WHERE resolved = FALSE` | Partial B-Tree | Operations dashboard querying unresolved quarantine errors by type. | Excludes resolved events, keeping index compact. |
| 12 | `idx_exceptions_payload_gin` | `system_exception_events`| `raw_failed_payload` | GIN (JSONB) | Sub-millisecond text/attribute search inside arbitrary failed JSON payloads. | Higher write cost on failure, but exception volume is low. |

---

## 3. Query Execution Plan Optimization (Qualitative Analysis)

### Target Monthly Payout Report Query

```sql
SELECT ma.match_id, s.student_id, ..., SUM(sa.verified_hours), l.hourly_rate, ...
FROM match_allocations ma
INNER JOIN students s ON ma.student_id = s.student_id
INNER JOIN lsas l ON ma.lsa_id = l.lsa_id
LEFT JOIN session_attendance sa ON ma.match_id = sa.match_id 
    AND sa.session_status = 'VERIFIED'
    AND sa.session_start_time >= '2026-10-01' AND sa.session_start_time < '2026-11-01'
WHERE ma.match_status = 'ACTIVE'
GROUP BY ...;
```

### Execution Strategy with Our Indexes:
1. **Match Filtering**: PostgreSQL utilizes `idx_matches_status_compatibility` to fetch only `ACTIVE` allocations, skipping terminated historical matches.
2. **Dimension Joins**: Direct Hash Joins or Nested Index Scans using PKs `students.student_id` and `lsas.lsa_id`.
3. **Session Aggregation**: Uses the partial covering index `idx_sessions_reporting_covering`. Because `verified_hours` is stored in the index payload (`INCLUDE`) and filtered by date range and status, PostgreSQL performs an **Index-Only Scan**, completely avoiding disk reads from the `session_attendance` table heap.
