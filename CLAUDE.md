# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **llmanalyst**, an agentic system that generates reports and dashboards from natural language user requests. The system analyzes data stored in a local ClickHouse server using the TPC-DS retail dataset.

**Project Goal**: Create an LLM-powered system that:
1. Accepts natural language queries from users (e.g., "Show me sales by product category for Q1 2000")
2. Generates appropriate SQL queries against the ClickHouse database
3. Returns results as reports and dashboards

**Data Source**: TPC-DS benchmark dataset (retail analytics with catalog, store, and web sales channels) loaded in the default database of the local ClickHouse server.

## Database Schema

The database schema is defined in `ch_files/create_tables.sql` and implements the TPC-DS (Transaction Processing Performance Council Decision Support) benchmark schema for ClickHouse.

### Key Schema Components

- **Database**: `tpcds`
- **SQL Dialect**: ClickHouse SQL (note the ClickHouse-specific syntax like `LowCardinality`, `Nullable`, compound primary keys)
- **Schema Structure**:
  - Fact tables: `catalog_sales`, `catalog_returns`, `store_sales`, `store_returns`, `web_sales`, `web_returns`, `inventory`
  - Dimension tables: `call_center`, `catalog_page`, `customer`, `customer_address`, `customer_demographics`, `date_dim`, `household_demographics`, `income_band`, `item`, `promotion`, `reason`, `ship_mode`, `store`, `time_dim`, `warehouse`, `web_page`, `web_site`

### Important ClickHouse-Specific Features

- **LowCardinality**: Used extensively for string columns with limited distinct values (e.g., state codes, gender, category names). This is a ClickHouse optimization for better compression and query performance.
- **Nullable**: Explicitly marked columns that can contain NULL values
- **Decimal(7,2)**: Precision types used for monetary values
- **Date and UInt32**: Date dimensions use UInt32 for date surrogate keys and Date type for actual dates
- **Compound Primary Keys**: Many tables use composite primary keys (e.g., `PRIMARY KEY (cs_item_sk, cs_order_number)`)

## Query Files

### ch_files/query_0.sql

Contains 99 TPC-DS benchmark queries (queries are numbered 1-99+). These queries follow TPC-DS templates and demonstrate:

- Complex analytical queries with multiple joins
- Window functions and CTEs (Common Table Expressions)
- Year-over-year comparisons
- Cross-channel sales analysis (catalog, store, web)
- Customer demographic analysis
- `top 100` syntax (ClickHouse alternative to `LIMIT 100`)

**Note**: The queries use ClickHouse-specific `top N` syntax instead of standard SQL `LIMIT N`.

## Working with SQL Files

When modifying or creating queries:

1. **ClickHouse Syntax**: Remember this is ClickHouse SQL, not standard SQL. Key differences:
   - Use `top N` instead of `LIMIT N` at the beginning of SELECT
   - ClickHouse has different function names and optimization hints
   - Join syntax may differ from PostgreSQL/MySQL

2. **TPC-DS Schema Knowledge**: The schema follows TPC-DS conventions:
   - `_sk` suffix = surrogate key
   - `_id` suffix = business identifier
   - Date dimensions use integer surrogate keys (`d_date_sk`) that join to `_date_sk` columns in fact tables
   - Time dimensions separate from date dimensions

3. **Performance Considerations**:
   - LowCardinality columns are optimized for filtering and grouping
   - Primary keys define data distribution and query performance
   - Fact tables are large; always filter on dimension keys when possible

## Repository Structure

```
llmanalyst/
├── ch_files/
│   ├── create_tables.sql         # TPC-DS schema DDL for ClickHouse
│   └── query_0.sql                # 99 TPC-DS benchmark query examples
├── SCHEMA_DOCUMENTATION.md        # Comprehensive schema documentation for LLM query generation
├── CLAUDE.md                      # This file - guidance for Claude Code
├── README.md                      # Basic project description
├── LICENSE                        # Project license
└── .gitignore
```

## Key Files

### SCHEMA_DOCUMENTATION.md
**Purpose**: Comprehensive, LLM-optimized documentation of the TPC-DS database schema. Use this file as the primary reference when generating SQL queries from user requests.

**Contents**:
- Detailed table descriptions with business context
- Column-by-column documentation with data types and relationships
- Common query patterns and examples
- Join relationship diagrams
- ClickHouse-specific syntax notes

**When to use**: Always refer to this file when generating SQL queries to ensure accurate table and column references.

### ch_files/create_tables.sql
Raw DDL statements for creating the TPC-DS schema in ClickHouse.

### ch_files/query_0.sql
99 example TPC-DS benchmark queries demonstrating complex analytical patterns.

## Working with ClickHouse

### Connecting to Local ClickHouse Server

The TPC-DS dataset is loaded in the **default database** of a local ClickHouse server.

**Connection command**:
```bash
clickhouse-client
```

**Query execution**:
```bash
# Execute a query from a file
clickhouse-client --query "$(cat query.sql)"

# Execute a query directly
clickhouse-client --query "SELECT COUNT(*) FROM store_sales"

# Interactive mode
clickhouse-client
# Then type queries at the prompt
```

**Check available tables**:
```sql
SHOW TABLES;
```

**Check table schema**:
```sql
DESCRIBE TABLE store_sales;
```

## Development Workflow

When building the report/dashboard generation system:

1. **Parse user request**: Understand what the user is asking for (metrics, dimensions, filters, time periods)
2. **Consult SCHEMA_DOCUMENTATION.md**: Identify the appropriate tables and columns
3. **Generate SQL query**: Create ClickHouse-compatible SQL based on the schema
4. **Test query**: Execute against the local ClickHouse server using `clickhouse-client`
5. **Format results**: Transform query results into reports or dashboard visualizations

## Common Patterns

When writing queries for this schema:

- **Join Pattern**: Most analytical queries join fact tables (sales/returns) with dimension tables (customer, item, date, etc.)
- **Date Filtering**: Use `d_date_sk` for joins and `d_year`, `d_month_seq`, etc. for filtering
- **Sales Analysis**: Combine multiple channels using UNION (catalog_sales, store_sales, web_sales)
- **Returns Handling**: Use LEFT JOIN with returns tables and COALESCE to handle NULL values
- **Aggregations**: Year-over-year analysis requires self-joins on dimension attributes
