WITH t AS (
    SELECT TRANSCODE, SUM(TRANSAMOUNT) AS 'SUM', CATEGID, SUBCATEGID, YEAR, MONTH, DAY
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
                             TRANSAMOUNT,
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
    GROUP BY TRANSCODE, CATEGID, SUBCATEGID, YEAR, MONTH, DAY),
     cb AS (
         WITH c AS (SELECT CATEGNAME, SUBCATEGNAME, CATEGORY_V1.CATEGID, IFNULL(SUBCATEGID, -1) AS SUBCATEGID
                    FROM CATEGORY_V1
                             LEFT OUTER JOIN SUBCATEGORY_V1 ON CATEGORY_V1.CATEGID == SUBCATEGORY_V1.CATEGID
                    UNION
                    SELECT CATEGNAME, NULL, CATEGID, -1
                    FROM CATEGORY_V1
                    ORDER BY CATEGNAME),
              b AS (SELECT CATEGID, SUBCATEGID, PERIOD, AMOUNT, BUDGETYEARNAME
                    FROM BUDGETTABLE_V1
                             JOIN BUDGETYEAR_V1 ON BUDGETYEAR_V1.BUDGETYEARID == BUDGETTABLE_V1.BUDGETYEARID),
              im AS (SELECT INFOVALUE FROM INFOTABLE_V1 WHERE INFOID == 12),
              id AS (SELECT INFOVALUE FROM INFOTABLE_V1 WHERE INFOID == 13)
         SELECT CATEGNAME,
                SUBCATEGNAME,
                c.CATEGID,
                c.SUBCATEGID,
                BUDGETYEARNAME,
                PERIOD,
                AMOUNT,
                im.INFOVALUE AS 'FINANCIAL_YEAR_START_MONTH',
                id.INFOVALUE AS 'FINANCIAL_YEAR_START_DAY'
         FROM c,
              im,
              id
                  LEFT OUTER JOIN b
                                  ON c.CATEGID == b.CATEGID AND c.SUBCATEGID == b.SUBCATEGID
     )
SELECT CATEGNAME,
       SUBCATEGNAME,
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
                   end) AS BUDGET,
       total(
               case
                   when TRANSCODE = 'Deposit' then SUM
                   when TRANSCODE = 'Withdrawal' then -1 * SUM
                   end) AS SUM,
       FINANCIAL_YEAR_START_MONTH,
       FINANCIAL_YEAR_START_DAY,
       YEAR,
       MONTH,
       DAY
FROM cb
         JOIN t ON cb.CATEGID == t.CATEGID AND cb.SUBCATEGID == t.SUBCATEGID
WHERE TRANSCODE != 'Transfer'
GROUP BY cb.CATEGID, cb.SUBCATEGID, BUDGETYEARNAME, TRANSCODE, YEAR, MONTH, DAY
UNION
SELECT *
FROM (
         SELECT CATEGORY_V1.CATEGNAME,
                SUBCATEGORY_V1.SUBCATEGNAME,
                null,
                0,
                0,
                cb.FINANCIAL_YEAR_START_MONTH,
                cb.FINANCIAL_YEAR_START_DAY,
                null,
                null,
                null
         FROM CATEGORY_V1
                  LEFT JOIN SUBCATEGORY_V1 ON CATEGORY_V1.CATEGID == SUBCATEGORY_V1.CATEGID,
              cb
         UNION
         SELECT CATEGORY_V1.CATEGNAME,
                null,
                null,
                0,
                0,
                cb.FINANCIAL_YEAR_START_MONTH,
                cb.FINANCIAL_YEAR_START_DAY,
                null,
                null,
                null
         FROM CATEGORY_V1, cb)
