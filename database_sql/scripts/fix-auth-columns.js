const fs = require('fs');
const path = require('path');

const replacements = [
  ['auth_rolespermisos', 'auth_roles_permisos'],
  ['auth_usuariosroles', 'auth_usuarios_roles'],
  ['nombreusuariomodificacion', 'nombre_usuario_modificacion'],
  ['nombreusuariocreacion', 'nombre_usuario_creacion'],
  ['idusuariomodificacion', 'id_usuario_modificacion'],
  ['idusuariocreacion', 'id_usuario_creacion'],
  ['fechamodificacion', 'fecha_modificacion'],
  ['fechacreacion', 'fecha_creacion'],
  ['nombrepermiso', 'nombre_permiso'],
  ['nombreusuario', 'nombre_usuario'],
  ['nombrerol', 'nombre_rol'],
  ['idpermiso', 'id_permiso'],
  ['idusuario', 'id_usuario'],
  ['useragent', 'user_agent'],
  ['fechainicio', 'fecha_inicio'],
  ['fechafin', 'fecha_fin'],
  ['idrol', 'id_rol'],
];

function fixFile(filePath) {
  let content = fs.readFileSync(filePath, 'utf8');
  for (const [from, to] of replacements) {
    content = content.replace(new RegExp(`\\b${from}\\b`, 'g'), to);
  }
  fs.writeFileSync(filePath, content);
}

const funcionesDir = path.join(__dirname, '..', 'funciones');
for (const folder of fs.readdirSync(funcionesDir)) {
  const folderPath = path.join(funcionesDir, folder);
  if (!fs.statSync(folderPath).isDirectory()) continue;
  for (const file of fs.readdirSync(folderPath)) {
    if (file.endsWith('.sql')) {
      fixFile(path.join(folderPath, file));
    }
  }
}

console.log('Column and table names fixed in funciones/');
