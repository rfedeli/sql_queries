/*
Collector profile lookup — verify a user's collector type (nurse vs. phleb)
and their SoftID role assignments.

Parameters:
  :user_id - the tech/collector ID (matches V_S_LAB_PHLEBOTOMIST.ID
             and V_S_IDN_ASSIGN.TECH_ID)
*/

-- 1. Phleb setup record — NURSE flag is the authoritative signal
--    NURSE='Y' → nurse
--    NURSE='N' → phlebotomist (or other non-nurse collector)
--    ACTIVE='N' → account disabled
SELECT
  ID,
  LAST_NAME,
  FIRST_NAME,
  NURSE,
  ACTIVE
FROM V_S_LAB_PHLEBOTOMIST
WHERE ID = :user_id;

-- 2. SoftID role assignments — shows what wards/teams they're authorized for.
--    Typical signals:
--      RN*, *RN*    → nursing roles
--      *BLD         → phleb bleeding team
--      *PCALL       → phleb collection/phlebotomy coverage
--      JNS*/TUH*/AOH*/EPH*/FCCC* → ward access (any collector type)
SELECT
  r.ID    AS ROLE_CODE,
  r.NAME  AS ROLE_NAME,
  a.IS_ACTIVE
FROM V_S_IDN_ASSIGN a
JOIN V_S_IDN_ROLE r ON r.AA_ID = a.ROLE_AA_ID
WHERE a.TECH_ID = :user_id
  AND a.IS_ACTIVE = 'Y'
ORDER BY r.ID;
