export interface SupabaseUploadResult {
  path: string;
  bucket: string;
  fullPath: string;
}

export interface SupabaseSignedUrlResult {
  path: string;
  signedUrl: string;
  expiresIn: number;
}

export interface SupabaseListItem {
  name: string;
  id: string | null;
  updatedAt: string | null;
  createdAt: string | null;
  lastAccessedAt: string | null;
  metadata: Record<string, unknown> | null;
}
