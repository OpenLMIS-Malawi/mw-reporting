{{
  config(
    materialized='table',
    engine='MergeTree()',
    order_by='(region, program_name, status)'
  )
}}

-- Malawi regional requisition summary: aggregates core requisition data
-- by geographic region. Demonstrates an extension mart that reads from
-- the core package's mart without modifying it.
-- official_region standardises the directional source region to the 3
-- official Malawi regions (Northern, Central, Southern) via region_crosswalk.

with requisitions as (
  select * from {{ ref('mart_requisition_summary') }}
),

facilities as (
  select * from {{ ref('mart_facility_directory') }}
)

select
  coalesce(f.parent_zone_name, f.geographic_zone_name)          as region,
  if(empty(cw.official_region), 'Unmapped', cw.official_region) as official_region,
  r.program_name,
  r.status,
  count()                as requisition_count,
  countIf(r.emergency)   as emergency_count
from requisitions r
left join facilities f
  on r.facility_code = f.facility_code
left join {{ ref('region_crosswalk') }} cw
  on coalesce(f.parent_zone_name, f.geographic_zone_name) = cw.source_region
group by
  region,
  official_region,
  r.program_name,
  r.status
