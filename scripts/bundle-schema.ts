import * as fs from "fs";
import * as path from "path";

interface MigrationEntry {
  version: string;
  name: string;
  file: string;
  remote?: string;
}

async function bundleSchema() {
  const migrationsDir = path.join(process.cwd(), "supabase", "migrations");
  const manifestPath = path.join(migrationsDir, "manifest.json");
  const outputPath = path.join(process.cwd(), "supabase", "full_schema.sql");

  let migrationFiles: string[] = [];

  if (fs.existsSync(manifestPath)) {
    const manifest: MigrationEntry[] = JSON.parse(
      fs.readFileSync(manifestPath, "utf-8")
    );
    migrationFiles = manifest.map((m) => m.file);
  } else {
    migrationFiles = fs
      .readdirSync(migrationsDir)
      .filter((f) => f.endsWith(".sql") && f !== "full_schema.sql")
      .sort();
  }

  const header = `-- ============================================================================
-- FULL CONSOLIDATED DATABASE SCHEMA FOR SUPABASE
-- Project: Nexus AI (Relationship Intelligence Platform)
-- Generated: ${new Date().toISOString()}
--
-- HOW TO USE:
-- 1. Create a new Supabase project at https://database.new
-- 2. Open the Supabase Dashboard -> SQL Editor
-- 3. Paste the contents of this file and click "Run"
-- ============================================================================

-- Ensure required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

`;

  let combinedSql = header;

  for (const file of migrationFiles) {
    const filePath = path.join(migrationsDir, file);
    if (!fs.existsSync(filePath)) {
      console.warn(`Skipping missing file: ${file}`);
      continue;
    }

    const content = fs.readFileSync(filePath, "utf-8");
    combinedSql += `\n-- ----------------------------------------------------------------------------\n`;
    combinedSql += `-- MIGRATION: ${file}\n`;
    combinedSql += `-- ----------------------------------------------------------------------------\n\n`;
    combinedSql += content.trim() + "\n";
  }

  fs.writeFileSync(outputPath, combinedSql, "utf-8");
  console.log(`✅ Successfully bundled ${migrationFiles.length} migrations into ${outputPath}`);
}

bundleSchema().catch((err) => {
  console.error("Failed to bundle schema:", err);
  process.exit(1);
});
