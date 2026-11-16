{{
  config(
    materialized='table',
    engine='MergeTree()',
    order_by='(official_region, zone_name, program_name, period_end_date)',
    settings={'allow_nullable_key': 1}
  )
}}

-- Malawi adjustments: extends the core mart_adjustments with the official
-- Malawi region (3-region crosswalk) and the month-completeness flags.
-- Additive: reads the core mart via ref(), does not modify it.

select
  a.adjustment_id,
  a.adjustment_quantity,
  a.line_item_id,
  a.requisition_id,
  a.requisition_created_date,
  a.facility_id,
  a.facility_code,
  a.facility_name,
  a.facility_active,
  a.facility_type_name,
  a.zone_name,
  a.parent_zone_name,
  a.program_name,
  a.program_code,
  a.period_name,
  a.period_start_date,
  a.period_end_date,
  a.orderable_id,
  a.product_code,
  a.product_name,
  a.status_change_status,
  a.status_change_date,
  a.reason_id,
  a.reason_name,
  a.reason_type,
  a.reason_category,
  a.signed_quantity,
  -- Same parent -> self -> Unmapped fallback as mart_malawi_reporting_status:
  -- facilities attached directly to a region-level zone have no crosswalk
  -- entry for their parent, so their own zone resolves the region.
  multiIf(
    cw_parent.official_region != '', cw_parent.official_region,
    cw_self.official_region   != '', cw_self.official_region,
    'Unmapped'
  )                                                              as official_region,
  -- month completeness (adjustments family): trend charts hide ragged
  -- trailing months through in_complete_month; in_latest_complete_month is
  -- kept so the dataset matches the core one. A missing flag row degrades to
  -- "complete" / "not latest"
  if(fl.month = toDate(0), 1, fl.is_complete)                    as in_complete_month,
  if(fl.month = toDate(0), 0, fl.is_latest_complete)             as in_latest_complete_month
from {{ ref('mart_adjustments') }} a
left join {{ ref('region_crosswalk') }} cw_parent
  on a.parent_zone_name = cw_parent.source_region
left join {{ ref('region_crosswalk') }} cw_self
  on a.zone_name = cw_self.source_region
left join (
  select month, is_complete, is_latest_complete
  from {{ ref('mart_month_completeness') }}
  where family = 'adjustments'
) fl
  on fl.month = toStartOfMonth(a.period_end_date)
