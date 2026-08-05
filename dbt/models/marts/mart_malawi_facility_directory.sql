{{
  config(
    materialized='table',
    engine='MergeTree()',
    order_by='(official_region, geographic_zone_name, facility_name)'
  )
}}

-- Malawi facility directory: extends the core mart_facility_directory with the
-- official Malawi region (3-region crosswalk) and district ISO code. Additive —
-- reads the core mart via ref(), does NOT modify core -- MW-1482.

select
  f.facility_id,
  f.facility_code,
  f.facility_name,
  f.facility_active,
  f.facility_enabled,
  f.facility_type_name,
  f.geographic_zone_id,
  f.geographic_zone_code,
  f.geographic_zone_name,
  f.geographic_zone_latitude,
  f.geographic_zone_longitude,
  f.parent_zone_id,
  f.parent_zone_name,
  if(empty(cw.official_region), 'Unmapped', cw.official_region) as official_region,
  di.district_iso
from {{ ref('mart_facility_directory') }} f
left join {{ ref('region_crosswalk') }} cw
  on f.parent_zone_name = cw.source_region
left join {{ ref('malawi_district_iso') }} di
  on f.geographic_zone_name = di.zone_name
