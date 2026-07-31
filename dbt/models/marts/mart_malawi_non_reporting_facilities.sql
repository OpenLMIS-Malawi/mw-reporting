{{
  config(
    materialized='table',
    engine='MergeTree()',
    order_by='(official_region, zone_name, program_name, period_end_date)',
    settings={'allow_nullable_key': 1}
  )
}}

-- Malawi non-reporting facilities: thin wrapper over the core
-- mart_non_reporting_facilities that adds the official Malawi region (3-region
-- crosswalk). Uses `f.*` because the core mart exposes a column named literally
-- `e.facility_id` (an upstream alias-prefixed name), so an explicit `f.facility_id`
-- select fails. Additive — reads core via ref(), does NOT modify core -- MW-1482.
-- Shared by the Malawi Reporting Summary and Malawi Orders dashboards.

select
  f.*,
  if(empty(cw.official_region), 'Unmapped', cw.official_region) as official_region
from {{ ref('mart_non_reporting_facilities') }} f
left join {{ ref('region_crosswalk') }} cw
  on f.parent_zone_name = cw.source_region
