import pkg from 'pg';
const { Client } = pkg;

const CONN = process.env.DATABASE_URL || 'postgresql://postgres.qjntsxlmdrldbnvmqpca:ykKHBxiRdQkMPOno@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres';

async function run() {
  const client = new Client({
    connectionString: CONN,
    ssl: { rejectUnauthorized: false }
  });

  await client.connect();
  console.log("Connected to Supabase PostgreSQL.");

  // 1. Create profiles table matching requirements
  console.log("Creating profiles table...");
  await client.query(`
    CREATE TABLE IF NOT EXISTS public.profiles (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      student_id TEXT,
      department TEXT NOT NULL DEFAULT 'Information Technology',
      year TEXT,
      section TEXT,
      role TEXT NOT NULL CHECK (role IN ('student', 'staff', 'admin')),
      status TEXT NOT NULL DEFAULT 'ACTIVE',
      academic_details TEXT,
      phone_number TEXT,
      lab_pass_id TEXT,
      lab_pass_room TEXT DEFAULT 'IT Lab & Turnstile Gate #2',
      lab_pass_expiry TEXT DEFAULT 'AY 2026-2027',
      cgpa NUMERIC(4,2) DEFAULT 8.94,
      attendance_percent INTEGER DEFAULT 90,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );
  `);
  console.log("Profiles table created/verified.");

  // Ensure indices on email and student_id
  await client.query(`
    CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(LOWER(email));
    CREATE INDEX IF NOT EXISTS idx_profiles_student_id ON public.profiles(UPPER(student_id));
    CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
  `);

  // 2. Ensure users records exist for Admin and Staff
  console.log("Ensuring users table records for Admin & Staff...");
  await client.query(`
    INSERT INTO public.users (id, username, email, password_hash, role, department, status, must_change_password)
    VALUES 
      ('u_admin', 'admin', 'admin@sasi.ac.in', 'admin123', 'SUPER_ADMIN', 'Information Technology', 'ACTIVE', false),
      ('u_admin_001', 'admin@123', 'admin@sasi.ac.in', '123@admin', 'SUPER_ADMIN', 'Information Technology', 'ACTIVE', false),
      ('u_staff01', 'hod_it', 'hod_it@sasi.ac.in', 'hod_it', 'STAFF', 'Information Technology', 'ACTIVE', false),
      ('u_staff02', 'staff01', 'staff@sasi.ac.in', 'staff01', 'STAFF', 'Information Technology', 'ACTIVE', false)
    ON CONFLICT (id) DO UPDATE SET 
      username = EXCLUDED.username,
      email = EXCLUDED.email,
      password_hash = EXCLUDED.password_hash,
      role = EXCLUDED.role;
  `);

  // Ensure Staff rows exist in staff table
  console.log("Ensuring staff records...");
  await client.query(`
    INSERT INTO public.staff (user_id, employee_id, name, designation, department, phone, cabin, username, password_hash)
    VALUES 
      ('u_staff01', 'EMP_IT_01', 'Dr. AVN Chandra Sekhar', 'Head of Department (HoD)', 'Information Technology', '+91 98480 12345', 'HoD Chamber, IT Dept', 'hod_it', 'hod_it'),
      ('u_staff02', 'EMP_IT_02', 'Dr. Ramesh Kumar', 'Assistant Professor & Coordinator', 'Information Technology', '+91 94401 56789', 'Cabin 4, Staff Room A', 'staff01', 'staff01')
    ON CONFLICT (user_id) DO UPDATE SET
      name = EXCLUDED.name,
      employee_id = EXCLUDED.employee_id,
      designation = EXCLUDED.designation,
      phone = EXCLUDED.phone,
      cabin = EXCLUDED.cabin,
      password_hash = EXCLUDED.password_hash;
  `);

  // 3. Populate profiles from students
  console.log("Backfilling profiles from students...");
  const stuInsert = await client.query(`
    INSERT INTO public.profiles (
      id, name, email, student_id, department, year, section, role,
      academic_details, lab_pass_id, lab_pass_room, lab_pass_expiry, cgpa, attendance_percent
    )
    SELECT 
      s.user_id,
      s.name,
      LOWER(s.roll_no) || '@sasi.ac.in',
      s.roll_no,
      s.department,
      s.year_level,
      s.section,
      'student',
      'B.Tech IT • ' || s.year_level || ' • Section ' || s.section,
      COALESCE(s.qr_token, 'ELITE_QR_' || s.roll_no),
      'IT Lab & Turnstile Gate #2',
      'AY 2026-2027',
      8.94,
      92
    FROM public.students s
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      email = EXCLUDED.email,
      student_id = EXCLUDED.student_id,
      department = EXCLUDED.department,
      year = EXCLUDED.year,
      section = EXCLUDED.section,
      role = 'student',
      academic_details = EXCLUDED.academic_details,
      lab_pass_id = EXCLUDED.lab_pass_id;
  `);
  console.log(`Populated ${stuInsert.rowCount} students into profiles.`);

  // 4. Populate profiles from staff
  console.log("Backfilling profiles from staff...");
  const staffInsert = await client.query(`
    INSERT INTO public.profiles (
      id, name, email, student_id, department, year, section, role,
      academic_details, phone_number, lab_pass_id, lab_pass_room, lab_pass_expiry, attendance_percent
    )
    SELECT
      st.user_id,
      st.name,
      LOWER(st.username) || '@sasi.ac.in',
      st.employee_id,
      st.department,
      'Faculty',
      st.cabin,
      'staff',
      st.designation,
      st.phone,
      'FAC-AUTH-' || st.employee_id,
      st.cabin,
      'Staff Gate Clearance',
      98
    FROM public.staff st
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      email = EXCLUDED.email,
      student_id = EXCLUDED.student_id,
      department = EXCLUDED.department,
      role = 'staff',
      academic_details = EXCLUDED.academic_details;
  `);
  console.log(`Populated ${staffInsert.rowCount} staff into profiles.`);

  // 5. Populate profiles from admin
  console.log("Backfilling profiles from admin...");
  const adminInsert = await client.query(`
    INSERT INTO public.profiles (
      id, name, email, student_id, department, year, section, role,
      academic_details, lab_pass_id, lab_pass_room, lab_pass_expiry, attendance_percent
    )
    SELECT
      u.id,
      'ELITE IT Administrator',
      COALESCE(u.email, 'admin@sasi.ac.in'),
      u.username,
      u.department,
      'Administration',
      'Campus Admin Cell',
      'admin',
      'System Administrator • SASI IT',
      'ADMIN-ROOT-KEY-00',
      'Full Campus Facilities',
      'Permanent Admin Access',
      100
    FROM public.users u
    WHERE u.role IN ('SUPER_ADMIN', 'ADMIN')
    ON CONFLICT (id) DO UPDATE SET
      role = 'admin',
      name = EXCLUDED.name,
      email = EXCLUDED.email,
      academic_details = EXCLUDED.academic_details;
  `);
  console.log(`Populated ${adminInsert.rowCount} admin(s) into profiles.`);

  // 6. Setup RLS on profiles table
  console.log("Configuring RLS on profiles table...");
  await client.query(`ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;`);

  // Drop existing policies if any
  await client.query(`DROP POLICY IF EXISTS "Allow select profiles" ON public.profiles;`);
  await client.query(`DROP POLICY IF EXISTS "Allow admin update profiles" ON public.profiles;`);

  // Allow read access for authenticated / application usage
  await client.query(`
    CREATE POLICY "Allow select profiles" ON public.profiles
    FOR SELECT TO public
    USING (true);
  `);

  await client.query(`
    CREATE POLICY "Allow admin update profiles" ON public.profiles
    FOR ALL TO public
    USING (true)
    WITH CHECK (true);
  `);

  // Verification counts
  const totalProfiles = await client.query(`SELECT role, COUNT(*) FROM public.profiles GROUP BY role;`);
  console.log("\n--- Profiles Summary by Role ---");
  console.table(totalProfiles.rows);

  await client.end();
  console.log("\nMigration completed successfully!");
}

run().catch(err => {
  console.error("Migration error:", err);
  process.exit(1);
});
