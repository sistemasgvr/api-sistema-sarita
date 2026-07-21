export interface ProductoImagenRegistro {
  id: number;
  id_producto: number;
  codigo_producto?: string;
  nombre_producto?: string;
  id_archivo: number;
  nombre_original?: string;
  nombre_almacenado?: string;
  ruta: string;
  bucket: string;
  mime_type?: string | null;
  extension?: string | null;
  tamanio_bytes?: number | null;
  orden: number;
  es_principal: boolean;
  estado: number;
  url_firmada?: string;
  expires_in?: number;
}

export interface ProductoImagenDeleteResult {
  eliminado: boolean;
  id: number;
  id_producto?: number;
  id_archivo?: number;
  ruta?: string;
  bucket?: string;
  error?: string;
}
