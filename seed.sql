-- BASMA | مستخدمان تجريبيان (مدير + طالب)
-- شغّله في Supabase ← SQL Editor بعد تشغيل schema.sql وبعد إنشاء المستخدمين من Authentication
-- (غيّر الإيميلين هنا إذا استخدمت إيميلات مختلفة)

do $$
declare s uuid; a uuid; u uuid;
begin
  select id into a from auth.users where email = 'admin@basma-demo.com';
  select id into u from auth.users where email = 'student@basma-demo.com';
  if a is null or u is null then
    raise exception 'أنشئ المستخدمين admin@basma-demo.com و student@basma-demo.com من Authentication ← Users أولًا';
  end if;

  insert into schools (name, governorate) values ('مدرسة تجريبية (Demo)', 'رام الله والبيرة')
    returning id into s;

  insert into profiles (id, role, full_name)
    values (a, 'super_admin', 'مدير المنصة (تجريبي)')
    on conflict (id) do update set role = excluded.role, full_name = excluded.full_name;

  insert into profiles (id, role, school_id, full_name)
    values (u, 'student', s, 'طالب تجريبي')
    on conflict (id) do update set role = excluded.role, school_id = excluded.school_id, full_name = excluded.full_name;
end $$;
