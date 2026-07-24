const { Client } = require('pg')
const fs = require('fs')
const path = require('path')

const migrationFile = process.argv[2]
if (!migrationFile) {
  console.error('Uso: node apply-migration.js <ruta-relativa-sql>')
  process.exit(1)
}

function loadDatabaseUrl() {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL
  const envPath = path.join(__dirname, '../../.env')
  const line = fs
    .readFileSync(envPath, 'utf8')
    .split(/\r?\n/)
    .find((entry) => entry.startsWith('DATABASE_URL='))
  if (!line) throw new Error('DATABASE_URL no encontrada')
  return line.slice('DATABASE_URL='.length).trim()
}

async function main() {
  const sqlPath = path.resolve(__dirname, '../..', migrationFile)
  const sql = fs.readFileSync(sqlPath, 'utf8')
  const client = new Client({
    connectionString: loadDatabaseUrl(),
    ssl: { rejectUnauthorized: false },
  })
  await client.connect()
  try {
    await client.query(sql)
    console.log('OK applied', migrationFile)
  } finally {
    await client.end()
  }
}

main().catch((error) => {
  console.error(error.message)
  process.exit(1)
})
