-- RIVER Club OS: database integrity smoke tests
-- Run with Supabase CLI/pgTAP against a disposable or linked test database.
begin;
select plan(12);

select has_table('public','athletes','athletes exists');
select has_table('public','memberships','memberships exists');
select has_table('public','payments','payments exists');
select has_table('public','products','products exists');
select has_table('public','product_variants','product variants exists');
select has_table('public','sales','sales exists');
select has_table('public','sale_items','sale items exists');
select has_table('public','inventory_movements','inventory movements exists');
select has_table('public','teams','teams exists');
select has_table('public','training_sessions','training sessions exists');
select has_table('public','attendance','attendance exists');
select has_table('public','club_settings','club settings exists');

select * from finish();
rollback;
