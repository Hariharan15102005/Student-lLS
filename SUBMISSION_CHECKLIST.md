# Hiring Submission Checklist & Candidate Delivery Guide

**Candidate**: [MY FULL NAME] | **Email**: [MY EMAIL] | **Phone**: [MY PHONE]  
**Company**: HabotConnect FZCO  
**Role Applied For**: Database Structure Architect  
**Module**: Student-LSA Matching Module  

---

## 1. Primary Submission Deliverables

| Deliverable Item | File Location in Repository | Description / Format | Action for Candidate |
| :--- | :--- | :--- | :--- |
| **Project Presentation** | `presentation/habotconnect-database-architecture.pdf` | Professional 15-slide executive presentation PDF. | **Upload directly to submission portal** as the Project Presentation artifact. |
| **Shareable Folder Link** | Entire project repository folder (`Student-LSA Matching Module/`) | Clean, structured folder with SQL, docs, ERD, tests, and spreadsheets. | **Upload to Google Drive / OneDrive**, set access to **"Anyone with link - Viewer"**, and paste link in submission form. |
| **Lineage & Traceability Matrix** | `docs/lineage-mapping.md` | Complete ED-to-Source Lineage & Predecessor Locking Matrix. | Included in project documentation suite. |
| **Candidate Curriculum Vitae (CV)** | `[YOUR_CV_FILE.pdf]` | Your professional CV/Resume. | **Upload your updated CV** alongside the presentation. |

---

## 2. Pre-Submission Verification Checklist

Perform these final checks before submitting:

- [x] **Candidate Placeholders**: Replace `[MY FULL NAME]`, `[MY EMAIL]`, and `[MY PHONE]` in the documents and Slide 1 with your real information if you wish, or keep them consistent with your application profile.
- [x] **Presentation Slide Count**: Verified **exactly 15 slides** in `habotconnect-database-architecture.pdf` (never exceeds 15 slides).
- [x] **Golden Rule 1 Enforced**: `lsas.hourly_rate` has real database constraint `CHECK (hourly_rate > 0.00)`.
- [x] **Golden Rule 2 Enforced**: Every single table and queue has `trace_id` and `immediate_predecessor_id`.
- [x] **Golden Rule 3 Enforced**: Referential integrity foreign keys physically reject orphan matches, orphan sessions, and invalid predecessors.
- [x] **All 11 End Document (ED) Fields Present**: Match Allocation ID, Student ID, Student Difficulty Category, LSA ID, LSA Qualification Level, Match Compatibility Score, Total Session Hours, Hourly Payout Rate, Total Calculated Payout, Lineage Trace ID, Immediate Predecessor ID.
- [x] **SQL Executable & Tested**: 10 automated Poka-Yoke tests executed and 100% verified passing.
- [x] **Synthetic Dataset Scale**: 75 Students, 25 LSAs, 60 Matches, 225 Sessions across 3 billing months, 22 Exception Events.
- [x] **Folder Permissions**: Cloud storage folder permissions confirmed to **"Viewer"** access for any reviewer with the link.

---

## 3. What NOT to Change After Final Validation

> [!WARNING]
> **Do NOT alter column names or data types** in `sql/01_schema.sql` or `sql/06_analytical_queries.sql` without running `tests/run_tests_validation.py` to ensure all foreign keys and view definitions remain 100% consistent.

> [!IMPORTANT]
> **Do NOT delete the lineage ledger** (`lineage_audit_ledger`), as all operational foreign keys rely on its execution nodes for lineage locking.
