# Normalization Analysis & Schema Decomposition (1NF, 2NF, 3NF)

**Candidate**: [MY FULL NAME] | **Email**: [MY EMAIL] | **Phone**: [MY PHONE]  
**Organization**: HabotConnect FZCO  
**Database Engine**: PostgreSQL 14+  

---

## 1. Overview of Normalization Strategy

The conceptual entities described in the Logical Design Document (LDD) contain multi-valued attributes, composite schedules, and non-key dependencies. Storing them as unnormalized, monolithic tables would lead to severe insertion, update, and deletion anomalies.

We apply formal relational normalization principles up to **Third Normal Form (3NF)** while maintaining intentional, controlled aggregation at the reporting boundary.

---

## 2. Step-by-Step Normalization Analysis

```
┌─────────────────────────┐
│     UNNORMALIZED        │ Multi-valued difficulty strings ("ADHD, Dyslexia")
│     STUDENT INTAKE      │ Repeating schedule slots ("Mon 9-11, Wed 2-4")
└────────────┬────────────┘
             │
             ▼ [Resolve 1NF: Atomic values, eliminate repeating groups]
┌─────────────────────────┐
│       FIRST NORMAL      │ • student_difficulties junction table
│        FORM (1NF)       │ • student_schedules individual slot rows
└────────────┬────────────┘
             │
             ▼ [Resolve 2NF: Eliminate partial key dependencies]
┌─────────────────────────┐
│      SECOND NORMAL      │ • Separate difficulty_categories catalog
│        FORM (2NF)       │ • All non-key attributes fully functionally dependent on PK
└────────────┬────────────┘
             │
             ▼ [Resolve 3NF: Eliminate transitive dependencies]
┌─────────────────────────┐
│       THIRD NORMAL      │ • locations table (eliminates city -> region transitive dep)
│        FORM (3NF)       │ • lsa_specializations catalog
└─────────────────────────┘
```

---

### Step 1: First Normal Form (1NF) Compliance

**Definition**: All column values must be atomic (no repeating groups, arrays, or comma-separated lists), and each table must possess a unique Primary Key.

- **Violation in Raw LDD**:
  - Entity 1 contains `List of learning difficulty tags` (e.g. `"ADHD, Dyslexia, Speech"`).
  - Entity 1 contains `Complex preferred weekly schedule (Days, Time slots)`.
- **1NF Resolution**:
  1. Multi-valued difficulty tags are decomposed into the junction table `student_difficulties(student_id, difficulty_id)`.
  2. Repeating schedule slots are decomposed into individual atomic rows in `student_schedules(schedule_id, student_id, day_of_week, start_time, end_time)`.
  3. Every table is assigned an immutable surrogate Primary Key (`UUID`).

---

### Step 2: Second Normal Form (2NF) Compliance

**Definition**: The relation must be in 1NF, and every non-prime attribute must be fully functionally dependent on the entire Primary Key (no partial key dependencies).

- **Evaluation of Composite Keys**:
  - In `student_difficulties(student_id, difficulty_id)`, the composite primary key is `(student_id, difficulty_id)`.
  - The non-key attribute `is_primary` depends on the **entire composite key** (a difficulty is designated primary specifically for that student).
  - Difficulty metadata (`category_name`, `description`) depends only on `difficulty_id`. Therefore, difficulty metadata is isolated in its own relation `difficulty_categories`, completely eliminating partial key dependency.

---

### Step 3: Third Normal Form (3NF) Compliance

**Definition**: The relation must be in 2NF, and no non-prime attribute may be transitively dependent on the Primary Key ($X \rightarrow Y \rightarrow Z$).

- **Violation in Unnormalized Schema**:
  - In `students`, storing `city_zone` along with `emirate_or_region` and `country_code` creates a transitive dependency:
    $$\text{student\_id} \longrightarrow \text{city\_zone} \longrightarrow \text{emirate\_or\_region}$$
  - In `lsas`, storing `specialization_name` and `specialization_description` alongside LSA profile info creates a transitive dependency:
    $$\text{lsa\_id} \longrightarrow \text{specialization\_id} \longrightarrow \text{specialization\_name}$$
- **3NF Resolution**:
  1. Geographical hierarchy is moved into `locations(location_id, city_zone, emirate_or_region, country_code)`. `students` stores only the foreign key `location_id`.
  2. LSA specialization taxonomy is isolated in `lsa_specializations(specialization_id, specialization_name)`. `lsas` stores only `specialization_id`.

---

## 3. Avoidance of Database Modification Anomalies

| Anomaly Type | Problem in Unnormalized Schema | How Our 3NF Design Prevents It |
| :--- | :--- | :--- |
| **Insertion Anomaly** | Cannot create a new learning difficulty category or LSA specialization domain until a student or LSA registers for it. | Categories exist independently in `difficulty_categories` and `lsa_specializations`. |
| **Update Anomaly** | Changing the description or name of "Dyslexia" or "Dubai Marina" requires updating hundreds of student records. | Updating the catalog record in `difficulty_categories` or `locations` instantly updates all references. |
| **Deletion Anomaly** | Deleting the only student in a specific location deletes all record of that location existing in the platform. | Deleting a student in `students` leaves the geographical zone intact in `locations`. |

---

## 4. Intentional Denormalization / Aggregation at Reporting Boundary

While operational OLTP tables are strictly in 3NF, the target End Document (**Monthly LSA-Student Match & Payout Report**) requires aggregated metrics (`total_session_hours`, `total_calculated_payout`, `student_difficulty_category`).

- **Architecture Choice**: This is achieved via a non-materialized SQL View `view_monthly_lsa_student_payout_report`.
- **Justification**: Eliminates stored redundancy in transactional tables while presenting a clean, pre-aggregated interface for billing and financial auditing.
