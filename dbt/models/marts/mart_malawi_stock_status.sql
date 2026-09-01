{{
  config(
    materialized='table',
    engine='MergeTree()',
    order_by='(malawi_program, period_end_date, product_code)'
  )
}}

-- Malawi stock status: extends the core mart_stock_status with
-- Malawi-specific enrichments.
-- malawi_program is the requisition's own program: every line item is
-- reported inside one program's requisition, whose template comes from the
-- live referencedata.program_orderables catalog - so the classification
-- follows current program data without duplicating multi-program products.
-- is_tracer flags the client-curated HSSP tracer product list
-- (malawi_tracer_products seed - it has no live counterpart).
-- official_region standardises the directional source region to the 3
-- official Malawi regions via the region_crosswalk seed; district_iso
-- provides the ISO 3166-2 code (map join key) via the malawi_district_iso seed.

with base as (

select
  s.line_item_id,
  s.requisition_id,
  s.facility_id,
  s.facility_code,
  s.facility_name,
  s.facility_active,
  s.facility_enabled,
  s.facility_type_name,
  s.zone_name as zone_name,
  s.parent_zone_name,
  s.program_name,
  s.program_code,
  s.period_name,
  s.period_start_date,
  s.period_end_date,
  s.schedule_name,
  s.schedule_type,
  s.orderable_id,
  s.product_code as product_code,
  s.product_name,
  s.beginning_balance,
  s.total_received_quantity,
  s.total_consumed_quantity,
  s.total_losses_and_adjustments,
  s.stock_on_hand,
  s.total_stockout_days,
  s.average_consumption,
  s.adjusted_consumption,
  s.max_periods_of_stock,
  s.calculated_order_quantity,
  s.requested_quantity,
  s.approved_quantity,
  s.packs_to_ship,
  s.price_per_pack,
  s.total_cost,
  s.months_of_stock,
  s.combined_stockout,
  s.stock_status,
  s.program_name as malawi_program,
  -- ClickHouse LEFT JOIN default-fills misses with '' (not NULL)
  if(tr.product_code != '', 1, 0) as is_tracer,
  -- Resolve the region from whichever rung of the zone hierarchy the
  -- crosswalk recognises: districts match via their parent zone, while
  -- facilities attached directly to a zone/region level match on their own
  -- zone name.
  multiIf(
    cw_parent.official_region != '', cw_parent.official_region,
    cw_self.official_region   != '', cw_self.official_region,
    'Unmapped'
  ) as official_region,
  di.district_iso
from {{ ref('mart_stock_status') }} s
left join {{ ref('malawi_tracer_products') }} tr
  on s.product_code = tr.product_code
left join {{ ref('region_crosswalk') }} cw_parent
  on s.parent_zone_name = cw_parent.source_region
left join {{ ref('region_crosswalk') }} cw_self
  on s.zone_name = cw_self.source_region
left join {{ ref('malawi_district_iso') }} di
  -- Case- and whitespace-insensitive match: the source zone names drift
  -- ('Nkhata bay' vs 'Nkhata Bay', 'Nkhota Kota' vs 'Nkhotakota'), and a
  -- miss here silently blanks the district on the Country Map.
  on replaceRegexpAll(lowerUTF8(s.zone_name), '\\s', '')
   = replaceRegexpAll(lowerUTF8(di.zone_name), '\\s', '')

),

-- Month flags from the core completeness mart. in_latest_month anchors the
-- snapshot charts (district map, inventory snapshot) on the latest COMPLETE
-- month - the newest month present in the data is structurally partial
-- (real data: 7% of the usual facility coverage) - and in_complete_month
-- lets the trend charts hide ragged trailing months. A missing flag row
-- degrades to "complete" so a stale flags table can never blank a dashboard.
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
