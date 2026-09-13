-- ============================================================================
-- HABOTCONNECT FZCO - STUDENT-LSA MATCHING MODULE
-- SCRIPT 06: TARGET REPORT & ANALYTICAL QUERIES
-- 
-- Candidate: [MY FULL NAME] | [MY EMAIL] | [MY PHONE]
-- Database Engine: PostgreSQL 14+
-- Purpose: Generates the target End Document (ED) report:
--          "Monthly LSA-Student Match & Payout Report" and analytical queries.
-- ============================================================================

-- ============================================================================
-- 1. PRIMARY TARGET REPORT VIEW: MONTHLY LSA-STUDENT MATCH & PAYOUT REPORT
-- Exact mapping of all 11 required End Document (ED) fields.
-- ============================================================================

CREATE OR REPLACE VIEW view_monthly_lsa_student_payout_report AS
SELECT 
    -- 1. Match Allocation ID (Unique identifier for finalized match)
    ma.match_id AS match_allocation_id,
    
    -- 2. Student ID (Unique identifier of enrolled child)
    s.student_id AS student_id,
    
    -- 3. Student Difficulty Category (Aggregated standardized difficulty tags)
    STRING_AGG(DISTINCT dc.category_name, ', ' ORDER BY dc.category_name) AS student_difficulty_category,
    
    -- 4. LSA ID (Unique identifier of assigned LSA)
    l.lsa_id AS lsa_id,
    
    -- 5. LSA Qualification Level (Certified competency tier)
    l.qualification_level AS lsa_qualification_level,
    
    -- 6. Match Compatibility Score (Algorithm-calculated index: 0.0000 to 1.0000)
    ma.compatibility_score AS match_compatibility_score,
    
    -- 7. Total Session Hours (Verified session hours completed in billing month)
    COALESCE(SUM(sa.verified_hours), 0.00) AS total_session_hours,
    
    -- 8. Hourly Payout Rate (Approved hourly rate in AED, strictly > 0)
    l.hourly_rate AS hourly_payout_rate,
    
    -- 9. Total Calculated Payout (Hours * Hourly Rate in AED)
    ROUND(COALESCE(SUM(sa.verified_hours), 0.00) * l.hourly_rate, 2) AS total_calculated_payout,
    
    -- 10. Lineage Trace ID (Universal request tracing identifier)
    ma.trace_id AS lineage_trace_id,
    
    -- 11. Immediate Predecessor ID (Lineage lock referencing upstream task)
    ma.immediate_predecessor_id AS immediate_predecessor_id

FROM match_allocations ma
INNER JOIN students s 
    ON ma.student_id = s.student_id
INNER JOIN student_difficulties sd 
    ON s.student_id = sd.student_id
INNER JOIN difficulty_categories dc 
    ON sd.difficulty_id = dc.difficulty_id
INNER JOIN lsas l 
    ON ma.lsa_id = l.lsa_id
LEFT JOIN session_attendance sa 
    ON ma.match_id = sa.match_id 
    AND sa.session_status = 'VERIFIED'
    AND sa.session_start_time >= '2026-10-01 00:00:00+04' 
    AND sa.session_start_time < '2026-11-01 00:00:00+04'

WHERE ma.match_status = 'ACTIVE'

GROUP BY 
    ma.match_id,
    s.student_id,
    l.lsa_id,
    l.qualification_level,
    ma.compatibility_score,
    l.hourly_rate,
    ma.trace_id,
    ma.immediate_predecessor_id;

COMMENT ON VIEW view_monthly_lsa_student_payout_report IS 
'Authoritative End Document (ED) view producing the Monthly LSA-Student Match & Payout Report.';

-- Execute the Target Report for October 2026:
SELECT * 
FROM view_monthly_lsa_student_payout_report
ORDER BY total_calculated_payout DESC, match_compatibility_score DESC
LIMIT 15;

-- ============================================================================
-- 2. SUPPORTING ANALYTICAL QUERY 1: LSA AGGREGATED MONTHLY PAYOUT SUMMARY
-- ============================================================================
SELECT 
    l.lsa_id,
    l.full_name AS lsa_name,
    l.qualification_level,
    l.hourly_rate,
    COUNT(DISTINCT ma.match_id) AS active_matches_count,
    COUNT(sa.session_id) AS completed_sessions_count,
    COALESCE(SUM(sa.verified_hours), 0.00) AS total_monthly_hours,
    ROUND(COALESCE(SUM(sa.verified_hours), 0.00) * l.hourly_rate, 2) AS total_monthly_payout_aed
FROM lsas l
INNER JOIN match_allocations ma ON l.lsa_id = ma.lsa_id AND ma.match_status = 'ACTIVE'
LEFT JOIN session_attendance sa ON ma.match_id = sa.match_id 
    AND sa.session_status = 'VERIFIED'
    AND sa.session_start_time >= '2026-10-01 00:00:00+04' 
    AND sa.session_start_time < '2026-11-01 00:00:00+04'
GROUP BY l.lsa_id, l.full_name, l.qualification_level, l.hourly_rate
ORDER BY total_monthly_payout_aed DESC;

-- ============================================================================
-- 3. SUPPORTING ANALYTICAL QUERY 2: STUDENTS GROUPED BY DIFFICULTY & LOCATION
-- ============================================================================
SELECT 
    dc.category_name AS difficulty_category,
    loc.city_zone,
    loc.emirate_or_region,
    COUNT(DISTINCT s.student_id) AS enrolled_students_count
FROM students s
INNER JOIN student_difficulties sd ON s.student_id = sd.student_id
INNER JOIN difficulty_categories dc ON sd.difficulty_id = dc.difficulty_id
INNER JOIN locations loc ON s.location_id = loc.location_id
GROUP BY dc.category_name, loc.city_zone, loc.emirate_or_region
ORDER BY enrolled_students_count DESC, dc.category_name;

-- ============================================================================
-- 4. SUPPORTING ANALYTICAL QUERY 3: EXCEPTION QUEUE AUDIT BY SYSTEM NODE
-- ============================================================================
SELECT 
    system_node,
    error_type,
    resolved,
    COUNT(*) AS total_quarantine_events,
    MIN(event_timestamp) AS earliest_event,
    MAX(event_timestamp) AS latest_event
FROM system_exception_events
GROUP BY system_node, error_type, resolved
ORDER BY total_quarantine_events DESC;

-- ============================================================================
-- 5. SUPPORTING ANALYTICAL QUERY 4: END-TO-END LINEAGE DAG BACKTRACKING
-- Demonstrates recursive lineage traversal from a report record back to root.
-- ============================================================================
WITH RECURSIVE lineage_dag AS (
    -- Anchor: Initial task from match allocation
    SELECT 
        l.execution_id,
        l.trace_id,
        l.task_name,
        l.system_node,
        l.parent_execution_id,
        1 AS lineage_depth,
        ARRAY[l.task_name]::text[] AS execution_path
    FROM lineage_audit_ledger l
    WHERE l.execution_id = 'a0000000-0000-0000-0000-000000000004'

    UNION ALL

    -- Recursive step: Follow parent_execution_id up to root
    SELECT 
        parent.execution_id,
        parent.trace_id,
        parent.task_name,
        parent.system_node,
        parent.parent_execution_id,
        dag.lineage_depth + 1,
        ARRAY_APPEND(dag.execution_path, parent.task_name)
    FROM lineage_audit_ledger parent
    INNER JOIN lineage_dag dag ON parent.execution_id = dag.parent_execution_id
)
SELECT 
    lineage_depth,
    execution_id,
    trace_id,
    task_name,
    system_node,
    parent_execution_id,
    execution_path
FROM lineage_dag
ORDER BY lineage_depth DESC;
