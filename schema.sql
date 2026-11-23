-- BASMA | Phase 2: core schema + Row Level Security
-- شغّله كاملًا في Supabase ← SQL Editor

create table if not exists schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  governorate text,
  active boolean default true,
  created_at timestamptz default now()
);

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('student','teacher','school_admin','super_admin','content_editor')),
  school_id uuid references schools(id),
  full_name text,
  active boolean default true,
  created_at timestamptz default now()
);

create table if not exists classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  teacher_id uuid references profiles(id),
  name text not null,
  grade int check (grade between 4 and 6)
);

create table if not exists enrollments (
  class_id uuid references classes(id) on delete cascade,
  student_id uuid references profiles(id) on delete cascade,
  primary key (class_id, student_id)
);

create table if not exists species (
  id uuid primary key default gen_random_uuid(),
  category text check (category in ('plant','animal','bird','insect')),
  name_ar text, name_en text, scientific_name text,
  description_ar text, description_en text,
  needs_review boolean default true,
  sources text,
  published boolean default false
);

create table if not exists student_progress (
  student_id uuid references profiles(id) on delete cascade,
  item_type text not null,   -- lesson | story | game | quiz
  item_id text not null,
  score int default 0,
  completed boolean default false,
  updated_at timestamptz default now(),
  primary key (student_id, item_type, item_id)
);

create table if not exists school_leads (
  id uuid primary key default gen_random_uuid(),
  school_name text not null,
  governorate text, contact_name text, email text, phone text, message text,
  status text default 'Lead', source text,
  created_at timestamptz default now()
);

-- دوال مساعدة (security definer لتجنب التكرار اللانهائي في السياسات)
create or replace function my_role() returns text
  language sql stable security definer set search_path = public as
  $$ select role from profiles where id = auth.uid() and active $$;
create or replace function my_school() returns uuid
  language sql stable security definer set search_path = public as
  $$ select school_id from profiles where id = auth.uid() and active $$;
create or replace function teaches_student(sid uuid) returns boolean
  language sql stable security definer set search_path = public as
  $$ select exists (select 1 from enrollments e join classes c on c.id = e.class_id
     where e.student_id = sid and c.teacher_id = auth.uid()) $$;

alter table schools enable row level security;
alter table profiles enable row level security;
alter table classes enable row level security;
alter table enrollments enable row level security;
alter table species enable row level security;
alter table student_progress enable row level security;
alter table school_leads enable row level security;

-- profiles: لا توجد سياسة تعديل للمستخدم العادي (لا يستطيع تغيير دوره)
create policy profiles_self on profiles for select using (id = auth.uid());
create policy profiles_admin on profiles for all using (my_role() = 'super_admin') with check (my_role() = 'super_admin');
create policy profiles_school on profiles for select using (my_role() = 'school_admin' and school_id = my_school());
create policy profiles_teacher on profiles for select using (my_role() = 'teacher' and teaches_student(id));

-- schools
create policy schools_admin on schools for all using (my_role() = 'super_admin') with check (my_role() = 'super_admin');
create policy schools_member on schools for select using (id = my_school());

-- classes
create policy classes_admin on classes for all using (my_role() = 'super_admin') with check (my_role() = 'super_admin');
create policy classes_school on classes for all using (my_role() = 'school_admin' and school_id = my_school())
  with check (my_role() = 'school_admin' and school_id = my_school());
create policy classes_teacher on classes for select using (teacher_id = auth.uid());
create policy classes_student on classes for select using (exists
  (select 1 from enrollments e where e.class_id = classes.id and e.student_id = auth.uid()));

-- enrollments
create policy enr_admin on enrollments for all using (my_role() = 'super_admin') with check (my_role() = 'super_admin');
create policy enr_school on enrollments for all using (exists
  (select 1 from classes c where c.id = class_id and c.school_id = my_school() and my_role() = 'school_admin'))
  with check (exists (select 1 from classes c where c.id = class_id and c.school_id = my_school() and my_role() = 'school_admin'));
create policy enr_teacher on enrollments for select using (exists
  (select 1 from classes c where c.id = class_id and c.teacher_id = auth.uid()));
create policy enr_student on enrollments for select using (student_id = auth.uid());

-- species: المنشور فقط للجميع، والمحررون يكتبون، والمدير يتحكم
create policy species_read on species for select using (published);
create policy species_editors on species for all using (my_role() in ('content_editor','super_admin'))
  with check (my_role() in ('content_editor','super_admin'));

-- student_progress
create policy prog_student on student_progress for all using (student_id = auth.uid()) with check (student_id = auth.uid());
create policy prog_teacher on student_progress for select using (my_role() = 'teacher' and teaches_student(student_id));
create policy prog_school on student_progress for select using (my_role() = 'school_admin' and exists
  (select 1 from profiles p where p.id = student_id and p.school_id = my_school()));
create policy prog_admin on student_progress for select using (my_role() = 'super_admin');

-- school_leads: الزائر يضيف فقط، والمدير يقرأ ويعدّل
create policy leads_insert on school_leads for insert to anon with check (true);
create policy leads_admin on school_leads for all using (my_role() = 'super_admin') with check (my_role() = 'super_admin');

-- ===== أول مدير للمنصة =====
-- 1) أنشئ مستخدمًا من Authentication ← Users (بإيميلك وكلمة مرور)
-- 2) انسخ الـ UUID الخاص به وشغّل:
-- insert into profiles (id, role, full_name) values ('PASTE-UUID-HERE', 'super_admin', 'Ahmad Abu Tbeikh');
