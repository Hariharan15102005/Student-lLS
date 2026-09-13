# Technical and Engineering Assumptions

**Candidate**: [MY FULL NAME] | **Email**: [MY EMAIL] | **Phone**: [MY PHONE]  
**Organization**: HabotConnect FZCO  
**Target Role**: Database Structure Architect  

---

## 1. Governance & Classification of Assumptions

Where the hiring project specification was silent on specific low-level implementation details, reasonable engineering decisions were adopted. To maintain complete transparency, all assumptions are categorized below.

---

### ASSUMPTION 1: Normalization of Multi-Valued Difficulty Tags
- **ASSUMPTION**: A student may have more than one diagnosed learning difficulty (e.g. ADHD co-occurring with Dyslexia), and difficulties should be modeled via a standardized reference catalog (`difficulty_categories`) and a junction table (`student_difficulties`).
- **WHY IT IS NEEDED**: The Logical Design Document (LDD) specifies a "List of learning difficulty tags". Storing comma-separated strings violates First Normal Form (1NF) and prevents indexing, analytical aggregation, and matching queries.
- **IMPACT ON DESIGN**: Created `difficulty_categories` (PK `difficulty_id`) and `student_difficulties` (composite PK `(student_id, difficulty_id)` with `is_primary` flag). The target ED report aggregates these tags using `STRING_AGG(DISTINCT dc.category_name, ', ')`.

---

### ASSUMPTION 2: Normalization of Weekly Preferred Schedules
- **ASSUMPTION**: A student's preferred schedule consists of multiple recurring weekly slots characterized by day of week (1=Monday to 7=Sunday), start time, and end time.
- **WHY IT IS NEEDED**: The LDD specifies a "Complex preferred weekly schedule (Days, Time slots)". Normalizing schedule slots into distinct rows allows relational time-overlap queries against LSA availability.
- **IMPACT ON DESIGN**: Created `student_schedules` with foreign key referencing `students(student_id)`, `day_of_week BETWEEN 1 AND 7`, and `end_time > start_time`.

---

### ASSUMPTION 3: Currency Precision & Financial Data Types
- **ASSUMPTION**: All financial amounts (hourly rates and monthly payouts) are denominated in United Arab Emirates Dirhams (AED) and modeled using fixed-point `NUMERIC(10,2)` and `NUMERIC(12,2)` rather than floating-point data types.
- **WHY IT IS NEEDED**: Floating-point types (`FLOAT`, `DOUBLE PRECISION`) suffer from binary rounding errors unsuitable for financial auditing and payroll compliance.
- **IMPACT ON DESIGN**: `lsas.hourly_rate` is modeled as `NUMERIC(10,2)` with `CHECK (hourly_rate > 0.00)`. Total calculated payout is computed and rounded to 2 decimal places in `NUMERIC(12,2)`.

---

### ASSUMPTION 4: Dual Verification of Session Attendance Hours
- **ASSUMPTION**: `verified_hours` is stored directly in `session_attendance` as confirmed by the mobile telemetry processing service, while the physical database enforces `session_end_time > session_start_time` and `verified_hours >= 0.00`.
- **WHY IT IS NEEDED**: Operational sessions may include verified breaks or mobile signal re-connections where active billable hours differ slightly from raw elapsed wall-clock time, but the database must guarantee non-negative durations and positive chronological ordering.
- **IMPACT ON DESIGN**: Stored as `NUMERIC(5,2)` with CHECK constraints preventing inverted or negative values.

---

### ASSUMPTION 5: Central Lineage Audit Ledger as the Predecessor Lock Anchor
- **ASSUMPTION**: The system uses a dedicated `lineage_audit_ledger` table to record atomic task execution nodes, and all operational tables reference this ledger via `immediate_predecessor_id`.
- **WHY IT IS NEEDED**: Golden Rules 2 and 3 require `immediate_predecessor_id` across all records and demand physical rejection of orphan predecessor links. Without a central execution anchor table, cross-entity predecessor IDs cannot be enforced by declarative relational Foreign Keys.
- **IMPACT ON DESIGN**: Created `lineage_audit_ledger` (PK `execution_id`). Every operational table defines `immediate_predecessor_id UUID NOT NULL REFERENCES lineage_audit_ledger(execution_id)`.

---

### ASSUMPTION 6: Lifecycle State Machine for Match Allocations
- **ASSUMPTION**: Match allocations progress through explicit lifecycle states (`PENDING`, `ACTIVE`, `PAUSED`, `TERMINATED`, `COMPLETED`), with only `ACTIVE` matches eligible for monthly payout report generation.
- **WHY IT IS NEEDED**: Real-world operations require student-assistant reassignments without deleting historical match records.
- **IMPACT ON DESIGN**: Added `match_status VARCHAR(30)` with CHECK constraint in `match_allocations` and filtered for `match_status = 'ACTIVE'` in the target report view.

---

### ASSUMPTION 7: Exception Event Queue Storage Strategy
- **ASSUMPTION**: The System Exception Event Queue is physically implemented as a PostgreSQL table (`system_exception_events`) with a `JSONB` payload column and GIN index.
- **WHY IT IS NEEDED**: Eliminates the operational overhead of managing separate external message queues or NoSQL clusters while providing immediate ACID transaction safety and schema-agnostic payload storage for validation engine failures.
- **IMPACT ON DESIGN**: Created `system_exception_events` with `raw_failed_payload JSONB NOT NULL` and `error_type` CHECK constraints.
