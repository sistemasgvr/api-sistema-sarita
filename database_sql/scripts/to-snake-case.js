const fs = require('fs');
const path = require('path');

function toSnakeCase(str) {
  return str.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();
}

function convertIdentifier(name) {
  if (!/[A-Z]/.test(name)) {
    return name.toLowerCase();
  }

  const underscoreIndex = name.indexOf('_');
  if (underscoreIndex === -1) {
    return toSnakeCase(name);
  }

  const prefix = name.slice(0, underscoreIndex).toLowerCase();
  const rest = name.slice(underscoreIndex + 1);
  return `${prefix}_${toSnakeCase(rest)}`;
}

function collectIdentifiers(sql) {
  const identifiers = new Set();

  const patterns = [
    /CREATE TABLE\s+(\w+)/gi,
    /REFERENCES\s+(\w+)\s*\(/gi,
    /INSERT INTO\s+(\w+)/gi,
    /CREATE (?:UNIQUE )?INDEX\s+\w+\s+ON\s+(\w+)/gi,
    /FROM\s+(\w+)/gi,
    /JOIN\s+(\w+)/gi,
    /UPDATE\s+(\w+)/gi,
    /INTO\s+(\w+)/gi,
    /TABLE\s+(\w+)/gi,
    /^\s{4}([a-z][a-zA-Z0-9]*)\s+(?:SERIAL|INT|VARCHAR|BOOLEAN|TIMESTAMP|NUMERIC|TEXT|DATE)/gm,
  ];

  for (const pattern of patterns) {
    let match;
    while ((match = pattern.exec(sql)) !== null) {
      if (/[A-Z]/.test(match[1]) || match[1].includes('_')) {
        identifiers.add(match[1]);
      }
    }
  }

  return identifiers;
}

function applySnakeCase(sql) {
  const identifiers = collectIdentifiers(sql);
  const mapping = new Map();

  for (const id of identifiers) {
    const converted = convertIdentifier(id);
    if (converted !== id) {
      mapping.set(id, converted);
    }
  }

  const sorted = [...mapping.keys()].sort((a, b) => b.length - a.length);
  let result = sql;

  for (const oldName of sorted) {
    const newName = mapping.get(oldName);
    result = result.replace(new RegExp(`\\b${oldName}\\b`, 'g'), newName);
  }

  return result;
}

function processFile(filePath) {
  const sql = fs.readFileSync(filePath, 'utf8');
  fs.writeFileSync(filePath, applySnakeCase(sql));
  console.log('updated', filePath);
}

processFile(path.join(__dirname, '..', 'database.sql'));

const funcionesDir = path.join(__dirname, '..', 'funciones');
for (const folder of fs.readdirSync(funcionesDir)) {
  const folderPath = path.join(funcionesDir, folder);
  if (!fs.statSync(folderPath).isDirectory()) continue;

  for (const file of fs.readdirSync(folderPath)) {
    if (file.endsWith('.sql')) {
      processFile(path.join(folderPath, file));
    }
  }
}
