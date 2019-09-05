WITH im AS (SELECT INFOVALUE FROM INFOTABLE_V1 WHERE INFOID == 12),
     id AS (SELECT INFOVALUE FROM INFOTABLE_V1 WHERE INFOID == 13),
     c AS (SELECT CATEGNAME,
                  SUBCATEGNAME,
                  CATEGORY_V1.CATEGID,
                  IFNULL(SUBCATEGID, -1) AS SUBCATEGID
           FROM CATEGORY_V1
                    LEFT OUTER JOIN SUBCATEGORY_V1 ON CATEGORY_V1.CATEGID == SUBCATEGORY_V1.CATEGID
           UNION
           SELECT CATEGNAME, NULL, CATEGID, -1
           FROM CATEGORY_V1
           ORDER BY CATEGNAME),
     b AS (SELECT CATEGID,
                  SUBCATEGID,
                  BUDGETYEARNAME,
                  total(
                          case
                              when Period = 'Weekly' then Amount * 30.41667 / 7 * 12
                              when Period = 'Bi-Weekly' then Amount * 30.41667 / 7 / 2 * 12
                              when Period = 'Monthly' then Amount * 12
                              when Period = 'Bi-Monthly' then Amount / 2 * 12
                              when Period = 'Quarterly' then Amount / 3 * 12
                              when Period = 'Half-Yearly' then Amount / 6 * 12
                              when Period = 'Yearly' then Amount / 12 * 12
                              when Period = 'Daily' then Amount * 30.41667
                              end) AS BUDGET
           FROM BUDGETTABLE_V1
                    JOIN BUDGETYEAR_V1 ON BUDGETYEAR_V1.BUDGETYEARID == BUDGETTABLE_V1.BUDGETYEARID
           GROUP BY CATEGID, SUBCATEGID, BUDGETYEARNAME),
     t AS (SELECT total(case
                            when TRANSCODE = 'Deposit' then TRANSAMOUNT
                            when TRANSCODE = 'Withdrawal' then -1 * TRANSAMOUNT
         end) AS SUM,
                  CATEGID,
                  SUBCATEGID,
                  YEAR,
                  MONTH,
                  DAY
           FROM (
                    SELECT TRANSCODE,
                           TRANSAMOUNT,
                           CATEGID,
                           SUBCATEGID,
                           SUBSTR(TRANSDATE, 1, 4) as 'YEAR',
                           SUBSTR(TRANSDATE, 6, 2) as 'MONTH',
                           SUBSTR(TRANSDATE, 9, 2) as 'DAY'
                    FROM (
                             SELECT CHECKINGACCOUNT_V1.TRANSID,
                                    TRANSCODE,
                                    SPLITTRANSAMOUNT AS TRANSAMOUNT,
                                    TRANSDATE,
                                    SPLITTRANSACTIONS_V1.CATEGID,
                                    SPLITTRANSACTIONS_V1.SUBCATEGID
                             FROM CHECKINGACCOUNT_V1
                                      JOIN SPLITTRANSACTIONS_V1
                                           ON CHECKINGACCOUNT_V1.TRANSID == SPLITTRANSACTIONS_V1.TRANSID
                             UNION
                             SELECT TRANSID, TRANSCODE, TRANSAMOUNT, TRANSDATE, CATEGID, SUBCATEGID
                             FROM CHECKINGACCOUNT_V1
                             WHERE CATEGID != -1))
           GROUP BY CATEGID, SUBCATEGID, YEAR, MONTH, DAY)

SELECT 0            AS TYPE,
       null         AS CATEGNAME,
       null         AS SUBCATEGNAME,
       null         AS BUDGETYEARNAME,
       0              AS BUDGET,
       0              AS SUM,
       im.INFOVALUE AS 'FINANCIAL_YEAR_START_MONTH',
       id.INFOVALUE AS 'FINANCIAL_YEAR_START_DAY',
       NULL         AS YEAR,
       NULL         AS MONTH,
       NULL         AS DAY
FROM im,
     id

UNION

SELECT 1    AS TYPE,
       CATEGNAME,
       SUBCATEGNAME,
       BUDGETYEARNAME,
       IFNULL(BUDGET, 0) AS BUDGET,
       0      AS SUM,
       0      AS 'FINANCIAL_YEAR_START_MONTH',
       0      AS 'FINANCIAL_YEAR_START_DAY',
       NULL AS YEAR,
       NULL AS MONTH,
       NULL AS DAY
FROM c
         LEFT OUTER JOIN b
                         ON c.CATEGID == b.CATEGID AND c.SUBCATEGID == b.SUBCATEGID

UNION

SELECT 2    AS TYPE,
       CATEGNAME,
       SUBCATEGNAME,
       null AS BUDGETYEARNAME,
       0      AS BUDGET,
       SUM,
       0      AS 'FINANCIAL_YEAR_START_MONTH',
       0      AS 'FINANCIAL_YEAR_START_DAY',
       YEAR,
       MONTH,
       DAY
FROM t JOIN c ON t.CATEGID = c.CATEGID AND t.SUBCATEGID = c.SUBCATEGID
