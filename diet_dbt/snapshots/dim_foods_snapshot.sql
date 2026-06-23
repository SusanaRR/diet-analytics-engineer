-- dim_foods_snapshot.sql
-- SCD Type 2 history of dim_foods. Uses the 'check' strategy since the
-- source data has no reliable updated_at field, USDA's publication_date
-- reflects when a record was published, not when its values last changed.
-- A new historical row is added whenever any of check_cols differs from
-- what's already snapshotted.

{% snapshot dim_foods_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='fdc_id',
      strategy='check',
      check_cols=['protein_g', 'fat_g', 'carbohydrate_g', 'fiber_g', 'total_sugar_g']
    )
}}

select * from {{ ref('dim_foods') }}

{% endsnapshot %}