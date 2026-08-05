{{
  config(
    materialized='table',
    engine='MergeTree()',
    order_by='(official_region, zone_name, period_end_date, product_code)',
    settings={'allow_nullable_key': 1}
  )
}}

-- Malawi full stock wrapper: thin, UNFILTERED wrapper over the core
-- mart_stock_status that adds the official Malawi region (3-region crosswalk).
-- Shared by the Malawi Orders and Malawi Consumption dashboards — both need the
-- full, unfiltered stock rows with official_region (unlike mart_malawi_stock_status,
-- which is filtered to Malawi tracer products / denied programmes). Additive —
-- reads core via ref(), does NOT modify core -- MW-1482.

select
  f.*,
  if(empty(cw.official_region), 'Unmapped', cw.official_region) as official_region
from {{ ref('mart_stock_status') }} f
left join {{ ref('region_crosswalk') }} cw
  on f.parent_zone_name = cw.source_region
