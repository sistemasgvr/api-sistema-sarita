import { registerAs } from '@nestjs/config';

/**
 * Supabase Storage — archivos (bucket privado por defecto).
 * Dashboard → Settings → API: Project URL + service_role key.
 */
export default registerAs('supabase', () => ({
  url: process.env.SUPABASE_URL ?? '',
  serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY ?? '',
  storageBucket: process.env.SUPABASE_STORAGE_BUCKET ?? 'storage-sarita',
}));
