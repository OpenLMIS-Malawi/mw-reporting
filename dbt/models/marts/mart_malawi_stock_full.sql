{{
  config(
    materialized='table',
    engine='MergeTree()',
    order_by='(official_region, zone_name, period_end_date, product_code)',
    settings={'allow_nullable_key': 1}
  )
}}

-- Malawi full stock wrapper: thin wrapper over the core mart_stock_status
-- that adds the official Malawi region (3-region crosswalk) and the month
-- completeness flags, nothing else. Shared by the Malawi Orders and Malawi
-- Consumption dashboards; the heavier mart_malawi_stock_status carries the
-- extra Malawi enrichments (health program, tracer flag, district ISO) for
-- the Stock dashboards. Additive: reads core via ref(), does not modify it.

with base as (

  select
    f.*,
    -- Same parent -> self -> Unmapped fallback as mart_malawi_stock_status:
    -- facilities attached directly to a region-level zone have no crosswalk
    -- entry for their parent, so their own zone resolves the region.
    multiIf(
      cw_parent.official_region != '', cw_parent.official_region,
      cw_self.official_region   != '', cw_self.official_region,
      'Unmapped'
    ) as official_region
  from {{ ref('mart_stock_status') }} f
  left join {{ ref('region_crosswalk') }} cw_parent
    on f.parent_zone_name = cw_parent.source_region
  left join {{ ref('region_crosswalk') }} cw_self
    on f.zone_name = cw_self.source_region

),

-- Month flags from the core completeness mart. in_latest_month anchors the
-- snapshot charts on the latest COMPLETE month - the newest month present
-- in the data is structurally partial (real data: 7% of the usual facility
-- coverage) - and in_complete_month lets the trend charts hide ragged
-- trailing months. A missing flag row degrades to "complete" so a stale
-- flags table can never blank a dashboard.
flags as (

  select month, is_complete, is_latest_complete
  from {{ ref('mart_month_completeness') }}
  where family = 'stock'

)

select
  base.*,
  if(f.month = toDate(0), 1, f.is_complete)        as in_complete_month,
  if(f.month = toDate(0), 0, f.is_latest_complete) as in_latest_month
from base
left join flags f
  on f.month = toStartOfMonth(base.period_end_date)
