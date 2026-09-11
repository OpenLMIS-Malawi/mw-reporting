{{
  config(
    materialized='table',
    engine='MergeTree()',
    order_by='(official_region, geographic_zone_name, facility_name)'
  )
}}

-- Malawi facility directory: extends the core mart_facility_directory with the
-- official Malawi region (3-region crosswalk) and district ISO code. Additive —
-- reads the core mart via ref(), does NOT modify core.

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
  -- Facilities usually attach to a district (parent = directional zone), but a
  -- handful attach directly to a zone or region level - resolve the region from
  -- whichever rung of the hierarchy the crosswalk recognises.
  multiIf(
    cw_parent.official_region != '', cw_parent.official_region,
    cw_self.official_region   != '', cw_self.official_region,
    'Unmapped'
  ) as official_region,
  di.district_iso
from {{ ref('mart_facility_directory') }} f
left join {{ ref('region_crosswalk') }} cw_parent
  on f.parent_zone_name = cw_parent.source_region
left join {{ ref('region_crosswalk') }} cw_self
  on f.geographic_zone_name = cw_self.source_region
left join {{ ref('malawi_district_iso') }} di
  -- Same case/whitespace-insensitive match as mart_malawi_stock_status: the
  -- source district strings drift ('Nkhata bay', 'Nkhota Kota').
  on replaceRegexpAll(lowerUTF8(f.geographic_zone_name), '\\s', '')
   = replaceRegexpAll(lowerUTF8(di.zone_name), '\\s', '')
