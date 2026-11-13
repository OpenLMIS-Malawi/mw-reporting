# olmis-analytics-malawi

Country-specific **analytics-extension** package for OpenLMIS Malawi, layered on top of [openlmis-reporting (analytics-core)](https://github.com/OpenLMIS/openlmis-reporting) and consumed by the [reporting-stack platform](https://github.com/SolDevelo/soldevelo-reporting-stack).

Extensions are additive only — they add new dbt marts and Superset dashboards but must not modify core models/dashboards or change ingestion contracts.

## Directory structure

```
olmis-analytics-malawi/
  manifest.yaml                          # Package metadata (type: extension)

  dbt/
    dbt_project.yml
    seeds/
      region_crosswalk.csv               # Source region -> official Malawi region
      malawi_district_iso.csv            # Zone name spellings -> ISO district code
      malawi_tracer_products.csv         # Client-curated HSSP tracer product list
    models/
      marts/
        mart_malawi_adjustments.sql
        mart_malawi_facility_directory.sql
        mart_malawi_logistics_summary.sql
        mart_malawi_non_reporting_facilities.sql
        mart_malawi_reporting_status.sql
        mart_malawi_requisition_by_region.sql
        mart_malawi_stock_full.sql
        mart_malawi_stock_status.sql
        schema.yml

  superset/
    assets/
      metadata.yaml
      databases/reporting_clickhouse.yaml
      datasets/reporting_clickhouse/     # One dataset per Malawi mart; the mart_malawi_stock_full
                                         # dataset is in mart_malawi_consumption.yaml
      charts/                            # 47 charts, all named "Malawi: ..."
      dashboards/                        # 10 dashboards, listed below
```

Note: extension packages do **not** include `connect/` or top-level `databases/` — ingestion configuration is owned by the core package. The `superset/assets/databases/reporting_clickhouse.yaml` here only re-declares the database for asset-import purposes; it must match the core package's UUID.

## dbt models

Each mart reads one core mart through `ref()` and adds Malawi reference data; none of them modifies core. All of them add `official_region` (Northern, Central, Southern, or Unmapped when a zone is missing from the crosswalk).

### Seeds

- `region_crosswalk`: maps the directional source regions (for example Central East) to the three official regions.
- `malawi_district_iso`: maps each zone name spelling to its ISO 3166-2 district code, the join key of the Country Map. Mzimba, Mzimba North and Mzimba South all resolve to MW-MZ.
- `malawi_tracer_products`: static CSV listing the client-curated HSSP tracer product codes. `mart_malawi_stock_status` exposes them as an `is_tracer` flag (the tracer trend chart filters on it); the mart itself is unfiltered — program classification comes from the requisition's own program, which follows the live `referencedata.program_orderables` catalog. To customise for a different country, replace the rows in this CSV or drop the flag.

### Marts

| Mart | Core mart | Adds besides `official_region` | Dashboards |
|---|---|---|---|
| `mart_malawi_adjustments` | `mart_adjustments` | month-completeness flags | Adjustments |
| `mart_malawi_facility_directory` | `mart_facility_directory` | district ISO code | Facilities |
| `mart_malawi_logistics_summary` | `mart_logistics_summary` | none | Consumption |
| `mart_malawi_non_reporting_facilities` | `mart_non_reporting_facilities` | none | Reporting Summary, Orders, Stock Status |
| `mart_malawi_reporting_status` | `mart_reporting_status` | month-completeness flags | Reporting Summary |
| `mart_malawi_requisition_by_region` | `mart_requisition_summary` | none (one row per requisition) | Requisition |
| `mart_malawi_stock_full` | `mart_stock_status` | month-completeness flags | Orders, Consumption |
| `mart_malawi_stock_status` | `mart_stock_status` | district ISO code and name, tracer flag, month flags | Summary, Stock Levels, Stockout Trends, Stock Status |

## Superset dashboards

Every dashboard title starts with "Malawi LMIS". OpenLMIS embeds each one through its own entry under Reports > Dashboard Reports.

| Dashboard | File | What it shows |
|---|---|---|
| Malawi LMIS Summary | `malawi_summary.yaml` | District stockout map and ranking, program stockout rates, tracer product stockouts, inventory snapshot per program |
| Malawi LMIS Consumption | `malawi_consumption.yaml` | Adjusted consumption trend, consumption by district, most consumed products, logistics summary |
| Malawi LMIS Facilities | `malawi_facilities.yaml` | Facilities per region and the facility list |
| Malawi LMIS Orders | `malawi_orders.yaml` | Emergency vs regular orders, order timeliness, estimated order value, total cost of orders, non-reporting facilities |
| Malawi LMIS Requisition | `malawi_regional_overview.yaml` | Requisitions by region and the raw requisition rows |
| Malawi LMIS Stock Levels | `malawi_stock_levels.yaml` | Stock status distribution over time and current stock status by facility |
| Malawi LMIS Reporting Summary | `malawi_reporting_summary.yaml` | Reporting rate by program and over time, timeliness, timeliness by week of the month, indicator pivot, annual rates, expected facilities, non-reporting and skipped facilities |
| Malawi LMIS Stockout Trends | `malawi_stockouts.yaml` | Stockout rate by program, product and district, stock status overview, most stocked-out facilities, products and districts |
| Malawi LMIS Adjustments | `malawi_adjustments.yaml` | Adjustments by reason, district and program, and the mathematical-error trend |
| Malawi LMIS Stock Status | `malawi_stock_status.yaml` | Stockout rate, months of stock and stock status distribution over time, non-reporting facilities |

Several charts are Malawi copies of core charts: the same query under a "Malawi: " name, on a Malawi dataset, so the Malawi filters (official region included) reach them. A Malawi dashboard cannot place a core chart directly: `superset import-directory` links charts and filter datasets only within one asset bundle, and the platform imports core and each extension as separate bundles. When migrating dashboards from a country's legacy stack, see [the platform's docs/migration-differences.md](https://github.com/SolDevelo/soldevelo-reporting-stack/blob/main/docs/migration-differences.md) for the conventions used.

## Usage

Clone this repository alongside the core package, then set both paths in the platform's `.env`:

```env
# absolute paths or relative to the platform repo root
ANALYTICS_CORE_PATH=/path/to/openlmis-reporting
ANALYTICS_EXTENSIONS_PATHS=/path/to/mw-reporting
```

Then run `make verify-packages` to validate, build, import, and verify.

## Customising for your country

To create an extension for a different country:

1. Copy this directory as a starting point — rename `manifest.yaml.name`, the dbt project name, and the asset UUIDs (UUIDs must be unique across packages).
2. Replace `seeds/malawi_tracer_products.csv` (and the region/district seeds) with your country's reference data, or remove them entirely if you don't need the tracer flag or region mapping.
3. Adjust the dbt marts to your country's reporting needs. Read from core marts (`{{ ref('mart_requisition_summary') }}`, etc.) rather than directly from the raw layer.
4. Replace the Superset charts and dashboards: author in the UI against your country's data, export with the import script, commit the YAML.
5. Run `make package-validate` to ensure no UUID collisions with core.

For detailed guidance, see [the platform's docs/usage-guide.md](https://github.com/SolDevelo/soldevelo-reporting-stack/blob/main/docs/usage-guide.md).
