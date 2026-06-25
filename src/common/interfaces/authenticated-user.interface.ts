export interface AuthenticatedUser {
  id: number;
  correo: string;
  permisos: string[];
  sesion: {
    id: number;
    id_usuario: number;
    nombre_usuario: string;
    correo: string;
    fecha_inicio: string;
  };
}
