# Technical Interview Preparation Guide
## Position: Database Structure Architect | HabotConnect FZCO
### Project: Student-LSA Matching Module

**Candidate**: [MY FULL NAME] | **Email**: [MY EMAIL] | **Phone**: [MY PHONE]  

This guide prepares you to defend your database architecture during technical interviews. Every answer is grounded directly in the actual implementation, physical schema, and mathematical rules of this project.

---

### Q1: Why did you choose PostgreSQL as the primary relational storage engine?
**Answer**:
"I selected PostgreSQL because the operational core of the Student-LSA Matching Module demands strict ACID transaction compliance, declarative multi-table foreign key constraints, complex domain range checks (`hourly_rate > 0.00`, $0.0000 \le \text{score} \le 1.0000$), and exact fixed-point financial arithmetic (`NUMERIC`). Furthermore, PostgreSQL supports advanced features like `JSONB` with Generalized Inverted Indexes (`GIN`) for schema-agnostic exception logging and the TimescaleDB extension for high-frequency telemetry, allowing us to build a lean, unified polyglot platform without the operational complexity of managing disparate database clusters."

---

### Q2: Why did you normalize the student data into multiple tables instead of keeping it in one table?
**Answer**:
"The raw Logical Design Document contained repeating schedule slots and a list of learning difficulty tags. Leaving these in a single table violates First Normal Form (1NF) and creates update anomalies. I decomposed student data into:
1. `students`: Core child profile and geographical home zone foreign key.
2. `student_difficulties`: 1NF junction table supporting multi-valued difficulty tags.
3. `student_schedules`: 1NF availability table supporting individual weekly day/time slots.
This enables efficient SQL joins against LSA competency profiles and schedule availability during algorithmic matching."

---

### Q3: Why separate difficulty tags into a catalog table (`difficulty_categories`) and a junction table (`student_difficulties`)?
**Answer**:
"This satisfies Second Normal Form (2NF). Storing descriptive text for 'ADHD' or 'Dyslexia' directly on the student profile creates partial key dependencies and data redundancy. By maintaining a normalized catalog `difficulty_categories`, we standardize pedagogical taxonomy across the platform, avoid spelling variations, and allow updating category descriptions in a single row without modifying thousands of student records."

---

### Q4: How does your Entity Relationship Diagram (ERD) prevent orphan records?
**Answer**:
"We implement a **Dual-Layer Integrity Lock**:
1. **Domain Referential Integrity**: Declarative `FOREIGN KEY` constraints with `NOT NULL` rules guarantee that a match cannot reference a non-existent student or LSA, and a session attendance record cannot reference a non-existent match.
2. **Process Lineage Integrity**: Every operational table enforces `immediate_predecessor_id NOT NULL REFERENCES lineage_audit_ledger(execution_id)`.
This makes it physically impossible for unanchored, orphaned, or out-of-order mutations to enter the physical storage engine."

---

### Q5: What is Data Lineage, and why is it critical in this module?
**Answer**:
"Data lineage is the complete, verifiable audit trail of data from its inbound origin, through intermediate algorithmic processing, to final analytical and financial reporting. In HabotConnect, financial payouts to LSAs are subject to strict contractual compliance. Lineage allows us to trace any AED payout figure back to the exact mobile telemetry sessions, matching algorithm execution, HR onboarding rate approval, and parent intake form that generated it."

---

### Q6: What does `trace_id` represent?
**Answer**:
"`trace_id` is a universal correlation identifier (`UUID`) that spans horizontally across the entire distributed lifecycle. It connects related transactions belonging to a single workflow (e.g. an intake batch, a student matching journey, or a monthly billing cycle) across all tables, logs, and exception events."

---

### Q7: What does `immediate_predecessor_id` represent, and how does it act as a lineage lock?
**Answer**:
"`immediate_predecessor_id` is an atomic Directed Acyclic Graph (DAG) task token that points strictly to the **immediate upstream parent task execution** in `lineage_audit_ledger`. Because it is constrained as a database-level `FOREIGN KEY`, any transaction that attempts to commit without a valid, registered upstream predecessor is aborted immediately by PostgreSQL (`SQLSTATE 23503`). This forms the physical lineage lock."

---

### Q8: How did you enforce Golden Rule 1 (`hourly_rate > 0`) at the database level?
**Answer**:
"Rather than relying on application-level validation or documentation comments, I declared a database-level `CHECK` constraint on the `lsas` table:
```sql
ALTER TABLE lsas ADD CONSTRAINT chk_lsa_hourly_rate_positive CHECK (hourly_rate > 0.00);
```
Our automated Poka-Yoke test suite explicitly demonstrated that attempts to insert an LSA with `hourly_rate = 0.00` or `hourly_rate = -50.00` are rejected immediately by the PostgreSQL engine."

---

### Q9: Why evaluate a Time-Series database for SD3 mobile telemetry, and what is your recommendation?
**Answer**:
"Mobile check-in/out telemetry generates append-only, timestamp-ordered write traffic. While standard relational tables can experience index bloat and vacuum contention at high scale, a time-series engine offers automated time-chunk partitioning and column-oriented compression. My primary recommendation is the **TimescaleDB extension on PostgreSQL**. It manages `session_attendance` as an automated hypertable while retaining full SQL join capability with `match_allocations` and avoiding the operational complexity of a separate InfluxDB or Cassandra cluster."

---

### Q10: Why not store all platform data in a NoSQL Document database like MongoDB?
**Answer**:
"A pure NoSQL document store lacks declarative, multi-table foreign key constraints and transactional cross-document referential integrity. In a platform where matching depends on strict relational integrity between students, specializations, rates, and attendance logs, MongoDB would shift the burden of orphan prevention and financial consistency entirely to application code, creating severe risk of corrupted billing records."

---

### Q11: How is the Monthly Payout calculated in the target report?
**Answer**:
"Total Calculated Payout is derived deterministically in the SQL View `view_monthly_lsa_student_payout_report`:
$$\text{Total Calculated Payout (AED)} = \text{SUM}(\text{verified\_hours}) \times \text{lsas.hourly\_rate}$$
The query filters `session_attendance` for `session_status = 'VERIFIED'` within the specific monthly timestamp window, groups by match allocation, and rounds the product to 2 decimal places using fixed-point `NUMERIC(12,2)` arithmetic."

---

### Q12: Why use `DECIMAL` / `NUMERIC` for financial values instead of `FLOAT` or `DOUBLE PRECISION`?
**Answer**:
"Floating-point types use IEEE-754 binary approximations, which introduce rounding errors (e.g. $0.1 + 0.2 = 0.30000000000000004$). For financial calculations and LSA payroll in AED, fixed-point `NUMERIC(10,2)` and `NUMERIC(12,2)` guarantee exact base-10 decimal arithmetic with zero rounding drift."

---

### Q13: Why is `compatibility_score` constrained between 0.0000 and 1.0000?
**Answer**:
"The End Document specifies that the matching compatibility score is an algorithm-calculated index bounded between 0.0000 and 1.0000. I implemented this via `NUMERIC(5,4)` and a declarative `CHECK (compatibility_score >= 0.0000 AND compatibility_score <= 1.0000)`, preventing malformed or out-of-range algorithmic outputs from being saved."

---

### Q14: What indexing strategy did you implement and why?
**Answer**:
"I implemented four targeted index categories:
1. **Foreign Key B-Tree Indexes**: On all relational FK columns to eliminate sequential table scans during joins.
2. **Partial Covering Index for Reporting**: `idx_sessions_reporting_covering` on `(match_id, session_start_time) INCLUDE (verified_hours) WHERE session_status = 'VERIFIED'`. This enables **Index-Only Scans** for monthly payout aggregations, bypassing the table heap entirely.
3. **Lineage B-Tree Indexes**: On `trace_id` and `immediate_predecessor_id` for rapid DAG traversal.
4. **GIN Index on JSONB**: On `system_exception_events.raw_failed_payload` for sub-millisecond nested error payload searches."

---

### Q15: What is First Normal Form (1NF), and how was it achieved?
**Answer**:
"1NF requires that all column values be atomic and that every row be identifiable by a unique primary key. I achieved 1NF by eliminating the multi-valued difficulty tag strings into the `student_difficulties` junction table and decomposing repeating weekly schedule slots into the `student_schedules` table."

---

### Q16: What is Second Normal Form (2NF), and how was it achieved?
**Answer**:
"2NF requires that the schema be in 1NF and that all non-key attributes be fully functionally dependent on the primary key. In `student_difficulties(student_id, difficulty_id)`, difficulty descriptions depend only on `difficulty_id`. I isolated difficulty category details into `difficulty_categories`, removing partial key dependencies."

---

### Q17: What is Third Normal Form (3NF), and how was it achieved?
**Answer**:
"3NF requires that the schema be in 2NF and that no non-prime attribute be transitively dependent on the primary key. In `students`, city zone determines emirate and country. I extracted geographical hierarchies into `locations`, ensuring that non-key attributes in `students` depend solely on `student_id`."

---

### Q18: What happens when a mobile check-in arrives without a valid match?
**Answer**:
"The Validation Engine (SD4) attempts to validate the packet against `match_allocations`. Because the database enforces a `FOREIGN KEY (match_id)`, any attempt to insert an orphan session is rejected. The packet is quarantined into `system_exception_events` with error type `ORPHAN_TELEMETRY_RECORD`, preserving the full raw JSON payload for operational debugging."

---

### Q19: How does the System Exception Event Queue work?
**Answer**:
"`system_exception_events` serves as a dead-letter quarantine store. It captures failed message IDs, error classifications, system publishing nodes, timestamps, lineage tokens, and raw payloads in a `JSONB` column. A Generalized Inverted Index (`GIN`) on the payload allows engineers to query error attributes (e.g. device ID or error code) with sub-millisecond efficiency."

---

### Q20: What architectural enhancements would you propose if system scale grew 100x?
**Answer**:
"If HabotConnect expanded across the entire MENA region:
1. **Telemetry Pipeline**: Decouple mobile check-in ingestion using an Apache Kafka streaming cluster with a schema registry, persisting high-frequency GPS pings to TimescaleDB or Bigtable.
2. **Analytical Warehouse**: Offload multi-year historical reporting from PostgreSQL to Google Cloud BigQuery via change data capture (CDC / Debezium).
3. **Read Replicas**: Introduce PostgreSQL read replicas for parent-facing mobile lookups while keeping write transactions on the primary node."
