{{
  config(
    materialized='table',
    engine='MergeTree()',
    order_by='(official_region, product_code, period_end_date, facility_name)',
    settings={'allow_nullable_key': 1}
  )
}}

-- Malawi logistics summary: thin wrapper over the core mart_logistics_summary
-- (five most-consumed products of each program, latest reporting month) + official
-- Malawi region (3-region crosswalk). Additive — reads the core mart via ref(),
-- does NOT modify core. Backs the "Malawi: Logistics Summary Report" chart and
-- lets the dashboard Region filter (official_region) cascade to that chart -- MW-1482.

select
  f.*,
  if(empty(cw.official_region), 'Unmapped', cw.official_region) as official_region
from {{ ref('mart_logistics_summary') }} f
left join {{ ref('region_crosswalk') }} cw
  on f.parent_zone_name = cw.source_region
