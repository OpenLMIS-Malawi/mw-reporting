{{
  config(
    materialized='table',
    engine='MergeTree()',
    order_by='(official_region, zone_name, program_name, period_end_date)',
    settings={'allow_nullable_key': 1}
  )
}}

-- Malawi reporting status: extends the core mart_reporting_status with the
-- official Malawi region (3-region crosswalk). Additive — reads the core mart
-- via ref(), does NOT modify core -- MW-1482.

select
  f.facility_id,
  f.facility_code,
  f.facility_name,
  f.facility_active,
  f.facility_type_name,
  f.zone_name,
  f.parent_zone_name,
  f.program_name,
  f.program_code,
  f.period_name,
  f.period_start_date,
  f.period_end_date,
  f.schedule_type,
  f.reporting_status,
  f.submitted_date,
  f.submitted_week_of_month,
  f.report_timeliness,
  if(empty(cw.official_region), 'Unmapped', cw.official_region) as official_region,
  -- month completeness (reporting family): trend charts hide ragged trailing
  -- months through this flag; a missing flag row degrades to "complete"
  if(fl.month = toDate(0), 1, fl.is_complete)                    as in_complete_month
from {{ ref('mart_reporting_status') }} f
left join {{ ref('region_crosswalk') }} cw
  on f.parent_zone_name = cw.source_region
left join (
  select month, is_complete
  from {{ ref('mart_month_completeness') }}
  where family = 'reporting'
) fl
  on fl.month = toStartOfMonth(f.period_end_date)
