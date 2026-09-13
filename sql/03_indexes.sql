-- ============================================================================
-- HABOTCONNECT FZCO - STUDENT-LSA MATCHING MODULE
-- SCRIPT 03: INDEXING STRATEGY & QUERY OPTIMIZATION
-- 
-- Candidate: [MY FULL NAME] | [MY EMAIL] | [MY PHONE]
-- Database Engine: PostgreSQL 14+
-- Purpose: Creates targeted indexes supporting foreign key joins, monthly
--          payout report generation, telemetry lookups, and lineage tracing.
-- ============================================================================

-- ============================================================================
-- 1. FOREIGN KEY LOOKUP INDEXES
-- Prevents table scans during relational joins and cascading validations.
-- ============================================================================

-- Index on Student location lookups
CREATE INDEX idx_students_location_id ON students(location_id);

-- Index on Student Difficulties junction table
CREATE INDEX idx_student_difficulties_diff_id ON student_difficulties(difficulty_id);

-- Index on Student Schedules
CREATE INDEX idx_student_schedules_student_id ON student_schedules(student_id);

-- Index on LSA specialization lookups
CREATE INDEX idx_lsas_specialization_id ON lsas(specialization_id);

-- Index on Match Allocations foreign keys
CREATE INDEX idx_matches_student_id ON match_allocations(student_id);
CREATE INDEX idx_matches_lsa_id ON match_allocations(lsa_id);

-- Index on Session Attendance match foreign key
CREATE INDEX idx_sessions_match_id ON session_attendance(match_id);

-- ============================================================================
-- 2. REPORTING & ANALYTICAL COMPOSITE INDEXES
-- Specifically designed to optimize the "Monthly LSA-Student Match & Payout Report".
-- ============================================================================

-- Composite index on Session Attendance for date-range aggregation and status filtering
CREATE INDEX idx_sessions_reporting_covering 
ON session_attendance(match_id, session_start_time) 
INCLUDE (verified_hours)
WHERE session_status = 'VERIFIED';

COMMENT ON INDEX idx_sessions_reporting_covering IS 
'Index-only scan support for monthly verified hours aggregation grouped by match_id.';

-- Composite index on Match Allocations for active match filtering and compatibility ranking
CREATE INDEX idx_matches_status_compatibility 
ON match_allocations(match_status, compatibility_score DESC);

-- ============================================================================
-- 3. LINEAGE & PREDECESSOR TRACEABILITY INDEXES
-- Optimizes universal lineage lookups and upstream DAG traversal.
-- ============================================================================

-- Index on trace_id across core tables for end-to-end request tracing
CREATE INDEX idx_lineage_ledger_trace_id ON lineage_audit_ledger(trace_id);
CREATE INDEX idx_lineage_ledger_parent_exec ON lineage_audit_ledger(parent_execution_id);
CREATE INDEX idx_students_trace_id ON students(trace_id);
CREATE INDEX idx_lsas_trace_id ON lsas(trace_id);
CREATE INDEX idx_matches_trace_id ON match_allocations(trace_id);
CREATE INDEX idx_sessions_trace_id ON session_attendance(trace_id);

-- Indexes on immediate_predecessor_id to validate parent links efficiently
CREATE INDEX idx_students_predecessor ON students(immediate_predecessor_id);
CREATE INDEX idx_lsas_predecessor ON lsas(immediate_predecessor_id);
CREATE INDEX idx_matches_predecessor ON match_allocations(immediate_predecessor_id);
CREATE INDEX idx_sessions_predecessor ON session_attendance(immediate_predecessor_id);

-- ============================================================================
-- 4. EXCEPTION QUEUE & SEMI-STRUCTURED JSON INDEXES
-- Supports validation engine quarantine queries and payload inspection.
-- ============================================================================

-- Index on error_type and resolution status
CREATE INDEX idx_exceptions_unresolved 
ON system_exception_events(error_type, event_timestamp DESC) 
WHERE resolved = FALSE;

-- GIN (Generalized Inverted Index) on raw JSONB failed payload for rapid key-value debugging
CREATE INDEX idx_exceptions_payload_gin 
ON system_exception_events USING GIN (raw_failed_payload);
