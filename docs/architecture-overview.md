# Architectural Overview: Student-LSA Matching Module

**Candidate**: [MY FULL NAME] | **Email**: [MY EMAIL] | **Phone**: [MY PHONE]  
**Organization**: HabotConnect FZCO  
**Target Role**: Database Structure Architect  
**Project**: Student-LSA Matching Module  

---

## 1. Executive Summary & Business Objective

HabotConnect FZCO operates a specialized digital matching platform connecting parents of children with learning difficulties (such as Attention Deficit Hyperactivity Disorder [ADHD], Dyslexia, and Autism Spectrum Disorder [ASD]) with accredited Learning Support Assistants (LSAs).

The **Student-LSA Matching Module** is the core operational engine responsible for:
1. Ingesting student profiles, special learning needs, location constraints, and weekly availability.
2. Managing verified LSA profiles, competency tiers, and contractually agreed hourly rates.
3. Calculating and storing algorithmic match allocations with compatibility scores.
4. Ingesting and verifying high-frequency mobile check-in/check-out telemetry session logs.
5. Reliably generating the **Monthly LSA-Student Match & Payout Report** (End Document [ED]) with exact financial calculations and end-to-end data lineage traceability.
6. Enforcing database-level mistake-proofing (Poka-Yoke) to physically prevent orphan records, invalid financial values, and unanchored state mutations.

---

## 2. Reverse-Engineering Architectural Methodology

To guarantee that the physical database architecture satisfies business requirements without unnecessary complexity or missing fields, the system was engineered using a strict backward-traceability methodology:

$$\text{Target End Document (ED)} \longleftarrow \text{Logical Design Document (LDD)} \longleftarrow \text{Source Documents (SD)}$$

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      SOURCE DOCUMENTS (INBOUND ORIGINS)                     │
├─────────────────────┬─────────────────────┬───────────────────┬─────────────┤
│ SD1: Parent Intake  │ SD2: HR Onboarding  │ SD3: Telemetry    │ SD4: Engine │
│ Web Form (Intake)   │ Portal (Staffing)   │ (Mobile Check-in) │ (Validation)│
└──────────┬──────────┴──────────┬──────────┴─────────┬─────────┴──────┬──────┘
           │                     │                    │                │
           ▼                     ▼                    ▼                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     LOGICAL DESIGN ENTITIES (CONCEPTUAL)                    │
├─────────────────────┬─────────────────────┬───────────────────┬─────────────┤
│ Entity 1: Student   │ Entity 2: LSA       │ Entity 3: Session │ Entity 4:   │
│ Profile (Demogr.)   │ Profile (Rates)     │ Attendance Log    │ Exception Q │
└──────────┬──────────┴──────────┬──────────┴─────────┬─────────┴──────┬──────┘
           │                     │                    │                │
           ▼                     ▼                    ▼                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                   PHYSICAL RELATIONAL SCHEMA (POSTGRESQL)                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ locations, difficulty_categories, students, student_difficulties,           │
│ student_schedules, lsa_specializations, lsas, match_allocations,            │
│ session_attendance, system_exception_events, lineage_audit_ledger           │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     TARGET END DOCUMENT (REPORT VIEW)                       │
├─────────────────────────────────────────────────────────────────────────────┤
│              Monthly LSA-Student Match & Payout Report (11 Fields)          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. High-Level Ingestion-to-Reporting Pipeline

1. **Intake & Staffing (SD1 & SD2)**:
   - Parents submit child profiles, difficulty tags, location zones, and availability slots.
   - HR logs approved LSAs, assigned specialization domains, qualification tiers, and approved hourly rates ($\text{hourly\_rate} > 0$).
2. **Algorithmic Matching Engine**:
   - Matches compatible students and LSAs based on difficulty specialization, schedule overlap, and geographical proximity.
   - Computes compatibility score ($0.0000 \le \text{compatibility\_score} \le 1.0000$) and records the allocation in `match_allocations`.
3. **Operational Telemetry & Session Verification (SD3)**:
   - LSAs execute sessions recorded via mobile app telemetry.
   - Sessions are validated against active matches and time constraints ($\text{session\_end\_time} > \text{session\_start\_time}$, $\text{verified\_hours} \ge 0$).
4. **Validation & Exception Handling (SD4)**:
   - Malformed payloads or invalid match attempts are quarantined into `system_exception_events` with raw `JSONB` payloads for audit and reprocessing.
5. **Monthly Financial & Operational Reporting (ED)**:
   - The authoritative SQL view `view_monthly_lsa_student_payout_report` aggregates verified hours and computes total compensation ($\text{Hours} \times \text{Rate}$) in United Arab Emirates Dirhams (AED).

---

## 4. Dual-Layer Integrity Architecture

To satisfy Golden Rules 2 and 3, the database implements two complementary layers of physical protection:

### Layer 1: Domain Referential Integrity
- Enforces relational consistency across entities via declarative `FOREIGN KEY` constraints.
- Prevents matches referencing non-existent students or LSAs.
- Prevents sessions referencing non-existent matches.

### Layer 2: Process Lineage Locking
- Every record across all operational tables carries `trace_id` (universal workflow token) and `immediate_predecessor_id` (immediate task token).
- `immediate_predecessor_id` is physically constrained as a `FOREIGN KEY REFERENCES lineage_audit_ledger(execution_id)`.
- Prevents untracked, out-of-order, or unanchored operational mutations from entering the database.

---

## 5. Architectural Principles

1. **Poka-Yoke (Automated Mistake-Proofing)**: The database is the ultimate authority of truth; business rules are enforced via database constraints, not merely application code.
2. **Explainability & Rigor**: Clean Third Normal Form (3NF) relational design in PostgreSQL without unnecessary microservice or distributed cluster overhead.
3. **Zero Orphan Guarantee**: Cascading rules and strict non-null foreign keys guarantee an orphan-free schema.
