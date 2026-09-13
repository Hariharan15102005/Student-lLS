# Polyglot Persistence Strategy & Storage Engine Evaluation

**Candidate**: [MY FULL NAME] | **Email**: [MY EMAIL] | **Phone**: [MY PHONE]  
**Organization**: HabotConnect FZCO  
**Database Engine Evaluation**: Relational vs. Time-Series vs. NoSQL vs. OLAP Warehouse  

---

## 1. Architectural Philosophy

Polyglot persistence is the practice of utilizing different data storage technologies for different data categories based on their specific read/write access patterns, consistency requirements, transaction semantics, and scale characteristics.

However, a senior Database Architect avoids adding storage technologies merely for cosmetic complexity. In this architecture:
- We **recommend practical, lean, and highly reliable storage engines**.
- We **evaluate industry alternatives** transparently and document the precise scale thresholds that would justify migrating to specialized engines.

---

## 2. Storage Engine Decision Matrix

| Data Category | Target Entity / Workflow | Primary Technology Choice | Engineering Rationale & Tradeoffs | Evaluated Alternative & Migration Threshold |
| :--- | :--- | :--- | :--- | :--- |
| **Core Relational Profiles** | `students`, `lsas`, `locations`, `difficulties`, `schedules` | **PostgreSQL (Relational OLTP)** | Strict ACID consistency, declarative foreign keys, multi-table normalization, sub-millisecond point lookups. | **MongoDB / DocumentDB**: Evaluated and rejected for operational OLTP because document stores lack declarative multi-table foreign key cascade enforcement and relational joins. |
| **Matching & Allocation Domain** | `match_allocations` | **PostgreSQL (Relational OLTP)** | Enforces range checks on compatibility score ($[0.0000, 1.0000]$), prevents duplicate active matches with composite unique constraints. | **Graph DB (Neo4j)**: Evaluated; beneficial if multi-hop student-peer social graphs are required, but overengineered for standard 1:1 or 1:many student-LSA matching. |
| **Operational & Financial Transactions** | `session_attendance` | **PostgreSQL (Relational OLTP)** | Financial auditability, exact fixed-point arithmetic (`NUMERIC`), strict time ordering constraints. | **Redis / DynamoDB**: Rejected; key-value stores cannot perform complex date-filtered aggregation ($Hours \times Rate$) with referential validation. |
| **High-Frequency Mobile Telemetry** | Raw mobile check-in/out pings, GPS fixes, heartbeat pings | **PostgreSQL + TimescaleDB Extension** | Provides automatic time-partitioned hypertables and 90%+ column-oriented compression within the existing PostgreSQL instance. | **Dedicated InfluxDB / Apache Cassandra**: Recommended only if raw GPS telemetry ingestion exceeds 100,000 writes/second across UAE operations. |
| **System Exception Quarantine** | `system_exception_events` | **PostgreSQL `JSONB` Table** | Immediate transactional consistency with validation engine, native GIN indexing on arbitrary error payloads. | **Apache Kafka DLQ + Elasticsearch**: Recommended when decoupled asynchronous event streaming across microservices exceeds 10,000 error events/minute. |
| **Analytical Reporting & Payouts** | Monthly LSA-Student Match & Payout Report | **PostgreSQL SQL Views / Materialized Views** | Real-time calculation directly from verified tables; zero ETL lag or sync discrepancy for monthly billing. | **Google Cloud BigQuery / Snowflake**: Recommended as an OLAP analytical data warehouse when historical session data exceeds 50 million records / multi-terabyte scale. |

---

## 3. Deep Dive: High-Frequency Mobile Telemetry (SD3)

Mobile check-in/check-out telemetry generates distinct write patterns compared to parent profile updates:
- **Write Profile**: High write volume, append-only, sequential timestamps, occasional GPS location drift.
- **Query Profile**: Time-bounded range queries (e.g. "fetch all telemetry between 09:00 and 11:30 for match $M$").

### Primary Recommendation: PostgreSQL with TimescaleDB
- **How it works**: The `session_attendance` table is managed as a TimescaleDB *hypertable*, partitioned automatically into 7-day chunks by `session_start_time`.
- **Advantages**:
  1. Preserves full SQL join compatibility with `match_allocations` and `lsas`.
  2. Eliminates the operational burden of managing a separate distributed database cluster.
  3. Achieves transparent compression and automated data retention policies.

---

## 4. Deep Dive: System Exception Event Queue (SD4)

The **Validation Engine** catches malformed JSON strings, orphan foreign keys, and rate violations.

### Primary Recommendation: PostgreSQL `JSONB` with GIN Indexing
- **Structure**: The `system_exception_events` table stores the raw failed payload in a `JSONB` column.
- **Advantages**:
  1. Schema-agnostic: Any malformed packet structure can be captured without breaking table schemas.
  2. GIN Indexed: Engineers can search inside the failed JSON payload for specific nested keys (e.g. `raw_failed_payload @> '{"device": "MOB-99"}'`) with indexed sub-millisecond execution.
  3. Zero Additional Infrastructure: Eliminates the complexity of maintaining external NoSQL document databases for an entry-to-mid scale platform.
