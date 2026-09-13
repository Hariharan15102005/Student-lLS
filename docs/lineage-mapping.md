# Data Lineage Architecture & Source-to-Target Traceability Matrix

**Candidate**: [MY FULL NAME] | **Email**: [MY EMAIL] | **Phone**: [MY PHONE]  
**Organization**: HabotConnect FZCO  
**Database Engine**: PostgreSQL 14+  

---

## 1. Lineage Architecture & Conceptual Foundation

Data Lineage in the HabotConnect architecture provides a complete, tamper-evident audit trail for every piece of data from the moment it enters the system through web forms, HR systems, or mobile telemetry, until it is aggregated into financial payout reports.

### The Two Mandatory Lineage Tokens (Golden Rule 2)

1. **`trace_id` (Universal Workflow Token)**:
   - **Semantics**: A globally unique identifier (`UUID`) assigned at the initiation of a business workflow (e.g. an intake batch, a student journey, or an operational billing cycle).
   - **Scope**: Propagates horizontally across all downstream tables, logs, and exception events.
   - **Use Case**: Allows auditors and engineers to query all database records belonging to a specific customer journey or matching run with a single indexed lookup.

2. **`immediate_predecessor_id` (Atomic DAG Lineage Lock)**:
   - **Semantics**: A unique identifier (`UUID`) pointing strictly to the **immediate upstream parent task or state transition** in the Directed Acyclic Graph (DAG) that produced this record.
   - **Scope**: Strictly enforced at the database level via a declarative `FOREIGN KEY REFERENCES lineage_audit_ledger(execution_id)`.
   - **Use Case**: Guarantees causal ordering, prevents orphan/unanchored records, and enables recursive root-cause analysis when diagnosing anomalies.

---

## 2. Lineage DAG Flowchart

```
[SD1: Parent Intake Batch]              [SD2: HR Onboarding Batch]
(Task: SD1_INTAKE_INGEST)               (Task: SD2_HR_ONBOARDING_INGEST)
(Exec ID: a000...002)                   (Exec ID: a000...003)
          │                                       │
          ▼                                       ▼
    ┌───────────┐                           ┌───────────┐
    │ students  │                           │   lsas    │
    └─────┬─────┘                           └─────┬─────┘
          │                                       │
          └───────────────────┬───────────────────┘
                              ▼
                [Matching Algorithm Execution]
                (Task: MATCHING_ENGINE_EXECUTION)
                (Exec ID: a000...004)
                              │
                              ▼
                    ┌───────────────────┐
                    │ match_allocations │
                    └─────────┬─────────┘
                              │
                              ▼
                [SD3: Mobile Telemetry Ingest]
                (Task: SD3_MOBILE_TELEMETRY_INGEST)
                (Exec ID: a000...005)
                              │
                              ▼
                    ┌───────────────────┐
                    │session_attendance │
                    └─────────┬─────────┘
                              │
                              ▼
                [End Document Reporting View]
                (view_monthly_lsa_student_payout_report)
```

---

## 3. Comprehensive Source-to-Target Lineage Matrix

This matrix maps every field of the final target report (**"Monthly LSA-Student Match & Payout Report"**) back through physical structures, logical entities, and raw source documents:

| # | Target ED Report Field | Logical Entity (LDD) | Inbound Source (SD) | Physical Table | Physical Column | Data Type | Transformation & Derivation Logic | Validation & Poka-Yoke Rule |
| :-: | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | **Match Allocation ID** | Match Allocation | SD1 + SD2 via Matching Engine | `match_allocations` | `match_id` | `UUID` | Direct PK extraction | Primary Key, Non-Null |
| 2 | **Student ID** | Student Profile | SD1: Parent Intake Web Form | `students` | `student_id` | `UUID` | Direct FK extraction | Foreign Key to `students(student_id)` |
| 3 | **Student Difficulty Category** | Student Profile | SD1: Parent Intake Web Form | `difficulty_categories` | `category_name` | `TEXT` | `STRING_AGG(DISTINCT dc.category_name, ', ')` | Resolves multi-tag junction table `student_difficulties` |
| 4 | **LSA ID** | LSA Profile | SD2: HR Onboarding Portal | `lsas` | `lsa_id` | `UUID` | Direct FK extraction | Foreign Key to `lsas(lsa_id)` |
| 5 | **LSA Qualification Level** | LSA Profile | SD2: HR Onboarding Portal | `lsas` | `qualification_level` | `VARCHAR(50)` | Direct extraction | `CHECK (qualification_level IN ('Tier 1'...'Tier 4'))` |
| 6 | **Match Compatibility Score** | Match Allocation | Algorithmic Matching Node | `match_allocations` | `compatibility_score` | `NUMERIC(5,4)`| Direct extraction | `CHECK (compatibility_score BETWEEN 0.0000 AND 1.0000)` |
| 7 | **Total Session Hours** | Session Attendance Log | SD3: Mobile Telemetry | `session_attendance` | `verified_hours` | `NUMERIC(6,2)`| `SUM(sa.verified_hours)` filtered by billing month | `CHECK (verified_hours >= 0.00)` and `end > start` |
| 8 | **Hourly Payout Rate** | LSA Profile | SD2: HR Onboarding Portal | `lsas` | `hourly_rate` | `NUMERIC(10,2)`| Direct extraction | `CHECK (hourly_rate > 0.00)` (Golden Rule 1, AED) |
| 9 | **Total Calculated Payout** | Financial Derivation | Derived from SD2 & SD3 | Derived Metric | Computed | `NUMERIC(12,2)`| `ROUND(SUM(sa.verified_hours) * l.hourly_rate, 2)` | Strict multiplication in AED; no negative values |
| 10 | **Lineage Trace ID** | Universal Trace | Distributed Pipeline | `match_allocations` | `trace_id` | `UUID` | Direct extraction | `NOT NULL`, indexed for cross-pipeline query |
| 11 | **Immediate Predecessor ID** | Lineage Lock | Task Execution Token | `match_allocations` | `immediate_predecessor_id` | `UUID` | Direct extraction | `FOREIGN KEY REFERENCES lineage_audit_ledger(execution_id)` |

---

## 4. How the Validation Engine Detects Orphan & Corrupted Records

The **Validation Engine (SD4)** runs continuous operational verification queries:

1. **Orphan Telemetry Detection**:
   - Query: Identifies mobile check-in attempts where `match_id` does not match an active row in `match_allocations`.
   - Action: Telemetry packet is rejected from `session_attendance` and quarantined into `system_exception_events` with error type `ORPHAN_TELEMETRY_RECORD`.
2. **Invalid Predecessor Detection**:
   - Query: Intercepts inbound batch records whose `immediate_predecessor_id` is missing from `lineage_audit_ledger`.
   - Action: Database foreign key immediately aborts transaction; record is quarantined as `INVALID_PREDECESSOR_LOCK`.
3. **Capacity & Inactive LSA Violations**:
   - Query: Identifies sessions logged for LSAs whose status is `is_active = FALSE`.
   - Action: Quarantined as `INACTIVE_LSA_SESSION_ATTEMPT`.
