-- ============================================================================
-- HABOTCONNECT FZCO - STUDENT-LSA MATCHING MODULE
-- SCRIPT 02: DATABASE CONSTRAINTS & DOMAIN INTEGRITY RULES
-- 
-- Candidate: [MY FULL NAME] | [MY EMAIL] | [MY PHONE]
-- Database Engine: PostgreSQL 14+
-- Purpose: Enforces Golden Rules (hourly_rate > 0, compatibility score range,
--          positive hours, time ordering, and domain validity).
-- ============================================================================

-- ============================================================================
-- 1. GOLDEN RULE 1: HOURLY PAYOUT RATE MUST BE STRICTLY POSITIVE (> 0)
-- ============================================================================
ALTER TABLE lsas
    ADD CONSTRAINT chk_lsa_hourly_rate_positive
    CHECK (hourly_rate > 0.00);

-- Enforce valid LSA qualification tiers
ALTER TABLE lsas
    ADD CONSTRAINT chk_lsa_qualification_tier
    CHECK (qualification_level IN (
        'Tier 1 - Certified Behavioral Specialist',
        'Tier 2 - Advanced Learning Assistant',
        'Tier 3 - Senior Literacy Specialist',
        'Tier 4 - Registered Inclusion Assistant'
    ));

-- ============================================================================
-- 2. MATCH ALLOCATION COMPATIBILITY SCORE CONSTRAINT [0.0000, 1.0000]
-- ============================================================================
ALTER TABLE match_allocations
    ADD CONSTRAINT chk_match_compatibility_score_range
    CHECK (compatibility_score >= 0.0000 AND compatibility_score <= 1.0000);

-- Enforce valid match status
ALTER TABLE match_allocations
    ADD CONSTRAINT chk_match_status_valid
    CHECK (match_status IN ('PENDING', 'ACTIVE', 'PAUSED', 'TERMINATED', 'COMPLETED'));

-- Enforce effective date logic
ALTER TABLE match_allocations
    ADD CONSTRAINT chk_match_effective_dates
    CHECK (effective_end_date IS NULL OR effective_end_date >= effective_start_date);

-- Prevent duplicate active matches for the same student-LSA pair
ALTER TABLE match_allocations
    ADD CONSTRAINT uq_student_lsa_active_match
    UNIQUE (student_id, lsa_id, effective_start_date);

-- ============================================================================
-- 3. SESSION ATTENDANCE INTEGRITY CONSTRAINTS
-- ============================================================================

-- Enforce session end time occurs strictly AFTER session start time
ALTER TABLE session_attendance
    ADD CONSTRAINT chk_session_time_ordering
    CHECK (session_end_time > session_start_time);

-- Enforce verified hours cannot be negative
ALTER TABLE session_attendance
    ADD CONSTRAINT chk_session_verified_hours_non_negative
    CHECK (verified_hours >= 0.00);

-- Enforce session status domain
ALTER TABLE session_attendance
    ADD CONSTRAINT chk_session_status_valid
    CHECK (session_status IN ('PENDING_VERIFICATION', 'VERIFIED', 'FLAGGED', 'REJECTED'));

-- ============================================================================
-- 4. SCHEDULE INTEGRITY CONSTRAINTS
-- ============================================================================

-- Enforce ISO day of week range (1 = Monday, 7 = Sunday)
ALTER TABLE student_schedules
    ADD CONSTRAINT chk_schedule_day_of_week
    CHECK (day_of_week BETWEEN 1 AND 7);

-- Enforce schedule end time occurs after start time
ALTER TABLE student_schedules
    ADD CONSTRAINT chk_schedule_time_ordering
    CHECK (end_time > start_time);

-- ============================================================================
-- 5. EXCEPTION EVENT VALIDATION
-- ============================================================================

-- Enforce error type categories
ALTER TABLE system_exception_events
    ADD CONSTRAINT chk_exception_error_type
    CHECK (error_type IN (
        'ORPHAN_TELEMETRY_RECORD',
        'INVALID_PREDECESSOR_LOCK',
        'UNMATCHED_STUDENT_REQUIREMENT',
        'INACTIVE_LSA_SESSION_ATTEMPT',
        'MALFORMED_JSON_PAYLOAD',
        'RATE_CONSTRAINT_VIOLATION'
    ));
