{{
  config(
    materialized='table',
    engine='MergeTree()',
    order_by='(district_iso, program_name)',
    settings={'allow_nullable_key': 1}
  )
}}

-- District x program stock-out snapshot for the Malawi map and its ranked
-- companion chart, zero-filled from the district seed so EVERY district has
-- a row for every program. Districts with no data in the latest reporting
-- month carry a NULL stockout_rate (never 0 - zero would read as "fully
-- stocked"), which lets the map show an honest "no data" hover instead of
-- a nameless blank polygon.

with districts as (

  -- one row per ISO district; spelling aliases in the seed (Mzimba North /
  -- Mzimba South) collapse to the shortest canonical name
  select
    district_iso,
    min(zone_name) as zone_name
  from {{ ref('malawi_district_iso') }}
  group by district_iso

),

programs as (

  select distinct program_name
  from {{ ref('mart_malawi_stock_status') }}

),

actual as (

  select
    district_iso,
    program_name,
    any(official_region)   as official_region,
    count()                as line_items,
    avg(combined_stockout) as rate,
    1                      as has_data
  from {{ ref('mart_malawi_stock_status') }}
  where in_latest_month = 1
    and district_iso != ''
  group by district_iso, program_name

)

select
  -- explicit aliases: the ClickHouse analyzer keeps join-key output columns
  -- prefixed (d.district_iso) when the name exists on both join sides, which
  -- would break the table's ORDER BY definition
  d.district_iso as district_iso,
  d.zone_name    as zone_name,
  p.program_name as program_name,
  a.official_region,
  -- ClickHouse LEFT JOIN fills misses with type defaults (0), not NULL, so
  -- the has_data flag guards the rate: no data => NULL, not 0%.
  if(a.has_data = 1, toNullable(a.rate), NULL) as stockout_rate,
  a.line_items
from districts d
cross join programs p
left join actual a
  on a.district_iso = d.district_iso
 and a.program_name = p.program_name
