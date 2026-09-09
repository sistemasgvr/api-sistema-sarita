const { Client } = require('pg')
const fs = require('fs')
const path = require('path')

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
  const sql = fs.readFileSync(path.join(__dirname, 'probe_e2e.sql'), 'utf8')
  const client = new Client({
    connectionString: loadDatabaseUrl(),
    ssl: { rejectUnauthorized: false },
  })
  client.on('notice', (msg) => {
    console.log('NOTICE:', msg.message)
  })
  await client.connect()
  try {
    await client.query('BEGIN')
    try {
      await client.query(sql)
      await client.query('ROLLBACK')
      console.error('probe_e2e.sql termino sin RAISE EXCEPTION')
      process.exit(2)
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {})
      const message = error.message || String(error)
      console.log(message)
      if (message.includes('--- E2E OK (revertido) ---')) {
        process.exit(1)
      }
      console.error('E2E FAIL')
      process.exit(2)
    }
  } finally {
    await client.end()
  }
}

main().catch((error) => {
  console.error(error)
  process.exit(2)
})
