-- ============================================================================
-- HABOTCONNECT FZCO - STUDENT-LSA MATCHING MODULE
-- SCRIPT 01: CORE DDL SCHEMA DEFINITION
-- 
-- Candidate: [MY FULL NAME] | [MY EMAIL] | [MY PHONE]
-- Database Engine: PostgreSQL 14+ (Compatible with ANSI SQL standards)
-- Purpose: Creates core reference tables, entities, transaction logs, 
--          exception queue, and lineage ledger.
-- ============================================================================

-- Enable UUID extension if available
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Clean teardown (in reverse dependency order)
DROP VIEW IF EXISTS view_monthly_lsa_student_payout_report CASCADE;
DROP TABLE IF EXISTS system_exception_events CASCADE;
DROP TABLE IF EXISTS session_attendance CASCADE;
DROP TABLE IF EXISTS match_allocations CASCADE;
DROP TABLE IF EXISTS lsas CASCADE;
DROP TABLE IF EXISTS lsa_specializations CASCADE;
DROP TABLE IF EXISTS student_schedules CASCADE;
DROP TABLE IF EXISTS student_difficulties CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS difficulty_categories CASCADE;
DROP TABLE IF EXISTS locations CASCADE;
DROP TABLE IF EXISTS lineage_audit_ledger CASCADE;

-- ============================================================================
-- 1. LINEAGE ANCHOR / AUDIT LEDGER
-- Physical anchor for DAG task executions and immediate predecessor locking.
-- ============================================================================
CREATE TABLE lineage_audit_ledger (
    execution_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trace_id                UUID NOT NULL,
    task_name               VARCHAR(100) NOT NULL,
    system_node             VARCHAR(100) NOT NULL,
    parent_execution_id     UUID REFERENCES lineage_audit_ledger(execution_id),
    status                  VARCHAR(30) NOT NULL DEFAULT 'COMPLETED',
    started_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at            TIMESTAMPTZ,
    metadata_payload        JSONB
);

COMMENT ON TABLE lineage_audit_ledger IS 'Universal lineage ledger tracking task execution nodes for immediate predecessor validation.';

-- ============================================================================
-- 2. REFERENCE CATALOGS (3NF NORMALIZATION)
-- ============================================================================

-- Reference table for geographical zones (SD1: Parent Intake)
CREATE TABLE locations (
    location_id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    city_zone               VARCHAR(100) NOT NULL UNIQUE,
    emirate_or_region       VARCHAR(50) NOT NULL,
    country_code            VARCHAR(3) NOT NULL DEFAULT 'ARE',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    trace_id                UUID NOT NULL,
    immediate_predecessor_id UUID NOT NULL REFERENCES lineage_audit_ledger(execution_id)
);

COMMENT ON TABLE locations IS 'Normalized geographical location zones to eliminate repeating string anomalies.';

-- Reference table for learning difficulty categories (SD1: Parent Intake)
CREATE TABLE difficulty_categories (
    difficulty_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_code           VARCHAR(20) NOT NULL UNIQUE,
    category_name           VARCHAR(100) NOT NULL,
    description             TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    trace_id                UUID NOT NULL,
    immediate_predecessor_id UUID NOT NULL REFERENCES lineage_audit_ledger(execution_id)
);

COMMENT ON TABLE difficulty_categories IS 'Standardized taxonomy catalog of learning difficulties.';

-- Reference table for LSA specializations (SD2: HR Onboarding)
CREATE TABLE lsa_specializations (
    specialization_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    specialization_code     VARCHAR(20) NOT NULL UNIQUE,
    specialization_name     VARCHAR(100) NOT NULL,
    description             TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    trace_id                UUID NOT NULL,
    immediate_predecessor_id UUID NOT NULL REFERENCES lineage_audit_ledger(execution_id)
);

COMMENT ON TABLE lsa_specializations IS 'Standardized taxonomy catalog of LSA domain specializations.';

-- ============================================================================
-- 3. CORE ENTITIES (STUDENTS & LSAS)
-- ============================================================================

-- Student Profile (Entity 1 / SD1: Parent Intake Web Form)
CREATE TABLE students (
    student_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    full_name               VARCHAR(150) NOT NULL,
    location_id             UUID NOT NULL REFERENCES locations(location_id),
    intake_date             DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    trace_id                UUID NOT NULL,
    immediate_predecessor_id UUID NOT NULL REFERENCES lineage_audit_ledger(execution_id)
);

COMMENT ON TABLE students IS 'Child profiles captured during parental intake.';

-- Student Difficulty Junction Table (1NF Normalization of multi-valued tags)
CREATE TABLE student_difficulties (
    student_id              UUID NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    difficulty_id           UUID NOT NULL REFERENCES difficulty_categories(difficulty_id),
    is_primary              BOOLEAN NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    trace_id                UUID NOT NULL,
    immediate_predecessor_id UUID NOT NULL REFERENCES lineage_audit_ledger(execution_id),
    PRIMARY KEY (student_id, difficulty_id)
);

COMMENT ON TABLE student_difficulties IS 'Resolves many-to-many relationship between students and difficulty categories.';

-- Student Preferred Schedule (1NF Normalization of complex weekly schedule slots)
CREATE TABLE student_schedules (
    schedule_id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id              UUID NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    day_of_week             SMALLINT NOT NULL, -- 1 = Monday, 7 = Sunday
    start_time              TIME NOT NULL,
    end_time                TIME NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    trace_id                UUID NOT NULL,
    immediate_predecessor_id UUID NOT NULL REFERENCES lineage_audit_ledger(execution_id)
);

COMMENT ON TABLE student_schedules IS 'Normalized availability time slots for enrolled students.';

-- LSA Profile (Entity 2 / SD2: HR Onboarding Portal)
CREATE TABLE lsas (
    lsa_id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    full_name               VARCHAR(150) NOT NULL,
    specialization_id       UUID NOT NULL REFERENCES lsa_specializations(specialization_id),
    qualification_level     VARCHAR(50) NOT NULL, -- e.g. Tier 1 - Certified Specialist
    hourly_rate             NUMERIC(10, 2) NOT NULL,
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    onboarding_date         DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    trace_id                UUID NOT NULL,
    immediate_predecessor_id UUID NOT NULL REFERENCES lineage_audit_ledger(execution_id)
);

COMMENT ON TABLE lsas IS 'Approved Learning Support Assistants and verified hourly compensation rates.';

-- ============================================================================
-- 4. MATCH ALLOCATIONS & OPERATIONAL TRANSACTIONS
-- ============================================================================

-- Match Allocation (Target Report Dimension / Algorithmic Output)
CREATE TABLE match_allocations (
    match_id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id              UUID NOT NULL REFERENCES students(student_id),
    lsa_id                  UUID NOT NULL REFERENCES lsas(lsa_id),
    compatibility_score     NUMERIC(5, 4) NOT NULL, -- Precision 0.0000 to 1.0000
    match_status            VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    effective_start_date    DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_end_date      DATE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    trace_id                UUID NOT NULL,
    immediate_predecessor_id UUID NOT NULL REFERENCES lineage_audit_ledger(execution_id)
);

COMMENT ON TABLE match_allocations IS 'Finalized match allocations between students and LSAs with compatibility index.';

-- Session Attendance Log (Entity 3 / SD3: Mobile Telemetry)
CREATE TABLE session_attendance (
    session_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    match_id                UUID NOT NULL REFERENCES match_allocations(match_id),
    session_start_time      TIMESTAMPTZ NOT NULL,
    session_end_time        TIMESTAMPTZ NOT NULL,
    verified_hours          NUMERIC(5, 2) NOT NULL,
    session_status          VARCHAR(30) NOT NULL DEFAULT 'VERIFIED',
    telemetry_device_id     VARCHAR(100),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    trace_id                UUID NOT NULL,
    immediate_predecessor_id UUID NOT NULL REFERENCES lineage_audit_ledger(execution_id)
);

COMMENT ON TABLE session_attendance IS 'Verified operational attendance records originating from mobile check-in/out telemetry.';

-- ============================================================================
-- 5. SYSTEM EXCEPTION EVENT QUEUE (ENTITY 4 / SD4)
-- ============================================================================

-- Exception Event Queue (SD4: Validation Engine / Dead-Letter Quarantine)
CREATE TABLE system_exception_events (
    event_id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    failed_message_id       VARCHAR(100) NOT NULL,
    error_type              VARCHAR(100) NOT NULL,
    system_node             VARCHAR(100) NOT NULL,
    raw_failed_payload      JSONB NOT NULL,
    event_timestamp         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved                BOOLEAN NOT NULL DEFAULT FALSE,
    resolution_notes        TEXT,
    trace_id                UUID NOT NULL,
    immediate_predecessor_id UUID NOT NULL REFERENCES lineage_audit_ledger(execution_id)
);

COMMENT ON TABLE system_exception_events IS 'Quarantine store for malformed payloads, orphan attempts, and validation failures.';
