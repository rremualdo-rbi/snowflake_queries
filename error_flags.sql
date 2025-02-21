WITH RECENT_ORDERS AS
(
    SELECT DISTINCT
        H.STORE_ID,
        H.POS_VENDOR,
        H.SERVICE_MODE,
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
            H.BUSINESS_DAY >= DATEADD(DAY, -1, CURRENT_DATE)
        AND H.COUNTRY_CODE = 'US'
        AND H.POS_VENDOR IN ('SICOM', 'NCR', 'SIMPHONY')
),

-- Identify missing products in brand_plk.dim.product
MISSING_PRODUCTS AS 
(
    SELECT
        R.STORE_ID,
        R.POS_VENDOR,
        R.SERVICE_MODE,
        R.PRODUCT_PLU,
        R.PRODUCT_NUMBER,
        R.IS_PROTEIN,
    'Product not found in dim.product' AS ERROR_DESCRIPTION
    FROM 
        RECENT_ORDERS R
    WHERE PRODUCT_NUMBER IS NULL
),

-- Product number in brand_plk.dim.product not in brand_plk.dim.hierarchy.
MISSING_HIERARCHY AS 
(
    SELECT
        R.STORE_ID,
        R.POS_VENDOR,
        R.SERVICE_MODE,
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
    WHERE HI.PRODUCT_NUMBER IS NULL
),

-- Product name discrepancy between brand_plk.dim.product and TLOG
PRODUCT_NAMES_DISCREPANCY AS
(
    SELECT 
        R.STORE_ID,
        R.POS_VENDOR,
        R.SERVICE_MODE,
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
CLOSED_STORES AS
(
    SELECT 
        R.STORE_ID,
        R.POS_VENDOR,
        R.SERVICE_MODE,
        R.PRODUCT_PLU,
        R.PRODUCT_NUMBER,
        R.IS_PROTEIN,
        'Store in brand_plk.stores.stores not OPEN but has recent transactions in TLOG' AS ERROR_DESCRIPTION
    FROM
        RECENT_ORDERS R
    LEFT JOIN
        BRAND_PLK.STORES.STORES S
        ON 
            R.STORE_ID = S.STORE_ID
    WHERE 
        S.STATUS = 'CLOSED'
),

-- Product number in brand_plk.dim.product not in brand_plk.dim.menu_item_recipe or vice versa.
