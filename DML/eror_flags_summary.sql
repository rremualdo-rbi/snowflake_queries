WITH RECENT_ORDERS AS
(
    SELECT DISTINCT
        H.STORE_ID,
        H.POS_VENDOR,
        --H.SERVICE_MODE,
        TP.PRODUCT_PLU,
        TP.PRODUCT_NUMBER,
        TP.PRODUCT_NAME,
        CASE WHEN SEGMENT_NAME LIKE '%CHICKEN%' THEN 1 ELSE 0 END AS IS_PROTEIN
    FROM 
        BRAND_PLK.TLOG.HEADERS H
    LEFT JOIN
        BRAND_PLK.TLOG.PRODUCTS TP
        ON
            H.STORE_ID = TP.STORE_ID
        AND
            H.HEADER_UID = TP.HEADER_UID
    LEFT JOIN
        BRAND_PLK.DIM.PRODUCT P
        ON 
            TP.PRODUCT_NUMBER = P.PRODUCT_NUMBER
    WHERE 
            H.BUSINESS_DAY >= DATEADD(DAY, -90, CURRENT_DATE)
        AND 
            H.COUNTRY_CODE = 'US'
        AND 
            H.POS_VENDOR IN ('SICOM', 'NCR', 'SIMPHONY')
        AND 
            TP.PRODUCT_NUMBER IS NOT NULL
        AND 
            TP.PRODUCT_PLU IS NOT NULL                                                                 
),

-- Identify missing products in brand_plk.dim.product
MISSING_PRODUCTS AS 
(
    SELECT
        R.STORE_ID,
        R.POS_VENDOR,
        --R.SERVICE_MODE,
        R.PRODUCT_PLU,
        R.PRODUCT_NUMBER,
        R.IS_PROTEIN,
        'Product not found in dim.product' AS ERROR_DESCRIPTION
    FROM 
        RECENT_ORDERS R
    WHERE 
            PRODUCT_NUMBER IS NULL
),

-- Product number in brand_plk.dim.product not in brand_plk.dim.hierarchy.
MISSING_HIERARCHY AS 
(
    SELECT
        R.STORE_ID,
        R.POS_VENDOR,
        --R.SERVICE_MODE,
        R.PRODUCT_PLU,
        R.PRODUCT_NUMBER,
        R.IS_PROTEIN,
        'Product not found in dim.hierarchy' AS ERROR_DESCRIPTION
    FROM
        RECENT_ORDERS R
    LEFT JOIN 
        BRAND_PLK.DIM.HIERARCHY HI
    ON
        R.PRODUCT_NUMBER = HI.PRODUCT_NUMBER
    WHERE 
            HI.PRODUCT_NUMBER IS NULL
),

-- Product name discrepancy between brand_plk.dim.product and TLOG
PRODUCT_NAMES_DISCREPANCY AS
(
    SELECT 
        R.STORE_ID,
        R.POS_VENDOR,
        --R.SERVICE_MODE,
        R.PRODUCT_PLU,
        R.PRODUCT_NUMBER,
        R.IS_PROTEIN,
        'Product name discrepancy between brand_plk.dim.product and TLOG' AS ERROR_DESCRIPTION
    FROM
        RECENT_ORDERS R
    LEFT JOIN
        BRAND_PLK.DIM.PRODUCT P
        ON 
            R.PRODUCT_NUMBER = P.PRODUCT_NUMBER        
    WHERE 
            R.PRODUCT_NAME <> P.PRODUCT_NAME
),

-- Store in brand_plk.stores.stores not OPEN but has recent transactions in TLOG
RECENT_ORDERS_WITH_BUSINESS_DAY AS
(
    SELECT DISTINCT
        H.STORE_ID,
        H.POS_VENDOR,
        --H.SERVICE_MODE,
        TP.PRODUCT_PLU,
        TP.PRODUCT_NUMBER,
        TP.PRODUCT_NAME,
        H.BUSINESS_DAY,
        CASE WHEN SEGMENT_NAME LIKE '%CHICKEN%' THEN 1 ELSE 0 END AS IS_PROTEIN
    FROM 
        BRAND_PLK.TLOG.HEADERS H
    LEFT JOIN
        BRAND_PLK.TLOG.PRODUCTS TP
        ON
            H.STORE_ID = TP.STORE_ID
        AND
            H.HEADER_UID = TP.HEADER_UID
    LEFT JOIN
        BRAND_PLK.DIM.PRODUCT P
        ON 
            TP.PRODUCT_NUMBER = P.PRODUCT_NUMBER
    WHERE 
            H.BUSINESS_DAY >= DATEADD(DAY, -90, CURRENT_DATE)
        AND 
            H.COUNTRY_CODE = 'US'
        AND 
            H.POS_VENDOR IN ('SICOM', 'NCR', 'SIMPHONY')
        AND 
            TP.PRODUCT_NUMBER IS NOT NULL
        AND 
            TP.PRODUCT_PLU IS NOT NULL                                                                 
),

CLOSED_STORES AS
(
    SELECT 
        R.STORE_ID,
        R.POS_VENDOR,
        --R.SERVICE_MODE,
        R.PRODUCT_PLU,
        R.PRODUCT_NUMBER,
        R.IS_PROTEIN,
        'Store in brand_plk.stores.stores not OPEN but has recent transactions in TLOG' AS ERROR_DESCRIPTION
    FROM
        RECENT_ORDERS_WITH_BUSINESS_DAY R
    LEFT JOIN
        BRAND_PLK.STORES.STORES S
        ON 
            R.STORE_ID = S.STORE_ID
    WHERE 
            S.STATUS = 'CLOSED'
    AND 
            R.BUSINESS_DAY > S.CLOSED_DATE
),

-- Product number in brand_plk.dim.product not in brand_plk.dim.menu_item_recipe or vice versa.
NOT_IN_MENU AS
(
    SELECT 
        PRODUCT_NUMBER
    FROM 
        BRAND_PLK.DIM.PRODUCT
    WHERE 
        PRODUCT_NUMBER NOT IN 
        (
        SELECT DISTINCT PRODUCT_NUMBER FROM BRAND_PLK.DIM.MENU_ITEM_RECIPE
        )

),

NOT_IN_PRODUCT AS
(
    SELECT 
        PRODUCT_NUMBER
    FROM 
        BRAND_PLK.DIM.MENU_ITEM_RECIPE
    WHERE 
        PRODUCT_NUMBER NOT IN 
        (
        SELECT DISTINCT PRODUCT_NUMBER FROM BRAND_PLK.DIM.PRODUCT
        )
),

NOT_IN_MENU_AND_PRODUCT AS
(
    SELECT 
        R.STORE_ID,
        R.POS_VENDOR,
        --R.SERVICE_MODE,
        R.PRODUCT_PLU,
        R.PRODUCT_NUMBER,
        R.IS_PROTEIN,
        'Product number in brand_plk.dim.product not in brand_plk.dim.menu_item_recipe or vice versa' AS ERROR_DESCRIPTION
    FROM
        RECENT_ORDERS R
    INNER JOIN
        NOT_IN_MENU M
        ON 
            R.PRODUCT_NUMBER = M.PRODUCT_NUMBER
    INNER JOIN
        NOT_IN_PRODUCT P
        ON 
            R.PRODUCT_NUMBER = P.PRODUCT_NUMBER
),

--No cost associated with a commodity number in brand_plk.costs.costs present in brand_plk.dim.menu_item_recipe.

NULL_BRAND_ITEM_ID AS
(
    SELECT M.COMMODITY_NUMBER, M.PRODUCT_NUMBER
    FROM BRAND_PLK.DIM.MENU_ITEM_RECIPE M
    LEFT JOIN 
        (
        BRAND_PLK.COSTS.COSTS C
        )
        ON M.COMMODITY_NUMBER = C.BRAND_ITEM_ID
    WHERE c.BRAND_ITEM_ID IS NULL
),

--No cost associated with a commodity number in brand_plk.costs.costs present in brand_plk.dim.menu_item_recipe

MENU_COMMODITIES AS
(
    SELECT DISTINCT
        PRODUCT_NUMBER,
        COMMODITY_NUMBER
    FROM 
        BRAND_PLK.DIM.MENU_ITEM_RECIPE
    WHERE 
        COUNTRY_CODE = 'US'
        AND 
        MDM_PRODUCT_STATUS = 'Active'
),
LATEST_COSTS AS
(
    SELECT
        STORE_ID,
        CORPORATE_ITEM_ID,
        AVERAGE_UNIT_PRICE
    FROM
        BRAND_PLK.COSTS.COSTS
    WHERE 
        CORPORATE_ITEM_ID IS NOT NULL
    QUALIFY
        ROW_NUMBER() OVER (PARTITION BY STORE_ID,CORPORATE_ITEM_ID ORDER BY DATE DESC) = 1
),
AVERAGE_UNIT_PRICE AS
(
    SELECT
        C.STORE_ID,
        M.PRODUCT_NUMBER,
        M.COMMODITY_NUMBER,
        C.AVERAGE_UNIT_PRICE
    FROM 
        LATEST_COSTS C
    LEFT JOIN
        MENU_COMMODITIES M
        ON C.CORPORATE_ITEM_ID = M.COMMODITY_NUMBER 
),
NO_COST_ASSOCIATED AS
(
    SELECT DISTINCT
        R.STORE_ID,
        R.POS_VENDOR,
        --R.SERVICE_MODE,
        R.PRODUCT_PLU,
        R.PRODUCT_NUMBER,
        R.IS_PROTEIN,
        'No cost associated with a commodity number in brand_plk.costs.costs present in brand_plk.dim.menu_item_recipe' AS ERROR_DESCRIPTION
    FROM
        RECENT_ORDERS R
    LEFT JOIN
        AVERAGE_UNIT_PRICE A
        ON
            R.STORE_ID = A.STORE_ID
        AND
            R.PRODUCT_NUMBER = A.PRODUCT_NUMBER
    WHERE A.AVERAGE_UNIT_PRICE IS NULL
),        

-- Vendor mismatch between brand_plk.stores.stores and recent TLOG data
VENDOR_MISMATCH AS
(
    SELECT 
        R.STORE_ID,
        R.POS_VENDOR,
        --R.SERVICE_MODE,
        R.PRODUCT_PLU,
        R.PRODUCT_NUMBER,
        R.IS_PROTEIN,
        'Vendor mismatch between brand_plk.stores.stores and recent TLOG data' AS ERROR_DESCRIPTION
    FROM
        RECENT_ORDERS_WITH_BUSINESS_DAY R
    LEFT JOIN
        BRAND_PLK.STORES.STORES S
        ON 
            R.STORE_ID = S.STORE_ID
    WHERE 
            R.POS_VENDOR <> S.POS_VENDOR
    AND 
            R.BUSINESS_DAY > TO_DATE(S.UPDATE_TIME)
),

-- Null product_number and product_plu in TLOG
RECENT_ORDERS_WITH_NULLS AS
(
    SELECT DISTINCT
        H.STORE_ID,
        H.POS_VENDOR,
        --H.SERVICE_MODE,
        TP.PRODUCT_PLU,
        TP.PRODUCT_NUMBER,
        TP.PRODUCT_NAME,
        CASE WHEN SEGMENT_NAME LIKE '%CHICKEN%' THEN 1 ELSE 0 END AS IS_PROTEIN
    FROM 
        BRAND_PLK.TLOG.HEADERS H
    LEFT JOIN
        BRAND_PLK.TLOG.PRODUCTS TP
        ON
            H.STORE_ID = TP.STORE_ID
        AND
            H.HEADER_UID = TP.HEADER_UID
    LEFT JOIN
        BRAND_PLK.DIM.PRODUCT P
        ON 
            TP.PRODUCT_NUMBER = P.PRODUCT_NUMBER
    WHERE 
            H.BUSINESS_DAY >= DATEADD(DAY, -90, CURRENT_DATE)
        AND 
            H.COUNTRY_CODE = 'US'
        AND 
            H.POS_VENDOR IN ('SICOM', 'NCR', 'SIMPHONY')
),

NULL_TLOG_PRODUCT_IDENTIFIERS AS
(
    SELECT 
        R.STORE_ID,
        R.POS_VENDOR,
        --R.SERVICE_MODE,
        R.PRODUCT_PLU,
        R.PRODUCT_NUMBER,
        R.IS_PROTEIN,
        'Null product_number and product_plu in TLOG' AS ERROR_DESCRIPTION
    FROM
        RECENT_ORDERS_WITH_NULLS R        
    WHERE 
            R.PRODUCT_NUMBER IS NULL
        AND 
            R.PRODUCT_PLU IS NULL                                                                 
),
-- Combine all errors
ALL_ERRORS AS 
(
    SELECT * FROM MISSING_PRODUCTS
    UNION ALL
    SELECT * FROM MISSING_HIERARCHY
    UNION ALL
    SELECT * FROM PRODUCT_NAMES_DISCREPANCY
    UNION ALL
    SELECT * FROM CLOSED_STORES
    UNION ALL
    SELECT * FROM NOT_IN_MENU_AND_PRODUCT
    UNION ALL
    SELECT * FROM NO_COST_ASSOCIATED
    UNION ALL
    SELECT * FROM VENDOR_MISMATCH
    UNION ALL
    SELECT * FROM NULL_TLOG_PRODUCT_IDENTIFIERS
)

SELECT
    ERROR_DESCRIPTION,
    COUNT(*) AS N
FROM
    ALL_ERRORS
WHERE
    IS_PROTEIN = 1
GROUP BY 
    ERROR_DESCRIPTION
ORDER BY
    N DESC
;