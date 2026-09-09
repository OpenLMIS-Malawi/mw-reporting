{{
  config(
    materialized='table',
    engine='MergeTree()',
    order_by='(official_region, geographic_zone_name, program_name, period_end_date)',
    settings={'allow_nullable_key': 1}
  )
}}

-- Malawi requisitions: extends the core mart_requisition_summary with the
-- official Malawi region (3-region crosswalk). Additive: reads the core mart
-- via ref(), does not modify it.
--
-- One row per requisition, like the other Malawi wrappers. It used to
-- aggregate to region x program x status, which left the dashboard with no
-- period and no district to filter on -- the two the client asked for first.
-- Superset aggregates instead, and the same rows serve the raw-data table.
--
-- official_region: facilities attached directly to a region-level zone have no
-- crosswalk entry for their parent, so their own zone resolves the region.
-- Same parent -> self -> Unmapped fallback as mart_malawi_stock_status.

with requisitions as (
  select * from {{ ref('mart_requisition_summary') }}
),

facilities as (
  select * from {{ ref('mart_facility_directory') }}
)

select
  r.requisition_id                                      as requisition_id,
  r.status                                              as status,
  r.emergency                                           as emergency,
  r.created_date                                        as requisition_created_date,
  r.modified_date                                       as requisition_modified_date,

  -- aliased explicitly: these names also exist on the facilities join, and
  -- ClickHouse keeps such columns qualified, which then breaks order_by
  r.facility_code                                       as facility_code,
  r.facility_name                                       as facility_name,
  r.geographic_zone_name                                as geographic_zone_name,
  r.parent_zone_name                                    as parent_zone_name,

  r.program_code                                        as program_code,
  r.program_name                                        as program_name,
  r.period_name                                         as period_name,
  r.period_end_date                                     as period_end_date,
  r.schedule_type                                       as schedule_type,

  -- the directional source region, kept for parity with the previous mart
  coalesce(f.parent_zone_name, f.geographic_zone_name)  as region,
  multiIf(
    cw_parent.official_region != '', cw_parent.official_region,
    cw_self.official_region   != '', cw_self.official_region,
    'Unmapped'
  )                                                     as official_region

from requisitions r
left join facilities f
  on r.facility_code = f.facility_code
left join {{ ref('region_crosswalk') }} cw_parent
  on f.parent_zone_name = cw_parent.source_region
left join {{ ref('region_crosswalk') }} cw_self
  on f.geographic_zone_name = cw_self.source_region
