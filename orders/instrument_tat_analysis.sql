/*
Instrument TAT Analysis - From GCM OTESTRESULT

Purpose: Track time intervals for instrument-posted results.

Parameters:
  :INSTRUMENT_WKS - Instrument workstation code (e.g., 'INST001')
  :START_DATE     - Start of date range in YYYYMMDD format (e.g., 20250101)
  :END_DATE       - End of date range in YYYYMMDD format (e.g., 20251231)

Example usage:
  DEFINE INSTRUMENT_WKS = 'INST001'
  DEFINE START_DATE = 20250101
  DEFINE END_DATE = 20251231

Columns:
  - MRN: Medical record number
  - ORDER_ID: Order number
  - INSTRUMENT_WORKSTATION: Instrument workstation code
  - INITIAL_DATE: Initial date (GP_OTR_DATE)
  - MODIFIED_DATE: Modified date (GP_OTR_MDATE)
  - SR_DATE: SR date (GP_OTR_SRDATE)
  - REVIEW_DATE: Review date (GP_OTR_RDATE)
  - FROM_INSTRUMENT: From instrument flag (Y/N)
  - INITIAL_TO_MODIFIED_MIN: Minutes from initial to modified
  - MODIFIED_TO_SR_MIN: Minutes from modified to SR
  - SR_TO_REVIEW_MIN: Minutes from SR to review
  - TOTAL_TAT_MIN: Total minutes from initial to review

*/

SELECT
  p.ID AS MRN,
  otr.GP_OTR_ORDNUM AS ORDER_ID,
  otr.GP_OTR_INSTWKS AS INSTRUMENT_WORKSTATION,
  TO_CHAR(otr.GP_OTR_DATE, 'YYYYMMDD') AS INITIAL_DATE,
  TO_CHAR(otr.GP_OTR_MDATE, 'YYYYMMDD') AS MODIFIED_DATE,
  TO_CHAR(otr.GP_OTR_SRDATE, 'YYYYMMDD') AS SR_DATE,
  TO_CHAR(otr.GP_OTR_RDATE, 'YYYYMMDD') AS REVIEW_DATE,
  otr.GP_OTR_FROMINSTR AS FROM_INSTRUMENT,
  ROUND((otr.GP_OTR_MDATE - otr.GP_OTR_DATE) * 1440, 2) AS INITIAL_TO_MODIFIED_MIN,
  ROUND((otr.GP_OTR_SRDATE - otr.GP_OTR_MDATE) * 1440, 2) AS MODIFIED_TO_SR_MIN,
  ROUND((otr.GP_OTR_RDATE - otr.GP_OTR_SRDATE) * 1440, 2) AS SR_TO_REVIEW_MIN,
  ROUND((otr.GP_OTR_RDATE - otr.GP_OTR_DATE) * 1440, 2) AS TOTAL_TAT_MIN
FROM V_P_GCM_OTESTRESULT otr
JOIN V_P_LAB_ORDER o ON o.ID = otr.GP_OTR_ORDNUM
JOIN V_P_LAB_STAY s ON s.AA_ID = o.STAY_AA_ID
JOIN V_P_LAB_PATIENT p ON p.AA_ID = s.PATIENT_AA_ID
WHERE otr.GP_OTR_FROMINSTR = 'Y'  -- Only instrument results
  AND otr.GP_OTR_INSTWKS = :INSTRUMENT_WKS
  AND TRUNC(otr.GP_OTR_DATE) BETWEEN TO_DATE(:START_DATE, 'YYYYMMDD')
                                  AND TO_DATE(:END_DATE, 'YYYYMMDD')
  AND REGEXP_LIKE(p.ID, '^E[0-9]+$')  -- Valid MRNs only
ORDER BY otr.GP_OTR_DATE DESC;
