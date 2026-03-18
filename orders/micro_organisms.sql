-- Micro organism reference list with genus, species, and type
-- Parses genus/species from NAME; derives type from classification flags
SELECT
    o.NAME,
    o.SNOMED,
    REGEXP_SUBSTR(o.NAME, '^\S+')                        AS genus,
    REGEXP_SUBSTR(o.NAME, '^\S+\s+(\S+)', 1, 1, NULL, 1) AS species,
    CASE
        WHEN o.Q_VIRUS   = 'Y' THEN 'Virus'
        WHEN o.R_FUNGI   = 'Y' THEN 'Fungus'
        WHEN o.A_GRAMPOS = 'Y' THEN 'Gram-Positive Bacteria'
        WHEN o.B_GRAMNEG = 'Y' THEN 'Gram-Negative Bacteria'
        WHEN o.C_GRAMVAR = 'Y' THEN 'Gram-Variable Bacteria'
        ELSE 'Other'
    END                                                   AS organism_type
FROM V_S_MIC_ORGANISM o
WHERE o.ACTIVE = 'Y'
ORDER BY organism_type, o.NAME;
