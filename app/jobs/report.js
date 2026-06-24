// Creative Job: reads matches + votes, computes group standings and the
// favourite team (most votes), and stores a JSON snapshot in a `reports` table.
// Run as a Kubernetes CronJob using the app image: node jobs/report.js
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'db',
  port: parseInt(process.env.DB_PORT, 10) || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  database: process.env.DB_NAME || 'worldcup2026',
});

async function computeStandings(client) {
  const teams = (await client.query(
    'SELECT id, name, group_letter FROM teams'
  )).rows;
  const matches = (await client.query(
    "SELECT team_home_id, team_away_id, score_home, score_away FROM matches WHERE stage = 'Group Stage'"
  )).rows;

  const table = {};
  for (const t of teams) {
    table[t.id] = { name: t.name, group: t.group_letter, pts: 0, gf: 0, ga: 0 };
  }
  for (const m of matches) {
    const h = table[m.team_home_id];
    const a = table[m.team_away_id];
    if (!h || !a) continue;
    h.gf += m.score_home; h.ga += m.score_away;
    a.gf += m.score_away; a.ga += m.score_home;
    if (m.score_home > m.score_away) h.pts += 3;
    else if (m.score_home < m.score_away) a.pts += 3;
    else { h.pts += 1; a.pts += 1; }
  }

  const groups = {};
  for (const row of Object.values(table)) {
    (groups[row.group] ||= []).push({
      name: row.name, points: row.pts, gd: row.gf - row.ga,
    });
  }
  for (const g of Object.keys(groups)) {
    groups[g].sort((x, y) => y.points - x.points || y.gd - x.gd);
  }
  return groups;
}

async function favouriteTeam(client) {
  const r = await client.query(`
    SELECT t.name, COUNT(v.id) AS votes
    FROM votes v JOIN teams t ON t.id = v.team_id
    GROUP BY t.name ORDER BY votes DESC LIMIT 1
  `);
  return r.rows[0] || null;
}

async function main() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS reports (
        id SERIAL PRIMARY KEY,
        generated_at TIMESTAMP DEFAULT NOW(),
        payload JSONB NOT NULL
      )
    `);
    const standings = await computeStandings(client);
    const favourite = await favouriteTeam(client);
    const payload = { standings, favourite };
    const res = await client.query(
      'INSERT INTO reports (payload) VALUES ($1) RETURNING id, generated_at',
      [payload]
    );
    console.log(`Report #${res.rows[0].id} generated at ${res.rows[0].generated_at}`);
    console.log(`Favourite team: ${favourite ? favourite.name : 'n/a'}`);
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((err) => {
  console.error('Report job failed:', err.message);
  process.exit(1);
});
