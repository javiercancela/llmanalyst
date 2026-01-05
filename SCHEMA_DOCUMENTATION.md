# TPC-DS Schema Documentation for LLM Query Generation

This document provides comprehensive documentation of the TPC-DS (Transaction Processing Performance Council - Decision Support) database schema loaded in the local ClickHouse server. Use this documentation to generate accurate SQL queries based on user requests for reports and dashboards.

## Database Context

- **Database Name**: `tpcds` (default database)
- **SQL Dialect**: ClickHouse
- **Schema Type**: Star schema for decision support and analytics
- **Business Domain**: Retail analytics across multiple sales channels (catalog, store, web)

## Schema Overview

The TPC-DS schema models a retail business with three sales channels:
1. **Catalog Sales**: Mail-order/phone sales
2. **Store Sales**: Physical retail store sales
3. **Web Sales**: Online/e-commerce sales

### Table Categories

**Fact Tables** (transaction data):
- `catalog_sales`, `catalog_returns`
- `store_sales`, `store_returns`
- `web_sales`, `web_returns`
- `inventory`

**Dimension Tables** (descriptive attributes):
- Customer: `customer`, `customer_address`, `customer_demographics`, `household_demographics`
- Product: `item`, `promotion`
- Location: `store`, `warehouse`, `call_center`, `web_site`, `web_page`
- Time: `date_dim`, `time_dim`
- Other: `catalog_page`, `ship_mode`, `reason`, `income_band`

---

## Fact Tables

### catalog_sales
**Purpose**: Records catalog/mail-order sales transactions

**Primary Key**: `(cs_item_sk, cs_order_number)`

**Key Columns**:
- `cs_sold_date_sk` (Nullable UInt32): Date when item was sold (joins to date_dim.d_date_sk)
- `cs_sold_time_sk` (Nullable Int64): Time when item was sold (joins to time_dim.t_time_sk)
- `cs_ship_date_sk` (Nullable UInt32): Date when item was shipped
- `cs_bill_customer_sk` (Nullable Int64): Billing customer (joins to customer.c_customer_sk)
- `cs_ship_customer_sk` (Nullable Int64): Shipping customer
- `cs_bill_cdemo_sk`, `cs_bill_hdemo_sk`, `cs_bill_addr_sk`: Customer demographics, household demographics, address
- `cs_call_center_sk` (Nullable Int64): Call center that processed the order
- `cs_catalog_page_sk` (Nullable Int64): Catalog page from which item was ordered
- `cs_ship_mode_sk` (Nullable Int64): Shipping mode
- `cs_warehouse_sk` (Nullable Int64): Warehouse that fulfilled the order
- `cs_item_sk` (Int64): Item sold (joins to item.i_item_sk)
- `cs_promo_sk` (Nullable Int64): Promotion applied
- `cs_order_number` (Int64): Order number

**Measures** (Decimal 7,2):
- `cs_quantity` (Nullable Int32): Quantity sold
- `cs_wholesale_cost`, `cs_list_price`, `cs_sales_price`: Pricing
- `cs_ext_discount_amt`: Extended discount amount
- `cs_ext_sales_price`: Extended sales price (quantity × sales_price)
- `cs_ext_wholesale_cost`, `cs_ext_list_price`: Extended costs
- `cs_ext_tax`: Tax amount
- `cs_coupon_amt`: Coupon discount
- `cs_ext_ship_cost`: Shipping cost
- `cs_net_paid`, `cs_net_paid_inc_tax`, `cs_net_paid_inc_ship`, `cs_net_paid_inc_ship_tax`: Net payment variations
- `cs_net_profit`: Net profit on the sale

**Common Joins**:
```sql
-- Sales by item
JOIN item ON cs_item_sk = i_item_sk
-- Sales by date
JOIN date_dim ON cs_sold_date_sk = d_date_sk
-- Sales by customer
JOIN customer ON cs_bill_customer_sk = c_customer_sk
```

---

### catalog_returns
**Purpose**: Records returns of catalog sales

**Primary Key**: `(cr_item_sk, cr_order_number)`

**Key Columns**:
- `cr_returned_date_sk` (Int32): Date of return
- `cr_returned_time_sk` (Int64): Time of return
- `cr_item_sk` (Int64): Item returned
- `cr_refunded_customer_sk`, `cr_returning_customer_sk`: Customers involved in return
- `cr_order_number` (Int64): Original order number (links to catalog_sales)

**Measures**:
- `cr_return_quantity` (Nullable Int32): Quantity returned
- `cr_return_amount`, `cr_return_tax`, `cr_return_amt_inc_tax`: Return amounts
- `cr_fee`, `cr_return_ship_cost`: Associated costs
- `cr_refunded_cash`, `cr_reversed_charge`, `cr_store_credit`: Refund methods
- `cr_net_loss`: Net loss from the return

**Common Pattern**:
```sql
-- Net sales (sales minus returns)
SELECT SUM(cs_ext_sales_price - COALESCE(cr_return_amount, 0.0)) AS net_sales
FROM catalog_sales
LEFT JOIN catalog_returns ON cs_order_number = cr_order_number
                          AND cs_item_sk = cr_item_sk
```

---

### store_sales
**Purpose**: Records in-store retail sales transactions

**Primary Key**: `(ss_item_sk, ss_ticket_number)`

**Key Columns**:
- `ss_sold_date_sk` (Nullable UInt32): Sale date
- `ss_sold_time_sk` (Nullable Int64): Sale time
- `ss_item_sk` (Int64): Item sold
- `ss_customer_sk` (Nullable Int64): Customer
- `ss_cdemo_sk`, `ss_hdemo_sk`, `ss_addr_sk`: Customer demographics
- `ss_store_sk` (Nullable Int64): Store where sale occurred
- `ss_promo_sk` (Nullable Int64): Promotion
- `ss_ticket_number` (Int64): Sales ticket/receipt number

**Measures**: Similar to catalog_sales
- `ss_quantity`, `ss_wholesale_cost`, `ss_list_price`, `ss_sales_price`
- `ss_ext_discount_amt`, `ss_ext_sales_price`, `ss_ext_wholesale_cost`
- `ss_ext_list_price`, `ss_ext_tax`, `ss_coupon_amt`
- `ss_net_paid`, `ss_net_paid_inc_tax`, `ss_net_profit`

---

### store_returns
**Purpose**: Records returns of store sales

**Primary Key**: `(sr_item_sk, sr_ticket_number)`

**Key Columns**:
- `sr_returned_date_sk` (Nullable UInt32): Return date
- `sr_return_time_sk` (Nullable Int64): Return time
- `sr_item_sk` (Int64): Item returned
- `sr_customer_sk`: Customer
- `sr_store_sk`: Store where return was processed
- `sr_reason_sk`: Reason for return
- `sr_ticket_number` (Int64): Original ticket number

**Measures**: Similar to catalog_returns

---

### web_sales
**Purpose**: Records online/web sales transactions

**Primary Key**: `(ws_item_sk, ws_order_number)`

**Key Columns**:
- `ws_sold_date_sk`, `ws_sold_time_sk`: Sale date/time
- `ws_ship_date_sk` (Nullable UInt32): Ship date
- `ws_item_sk` (Int64): Item sold
- `ws_bill_customer_sk`, `ws_ship_customer_sk`: Billing and shipping customers
- `ws_web_page_sk` (Nullable Int64): Web page where order originated
- `ws_web_site_sk` (Nullable Int64): Web site
- `ws_ship_mode_sk`, `ws_warehouse_sk`: Shipping and fulfillment
- `ws_promo_sk`: Promotion
- `ws_order_number` (Int64): Order number

**Measures**: Similar to catalog_sales, with all pricing and profit fields

---

### web_returns
**Purpose**: Records returns of web sales

**Primary Key**: `(wr_item_sk, wr_order_number)`

**Key Columns**: Similar to catalog_returns and store_returns
**Measures**: Similar to other return tables

---

### inventory
**Purpose**: Records inventory levels at warehouses by date and item

**Primary Key**: `(inv_date_sk, inv_item_sk, inv_warehouse_sk)`

**Columns**:
- `inv_date_sk` (UInt32): Inventory date
- `inv_item_sk` (Int64): Item
- `inv_warehouse_sk` (Int64): Warehouse
- `inv_quantity_on_hand` (Nullable Int32): Quantity available

---

## Dimension Tables

### date_dim
**Purpose**: Date dimension for time-based analysis

**Primary Key**: `d_date_sk` (UInt32)

**Key Columns**:
- `d_date_sk`: Surrogate key (used in all date_sk foreign keys)
- `d_date_id` (LowCardinality String): Date identifier
- `d_date` (Date): Actual date
- `d_year` (UInt16): Year (e.g., 1998, 1999, 2000)
- `d_moy` (UInt16): Month of year (1-12)
- `d_dom` (UInt16): Day of month (1-31)
- `d_qoy` (UInt16): Quarter of year (1-4)
- `d_dow` (UInt16): Day of week (0-6)
- `d_month_seq`, `d_week_seq`, `d_quarter_seq`: Sequential counters
- `d_fy_year`, `d_fy_quarter_seq`, `d_fy_week_seq`: Fiscal year variants
- `d_day_name` (LowCardinality String): e.g., "Monday"
- `d_quarter_name` (LowCardinality String): e.g., "2000Q1"
- `d_holiday`, `d_weekend`, `d_following_holiday` (LowCardinality String): "Y"/"N" flags
- `d_current_day`, `d_current_week`, `d_current_month`, `d_current_quarter`, `d_current_year`: Current period flags

**Common Usage**:
```sql
-- Filter by year
WHERE d_year = 2000
-- Filter by quarter
WHERE d_year = 2000 AND d_qoy = 1
-- Filter by date range
WHERE d_date BETWEEN '2000-01-01' AND '2000-12-31'
```

---

### time_dim
**Purpose**: Time of day dimension

**Primary Key**: `t_time_sk` (UInt32)

**Key Columns**:
- `t_time_sk`: Surrogate key
- `t_time_id` (LowCardinality String): Time identifier
- `t_time` (UInt32): Time in seconds since midnight
- `t_hour` (UInt8): Hour (0-23)
- `t_minute` (UInt8): Minute (0-59)
- `t_second` (UInt8): Second (0-59)
- `t_am_pm` (LowCardinality String): "AM" or "PM"
- `t_shift` (LowCardinality String): Work shift
- `t_sub_shift` (LowCardinality String): Sub-shift
- `t_meal_time` (Nullable LowCardinality String): Meal time indicator

---

### item
**Purpose**: Product/item master data

**Primary Key**: `i_item_sk` (Int64)

**Key Columns**:
- `i_item_sk`: Surrogate key
- `i_item_id` (LowCardinality String): Item business identifier
- `i_rec_start_date`, `i_rec_end_date`: Record validity dates (Nullable String)
- `i_item_desc` (Nullable LowCardinality String): Item description
- `i_current_price`, `i_wholesale_cost` (Nullable Decimal 7,2): Pricing
- `i_brand_id` (Nullable Int32), `i_brand` (Nullable LowCardinality String): Brand
- `i_class_id` (Nullable Int32), `i_class` (Nullable LowCardinality String): Product class
- `i_category_id` (Nullable Int32), `i_category` (Nullable LowCardinality String): Product category
- `i_manufact_id` (Nullable Int32), `i_manufact` (Nullable LowCardinality String): Manufacturer
- `i_size`, `i_formulation`, `i_color`, `i_units`, `i_container`: Product attributes
- `i_manager_id` (Nullable Int32): Product manager
- `i_product_name` (Nullable LowCardinality String): Product name

**Product Hierarchy**: Category → Class → Brand → Item

---

### customer
**Purpose**: Customer master data

**Primary Key**: `c_customer_sk` (Int64)

**Key Columns**:
- `c_customer_sk`: Surrogate key
- `c_customer_id` (LowCardinality String): Customer business identifier
- `c_current_cdemo_sk` (Nullable Int64): Current customer demographics
- `c_current_hdemo_sk` (Nullable Int64): Current household demographics
- `c_current_addr_sk` (Nullable Int64): Current address
- `c_first_shipto_date_sk`, `c_first_sales_date_sk`: Key dates
- `c_salutation`, `c_first_name`, `c_last_name`: Name
- `c_preferred_cust_flag` (Nullable LowCardinality String): Preferred customer flag
- `c_birth_day`, `c_birth_month`, `c_birth_year`: Birth date components
- `c_birth_country`, `c_login`, `c_email_address`: Contact info
- `c_last_review_date`: Last review date

---

### customer_demographics
**Purpose**: Customer demographic segments

**Primary Key**: `cd_demo_sk` (Int64)

**Key Columns**:
- `cd_demo_sk`: Surrogate key
- `cd_gender` (LowCardinality String): Gender ("M", "F")
- `cd_marital_status` (LowCardinality String): Marital status
- `cd_education_status` (LowCardinality String): Education level
- `cd_purchase_estimate` (Int32): Purchase estimate
- `cd_credit_rating` (LowCardinality String): Credit rating
- `cd_dep_count` (Int32): Number of dependents
- `cd_dep_employed_count` (Int32): Number of employed dependents
- `cd_dep_college_count` (Int32): Number of dependents in college

---

### household_demographics
**Purpose**: Household demographic segments

**Primary Key**: `hd_demo_sk` (Int64)

**Key Columns**:
- `hd_demo_sk`: Surrogate key
- `hd_income_band_sk` (Int64): Income band (joins to income_band)
- `hd_buy_potential` (LowCardinality String): Buying potential category
- `hd_dep_count` (Int32): Number of dependents
- `hd_vehicle_count` (Int32): Number of vehicles

---

### customer_address
**Purpose**: Customer address information

**Primary Key**: `ca_address_sk` (Int64)

**Key Columns**:
- `ca_address_sk`: Surrogate key
- `ca_address_id` (LowCardinality String): Address identifier
- `ca_street_number`, `ca_street_name`, `ca_street_type`, `ca_suite_number`: Address components
- `ca_city`, `ca_county`, `ca_state`, `ca_zip`, `ca_country`: Location
- `ca_gmt_offset` (Nullable Decimal 7,2): GMT offset
- `ca_location_type` (Nullable LowCardinality String): Location type

---

### income_band
**Purpose**: Income range definitions

**Primary Key**: `ib_income_band_sk` (Int64)

**Columns**:
- `ib_income_band_sk`: Surrogate key
- `ib_lower_bound` (Int32): Lower income bound
- `ib_upper_bound` (Int32): Upper income bound

---

### store
**Purpose**: Physical store master data

**Primary Key**: `s_store_sk` (Int64)

**Key Columns**:
- `s_store_sk`: Surrogate key
- `s_store_id` (LowCardinality String): Store identifier
- `s_rec_start_date`, `s_rec_end_date`: Record validity dates
- `s_closed_date_sk` (Nullable UInt32): Closed date
- `s_store_name` (Nullable LowCardinality String): Store name
- `s_number_employees` (Nullable Int32): Number of employees
- `s_floor_space` (Nullable Int32): Floor space
- `s_hours`, `s_manager`: Operating hours and manager
- `s_market_id`, `s_geography_class`, `s_market_desc`, `s_market_manager`: Market info
- `s_division_id`, `s_division_name`: Division
- `s_company_id`, `s_company_name`: Company
- Address fields: `s_street_number`, `s_street_name`, `s_street_type`, `s_suite_number`, `s_city`, `s_county`, `s_state`, `s_zip`, `s_country`
- `s_gmt_offset`, `s_tax_percentage`: Location details

---

### warehouse
**Purpose**: Warehouse/distribution center master data

**Primary Key**: `w_warehouse_sk` (Int64)

**Key Columns**:
- `w_warehouse_sk`: Surrogate key
- `w_warehouse_id` (LowCardinality String): Warehouse identifier
- `w_warehouse_name` (Nullable LowCardinality String): Warehouse name
- `w_warehouse_sq_ft` (Nullable Int32): Square footage
- Address fields: Similar to store
- `w_gmt_offset` (Decimal 7,2): GMT offset

---

### call_center
**Purpose**: Call center master data

**Primary Key**: `cc_call_center_sk` (Int64)

**Key Columns**:
- `cc_call_center_sk`: Surrogate key
- `cc_call_center_id` (LowCardinality String): Call center identifier
- `cc_rec_start_date`, `cc_rec_end_date` (Nullable Date): Record validity
- `cc_closed_date_sk`, `cc_open_date_sk`: Open/close dates
- `cc_name`, `cc_class`: Name and class
- `cc_employees` (Int32): Number of employees
- `cc_sq_ft` (Int32): Square footage
- `cc_hours`, `cc_manager`: Operating hours and manager
- `cc_mkt_id`, `cc_mkt_class`, `cc_mkt_desc`, `cc_market_manager`: Market info
- `cc_division`, `cc_division_name`, `cc_company`, `cc_company_name`: Organizational hierarchy
- Address fields and `cc_gmt_offset`, `cc_tax_percentage`

---

### web_site
**Purpose**: E-commerce website master data

**Primary Key**: `web_site_sk` (Int64)

**Key Columns**:
- `web_site_sk`: Surrogate key
- `web_site_id` (LowCardinality String): Website identifier
- `web_rec_start_date`, `web_rec_end_date`: Record validity
- `web_name` (LowCardinality String): Website name
- `web_open_date_sk`, `web_close_date_sk`: Open/close dates
- `web_class`, `web_manager`: Classification and manager
- `web_mkt_id`, `web_mkt_class`, `web_mkt_desc`, `web_market_manager`: Marketing info
- `web_company_id`, `web_company_name`: Company
- Address fields and `web_gmt_offset`, `web_tax_percentage`

---

### web_page
**Purpose**: Individual web page master data

**Primary Key**: `wp_web_page_sk` (Int64)

**Key Columns**:
- `wp_web_page_sk`: Surrogate key
- `wp_web_page_id` (LowCardinality String): Page identifier
- `wp_rec_start_date`, `wp_rec_end_date`: Record validity
- `wp_creation_date_sk`, `wp_access_date_sk`: Creation and access dates
- `wp_autogen_flag` (Nullable LowCardinality String): Auto-generated flag
- `wp_customer_sk` (Nullable Int64): Associated customer
- `wp_url` (Nullable LowCardinality String): Page URL
- `wp_type` (Nullable LowCardinality String): Page type
- `wp_char_count`, `wp_link_count`, `wp_image_count`, `wp_max_ad_count`: Page metrics

---

### catalog_page
**Purpose**: Catalog page master data

**Primary Key**: `cp_catalog_page_sk` (Int64)

**Key Columns**:
- `cp_catalog_page_sk`: Surrogate key
- `cp_catalog_page_id` (LowCardinality String): Page identifier
- `cp_start_date_sk`, `cp_end_date_sk` (Nullable UInt32): Validity dates
- `cp_department` (Nullable LowCardinality String): Department
- `cp_catalog_number`, `cp_catalog_page_number` (Nullable Int32): Catalog identifiers
- `cp_description`, `cp_type`: Description and type

---

### promotion
**Purpose**: Sales promotion master data

**Primary Key**: `p_promo_sk` (Int64)

**Key Columns**:
- `p_promo_sk`: Surrogate key
- `p_promo_id` (LowCardinality String): Promotion identifier
- `p_start_date_sk`, `p_end_date_sk` (Nullable UInt32): Promotion period
- `p_item_sk` (Nullable Int64): Promoted item
- `p_cost` (Nullable Decimal 15,2): Promotion cost
- `p_response_target` (Nullable Int32): Response target
- `p_promo_name` (Nullable LowCardinality String): Promotion name
- Channel flags (all Nullable LowCardinality String): `p_channel_dmail`, `p_channel_email`, `p_channel_catalog`, `p_channel_tv`, `p_channel_radio`, `p_channel_press`, `p_channel_event`, `p_channel_demo`
- `p_channel_details`, `p_purpose`, `p_discount_active`: Additional details

---

### ship_mode
**Purpose**: Shipping method master data

**Primary Key**: `sm_ship_mode_sk` (Int64)

**Key Columns**:
- `sm_ship_mode_sk`: Surrogate key
- `sm_ship_mode_id` (LowCardinality String): Ship mode identifier
- `sm_type` (LowCardinality String): Shipping type
- `sm_code` (LowCardinality String): Shipping code
- `sm_carrier` (LowCardinality String): Carrier
- `sm_contract` (LowCardinality String): Contract

---

### reason
**Purpose**: Return reason codes

**Primary Key**: `r_reason_sk` (Int64)

**Columns**:
- `r_reason_sk`: Surrogate key
- `r_reason_id` (LowCardinality String): Reason identifier
- `r_reason_desc` (LowCardinality String): Reason description

---

## Common Query Patterns

### 1. Total Sales by Channel
```sql
SELECT
    'Store' AS channel,
    SUM(ss_net_paid) AS total_sales
FROM store_sales
JOIN date_dim ON ss_sold_date_sk = d_date_sk
WHERE d_year = 2000

UNION ALL

SELECT
    'Catalog' AS channel,
    SUM(cs_net_paid) AS total_sales
FROM catalog_sales
JOIN date_dim ON cs_sold_date_sk = d_date_sk
WHERE d_year = 2000

UNION ALL

SELECT
    'Web' AS channel,
    SUM(ws_net_paid) AS total_sales
FROM web_sales
JOIN date_dim ON ws_sold_date_sk = d_date_sk
WHERE d_year = 2000
```

### 2. Sales with Returns (Net Sales)
```sql
SELECT
    d_year,
    SUM(ss_ext_sales_price - COALESCE(sr_return_amt, 0.0)) AS net_sales
FROM store_sales
JOIN date_dim ON ss_sold_date_sk = d_date_sk
LEFT JOIN store_returns ON ss_ticket_number = sr_ticket_number
                        AND ss_item_sk = sr_item_sk
GROUP BY d_year
```

### 3. Product Category Analysis
```sql
SELECT
    i_category,
    i_class,
    i_brand,
    SUM(ss_net_paid) AS total_sales,
    SUM(ss_quantity) AS total_quantity
FROM store_sales
JOIN item ON ss_item_sk = i_item_sk
JOIN date_dim ON ss_sold_date_sk = d_date_sk
WHERE d_year = 2000
GROUP BY i_category, i_class, i_brand
ORDER BY total_sales DESC
```

### 4. Customer Demographics Analysis
```sql
SELECT
    cd_gender,
    cd_marital_status,
    cd_education_status,
    COUNT(DISTINCT c_customer_sk) AS customer_count,
    SUM(ss_net_paid) AS total_sales
FROM store_sales
JOIN customer ON ss_customer_sk = c_customer_sk
JOIN customer_demographics ON c_current_cdemo_sk = cd_demo_sk
JOIN date_dim ON ss_sold_date_sk = d_date_sk
WHERE d_year = 2000
GROUP BY cd_gender, cd_marital_status, cd_education_status
```

### 5. Time-based Analysis
```sql
-- Sales by quarter
SELECT
    d_year,
    d_qoy AS quarter,
    SUM(ss_net_paid) AS total_sales
FROM store_sales
JOIN date_dim ON ss_sold_date_sk = d_date_sk
GROUP BY d_year, d_qoy
ORDER BY d_year, d_qoy

-- Sales by hour of day
SELECT
    t_hour,
    COUNT(*) AS transaction_count,
    SUM(ss_net_paid) AS total_sales
FROM store_sales
JOIN time_dim ON ss_sold_time_sk = t_time_sk
GROUP BY t_hour
ORDER BY t_hour
```

### 6. Geographic Analysis
```sql
SELECT
    ca_state,
    ca_city,
    COUNT(DISTINCT c_customer_sk) AS customer_count,
    SUM(ss_net_paid) AS total_sales
FROM store_sales
JOIN customer ON ss_customer_sk = c_customer_sk
JOIN customer_address ON c_current_addr_sk = ca_address_sk
JOIN date_dim ON ss_sold_date_sk = d_date_sk
WHERE d_year = 2000
GROUP BY ca_state, ca_city
ORDER BY total_sales DESC
```

### 7. Year-over-Year Comparison
```sql
WITH sales_by_year AS (
    SELECT
        d_year,
        i_category,
        SUM(ss_net_paid) AS sales_amt
    FROM store_sales
    JOIN item ON ss_item_sk = i_item_sk
    JOIN date_dim ON ss_sold_date_sk = d_date_sk
    GROUP BY d_year, i_category
)
SELECT
    curr.i_category,
    prev.d_year AS prev_year,
    curr.d_year AS curr_year,
    prev.sales_amt AS prev_year_sales,
    curr.sales_amt AS curr_year_sales,
    curr.sales_amt - prev.sales_amt AS sales_diff,
    (curr.sales_amt - prev.sales_amt) / prev.sales_amt * 100 AS growth_pct
FROM sales_by_year curr
JOIN sales_by_year prev ON curr.i_category = prev.i_category
                        AND curr.d_year = prev.d_year + 1
ORDER BY growth_pct DESC
```

---

## Key Relationships Summary

### Sales Transaction Joins
```
fact_sales (ss/cs/ws)
├── date_dim (ON sold_date_sk = d_date_sk)
├── time_dim (ON sold_time_sk = t_time_sk)
├── item (ON item_sk = i_item_sk)
├── customer (ON customer_sk = c_customer_sk)
│   ├── customer_demographics (ON c_current_cdemo_sk = cd_demo_sk)
│   ├── household_demographics (ON c_current_hdemo_sk = hd_demo_sk)
│   │   └── income_band (ON hd_income_band_sk = ib_income_band_sk)
│   └── customer_address (ON c_current_addr_sk = ca_address_sk)
├── promotion (ON promo_sk = p_promo_sk)
└── Channel-specific:
    ├── store_sales → store (ON ss_store_sk = s_store_sk)
    ├── catalog_sales → call_center (ON cs_call_center_sk = cc_call_center_sk)
    │                 → catalog_page (ON cs_catalog_page_sk = cp_catalog_page_sk)
    └── web_sales → web_site (ON ws_web_site_sk = web_site_sk)
                  → web_page (ON ws_web_page_sk = wp_web_page_sk)
```

### Return Transaction Joins
```
fact_returns (sr/cr/wr)
├── Original Sale (ON ticket_number/order_number AND item_sk)
├── reason (ON reason_sk = r_reason_sk)
└── Other dimensions (same as sales)
```

### Inventory Joins
```
inventory
├── date_dim (ON inv_date_sk = d_date_sk)
├── item (ON inv_item_sk = i_item_sk)
└── warehouse (ON inv_warehouse_sk = w_warehouse_sk)
```

---

## Important ClickHouse Syntax Notes

1. **TOP N instead of LIMIT**: Use `SELECT top 100` instead of `SELECT ... LIMIT 100`
2. **LowCardinality**: Pre-optimized columns for filtering and grouping
3. **Nullable**: Explicit NULL handling required; use `COALESCE()` when needed
4. **String vs. Date**: Some date fields are stored as strings, not Date type
5. **Decimal Precision**: All monetary amounts use Decimal(7,2) or Decimal(15,2)

---

## Tips for Query Generation

1. **Always join on surrogate keys** (columns ending in `_sk`)
2. **Use date_dim for date filtering** instead of direct date columns
3. **LEFT JOIN for returns** to include sales with no returns
4. **COALESCE for nullable measures** when calculating net amounts
5. **Filter early** using WHERE clauses on dimension attributes
6. **Use appropriate aggregations**: SUM for amounts, COUNT for quantities, AVG for averages
7. **Consider all three channels** (store, catalog, web) for complete retail picture
8. **Product hierarchy**: Filter by category first, then class, then brand for performance
