# Comprehensive Data Dictionary: Student-LSA Matching Module

**Candidate**: [MY FULL NAME] | **Email**: [MY EMAIL] | **Phone**: [MY PHONE]  
**Organization**: HabotConnect FZCO  
**Database Engine**: PostgreSQL 14+  

---

## Table of Contents
1. [`lineage_audit_ledger`](#1-table-lineage_audit_ledger)
2. [`locations`](#2-table-locations)
3. [`difficulty_categories`](#3-table-difficulty_categories)
4. [`lsa_specializations`](#4-table-lsa_specializations)
5. [`students`](#5-table-students)
6. [`student_difficulties`](#6-table-student_difficulties)
7. [`student_schedules`](#7-table-student_schedules)
8. [`lsas`](#8-table-lsas)
9. [`match_allocations`](#9-table-match_allocations)
10. [`session_attendance`](#10-table-session_attendance)
11. [`system_exception_events`](#11-table-system_exception_events)
12. [`view_monthly_lsa_student_payout_report`](#12-view-view_monthly_lsa_student_payout_report)

---

### 1. Table: `lineage_audit_ledger`
**Purpose**: Central lineage registry storing valid execution task nodes across the distributed system. Serves as the foreign key anchor for immediate predecessor validation.

| Column Name | Data Type | Nullable? | PK / FK | Default / Constraint | Description & Source |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `execution_id` | `UUID` | NO | **PK** | `uuid_generate_v4()` | Unique atomic execution identifier for the task. |
| `trace_id` | `UUID` | NO | - | - | Universal trace ID for the entire lifecycle workflow. |
| `task_name` | `VARCHAR(100)`| NO | - | - | Name of pipeline task (e.g. `SD1_INTAKE_INGEST`). |
| `system_node` | `VARCHAR(100)`| NO | - | - | Host/node publishing the execution state. |
| `parent_execution_id`| `UUID` | YES | **FK** | `REFERENCES lineage_audit_ledger` | Parent execution node in DAG (NULL for root). |
| `status` | `VARCHAR(30)` | NO | - | `'COMPLETED'` | Execution state (`STARTED`, `COMPLETED`, `FAILED`). |
| `started_at` | `TIMESTAMPTZ` | NO | - | `CURRENT_TIMESTAMP` | Timestamp when task execution commenced. |
| `completed_at` | `TIMESTAMPTZ` | YES | - | - | Timestamp when task execution finalized. |
| `metadata_payload`| `JSONB` | YES | - | - | Additional task context or batch metadata. |

---

### 2. Table: `locations`
**Purpose**: 3NF reference lookup for geographic zones across UAE to eliminate repeating zone strings.

| Column Name | Data Type | Nullable? | PK / FK | Default / Constraint | Description & Source |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `location_id` | `UUID` | NO | **PK** | `uuid_generate_v4()` | Unique geographical location identifier. |
| `city_zone` | `VARCHAR(100)`| NO | - | `UNIQUE` | Specific urban zone (e.g. Dubai Marina, Al Reem). |
| `emirate_or_region`| `VARCHAR(50)` | NO | - | - | Emirate name (Dubai, Abu Dhabi, Sharjah, etc.). |
| `country_code` | `VARCHAR(3)` | NO | - | `'ARE'` | ISO-3166-1 alpha-3 country code. |
| `created_at` | `TIMESTAMPTZ` | NO | - | `CURRENT_TIMESTAMP` | Ingestion timestamp. |
| `trace_id` | `UUID` | NO | - | - | Universal lineage trace identifier. |
| `immediate_predecessor_id` | `UUID` | NO | **FK** | `REFERENCES lineage_audit_ledger` | Immediate upstream task execution ID. |

---

### 3. Table: `difficulty_categories`
**Purpose**: Standardized taxonomy catalog of special educational needs and learning difficulties.

| Column Name | Data Type | Nullable? | PK / FK | Default / Constraint | Description & Source |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `difficulty_id` | `UUID` | NO | **PK** | `uuid_generate_v4()` | Unique difficulty identifier. |
| `category_code` | `VARCHAR(20)` | NO | - | `UNIQUE` | Short code (e.g. `ADHD`, `DYSLEXIA`, `ASD`). |
| `category_name` | `VARCHAR(100)`| NO | - | - | Full name of learning difficulty category. |
| `description` | `TEXT` | YES | - | - | Pedagogical description and support guidance. |
| `created_at` | `TIMESTAMPTZ` | NO | - | `CURRENT_TIMESTAMP` | Ingestion timestamp. |
| `trace_id` | `UUID` | NO | - | - | Universal lineage trace identifier. |
| `immediate_predecessor_id` | `UUID` | NO | **FK** | `REFERENCES lineage_audit_ledger` | Immediate upstream task execution ID. |

---

### 4. Table: `lsa_specializations`
**Purpose**: Standardized taxonomy catalog of LSA domain specializations.

| Column Name | Data Type | Nullable? | PK / FK | Default / Constraint | Description & Source |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `specialization_id`| `UUID` | NO | **PK** | `uuid_generate_v4()` | Unique specialization identifier. |
| `specialization_code`| `VARCHAR(20)`| NO | - | `UNIQUE` | Short code (e.g. `BEHAVIORAL`, `LITERACY`). |
| `specialization_name`| `VARCHAR(100)`| NO| - | - | Full domain name. |
| `description` | `TEXT` | YES | - | - | Domain competency scope. |
| `created_at` | `TIMESTAMPTZ` | NO | - | `CURRENT_TIMESTAMP` | Ingestion timestamp. |
| `trace_id` | `UUID` | NO | - | - | Universal lineage trace identifier. |
| `immediate_predecessor_id` | `UUID` | NO | **FK** | `REFERENCES lineage_audit_ledger` | Immediate upstream task execution ID. |

---

### 5. Table: `students`
**Purpose**: Core child profile entity captured from SD1 (Parent Intake Web Form).

| Column Name | Data Type | Nullable? | PK / FK | Default / Constraint | Description & Source |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `student_id` | `UUID` | NO | **PK** | `uuid_generate_v4()` | Unique student identifier. |
| `full_name` | `VARCHAR(150)`| NO | - | - | Child full legal name. |
| `location_id` | `UUID` | NO | **FK** | `REFERENCES locations` | Foreign key referencing home location zone. |
| `intake_date` | `DATE` | NO | - | `CURRENT_DATE` | Date student enrolled in platform. |
| `created_at` | `TIMESTAMPTZ` | NO | - | `CURRENT_TIMESTAMP` | Database insertion timestamp. |
| `trace_id` | `UUID` | NO | - | - | Universal lineage trace identifier from SD1. |
| `immediate_predecessor_id` | `UUID` | NO | **FK** | `REFERENCES lineage_audit_ledger` | Upstream intake execution task node ID. |

---

### 6. Table: `student_difficulties`
**Purpose**: Resolves the multi-valued difficulty tags into First Normal Form (1NF).

| Column Name | Data Type | Nullable? | PK / FK | Default / Constraint | Description & Source |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `student_id` | `UUID` | NO | **PK, FK** | `REFERENCES students ON DELETE CASCADE` | Student reference. |
| `difficulty_id` | `UUID` | NO | **PK, FK** | `REFERENCES difficulty_categories` | Difficulty category reference. |
| `is_primary` | `BOOLEAN` | NO | - | `DEFAULT FALSE` | Flag indicating primary diagnosed difficulty. |
| `created_at` | `TIMESTAMPTZ` | NO | - | `CURRENT_TIMESTAMP` | Record creation timestamp. |
| `trace_id` | `UUID` | NO | - | - | Universal lineage trace identifier. |
| `immediate_predecessor_id` | `UUID` | NO | **FK** | `REFERENCES lineage_audit_ledger` | Upstream task execution ID. |

---

### 7. Table: `student_schedules`
**Purpose**: Normalized time slots representing preferred weekly availability for students.

| Column Name | Data Type | Nullable? | PK / FK | Default / Constraint | Description & Source |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `schedule_id` | `UUID` | NO | **PK** | `uuid_generate_v4()` | Unique schedule slot identifier. |
| `student_id` | `UUID` | NO | **FK** | `REFERENCES students ON DELETE CASCADE` | Enrolled child reference. |
| `day_of_week` | `SMALLINT` | NO | - | `CHECK (1 TO 7)` | ISO day of week (1=Monday, 7=Sunday). |
| `start_time` | `TIME` | NO | - | - | Preferred slot start time. |
| `end_time` | `TIME` | NO | - | `CHECK (end_time > start_time)` | Preferred slot end time. |
| `created_at` | `TIMESTAMPTZ` | NO | - | `CURRENT_TIMESTAMP` | Record creation timestamp. |
| `trace_id` | `UUID` | NO | - | - | Universal lineage trace identifier. |
| `immediate_predecessor_id` | `UUID` | NO | **FK** | `REFERENCES lineage_audit_ledger` | Upstream task execution ID. |

---

### 8. Table: `lsas`
**Purpose**: Core LSA profile entity captured from SD2 (HR Onboarding Portal).

| Column Name | Data Type | Nullable? | PK / FK | Default / Constraint | Description & Source |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `lsa_id` | `UUID` | NO | **PK** | `uuid_generate_v4()` | Unique LSA identifier. |
| `full_name` | `VARCHAR(150)`| NO | - | - | Assistant full legal name. |
| `specialization_id`| `UUID` | NO | **FK** | `REFERENCES lsa_specializations` | Primary specialization domain reference. |
| `qualification_level`| `VARCHAR(50)` | NO | - | `CHECK (Tier 1-4)` | Certified qualification tier of LSA. |
| `hourly_rate` | `NUMERIC(10,2)`| NO | - | `CHECK (hourly_rate > 0.00)` | Contracted hourly rate in AED (Golden Rule 1). |
| `is_active` | `BOOLEAN` | NO | - | `DEFAULT TRUE` | Operational availability status. |
| `onboarding_date`| `DATE` | NO | - | `CURRENT_DATE` | Date LSA completed HR onboarding. |
| `created_at` | `TIMESTAMPTZ` | NO | - | `CURRENT_TIMESTAMP` | Record creation timestamp. |
| `trace_id` | `UUID` | NO | - | - | Universal lineage trace identifier from SD2. |
| `immediate_predecessor_id` | `UUID` | NO | **FK** | `REFERENCES lineage_audit_ledger` | Upstream HR onboarding task execution ID. |

---

### 9. Table: `match_allocations`
**Purpose**: Finalized match allocations generated by the algorithmic matching engine.

| Column Name | Data Type | Nullable? | PK / FK | Default / Constraint | Description & Source |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `match_id` | `UUID` | NO | **PK** | `uuid_generate_v4()` | Unique match allocation identifier. |
| `student_id` | `UUID` | NO | **FK** | `REFERENCES students` | Matched student identifier. |
| `lsa_id` | `UUID` | NO | **FK** | `REFERENCES lsas` | Matched LSA identifier. |
| `compatibility_score`| `NUMERIC(5,4)`| NO | - | `CHECK (0.0000 TO 1.0000)` | Algorithmically computed compatibility index. |
| `match_status` | `VARCHAR(30)` | NO | - | `CHECK (ACTIVE/TERMINATED/etc)` | Match lifecycle status. |
| `effective_start_date`| `DATE` | NO | - | `CURRENT_DATE` | Date match assignment becomes active. |
| `effective_end_date`| `DATE` | YES | - | `CHECK (end >= start)` | Termination date if match completed/cancelled. |
| `created_at` | `TIMESTAMPTZ` | NO | - | `CURRENT_TIMESTAMP` | Record creation timestamp. |
| `trace_id` | `UUID` | NO | - | - | Universal lineage trace identifier. |
| `immediate_predecessor_id` | `UUID` | NO | **FK** | `REFERENCES lineage_audit_ledger` | Matching engine execution task node ID. |

---

### 10. Table: `session_attendance`
**Purpose**: Operational attendance logs ingested from SD3 (Mobile Check-in/Check-out Telemetry).

| Column Name | Data Type | Nullable? | PK / FK | Default / Constraint | Description & Source |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `session_id` | `UUID` | NO | **PK** | `uuid_generate_v4()` | Unique session attendance log identifier. |
| `match_id` | `UUID` | NO | **FK** | `REFERENCES match_allocations` | Active match allocation reference. |
| `session_start_time`| `TIMESTAMPTZ`| NO | - | - | Exact session check-in timestamp. |
| `session_end_time`| `TIMESTAMPTZ`| NO | - | `CHECK (end > start)` | Exact session check-out timestamp. |
| `verified_hours` | `NUMERIC(5,2)`| NO | - | `CHECK (verified_hours >= 0.00)`| Verified duration in decimal hours. |
| `session_status` | `VARCHAR(30)` | NO | - | `CHECK (VERIFIED/FLAGGED/etc)` | Verification status of attendance. |
| `telemetry_device_id`| `VARCHAR(100)`| YES | - | - | Mobile hardware device identifier. |
| `created_at` | `TIMESTAMPTZ` | NO | - | `CURRENT_TIMESTAMP` | Ingestion timestamp. |
| `trace_id` | `UUID` | NO | - | - | Universal lineage trace identifier from SD3. |
| `immediate_predecessor_id` | `UUID` | NO | **FK** | `REFERENCES lineage_audit_ledger` | Telemetry ingestion task execution ID. |

---

### 11. Table: `system_exception_events`
**Purpose**: Dead-letter quarantine store capturing malformed payloads, orphan attempts, and validation errors from SD4.

| Column Name | Data Type | Nullable? | PK / FK | Default / Constraint | Description & Source |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `event_id` | `UUID` | NO | **PK** | `uuid_generate_v4()` | Unique exception event identifier. |
| `failed_message_id`| `VARCHAR(100)`| NO | - | - | Identifier of the incoming failed message/packet. |
| `error_type` | `VARCHAR(100)`| NO | - | `CHECK (error_type categories)`| Specific validation error classification. |
| `system_node` | `VARCHAR(100)`| NO | - | - | System node where failure occurred. |
| `raw_failed_payload`| `JSONB` | NO | - | - | Complete raw input payload for audit/replay. |
| `event_timestamp`| `TIMESTAMPTZ`| NO | - | `CURRENT_TIMESTAMP` | Exact timestamp failure was captured. |
| `resolved` | `BOOLEAN` | NO | - | `DEFAULT FALSE` | Resolution status flag. |
| `resolution_notes`| `TEXT` | YES | - | - | Remediation notes by engineering/ops. |
| `trace_id` | `UUID` | NO | - | - | Lineage trace identifier associated with failure. |
| `immediate_predecessor_id` | `UUID` | NO | **FK** | `REFERENCES lineage_audit_ledger` | Validation engine execution task node ID. |

---

### 12. View: `view_monthly_lsa_student_payout_report`
**Purpose**: Authoritative implementation of the End Document (ED) target report.

| Column Name | Target ED Field | Data Type | Source Table & Derivation Logic |
| :--- | :--- | :--- | :--- |
| `match_allocation_id` | Match Allocation ID | `UUID` | `match_allocations.match_id` |
| `student_id` | Student ID | `UUID` | `students.student_id` |
| `student_difficulty_category`| Student Difficulty Category | `TEXT` | `STRING_AGG(DISTINCT dc.category_name, ', ')` |
| `lsa_id` | LSA ID | `UUID` | `lsas.lsa_id` |
| `lsa_qualification_level` | LSA Qualification Level | `VARCHAR(50)` | `lsas.qualification_level` |
| `match_compatibility_score`| Match Compatibility Score | `NUMERIC(5,4)` | `match_allocations.compatibility_score` |
| `total_session_hours` | Total Session Hours | `NUMERIC(6,2)` | `SUM(sa.verified_hours)` filtered by billing month |
| `hourly_payout_rate` | Hourly Payout Rate | `NUMERIC(10,2)` | `lsas.hourly_rate` (AED) |
| `total_calculated_payout` | Total Calculated Payout | `NUMERIC(12,2)` | `ROUND(SUM(sa.verified_hours) * lsas.hourly_rate, 2)` (AED) |
| `lineage_trace_id` | Lineage Trace ID | `UUID` | `match_allocations.trace_id` |
| `immediate_predecessor_id`| Immediate Predecessor ID | `UUID` | `match_allocations.immediate_predecessor_id` |
