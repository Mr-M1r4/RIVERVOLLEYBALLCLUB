-- Product reference images stored in Supabase Storage.
alter table public.products add column if not exists image_path text;
alter table public.products add column if not exists image_url text;
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists product_images_read on storage.objects;
drop policy if exists product_images_insert on storage.objects;
drop policy if exists product_images_update on storage.objects;
drop policy if exists product_images_delete on storage.objects;
create policy product_images_read on storage.objects for select to authenticated using (bucket_id='product-images');
create policy product_images_insert on storage.objects for insert to authenticated with check (bucket_id='product-images' and private.current_role() in ('owner','admin','staff'));
create policy product_images_update on storage.objects for update to authenticated using (bucket_id='product-images' and private.current_role() in ('owner','admin','staff')) with check (bucket_id='product-images' and private.current_role() in ('owner','admin','staff'));
create policy product_images_delete on storage.objects for delete to authenticated using (bucket_id='product-images' and private.current_role() in ('owner','admin','staff'));
