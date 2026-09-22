-- RIVER Club OS · Políticas de seguridad (RLS)
-- ============================================================
-- Aplicar en: Supabase Dashboard > SQL Editor > "New query" > Run
-- (o con: supabase db push / psql a la base)
--
-- Antes de aplicar, en el Dashboard desactiva:
--   Authentication > Providers > Email > "Allow new users to sign up" = OFF
--   (si la app debe seguir permitiendo administradores, agrégalos
--    manualmente desde Authentication > Users > "Add user")
--
-- Después de aplicar:
--   Los datos solo son visibles para usuarios autenticados (login de la app).
--   El rol anónimo (REST público / llave publishable) ya no puede
--   leer ni escribir NADA de estas tablas.
--
-- Nota: la app solo hace SELECT e INSERT vía la API REST, así que
-- aquí se deja select/insert para 'authenticated' y nada para 'anon'.
-- Si más adelante la app necesita UPDATE/DELETE, agrega políticas.

-- 1) Quitar acceso por defecto al rol anónimo
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'athletes','membership_plans','memberships','payments',
    'products','product_variants','staff_members','staff_payments','registrations'
  ]
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON TABLE %I FROM anon', t);
  END LOOP;
END $$;

-- 2) Limpiar políticas autogeneradas por Supabase (por defecto dejan acceso)
DO $$
DECLARE t text; p text; r record;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'athletes','membership_plans','memberships','payments',
    'products','product_variants','staff_members','staff_payments','registrations'
  ]
  LOOP
    FOR r IN
      SELECT policyname FROM pg_policies
      WHERE schemaname = 'public' AND tablename = t
        AND (policyname LIKE 'Enable %' OR policyname LIKE 'club_os_%')
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.policyname, t);
    END LOOP;
  END LOOP;
END $$;

-- 3) Políticas nuevas: solo usuarios autenticados (login de la app)
--    SELECT en todas las tablas de la app:
CREATE POLICY club_os_select_auth ON athletes          FOR SELECT TO authenticated USING (true);
CREATE POLICY club_os_select_auth ON membership_plans  FOR SELECT TO authenticated USING (true);
CREATE POLICY club_os_select_auth ON memberships       FOR SELECT TO authenticated USING (true);
CREATE POLICY club_os_select_auth ON payments          FOR SELECT TO authenticated USING (true);
CREATE POLICY club_os_select_auth ON products          FOR SELECT TO authenticated USING (true);
CREATE POLICY club_os_select_auth ON product_variants  FOR SELECT TO authenticated USING (true);
CREATE POLICY club_os_select_auth ON staff_members     FOR SELECT TO authenticated USING (true);
CREATE POLICY club_os_select_auth ON staff_payments    FOR SELECT TO authenticated USING (true);
CREATE POLICY club_os_select_auth ON registrations     FOR SELECT TO authenticated USING (true);

--    INSERT solo donde la app lo necesita:
CREATE POLICY club_os_insert_auth ON athletes      FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY club_os_insert_auth ON memberships   FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY club_os_insert_auth ON staff_members FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY club_os_insert_auth ON registrations FOR INSERT TO authenticated WITH CHECK (true);

--    (Sin políticas UPDATE/DELETE: la API RSS no podrá modificar/borrar vía app)