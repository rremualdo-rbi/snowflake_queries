INSERT INTO BRAND_PLK.DIM.ERRORS (ERROR_ID, ERROR_DESCRIPTION)
VALUES 
    (1, 'Product not found in dim.product'),
    (2, 'Product not found in dim.hierarchy'),
    (3, 'Product name discrepancy between brand_plk.dim.product and TLOG'),
    (4, 'Store in brand_plk.stores.stores not OPEN but has recent transactions in TLOG'),
    (5, 'Product number in brand_plk.dim.product not in brand_plk.dim.menu_item_recipe or vice versa'),
    (6, 'No cost associated with a commodity number in brand_plk.costs.costs present in brand_plk.dim.menu_item_recipe'),
    (7, 'Vendor mismatch between brand_plk.stores.stores and recent TLOG data')
    (8, 'Null product_number and product_plu in TLOG')
;