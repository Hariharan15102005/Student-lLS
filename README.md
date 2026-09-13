# HabotConnect FZCO — Student-LSA Matching Module
## Physical Database Architecture, Data Lineage & Polyglot Persistence Strategy

**Position**: Database Structure Architect Hiring Project  
**Candidate**: [MY FULL NAME]  
**Contact**: [MY EMAIL] | [MY PHONE]  
**Primary Database Engine**: PostgreSQL 14+ (ANSI SQL Standard)  

---

## 1. Project Objective & Context

HabotConnect FZCO connects parents of children with learning difficulties (such as Attention Deficit Hyperactivity Disorder [ADHD], Dyslexia, and Autism Spectrum Disorder [ASD]) with specialized Learning Support Assistants (LSAs).

This repository contains the complete physical database architecture, data lineage model, polyglot persistence strategy, indexing design, synthetic validation dataset, and automated mistake-proofing (Poka-Yoke) test harness for the **Student-LSA Matching Module**.

The physical database is engineered to deterministically generate the authoritative **"Monthly LSA-Student Match & Payout Report"** while enforcing strict database-level constraints that prevent orphan records and guarantee end-to-end lineage locking.

---

## 2. Target End Document (ED) Mapping

The architecture accurately produces the 11 required fields in the target report:

| # | End Document (ED) Field | Physical Table | Physical Column | Business / Derivation Logic |
| :-: | :--- | :--- | :--- | :--- |
| 1 | **Match Allocation ID** | `match_allocations` | `match_id` | Unique UUID for the finalized match allocation |
| 2 | **Student ID** | `students` | `student_id` | Unique UUID of enrolled child from SD1 |
| 3 | **Student Difficulty Category** | `difficulty_categories` | `category_name` | `STRING_AGG(DISTINCT dc.category_name, ', ')` via junction table |
| 4 | **LSA ID** | `lsas` | `lsa_id` | Unique UUID of assigned assistant from SD2 |
| 5 | **LSA Qualification Level** | `lsas` | `qualification_level` | Certified competency tier (Tier 1 - 4) |
| 6 | **Match Compatibility Score** | `match_allocations` | `compatibility_score` | Algorithm-calculated index ($0.0000 \le \text{score} \le 1.0000$) |
| 7 | **Total Session Hours** | `session_attendance` | `verified_hours` | `SUM(sa.verified_hours)` verified in billing month from SD3 |
| 8 | **Hourly Payout Rate** | `lsas` | `hourly_rate` | Approved hourly rate in AED (`hourly_rate > 0.00`, Golden Rule 1) |
| 9 | **Total Calculated Payout** | Derived | Computed | `ROUND(SUM(sa.verified_hours) * l.hourly_rate, 2)` (AED) |
| 10 | **Lineage Trace ID** | Operational Tables | `trace_id` | Universal request tracing UUID (Golden Rule 2) |
| 11 | **Immediate Predecessor ID** | Operational Tables | `immediate_predecessor_id` | Lineage lock `FOREIGN KEY REFERENCES lineage_audit_ledger` |

---

## 3. Directory Structure

```
Student-LSA Matching Module/
├── README.md                                  # Complete architecture & executive guide
├── INTERVIEW_PREPARATION.md                   # 20 in-depth technical interview Q&A
├── SUBMISSION_CHECKLIST.md                    # Exact submission steps & file mapping
│
├── sql/
│   ├── 01_schema.sql                          # DDL: 11 normalized physical tables & PK/FK
│   ├── 02_constraints.sql                     # CHECK constraints, financial checks, domain rules
│   ├── 03_indexes.sql                         # B-Tree, covering, partial, and GIN JSONB indexes
│   ├── 04_sample_data.sql                     # Deterministic synthetic dataset (75 students, 25 LSAs)
│   ├── 05_validation_tests.sql                # 10 automated Poka-Yoke mistake-proofing test cases
│   └── 06_analytical_queries.sql              # Target ED report SQL view & analytical aggregations
│
├── docs/
│   ├── architecture-overview.md               # High-level architecture & pipeline narrative
│   ├── data-dictionary.md                     # Comprehensive data dictionary for all tables/columns
│   ├── lineage-mapping.md                     # SD -> LDD -> Physical -> ED traceability matrix
│   ├── polyglot-persistence.md                # Relational vs Time-Series vs NoSQL vs DW evaluation
│   ├── normalization.md                       # Formal 1NF, 2NF, 3NF decomposition proof
│   ├── indexing-strategy.md                   # Query access pattern analysis & index tradeoffs
│   └── assumptions.md                         # Explicit technical and engineering assumptions
│
├── erd/
│   ├── erd.html                               # Standalone HTML ERD canvas
│   ├── erd.css                                # Pure CSS stylesheet for ERD canvas
│   ├── erd.svg                                # High-resolution vector ERD diagram
│   ├── erd.png                                # 300-DPI high-resolution visual ERD image
│   └── business-erd.mmd                       # Editable Mermaid ERD source code
│
├── presentation/
│   └── habotconnect-database-architecture.pdf # Polished 15-slide submission presentation PDF
│
└── tests/
    └── validation-test-results.md             # Execution log and proof of all 10 Poka-Yoke tests
```

---

## 4. How to Run the SQL Scripts

### Prerequisites
- **PostgreSQL 14+** (or compatible ANSI SQL database engine)
- Standard PostgreSQL client (`psql`, pgAdmin, or DBeaver)

### Execution Sequence in PostgreSQL
```bash
# 1. Connect to PostgreSQL
psql -U postgres -d habotconnect_db

# 2. Execute schema, constraints, and indexes
\i sql/01_schema.sql
\i sql/02_constraints.sql
\i sql/03_indexes.sql

# 3. Load synthetic demonstration dataset
\i sql/04_sample_data.sql

# 4. Execute analytical queries & target payout report
\i sql/06_analytical_queries.sql
```

---

## 5. Automated Validation & Poka-Yoke Testing

To run the automated validation test suite on any platform using Python:

```bash
python tests/run_tests_validation.py
```

### Verified Test Summary (100% Pass Rate):
- **TEST 1 & 2**: Rejects `hourly_rate = 0.00` and `hourly_rate < 0.00` via database `CHECK` constraint.
- **TEST 3 & 4**: Rejects matches referencing non-existent students or LSAs via `FOREIGN KEY` constraint.
- **TEST 5**: Rejects session attendance referencing non-existent matches via `FOREIGN KEY` constraint.
- **TEST 6**: Rejects unanchored transactions referencing invalid `immediate_predecessor_id` via lineage `FOREIGN KEY` constraint.
- **TEST 7 & 8**: Rejects compatibility scores $> 1.0000$ or $< 0.0000$ via `CHECK` constraint.
- **TEST 9 & 10**: Rejects inverted session times (`end <= start`) and negative verified hours via `CHECK` constraints.

---

## 6. Synthetic Data Disclaimer

> **DISCLAIMER**:  
> *"Illustrative synthetic test data created solely for schema validation."*  
> All records in `sql/04_sample_data.sql` are deterministically generated synthetic demonstration entities designed to validate referential integrity, constraints, query logic, and reporting accuracy at scale (75 Students, 25 LSAs, 60 Matches, 225 Sessions, 22 Exceptions). No actual customer or personal data is used.

---

## 7. Polyglot Persistence Architecture Summary

| Layer | Primary Implementation | Architectural Evaluation / Alternatives |
| :--- | :--- | :--- |
| **Operational Core (OLTP)** | **PostgreSQL (Required Core)** | Strict ACID consistency, declarative foreign keys, 3NF normalization, and financial auditability. |
| **Telemetry (SD3)** | **PostgreSQL + TimescaleDB** | Time-partitioned hypertables and 90%+ compression without adding external cluster management overhead. |
| **Exception Queue (SD4)** | **PostgreSQL `JSONB`** | ACID safety and sub-millisecond GIN indexing for arbitrary malformed error payloads. |
| **Reporting (ED)** | **PostgreSQL SQL Views** | Direct, deterministic calculation for monthly billing; Cloud DW (BigQuery / Snowflake) if historical data $> 50\text{M}$ rows. |
