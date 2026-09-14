-- ============================================================================
-- FULL CONSOLIDATED DATABASE SCHEMA FOR SUPABASE
-- Project: Nexus AI (Relationship Intelligence Platform)
-- Generated: 2026-09-14T12:51:52.123Z
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


-- ----------------------------------------------------------------------------
-- MIGRATION: 20260626145530_initial_schema_tables.sql
-- ----------------------------------------------------------------------------

-- Migration 1/5: Extensions, enums, and core tables
-- Applied to remote: yes

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

CREATE TYPE workspace_role AS ENUM ('owner', 'admin', 'member', 'viewer');
CREATE TYPE oauth_provider AS ENUM ('google', 'microsoft', 'outlook');
CREATE TYPE connection_status AS ENUM ('active', 'expired', 'revoked', 'pending');
CREATE TYPE relationship_event_type AS ENUM ('email', 'meeting', 'introduction', 'mutual_connection', 'linkedin');
CREATE TYPE introduction_status AS ENUM ('draft', 'requested', 'accepted', 'declined', 'completed');
CREATE TYPE sync_job_status AS ENUM ('pending', 'running', 'completed', 'failed');
CREATE TYPE sync_source AS ENUM ('google_contacts', 'google_calendar', 'gmail', 'outlook', 'csv');

CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  name TEXT,
  avatar_url TEXT,
  bio TEXT,
  title TEXT,
  linkedin_url TEXT,
  is_admin BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE workspaces (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  logo_url TEXT,
  plan TEXT DEFAULT 'free',
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE workspace_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role workspace_role NOT NULL DEFAULT 'member',
  invited_by UUID REFERENCES profiles(id),
  joined_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(workspace_id, user_id)
);

CREATE TABLE workspace_invites (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role workspace_role NOT NULL DEFAULT 'member',
  token TEXT NOT NULL UNIQUE,
  invited_by UUID NOT NULL REFERENCES profiles(id),
  expires_at TIMESTAMPTZ NOT NULL,
  accepted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE oauth_connections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  provider oauth_provider NOT NULL,
  provider_account_id TEXT,
  access_token TEXT,
  refresh_token TEXT,
  token_expires_at TIMESTAMPTZ,
  scopes TEXT[],
  status connection_status DEFAULT 'pending',
  last_synced_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(user_id, workspace_id, provider)
);

CREATE TABLE companies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  domain TEXT,
  industry TEXT,
  size TEXT,
  description TEXT,
  linkedin_url TEXT,
  logo_url TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE contacts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  owner_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  full_name TEXT NOT NULL,
  first_name TEXT,
  last_name TEXT,
  title TEXT,
  email TEXT,
  phone TEXT,
  linkedin_url TEXT,
  twitter_url TEXT,
  company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
  company_name TEXT,
  location TEXT,
  bio TEXT,
  tags TEXT[] DEFAULT '{}',
  source sync_source,
  external_id TEXT,
  embedding vector(1536),
  strength_score FLOAT DEFAULT 0,
  last_interaction_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE contact_notes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE relationship_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  type relationship_event_type NOT NULL,
  source TEXT,
  contact_a UUID REFERENCES contacts(id) ON DELETE CASCADE,
  contact_b UUID REFERENCES contacts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  score FLOAT DEFAULT 0,
  title TEXT,
  description TEXT,
  occurred_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE introductions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  requester_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  connector_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  target_contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  status introduction_status DEFAULT 'draft',
  message TEXT,
  outreach_draft TEXT,
  notes TEXT,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE search_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  query TEXT NOT NULL,
  result JSONB,
  filters JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE saved_searches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  query TEXT NOT NULL,
  filters JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE activities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  event TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT DEFAULT 'info',
  read BOOLEAN DEFAULT FALSE,
  link TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE sync_jobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  connection_id UUID REFERENCES oauth_connections(id) ON DELETE SET NULL,
  source sync_source NOT NULL,
  status sync_job_status DEFAULT 'pending',
  progress INTEGER DEFAULT 0,
  total INTEGER DEFAULT 0,
  error TEXT,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE feature_flags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT NOT NULL UNIQUE,
  enabled BOOLEAN DEFAULT FALSE,
  description TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE ai_usage (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  operation TEXT NOT NULL,
  tokens_used INTEGER DEFAULT 0,
  model TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260626145545_initial_schema_indexes_and_functions.sql
-- ----------------------------------------------------------------------------

-- Migration 2/5: Indexes, triggers, and database functions
-- Applied to remote: yes

CREATE INDEX idx_workspace_members_user ON workspace_members(user_id);
CREATE INDEX idx_workspace_members_workspace ON workspace_members(workspace_id);
CREATE INDEX idx_contacts_workspace ON contacts(workspace_id);
CREATE INDEX idx_contacts_email ON contacts(email);
CREATE INDEX idx_contacts_company ON contacts(company_id);
CREATE INDEX idx_contacts_name_trgm ON contacts USING gin (full_name gin_trgm_ops);
CREATE INDEX idx_companies_workspace ON companies(workspace_id);
CREATE INDEX idx_relationship_events_workspace ON relationship_events(workspace_id);
CREATE INDEX idx_relationship_events_contacts ON relationship_events(contact_a, contact_b);
CREATE INDEX idx_search_history_workspace ON search_history(workspace_id);
CREATE INDEX idx_search_history_user ON search_history(user_id);
CREATE INDEX idx_activities_workspace ON activities(workspace_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_oauth_connections_user ON oauth_connections(user_id);
CREATE INDEX idx_sync_jobs_workspace ON sync_jobs(workspace_id);

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER workspaces_updated_at BEFORE UPDATE ON workspaces FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER contacts_updated_at BEFORE UPDATE ON contacts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER companies_updated_at BEFORE UPDATE ON companies FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER oauth_connections_updated_at BEFORE UPDATE ON oauth_connections FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER introductions_updated_at BEFORE UPDATE ON introductions FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

CREATE OR REPLACE FUNCTION match_contacts(
  query_embedding vector(1536),
  match_workspace_id UUID,
  match_threshold FLOAT DEFAULT 0.5,
  match_count INT DEFAULT 20
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  title TEXT,
  email TEXT,
  company_name TEXT,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.full_name,
    c.title,
    c.email,
    c.company_name,
    1 - (c.embedding <=> query_embedding) AS similarity
  FROM contacts c
  WHERE c.workspace_id = match_workspace_id
    AND c.embedding IS NOT NULL
    AND 1 - (c.embedding <=> query_embedding) > match_threshold
  ORDER BY c.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

CREATE OR REPLACE FUNCTION is_workspace_member(ws_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM workspace_members
    WHERE workspace_id = ws_id AND user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_workspace_role(ws_id UUID)
RETURNS workspace_role AS $$
  SELECT role FROM workspace_members
  WHERE workspace_id = ws_id AND user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260626145601_rls_policies.sql
-- ----------------------------------------------------------------------------

-- Migration 3/5: Row Level Security policies
-- Applied to remote: yes

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Workspace members can view teammate profiles" ON profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM workspace_members wm1
      JOIN workspace_members wm2 ON wm1.workspace_id = wm2.workspace_id
      WHERE wm1.user_id = auth.uid() AND wm2.user_id = profiles.id
    )
  );

ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view workspace" ON workspaces
  FOR SELECT USING (is_workspace_member(id));

CREATE POLICY "Owners and admins can update workspace" ON workspaces
  FOR UPDATE USING (get_workspace_role(id) IN ('owner', 'admin'));

CREATE POLICY "Authenticated users can create workspace" ON workspaces
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

ALTER TABLE workspace_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view workspace members" ON workspace_members
  FOR SELECT USING (is_workspace_member(workspace_id));

CREATE POLICY "Owners and admins can manage members" ON workspace_members
  FOR ALL USING (get_workspace_role(workspace_id) IN ('owner', 'admin'));

CREATE POLICY "Users can join via invite" ON workspace_members
  FOR INSERT WITH CHECK (auth.uid() = user_id);

ALTER TABLE workspace_invites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view invites" ON workspace_invites
  FOR SELECT USING (is_workspace_member(workspace_id));

CREATE POLICY "Owners and admins can create invites" ON workspace_invites
  FOR INSERT WITH CHECK (get_workspace_role(workspace_id) IN ('owner', 'admin'));

ALTER TABLE oauth_connections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own connections" ON oauth_connections
  FOR ALL USING (auth.uid() = user_id AND is_workspace_member(workspace_id));

ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view companies" ON companies
  FOR SELECT USING (is_workspace_member(workspace_id));

CREATE POLICY "Members can manage companies" ON companies
  FOR ALL USING (is_workspace_member(workspace_id) AND get_workspace_role(workspace_id) != 'viewer');

ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view contacts" ON contacts
  FOR SELECT USING (is_workspace_member(workspace_id));

CREATE POLICY "Members can manage contacts" ON contacts
  FOR ALL USING (is_workspace_member(workspace_id) AND get_workspace_role(workspace_id) != 'viewer');

ALTER TABLE contact_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view notes" ON contact_notes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM contacts c
      WHERE c.id = contact_notes.contact_id AND is_workspace_member(c.workspace_id)
    )
  );

CREATE POLICY "Members can manage own notes" ON contact_notes
  FOR ALL USING (auth.uid() = author_id);

ALTER TABLE relationship_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view events" ON relationship_events
  FOR SELECT USING (is_workspace_member(workspace_id));

CREATE POLICY "Members can create events" ON relationship_events
  FOR INSERT WITH CHECK (is_workspace_member(workspace_id));

ALTER TABLE introductions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view introductions" ON introductions
  FOR SELECT USING (is_workspace_member(workspace_id));

CREATE POLICY "Members can manage introductions" ON introductions
  FOR ALL USING (is_workspace_member(workspace_id) AND get_workspace_role(workspace_id) != 'viewer');

ALTER TABLE search_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own search history" ON search_history
  FOR SELECT USING (auth.uid() = user_id AND is_workspace_member(workspace_id));

CREATE POLICY "Users can create search history" ON search_history
  FOR INSERT WITH CHECK (auth.uid() = user_id AND is_workspace_member(workspace_id));

ALTER TABLE saved_searches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own saved searches" ON saved_searches
  FOR ALL USING (auth.uid() = user_id AND is_workspace_member(workspace_id));

ALTER TABLE activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view activities" ON activities
  FOR SELECT USING (is_workspace_member(workspace_id));

CREATE POLICY "System can insert activities" ON activities
  FOR INSERT WITH CHECK (is_workspace_member(workspace_id));

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

ALTER TABLE sync_jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own sync jobs" ON sync_jobs
  FOR SELECT USING (auth.uid() = user_id AND is_workspace_member(workspace_id));

CREATE POLICY "Users can create sync jobs" ON sync_jobs
  FOR INSERT WITH CHECK (auth.uid() = user_id AND is_workspace_member(workspace_id));

ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read feature flags" ON feature_flags
  FOR SELECT USING (true);

ALTER TABLE ai_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view workspace AI usage" ON ai_usage
  FOR SELECT USING (is_workspace_member(workspace_id));

CREATE POLICY "Users can log AI usage" ON ai_usage
  FOR INSERT WITH CHECK (auth.uid() = user_id AND is_workspace_member(workspace_id));

CREATE POLICY "Admins can view all profiles" ON profiles
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  );

CREATE POLICY "Admins can view all workspaces" ON workspaces
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  );

CREATE POLICY "Admins can manage feature flags" ON feature_flags
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  );

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260626145704_harden_function_grants.sql
-- ----------------------------------------------------------------------------

-- Migration 4/5: Harden function grants and search_path
-- Applied to remote: yes

REVOKE ALL ON FUNCTION public.get_workspace_role(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_workspace_member(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.is_workspace_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_workspace_role(uuid) TO authenticated;

ALTER FUNCTION public.update_updated_at() SET search_path = public;
ALTER FUNCTION public.handle_new_user() SET search_path = public;
ALTER FUNCTION public.match_contacts(vector, uuid, float, int) SET search_path = public;
ALTER FUNCTION public.is_workspace_member(uuid) SET search_path = public;
ALTER FUNCTION public.get_workspace_role(uuid) SET search_path = public;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260626150000_vector_index.sql
-- ----------------------------------------------------------------------------

-- Migration 5/5: Vector similarity index for contact embeddings
-- Applied to remote: pending (run via supabase db push or MCP apply_migration)
-- Uses HNSW so the index can be created before contacts are seeded.

CREATE INDEX IF NOT EXISTS idx_contacts_embedding
  ON contacts USING hnsw (embedding vector_cosine_ops);

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260626180000_fix_profiles_rls_recursion.sql
-- ----------------------------------------------------------------------------

-- Fix infinite recursion in profiles RLS (admin policies queried profiles from within profiles policies)
-- Add atomic workspace creation RPC

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()),
    false
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
CREATE POLICY "Admins can view all profiles" ON profiles
  FOR SELECT USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can view all workspaces" ON workspaces;
CREATE POLICY "Admins can view all workspaces" ON workspaces
  FOR SELECT USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can manage feature flags" ON feature_flags;
CREATE POLICY "Admins can manage feature flags" ON feature_flags
  FOR ALL USING (public.is_admin());

DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE OR REPLACE FUNCTION public.create_workspace_with_owner(workspace_name text)
RETURNS workspaces
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_workspace workspaces;
  base_slug text;
  final_slug text;
  suffix int := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  base_slug := lower(regexp_replace(trim(workspace_name), '[^a-zA-Z0-9]+', '-', 'g'));
  base_slug := trim(both '-' from base_slug);
  IF base_slug = '' THEN
    base_slug := 'workspace';
  END IF;
  final_slug := base_slug;

  WHILE EXISTS (SELECT 1 FROM workspaces WHERE slug = final_slug) LOOP
    suffix := suffix + 1;
    final_slug := base_slug || '-' || suffix;
  END LOOP;

  INSERT INTO workspaces (name, slug)
  VALUES (workspace_name, final_slug)
  RETURNING * INTO new_workspace;

  INSERT INTO workspace_members (workspace_id, user_id, role)
  VALUES (new_workspace.id, auth.uid(), 'owner');

  RETURN new_workspace;
END;
$$;

REVOKE ALL ON FUNCTION public.create_workspace_with_owner(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_workspace_with_owner(text) TO authenticated;

ALTER FUNCTION public.is_admin() SET search_path = public;
ALTER FUNCTION public.create_workspace_with_owner(text) SET search_path = public;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260626200000_onboarding_and_defaults.sql
-- ----------------------------------------------------------------------------

-- Default workspace on signup, vector index, and feature flag seeds

CREATE INDEX IF NOT EXISTS idx_contacts_embedding
  ON contacts USING hnsw (embedding vector_cosine_ops);

CREATE OR REPLACE FUNCTION public.create_default_workspace_for_user(p_user_id uuid, p_name text)
RETURNS workspaces
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_workspace workspaces;
  base_slug text;
  final_slug text;
  suffix int := 0;
BEGIN
  base_slug := lower(regexp_replace(trim(p_name), '[^a-zA-Z0-9]+', '-', 'g'));
  base_slug := trim(both '-' from base_slug);
  IF base_slug = '' THEN
    base_slug := 'workspace';
  END IF;
  final_slug := base_slug;

  WHILE EXISTS (SELECT 1 FROM workspaces WHERE slug = final_slug) LOOP
    suffix := suffix + 1;
    final_slug := base_slug || '-' || suffix;
  END LOOP;

  INSERT INTO workspaces (name, slug)
  VALUES (p_name, final_slug)
  RETURNING * INTO new_workspace;

  INSERT INTO workspace_members (workspace_id, user_id, role)
  VALUES (new_workspace.id, p_user_id, 'owner');

  RETURN new_workspace;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  display_name text;
BEGIN
  display_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    split_part(NEW.email, '@', 1)
  );

  INSERT INTO profiles (id, email, name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    display_name,
    NEW.raw_user_meta_data->>'avatar_url'
  );

  PERFORM public.create_default_workspace_for_user(NEW.id, display_name || '''s Workspace');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

INSERT INTO feature_flags (key, enabled, description) VALUES
  ('ai_search', true, 'Enable AI-powered network search'),
  ('graph_view', true, 'Enable relationship graph visualization'),
  ('outreach_engine', true, 'Enable AI outreach generation'),
  ('team_collaboration', true, 'Enable team invites and shared workspaces')
ON CONFLICT (key) DO NOTHING;

DROP POLICY IF EXISTS "Users can create own notifications" ON notifications;
CREATE POLICY "Users can create own notifications" ON notifications
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260626210000_fix_rls_function_grants.sql
-- ----------------------------------------------------------------------------

-- Restore EXECUTE on RLS helper functions for authenticated users.
-- harden_function_grants revoked these, which broke every policy that calls them.

GRANT EXECUTE ON FUNCTION public.is_workspace_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_workspace_role(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_contacts(vector, uuid, double precision, integer) TO authenticated;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260627120000_data_connectors.sql
-- ----------------------------------------------------------------------------

-- Flexible connector storage for the Connector Dashboard

CREATE TABLE IF NOT EXISTS data_connectors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  connector_key TEXT NOT NULL,
  status connection_status DEFAULT 'pending',
  access_token TEXT,
  refresh_token TEXT,
  provider_account_id TEXT,
  last_synced_at TIMESTAMPTZ,
  records_count INT DEFAULT 0,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (user_id, workspace_id, connector_key)
);

CREATE INDEX IF NOT EXISTS idx_data_connectors_user ON data_connectors(user_id);
CREATE INDEX IF NOT EXISTS idx_data_connectors_workspace ON data_connectors(workspace_id);

ALTER TABLE data_connectors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own connectors" ON data_connectors;
CREATE POLICY "Users manage own connectors" ON data_connectors
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS data_connectors_updated_at ON data_connectors;
CREATE TRIGGER data_connectors_updated_at
  BEFORE UPDATE ON data_connectors
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260627140000_multi_account_connectors.sql
-- ----------------------------------------------------------------------------

-- Allow multiple connected accounts per connector type

ALTER TABLE data_connectors
  ADD COLUMN IF NOT EXISTS account_email TEXT,
  ADD COLUMN IF NOT EXISTS account_label TEXT;

ALTER TABLE data_connectors
  DROP CONSTRAINT IF EXISTS data_connectors_user_id_workspace_id_connector_key_key;

CREATE UNIQUE INDEX IF NOT EXISTS data_connectors_oauth_account_unique
  ON data_connectors (user_id, workspace_id, connector_key, provider_account_id)
  WHERE provider_account_id IS NOT NULL;

-- Supabase upsert support
ALTER TABLE data_connectors
  DROP CONSTRAINT IF EXISTS data_connectors_account_unique;

ALTER TABLE data_connectors
  ADD CONSTRAINT data_connectors_account_unique
  UNIQUE (user_id, workspace_id, connector_key, provider_account_id);

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260627160000_ensure_user_onboarded.sql
-- ----------------------------------------------------------------------------

-- Ensure OAuth / legacy users have profiles before workspace membership.
-- workspace_members.user_id references profiles(id), not auth.users(id).

INSERT INTO profiles (id, email, name, avatar_url)
SELECT
  u.id,
  COALESCE(u.email, ''),
  COALESCE(
    u.raw_user_meta_data->>'full_name',
    u.raw_user_meta_data->>'name',
    split_part(COALESCE(u.email, 'user'), '@', 1)
  ),
  u.raw_user_meta_data->>'avatar_url'
FROM auth.users u
LEFT JOIN profiles p ON p.id = u.id
WHERE p.id IS NULL;

CREATE OR REPLACE FUNCTION public.ensure_user_onboarded()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  display_name text;
  new_workspace workspaces;
  existing_ws uuid;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT wm.workspace_id INTO existing_ws
  FROM workspace_members wm
  WHERE wm.user_id = uid
  ORDER BY wm.joined_at
  LIMIT 1;

  IF existing_ws IS NOT NULL THEN
    RETURN existing_ws;
  END IF;

  SELECT COALESCE(
    u.raw_user_meta_data->>'full_name',
    u.raw_user_meta_data->>'name',
    split_part(COALESCE(u.email, 'user'), '@', 1),
    'My'
  )
  INTO display_name
  FROM auth.users u
  WHERE u.id = uid;

  INSERT INTO profiles (id, email, name, avatar_url)
  SELECT
    u.id,
    COALESCE(u.email, ''),
    display_name,
    u.raw_user_meta_data->>'avatar_url'
  FROM auth.users u
  WHERE u.id = uid
  ON CONFLICT (id) DO NOTHING;

  SELECT * INTO new_workspace
  FROM public.create_default_workspace_for_user(uid, display_name || '''s Group');

  RETURN new_workspace.id;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_user_onboarded() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_user_onboarded() TO authenticated;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260627180000_workspace_invite_token.sql
-- ----------------------------------------------------------------------------

-- Reusable shareable invite link per workspace

ALTER TABLE workspaces
  ADD COLUMN IF NOT EXISTS invite_token TEXT UNIQUE;

CREATE UNIQUE INDEX IF NOT EXISTS idx_workspaces_invite_token
  ON workspaces (invite_token)
  WHERE invite_token IS NOT NULL;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260627200000_match_contacts_in_workspaces.sql
-- ----------------------------------------------------------------------------

-- Search contacts across multiple workspaces the user belongs to

CREATE OR REPLACE FUNCTION match_contacts_in_workspaces(
  query_embedding vector(1536),
  match_workspace_ids UUID[],
  match_threshold FLOAT DEFAULT 0.3,
  match_count INT DEFAULT 20
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  title TEXT,
  email TEXT,
  company_name TEXT,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.full_name,
    c.title,
    c.email,
    c.company_name,
    1 - (c.embedding <=> query_embedding) AS similarity
  FROM contacts c
  WHERE c.workspace_id = ANY(match_workspace_ids)
    AND c.embedding IS NOT NULL
    AND 1 - (c.embedding <=> query_embedding) > match_threshold
  ORDER BY c.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

ALTER FUNCTION public.match_contacts_in_workspaces(vector, uuid[], float, int) SET search_path = public;
GRANT EXECUTE ON FUNCTION public.match_contacts_in_workspaces(vector, uuid[], double precision, integer) TO authenticated;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260627210000_billing_and_feature_flags.sql
-- ----------------------------------------------------------------------------

-- Stripe billing columns + additional feature flags

ALTER TABLE workspaces
  ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT,
  ADD COLUMN IF NOT EXISTS stripe_subscription_id TEXT;

CREATE INDEX IF NOT EXISTS idx_workspaces_stripe_subscription
  ON workspaces (stripe_subscription_id)
  WHERE stripe_subscription_id IS NOT NULL;

INSERT INTO feature_flags (key, enabled, description) VALUES
  ('beta_connectors', false, 'Enable beta connector integrations'),
  ('billing_enforcement', true, 'Enforce plan limits on search and imports')
ON CONFLICT (key) DO UPDATE SET
  description = EXCLUDED.description;

-- Use "Group" naming for auto-created default groups
CREATE OR REPLACE FUNCTION public.ensure_user_onboarded()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  display_name text;
  new_workspace workspaces;
  existing_ws uuid;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT wm.workspace_id INTO existing_ws
  FROM workspace_members wm
  WHERE wm.user_id = uid
  ORDER BY wm.joined_at
  LIMIT 1;

  IF existing_ws IS NOT NULL THEN
    RETURN existing_ws;
  END IF;

  SELECT COALESCE(
    u.raw_user_meta_data->>'full_name',
    u.raw_user_meta_data->>'name',
    split_part(COALESCE(u.email, 'user'), '@', 1),
    'My'
  )
  INTO display_name
  FROM auth.users u
  WHERE u.id = uid;

  INSERT INTO profiles (id, email, name, avatar_url)
  SELECT
    u.id,
    COALESCE(u.email, ''),
    display_name,
    u.raw_user_meta_data->>'avatar_url'
  FROM auth.users u
  WHERE u.id = uid
  ON CONFLICT (id) DO NOTHING;

  SELECT * INTO new_workspace
  FROM public.create_default_workspace_for_user(uid, display_name || '''s Group');

  RETURN new_workspace.id;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_user_onboarded() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_user_onboarded() TO authenticated;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260628100000_playbooks_and_segments.sql
-- ----------------------------------------------------------------------------

-- Playbooks (Agent Mode), Segments, outreach pipeline

CREATE TYPE playbook_status AS ENUM ('draft', 'active', 'paused', 'archived');
CREATE TYPE automation_level AS ENUM ('assist', 'supervised', 'autonomous');
CREATE TYPE outreach_mode AS ENUM ('warm_preferred', 'warm_required', 'cold_allowed');
CREATE TYPE playbook_run_status AS ENUM (
  'pending', 'matching', 'review', 'finalized', 'executing', 'completed', 'failed', 'cancelled'
);
CREATE TYPE playbook_prospect_status AS ENUM (
  'matched', 'selected', 'queued', 'pending_approval', 'sent', 'replied', 'booked', 'opted_out', 'failed', 'skipped'
);
CREATE TYPE outbound_channel AS ENUM ('email', 'in_app', 'linkedin');
CREATE TYPE outbound_message_status AS ENUM ('draft', 'pending_approval', 'queued', 'sent', 'failed', 'cancelled');

CREATE TABLE segments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  source TEXT DEFAULT 'manual',
  contact_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE segment_contacts (
  segment_id UUID NOT NULL REFERENCES segments(id) ON DELETE CASCADE,
  contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  added_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  PRIMARY KEY (segment_id, contact_id)
);

CREATE TABLE email_templates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  subject TEXT NOT NULL,
  preheader TEXT,
  body_html TEXT NOT NULL,
  body_text TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE playbooks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  status playbook_status DEFAULT 'draft' NOT NULL,
  automation_level automation_level DEFAULT 'assist' NOT NULL,
  outreach_mode outreach_mode DEFAULT 'warm_preferred' NOT NULL,
  goal TEXT,
  tone TEXT DEFAULT 'professional',
  icp_profile JSONB DEFAULT '{}'::jsonb NOT NULL,
  matching_config JSONB DEFAULT '{}'::jsonb NOT NULL,
  send_config JSONB DEFAULT '{}'::jsonb NOT NULL,
  template_id UUID REFERENCES email_templates(id) ON DELETE SET NULL,
  settings JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE playbook_runs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  playbook_id UUID NOT NULL REFERENCES playbooks(id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  triggered_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  segment_id UUID REFERENCES segments(id) ON DELETE SET NULL,
  status playbook_run_status DEFAULT 'pending' NOT NULL,
  icp_snapshot JSONB DEFAULT '{}'::jsonb NOT NULL,
  stats JSONB DEFAULT '{}'::jsonb NOT NULL,
  dry_run BOOLEAN DEFAULT FALSE NOT NULL,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE playbook_run_contacts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  run_id UUID NOT NULL REFERENCES playbook_runs(id) ON DELETE CASCADE,
  contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  match_score INTEGER DEFAULT 0 NOT NULL,
  match_reason TEXT,
  matched_signals JSONB DEFAULT '[]'::jsonb NOT NULL,
  warm_path JSONB DEFAULT '[]'::jsonb NOT NULL,
  status playbook_prospect_status DEFAULT 'matched' NOT NULL,
  draft_subject TEXT,
  draft_body TEXT,
  skip_reason TEXT,
  last_action_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (run_id, contact_id)
);

CREATE TABLE contact_preferences (
  contact_id UUID PRIMARY KEY REFERENCES contacts(id) ON DELETE CASCADE,
  unsubscribed_at TIMESTAMPTZ,
  do_not_contact BOOLEAN DEFAULT FALSE NOT NULL,
  bounce_count INTEGER DEFAULT 0 NOT NULL,
  last_contacted_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE outbound_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  run_id UUID REFERENCES playbook_runs(id) ON DELETE SET NULL,
  run_contact_id UUID REFERENCES playbook_run_contacts(id) ON DELETE SET NULL,
  contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  channel outbound_channel DEFAULT 'email' NOT NULL,
  subject TEXT,
  body TEXT NOT NULL,
  status outbound_message_status DEFAULT 'draft' NOT NULL,
  provider_message_id TEXT,
  sent_at TIMESTAMPTZ,
  replied_at TIMESTAMPTZ,
  error TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  metadata JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE conversation_threads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  run_contact_id UUID REFERENCES playbook_run_contacts(id) ON DELETE SET NULL,
  contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  participant_user_ids UUID[] DEFAULT '{}',
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE thread_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  thread_id UUID NOT NULL REFERENCES conversation_threads(id) ON DELETE CASCADE,
  sender_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  body TEXT NOT NULL,
  message_type TEXT DEFAULT 'text' NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_segments_workspace ON segments(workspace_id);
CREATE INDEX idx_playbooks_workspace ON playbooks(workspace_id);
CREATE INDEX idx_playbook_runs_playbook ON playbook_runs(playbook_id);
CREATE INDEX idx_playbook_run_contacts_run ON playbook_run_contacts(run_id);
CREATE INDEX idx_outbound_messages_contact ON outbound_messages(contact_id);
CREATE INDEX idx_audit_logs_workspace ON audit_logs(workspace_id, created_at DESC);

-- RLS
ALTER TABLE segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE segment_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE playbooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE playbook_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE playbook_run_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE outbound_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE thread_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members manage segments" ON segments
  FOR ALL USING (is_workspace_member(workspace_id) AND get_workspace_role(workspace_id) != 'viewer');

CREATE POLICY "Members manage segment contacts" ON segment_contacts
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM segments s
      WHERE s.id = segment_contacts.segment_id AND is_workspace_member(s.workspace_id)
    )
  );

CREATE POLICY "Members manage templates" ON email_templates
  FOR ALL USING (is_workspace_member(workspace_id) AND get_workspace_role(workspace_id) != 'viewer');

CREATE POLICY "Members manage playbooks" ON playbooks
  FOR ALL USING (is_workspace_member(workspace_id) AND get_workspace_role(workspace_id) != 'viewer');

CREATE POLICY "Members manage playbook runs" ON playbook_runs
  FOR ALL USING (is_workspace_member(workspace_id) AND get_workspace_role(workspace_id) != 'viewer');

CREATE POLICY "Members manage run contacts" ON playbook_run_contacts
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM playbook_runs r
      WHERE r.id = playbook_run_contacts.run_id AND is_workspace_member(r.workspace_id)
    )
  );

CREATE POLICY "Members view contact preferences" ON contact_preferences
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM contacts c
      WHERE c.id = contact_preferences.contact_id AND is_workspace_member(c.workspace_id)
    )
  );

CREATE POLICY "Members manage outbound messages" ON outbound_messages
  FOR ALL USING (is_workspace_member(workspace_id) AND get_workspace_role(workspace_id) != 'viewer');

CREATE POLICY "Members view audit logs" ON audit_logs
  FOR SELECT USING (is_workspace_member(workspace_id));

CREATE POLICY "Members insert audit logs" ON audit_logs
  FOR INSERT WITH CHECK (is_workspace_member(workspace_id));

CREATE POLICY "Members manage threads" ON conversation_threads
  FOR ALL USING (is_workspace_member(workspace_id));

CREATE POLICY "Members manage thread messages" ON thread_messages
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM conversation_threads t
      WHERE t.id = thread_messages.thread_id AND is_workspace_member(t.workspace_id)
    )
  );

INSERT INTO feature_flags (key, enabled, description) VALUES
  ('playbook_mode', true, 'Enable Playbooks outreach pipeline'),
  ('platform_chat', false, 'Enable realtime platform chat in prospect view')
ON CONFLICT (key) DO UPDATE SET description = EXCLUDED.description;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260628120000_playbook_sequences_polish.sql
-- ----------------------------------------------------------------------------

-- Sequences, prospect polish, Calendly, reply tracking

ALTER TABLE playbooks ADD COLUMN IF NOT EXISTS calendly_url TEXT;

ALTER TABLE playbook_run_contacts
  ADD COLUMN IF NOT EXISTS current_sequence_step INTEGER DEFAULT 0 NOT NULL,
  ADD COLUMN IF NOT EXISTS next_action_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS calendly_booked_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS playbook_sequence_steps (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  playbook_id UUID NOT NULL REFERENCES playbooks(id) ON DELETE CASCADE,
  step_order INTEGER NOT NULL,
  delay_days INTEGER DEFAULT 0 NOT NULL,
  tone TEXT DEFAULT 'professional',
  goal_override TEXT,
  subject_hint TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (playbook_id, step_order)
);

CREATE INDEX IF NOT EXISTS idx_sequence_steps_playbook ON playbook_sequence_steps(playbook_id, step_order);
CREATE INDEX IF NOT EXISTS idx_run_contacts_next_action ON playbook_run_contacts(next_action_at)
  WHERE next_action_at IS NOT NULL;

ALTER TABLE playbook_sequence_steps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members manage sequence steps" ON playbook_sequence_steps
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM playbooks p
      WHERE p.id = playbook_sequence_steps.playbook_id
        AND is_workspace_member(p.workspace_id)
        AND get_workspace_role(p.workspace_id) != 'viewer'
    )
  );

CREATE POLICY "Members update contact preferences" ON contact_preferences
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM contacts c
      WHERE c.id = contact_preferences.contact_id AND is_workspace_member(c.workspace_id)
    )
  );

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260629120000_workspace_email_settings.sql
-- ----------------------------------------------------------------------------

-- Per-workspace outbound email sender configuration (platform vs custom)

ALTER TABLE workspaces
  ADD COLUMN IF NOT EXISTS email_sender_mode TEXT NOT NULL DEFAULT 'platform'
    CHECK (email_sender_mode IN ('platform', 'custom')),
  ADD COLUMN IF NOT EXISTS custom_sender_name TEXT,
  ADD COLUMN IF NOT EXISTS custom_sender_email TEXT;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260629140000_email_personal_and_domain_verification.sql
-- ----------------------------------------------------------------------------

-- Add personal sender mode + domain verification fields for custom From addresses

ALTER TABLE workspaces DROP CONSTRAINT IF EXISTS workspaces_email_sender_mode_check;

ALTER TABLE workspaces
  ADD COLUMN IF NOT EXISTS sender_domain TEXT,
  ADD COLUMN IF NOT EXISTS sender_domain_status TEXT NOT NULL DEFAULT 'not_started',
  ADD COLUMN IF NOT EXISTS resend_domain_id TEXT;

ALTER TABLE workspaces
  ADD CONSTRAINT workspaces_email_sender_mode_check
    CHECK (email_sender_mode IN ('platform', 'personal', 'custom'));

ALTER TABLE workspaces
  ADD CONSTRAINT workspaces_sender_domain_status_check
    CHECK (sender_domain_status IN ('not_started', 'pending', 'verified', 'failed'));

-- Existing custom rows may have unverified domains
UPDATE workspaces
SET sender_domain_status = 'not_started'
WHERE email_sender_mode = 'custom'
  AND sender_domain IS NULL
  AND sender_domain_status = 'not_started';

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260629160000_workspace_leave_and_delete.sql
-- ----------------------------------------------------------------------------

-- Allow members to leave a group and owners to delete a group

CREATE POLICY "Members can leave workspace" ON workspace_members
  FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Owners can delete workspace" ON workspaces
  FOR DELETE USING (get_workspace_role(id) = 'owner');

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260707140000_platform_chat_delivery.sql
-- ----------------------------------------------------------------------------

-- Platform chat: deliver to Potentially users in-app, or via email when off-platform.

ALTER TABLE conversation_threads
  ADD COLUMN IF NOT EXISTS recipient_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS initiator_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS initiator_display_name TEXT,
  ADD COLUMN IF NOT EXISTS initiator_workspace_name TEXT;

CREATE INDEX IF NOT EXISTS idx_conversation_threads_recipient
  ON conversation_threads(recipient_user_id)
  WHERE recipient_user_id IS NOT NULL;

-- Recipients can read threads addressed to them
CREATE POLICY "Recipients can view their threads" ON conversation_threads
  FOR SELECT USING (recipient_user_id = auth.uid());

CREATE POLICY "Recipients can update their thread activity" ON conversation_threads
  FOR UPDATE
  USING (recipient_user_id = auth.uid())
  WITH CHECK (recipient_user_id = auth.uid());

CREATE POLICY "Recipients can view their thread messages" ON thread_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM conversation_threads t
      WHERE t.id = thread_messages.thread_id AND t.recipient_user_id = auth.uid()
    )
  );

CREATE POLICY "Recipients can reply in their threads" ON thread_messages
  FOR INSERT WITH CHECK (
    sender_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM conversation_threads t
      WHERE t.id = thread_messages.thread_id AND t.recipient_user_id = auth.uid()
    )
  );

-- Link existing threads when a profile is created with a matching contact email
CREATE OR REPLACE FUNCTION public.link_conversation_threads_for_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE conversation_threads ct
  SET recipient_user_id = NEW.id
  FROM contacts c
  WHERE ct.contact_id = c.id
    AND ct.recipient_user_id IS NULL
    AND c.email IS NOT NULL
    AND lower(trim(c.email)) = lower(trim(NEW.email));

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS link_threads_on_profile_insert ON profiles;
CREATE TRIGGER link_threads_on_profile_insert
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.link_conversation_threads_for_profile();

-- Also link when profile email is updated
CREATE OR REPLACE FUNCTION public.link_conversation_threads_on_profile_email_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.email IS NOT NULL AND (TG_OP = 'INSERT' OR NEW.email IS DISTINCT FROM OLD.email) THEN
    UPDATE conversation_threads ct
    SET recipient_user_id = NEW.id
    FROM contacts c
    WHERE ct.contact_id = c.id
      AND ct.recipient_user_id IS NULL
      AND c.email IS NOT NULL
      AND lower(trim(c.email)) = lower(trim(NEW.email));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS link_threads_on_profile_email_update ON profiles;
CREATE TRIGGER link_threads_on_profile_email_update
  AFTER INSERT OR UPDATE OF email ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.link_conversation_threads_on_profile_email_update();

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260707180000_playbook_sequences_cron.sql
-- ----------------------------------------------------------------------------

-- pg_cron job: POST /api/cron/playbook-sequences hourly.
-- Requires vault secrets (set once in Supabase SQL editor):
--   SELECT vault.create_secret('<CRON_SECRET>', 'potentially_cron_secret', 'Bearer for playbook cron');
--   SELECT vault.create_secret('https://potentially.mechlintech.com', 'potentially_app_url', 'App URL for cron');

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.invoke_playbook_sequence_cron()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault, pg_temp
AS $$
DECLARE
  cron_secret text;
  app_url text;
  request_id bigint;
BEGIN
  SELECT decrypted_secret INTO cron_secret
  FROM vault.decrypted_secrets
  WHERE name = 'potentially_cron_secret'
  LIMIT 1;

  SELECT decrypted_secret INTO app_url
  FROM vault.decrypted_secrets
  WHERE name = 'potentially_app_url'
  LIMIT 1;

  IF cron_secret IS NULL OR btrim(cron_secret) = '' THEN
    RAISE WARNING 'potentially_cron_secret not configured in vault';
    RETURN;
  END IF;

  IF app_url IS NULL OR btrim(app_url) = '' THEN
    app_url := 'https://potentially.mechlintech.com';
  END IF;

  SELECT net.http_post(
    url := rtrim(app_url, '/') || '/api/cron/playbook-sequences',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || cron_secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  ) INTO request_id;
END;
$$;

REVOKE ALL ON FUNCTION private.invoke_playbook_sequence_cron() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.invoke_playbook_sequence_cron() TO postgres;

DO $$
DECLARE
  existing_job_id bigint;
BEGIN
  SELECT jobid INTO existing_job_id
  FROM cron.job
  WHERE jobname = 'potentially-playbook-sequences'
  LIMIT 1;

  IF existing_job_id IS NOT NULL THEN
    PERFORM cron.unschedule(existing_job_id);
  END IF;
END $$;

SELECT cron.schedule(
  'potentially-playbook-sequences',
  '0 * * * *',
  $$SELECT private.invoke_playbook_sequence_cron();$$
);

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260707190000_thread_messages_realtime.sql
-- ----------------------------------------------------------------------------

-- Enable live chat updates via Supabase Realtime (filtered INSERT subscriptions).

ALTER TABLE thread_messages REPLICA IDENTITY FULL;

ALTER PUBLICATION supabase_realtime ADD TABLE thread_messages;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260708120000_sequence_allowed_weekdays.sql
-- ----------------------------------------------------------------------------

-- Per-step weekday window for follow-up triggers (0=Sun … 6=Sat).
ALTER TABLE playbook_sequence_steps
  ADD COLUMN IF NOT EXISTS allowed_weekdays INTEGER[] NOT NULL DEFAULT ARRAY[1, 2, 3, 4, 5];

COMMENT ON COLUMN playbook_sequence_steps.allowed_weekdays IS
  'Days of week (0=Sunday … 6=Saturday) when this follow-up may fire after delay_days.';

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260708140000_conversation_threads_per_contact.sql
-- ----------------------------------------------------------------------------

-- One conversation thread per contact per workspace (merge existing duplicates).

WITH ranked AS (
  SELECT
    id,
    workspace_id,
    contact_id,
    ROW_NUMBER() OVER (
      PARTITION BY workspace_id, contact_id
      ORDER BY last_message_at DESC NULLS LAST, created_at ASC
    ) AS rn
  FROM conversation_threads
  WHERE contact_id IS NOT NULL
),
keepers AS (
  SELECT id AS keep_id, workspace_id, contact_id
  FROM ranked
  WHERE rn = 1
),
dupes AS (
  SELECT r.id AS dupe_id, k.keep_id
  FROM ranked r
  INNER JOIN keepers k
    ON k.workspace_id = r.workspace_id
   AND k.contact_id = r.contact_id
  WHERE r.rn > 1
)
UPDATE thread_messages tm
SET thread_id = d.keep_id
FROM dupes d
WHERE tm.thread_id = d.dupe_id;

WITH ranked AS (
  SELECT
    id,
    workspace_id,
    contact_id,
    ROW_NUMBER() OVER (
      PARTITION BY workspace_id, contact_id
      ORDER BY last_message_at DESC NULLS LAST, created_at ASC
    ) AS rn
  FROM conversation_threads
  WHERE contact_id IS NOT NULL
)
DELETE FROM conversation_threads ct
USING ranked r
WHERE ct.id = r.id
  AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS idx_conversation_threads_workspace_contact
  ON conversation_threads (workspace_id, contact_id)
  WHERE contact_id IS NOT NULL;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260709120000_performance_package.sql
-- ----------------------------------------------------------------------------

-- Performance package: dashboard stats RPC, notification realtime, missing FK indexes

CREATE OR REPLACE FUNCTION get_dashboard_stats(p_user_id uuid, p_workspace_ids uuid[])
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'contacts_indexed', COALESCE((
      SELECT count(*)::int FROM contacts
      WHERE workspace_id = ANY(p_workspace_ids)
    ), 0),
    'recent_searches', COALESCE((
      SELECT count(*)::int FROM search_history
      WHERE user_id = p_user_id
    ), 0),
    'introductions_success', COALESCE((
      SELECT count(*)::int FROM introductions
      WHERE status = 'completed'
        AND workspace_id = ANY(p_workspace_ids)
    ), 0)
  );
$$;

GRANT EXECUTE ON FUNCTION public.get_dashboard_stats(uuid, uuid[]) TO authenticated;

ALTER TABLE notifications REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

CREATE INDEX IF NOT EXISTS idx_workspace_members_invited_by ON workspace_members(invited_by);
CREATE INDEX IF NOT EXISTS idx_workspace_invites_invited_by ON workspace_invites(invited_by);
CREATE INDEX IF NOT EXISTS idx_workspace_invites_workspace ON workspace_invites(workspace_id);
CREATE INDEX IF NOT EXISTS idx_contacts_owner ON contacts(owner_id);
CREATE INDEX IF NOT EXISTS idx_contact_notes_author ON contact_notes(author_id);
CREATE INDEX IF NOT EXISTS idx_contact_notes_contact ON contact_notes(contact_id);
CREATE INDEX IF NOT EXISTS idx_relationship_events_user ON relationship_events(user_id);
CREATE INDEX IF NOT EXISTS idx_introductions_connector ON introductions(connector_id);
CREATE INDEX IF NOT EXISTS idx_introductions_requester ON introductions(requester_id);
CREATE INDEX IF NOT EXISTS idx_introductions_target_contact ON introductions(target_contact_id);
CREATE INDEX IF NOT EXISTS idx_introductions_workspace ON introductions(workspace_id);
CREATE INDEX IF NOT EXISTS idx_saved_searches_user ON saved_searches(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_searches_workspace ON saved_searches(workspace_id);
CREATE INDEX IF NOT EXISTS idx_activities_user ON activities(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_workspace ON notifications(workspace_id);
CREATE INDEX IF NOT EXISTS idx_sync_jobs_connection ON sync_jobs(connection_id);
CREATE INDEX IF NOT EXISTS idx_sync_jobs_user ON sync_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_usage_user ON ai_usage(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_usage_workspace ON ai_usage(workspace_id);
CREATE INDEX IF NOT EXISTS idx_segments_created_by ON segments(created_by);
CREATE INDEX IF NOT EXISTS idx_email_templates_created_by ON email_templates(created_by);
CREATE INDEX IF NOT EXISTS idx_email_templates_workspace ON email_templates(workspace_id);
CREATE INDEX IF NOT EXISTS idx_playbooks_created_by ON playbooks(created_by);
CREATE INDEX IF NOT EXISTS idx_playbooks_template ON playbooks(template_id);
CREATE INDEX IF NOT EXISTS idx_playbook_runs_segment ON playbook_runs(segment_id);
CREATE INDEX IF NOT EXISTS idx_playbook_runs_triggered_by ON playbook_runs(triggered_by);
CREATE INDEX IF NOT EXISTS idx_playbook_runs_workspace ON playbook_runs(workspace_id);
CREATE INDEX IF NOT EXISTS idx_outbound_messages_run_contact ON outbound_messages(run_contact_id);
CREATE INDEX IF NOT EXISTS idx_outbound_messages_run ON outbound_messages(run_id);
CREATE INDEX IF NOT EXISTS idx_outbound_messages_workspace ON outbound_messages(workspace_id);

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260710120000_workspace_member_counts.sql
-- ----------------------------------------------------------------------------

-- Workspace member counts RPC for listUserWorkspaces

CREATE OR REPLACE FUNCTION get_workspace_member_counts(p_workspace_ids uuid[])
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT COALESCE(
    jsonb_object_agg(workspace_id::text, member_count),
    '{}'::jsonb
  )
  FROM (
    SELECT workspace_id, count(*)::int AS member_count
    FROM workspace_members
    WHERE workspace_id = ANY(p_workspace_ids)
    GROUP BY workspace_id
  ) counts;
$$;

GRANT EXECUTE ON FUNCTION public.get_workspace_member_counts(uuid[]) TO authenticated;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260710140000_phase3_optimizations.sql
-- ----------------------------------------------------------------------------

-- Phase 3: thread inbox stats, admin aggregates, contact growth

CREATE OR REPLACE FUNCTION get_thread_inbox_stats(
  p_thread_ids uuid[],
  p_exclude_sender_only boolean DEFAULT false
)
RETURNS TABLE (
  thread_id uuid,
  message_count int,
  last_body text,
  last_created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    tm.thread_id,
    count(*)::int AS message_count,
    (array_agg(tm.body ORDER BY tm.created_at DESC))[1] AS last_body,
    max(tm.created_at) AS last_created_at
  FROM thread_messages tm
  WHERE tm.thread_id = ANY(p_thread_ids)
    AND (
      NOT p_exclude_sender_only
      OR NOT (
        tm.message_type = 'system'
        AND COALESCE(tm.metadata->>'event', '') <> 'calendly_booked'
        AND COALESCE(tm.metadata->>'audience', '') <> 'all'
        AND (
          COALESCE(tm.metadata->>'audience', '') = 'sender'
          OR COALESCE(tm.metadata->>'channel', '') = 'email'
          OR tm.body LIKE 'Email sent:%'
        )
      )
    )
  GROUP BY tm.thread_id;
$$;

CREATE OR REPLACE FUNCTION get_admin_workspace_stats()
RETURNS TABLE (
  workspace_id uuid,
  name text,
  plan text,
  member_count int,
  contact_count int
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    w.id,
    w.name,
    w.plan,
    (SELECT count(*)::int FROM workspace_members wm WHERE wm.workspace_id = w.id),
    (SELECT count(*)::int FROM contacts c WHERE c.workspace_id = w.id)
  FROM workspaces w
  ORDER BY w.name;
$$;

CREATE OR REPLACE FUNCTION get_admin_user_workspace_counts()
RETURNS TABLE (
  user_id uuid,
  workspace_count int
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT wm.user_id, count(*)::int
  FROM workspace_members wm
  GROUP BY wm.user_id;
$$;

CREATE OR REPLACE FUNCTION get_workspace_contact_growth(
  p_workspace_ids uuid[],
  p_months int DEFAULT 6
)
RETURNS TABLE (
  month_label text,
  contact_count int
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', now()) - ((GREATEST(p_months, 1) - 1) || ' months')::interval,
      date_trunc('month', now()),
      '1 month'::interval
    ) AS month_start
  )
  SELECT
    to_char(m.month_start, 'Mon') AS month_label,
    (
      SELECT count(*)::int
      FROM contacts c
      WHERE c.workspace_id = ANY(p_workspace_ids)
        AND c.created_at < m.month_start + interval '1 month'
    ) AS contact_count
  FROM months m
  ORDER BY m.month_start;
$$;

GRANT EXECUTE ON FUNCTION public.get_thread_inbox_stats(uuid[], boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_workspace_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_user_workspace_counts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_workspace_contact_growth(uuid[], int) TO authenticated;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260710180000_chat_delete.sql
-- ----------------------------------------------------------------------------

-- Chat hide (per-user inbox delete) + recipient can delete own messages

CREATE TABLE IF NOT EXISTS chat_hides (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  thread_id UUID REFERENCES conversation_threads(id) ON DELETE CASCADE,
  run_contact_id UUID REFERENCES playbook_run_contacts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  CONSTRAINT chat_hides_has_target CHECK (thread_id IS NOT NULL OR run_contact_id IS NOT NULL)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_hides_user_thread
  ON chat_hides (user_id, thread_id)
  WHERE thread_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_hides_user_run_contact
  ON chat_hides (user_id, run_contact_id)
  WHERE run_contact_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_chat_hides_user ON chat_hides (user_id);

ALTER TABLE chat_hides ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own chat hides" ON chat_hides
  FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Recipients may delete their own messages (workspace members already have FOR ALL)
CREATE POLICY "Recipients can delete own thread messages" ON thread_messages
  FOR DELETE
  USING (
    sender_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM conversation_threads t
      WHERE t.id = thread_messages.thread_id
        AND t.recipient_user_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260714120000_connector_auto_sync.sql
-- ----------------------------------------------------------------------------

-- Opt-in daily auto-sync for connector accounts.

ALTER TABLE data_connectors
  ADD COLUMN IF NOT EXISTS auto_sync_enabled BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_data_connectors_auto_sync_due
  ON data_connectors (status, auto_sync_enabled, last_synced_at)
  WHERE auto_sync_enabled = true AND status = 'active';

-- Daily cron: POST /api/cron/connector-auto-sync
-- Reuses vault secrets potentially_cron_secret + potentially_app_url (same as playbook cron).

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.invoke_connector_auto_sync_cron()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault, pg_temp
AS $$
DECLARE
  cron_secret text;
  app_url text;
  request_id bigint;
BEGIN
  SELECT decrypted_secret INTO cron_secret
  FROM vault.decrypted_secrets
  WHERE name = 'potentially_cron_secret'
  LIMIT 1;

  SELECT decrypted_secret INTO app_url
  FROM vault.decrypted_secrets
  WHERE name = 'potentially_app_url'
  LIMIT 1;

  IF cron_secret IS NULL OR btrim(cron_secret) = '' THEN
    RAISE WARNING 'potentially_cron_secret not configured in vault';
    RETURN;
  END IF;

  IF app_url IS NULL OR btrim(app_url) = '' THEN
    app_url := 'https://potentially.mechlintech.com';
  END IF;

  SELECT net.http_post(
    url := rtrim(app_url, '/') || '/api/cron/connector-auto-sync',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || cron_secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  ) INTO request_id;
END;
$$;

REVOKE ALL ON FUNCTION private.invoke_connector_auto_sync_cron() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.invoke_connector_auto_sync_cron() TO postgres;

DO $$
DECLARE
  existing_job_id bigint;
BEGIN
  SELECT jobid INTO existing_job_id
  FROM cron.job
  WHERE jobname = 'potentially-connector-auto-sync'
  LIMIT 1;

  IF existing_job_id IS NOT NULL THEN
    PERFORM cron.unschedule(existing_job_id);
  END IF;
END $$;

SELECT cron.schedule(
  'potentially-connector-auto-sync',
  '0 3 * * *',
  $$SELECT private.invoke_connector_auto_sync_cron();$$
);

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260716120000_profile_group_images_and_details.sql
-- ----------------------------------------------------------------------------

-- Extra profile fields for richer public profiles
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS company TEXT,
  ADD COLUMN IF NOT EXISTS location TEXT,
  ADD COLUMN IF NOT EXISTS website_url TEXT;

-- Public image buckets (avatars + group logos)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  (
    'avatars',
    'avatars',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
  ),
  (
    'workspace-logos',
    'workspace-logos',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
  )
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Avatars: public read; users manage their own folder
DROP POLICY IF EXISTS "Avatar images are publicly accessible" ON storage.objects;
CREATE POLICY "Avatar images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);

DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
)
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);

DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
CREATE POLICY "Users can delete own avatar"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);

-- Workspace logos: public read; owners/admins manage folder named by workspace id
DROP POLICY IF EXISTS "Workspace logos are publicly accessible" ON storage.objects;
CREATE POLICY "Workspace logos are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'workspace-logos');

DROP POLICY IF EXISTS "Workspace admins can upload logos" ON storage.objects;
CREATE POLICY "Workspace admins can upload logos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'workspace-logos'
  AND public.get_workspace_role(((storage.foldername(name))[1])::uuid) IN ('owner', 'admin')
);

DROP POLICY IF EXISTS "Workspace admins can update logos" ON storage.objects;
CREATE POLICY "Workspace admins can update logos"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'workspace-logos'
  AND public.get_workspace_role(((storage.foldername(name))[1])::uuid) IN ('owner', 'admin')
)
WITH CHECK (
  bucket_id = 'workspace-logos'
  AND public.get_workspace_role(((storage.foldername(name))[1])::uuid) IN ('owner', 'admin')
);

DROP POLICY IF EXISTS "Workspace admins can delete logos" ON storage.objects;
CREATE POLICY "Workspace admins can delete logos"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'workspace-logos'
  AND public.get_workspace_role(((storage.foldername(name))[1])::uuid) IN ('owner', 'admin')
);

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260717120000_workflows.sql
-- ----------------------------------------------------------------------------

-- Agent Mode visual workflows (React Flow graphs)

CREATE TYPE workflow_status AS ENUM ('draft', 'active', 'paused', 'archived');

CREATE TABLE workflows (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  status workflow_status DEFAULT 'draft' NOT NULL,
  graph JSONB DEFAULT '{"nodes":[],"edges":[]}'::jsonb NOT NULL,
  segment_id UUID REFERENCES segments(id) ON DELETE SET NULL,
  playbook_id UUID REFERENCES playbooks(id) ON DELETE SET NULL,
  icp_profile JSONB DEFAULT '{}'::jsonb NOT NULL,
  matching_config JSONB DEFAULT '{}'::jsonb NOT NULL,
  send_config JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_workflows_workspace ON workflows(workspace_id);
CREATE INDEX idx_workflows_updated ON workflows(workspace_id, updated_at DESC);

CREATE TRIGGER workflows_updated_at
  BEFORE UPDATE ON workflows
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE workflows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members manage workflows" ON workflows
  FOR ALL USING (
    workspace_id IN (
      SELECT workspace_id FROM workspace_members WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    workspace_id IN (
      SELECT workspace_id FROM workspace_members WHERE user_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260717140000_workflow_last_run.sql
-- ----------------------------------------------------------------------------

-- Persist last workflow execution summary

ALTER TABLE workflows
  ADD COLUMN IF NOT EXISTS last_run JSONB;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260717180000_sync_source_outlook_mail.sql
-- ----------------------------------------------------------------------------

-- Outlook Email connector persists contacts with source = outlook_mail.
-- App types already include this value; add it to the Postgres enum.

ALTER TYPE sync_source ADD VALUE IF NOT EXISTS 'outlook_mail';

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260720100000_support_tickets_and_user_feature_flags.sql
-- ----------------------------------------------------------------------------

-- Support ticketing + per-user feature flag overrides
-- Applied via Supabase MCP; kept in repo for local parity.

DO $$ BEGIN
  CREATE TYPE public.support_ticket_status AS ENUM ('open', 'in_progress', 'waiting_on_user', 'resolved', 'closed');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.support_ticket_priority AS ENUM ('low', 'medium', 'high', 'urgent');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  assigned_admin_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  subject text NOT NULL,
  category text NOT NULL DEFAULT 'general',
  status public.support_ticket_status NOT NULL DEFAULT 'open',
  priority public.support_ticket_priority NOT NULL DEFAULT 'medium',
  last_message_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.support_ticket_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  body text NOT NULL,
  is_staff boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_feature_flags (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  flag_key text NOT NULL REFERENCES public.feature_flags(key) ON DELETE CASCADE,
  enabled boolean NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  PRIMARY KEY (user_id, flag_key)
);

CREATE INDEX IF NOT EXISTS support_tickets_user_id_idx ON public.support_tickets(user_id);
CREATE INDEX IF NOT EXISTS support_tickets_status_idx ON public.support_tickets(status);
CREATE INDEX IF NOT EXISTS support_tickets_assigned_admin_id_idx ON public.support_tickets(assigned_admin_id);
CREATE INDEX IF NOT EXISTS support_tickets_last_message_at_idx ON public.support_tickets(last_message_at DESC);
CREATE INDEX IF NOT EXISTS support_ticket_messages_ticket_id_idx ON public.support_ticket_messages(ticket_id, created_at);
CREATE INDEX IF NOT EXISTS user_feature_flags_flag_key_idx ON public.user_feature_flags(flag_key);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_ticket_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_feature_flags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS support_tickets_select ON public.support_tickets;
CREATE POLICY support_tickets_select ON public.support_tickets
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS support_tickets_insert ON public.support_tickets;
CREATE POLICY support_tickets_insert ON public.support_tickets
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS support_tickets_update ON public.support_tickets;
CREATE POLICY support_tickets_update ON public.support_tickets
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() OR public.is_admin())
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS support_tickets_delete ON public.support_tickets;
CREATE POLICY support_tickets_delete ON public.support_tickets
  FOR DELETE TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS support_ticket_messages_select ON public.support_ticket_messages;
CREATE POLICY support_ticket_messages_select ON public.support_ticket_messages
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.support_tickets t
      WHERE t.id = ticket_id AND (t.user_id = auth.uid() OR public.is_admin())
    )
  );

DROP POLICY IF EXISTS support_ticket_messages_insert ON public.support_ticket_messages;
CREATE POLICY support_ticket_messages_insert ON public.support_ticket_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    author_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.support_tickets t
      WHERE t.id = ticket_id
        AND (
          (t.user_id = auth.uid() AND is_staff = false)
          OR public.is_admin()
        )
    )
  );

DROP POLICY IF EXISTS user_feature_flags_select ON public.user_feature_flags;
CREATE POLICY user_feature_flags_select ON public.user_feature_flags
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS user_feature_flags_admin_all ON public.user_feature_flags;
CREATE POLICY user_feature_flags_admin_all ON public.user_feature_flags
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

INSERT INTO public.feature_flags (key, enabled, description) VALUES
  ('ai_search', true, 'AI Search — natural language search across your network'),
  ('graph_view', true, 'Network Graph — interactive relationship visualization'),
  ('outreach_engine', true, 'Outreach Engine — AI emails, LinkedIn messages, and intro requests'),
  ('team_collaboration', true, 'Team Collaboration — groups, invites, and member roles'),
  ('beta_connectors', true, 'Beta Connectors — early-access connector integrations'),
  ('billing_enforcement', true, 'Billing Enforcement — plan limits on search, imports, and usage'),
  ('playbook_mode', true, 'Playbooks (Agent Mode) — playbooks, runs, sequences, and segments'),
  ('platform_chat', true, 'Platform Chat — realtime prospect conversation UI'),
  ('analytics', true, 'Analytics — workspace analytics dashboard and insights'),
  ('csv_import', true, 'CSV Import — upload contacts from CSV / spreadsheets'),
  ('google_sync', true, 'Google Sync — Google Contacts, Calendar, and Gmail'),
  ('outlook_sync', true, 'Outlook Sync — Outlook contacts and mail'),
  ('support_ticketing', true, 'Support Ticketing — in-app support tickets under Resources')
ON CONFLICT (key) DO UPDATE SET
  description = EXCLUDED.description;

CREATE OR REPLACE FUNCTION public.touch_support_ticket_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS support_tickets_touch_updated_at ON public.support_tickets;
CREATE TRIGGER support_tickets_touch_updated_at
  BEFORE UPDATE ON public.support_tickets
  FOR EACH ROW EXECUTE FUNCTION public.touch_support_ticket_updated_at();

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260720120000_support_ticket_attachments.sql
-- ----------------------------------------------------------------------------

-- Support ticket file attachments (private storage)
-- Applied via Supabase MCP; kept in repo for local parity.

CREATE TABLE IF NOT EXISTS public.support_ticket_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  message_id uuid NOT NULL REFERENCES public.support_ticket_messages(id) ON DELETE CASCADE,
  uploaded_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  file_name text NOT NULL,
  file_size integer NOT NULL CHECK (file_size > 0),
  mime_type text NOT NULL,
  storage_path text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS support_ticket_attachments_ticket_id_idx
  ON public.support_ticket_attachments(ticket_id);
CREATE INDEX IF NOT EXISTS support_ticket_attachments_message_id_idx
  ON public.support_ticket_attachments(message_id);

ALTER TABLE public.support_ticket_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS support_ticket_attachments_select ON public.support_ticket_attachments;
CREATE POLICY support_ticket_attachments_select ON public.support_ticket_attachments
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.support_tickets t
      WHERE t.id = ticket_id AND (t.user_id = auth.uid() OR public.is_admin())
    )
  );

DROP POLICY IF EXISTS support_ticket_attachments_insert ON public.support_ticket_attachments;
CREATE POLICY support_ticket_attachments_insert ON public.support_ticket_attachments
  FOR INSERT TO authenticated
  WITH CHECK (
    uploaded_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.support_tickets t
      WHERE t.id = ticket_id
        AND (
          t.user_id = auth.uid()
          OR public.is_admin()
        )
    )
    AND EXISTS (
      SELECT 1 FROM public.support_ticket_messages m
      WHERE m.id = message_id AND m.ticket_id = ticket_id AND m.author_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS support_ticket_attachments_delete ON public.support_ticket_attachments;
CREATE POLICY support_ticket_attachments_delete ON public.support_ticket_attachments
  FOR DELETE TO authenticated
  USING (public.is_admin() OR uploaded_by = auth.uid());

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'support-attachments',
  'support-attachments',
  false,
  10485760,
  ARRAY[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'application/pdf',
    'text/plain',
    'text/csv',
    'application/zip',
    'application/x-zip-compressed',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE OR REPLACE FUNCTION public.can_access_support_attachment_path(object_name text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.support_tickets t
    WHERE t.id::text = (storage.foldername(object_name))[1]
      AND (t.user_id = auth.uid() OR public.is_admin())
  );
$$;

REVOKE ALL ON FUNCTION public.can_access_support_attachment_path(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_access_support_attachment_path(text) TO authenticated;

DROP POLICY IF EXISTS "Support attachments readable by ticket parties" ON storage.objects;
CREATE POLICY "Support attachments readable by ticket parties"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'support-attachments'
  AND public.can_access_support_attachment_path(name)
);

DROP POLICY IF EXISTS "Support attachments upload by ticket parties" ON storage.objects;
CREATE POLICY "Support attachments upload by ticket parties"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'support-attachments'
  AND public.can_access_support_attachment_path(name)
);

DROP POLICY IF EXISTS "Support attachments delete by ticket parties" ON storage.objects;
CREATE POLICY "Support attachments delete by ticket parties"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'support-attachments'
  AND public.can_access_support_attachment_path(name)
);

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260720140000_support_ticket_reads.sql
-- ----------------------------------------------------------------------------

-- Per-user last-read tracking for support ticket unread badges
-- Applied via Supabase MCP; kept in repo for local parity.

CREATE TABLE IF NOT EXISTS public.support_ticket_reads (
  ticket_id uuid NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  last_read_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (ticket_id, user_id)
);

CREATE INDEX IF NOT EXISTS support_ticket_reads_user_id_idx
  ON public.support_ticket_reads(user_id);

ALTER TABLE public.support_ticket_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS support_ticket_reads_select ON public.support_ticket_reads;
CREATE POLICY support_ticket_reads_select ON public.support_ticket_reads
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS support_ticket_reads_insert ON public.support_ticket_reads;
CREATE POLICY support_ticket_reads_insert ON public.support_ticket_reads
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.support_tickets t
      WHERE t.id = ticket_id AND (t.user_id = auth.uid() OR public.is_admin())
    )
  );

DROP POLICY IF EXISTS support_ticket_reads_update ON public.support_ticket_reads;
CREATE POLICY support_ticket_reads_update ON public.support_ticket_reads
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.support_unread_message_count(p_user_id uuid DEFAULT auth.uid())
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(COUNT(*)::integer, 0)
  FROM public.support_ticket_messages m
  JOIN public.support_tickets t ON t.id = m.ticket_id
  LEFT JOIN public.support_ticket_reads r
    ON r.ticket_id = t.id AND r.user_id = p_user_id
  WHERE m.author_id <> p_user_id
    AND m.created_at > COALESCE(r.last_read_at, '1970-01-01'::timestamptz)
    AND (
      t.user_id = p_user_id
      OR EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = p_user_id AND p.is_admin = true
      )
    );
$$;

REVOKE ALL ON FUNCTION public.support_unread_message_count(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.support_unread_message_count(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_support_ticket_read(p_ticket_id uuid, p_user_id uuid DEFAULT auth.uid())
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.support_tickets t
    WHERE t.id = p_ticket_id
      AND (
        t.user_id = p_user_id
        OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = p_user_id AND p.is_admin = true)
      )
  ) THEN
    RAISE EXCEPTION 'Ticket not found';
  END IF;

  INSERT INTO public.support_ticket_reads (ticket_id, user_id, last_read_at)
  VALUES (p_ticket_id, p_user_id, now())
  ON CONFLICT (ticket_id, user_id)
  DO UPDATE SET last_read_at = EXCLUDED.last_read_at;

  UPDATE public.notifications n
  SET read = true
  WHERE n.user_id = p_user_id
    AND n.read = false
    AND n.type = 'support_ticket'
    AND n.link ILIKE '%' || p_ticket_id::text || '%';
END;
$$;

REVOKE ALL ON FUNCTION public.mark_support_ticket_read(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_support_ticket_read(uuid, uuid) TO authenticated;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260721120000_platform_email_templates.sql
-- ----------------------------------------------------------------------------

-- Platform-managed transactional email copy (admin CMS).
-- Brand shell stays in application code; this table stores structured fields.

CREATE TABLE IF NOT EXISTS public.platform_email_templates (
  key TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  subject TEXT NOT NULL,
  preview TEXT NOT NULL DEFAULT '',
  banner TEXT,
  heading TEXT NOT NULL,
  greeting TEXT,
  body TEXT NOT NULL,
  quote_enabled BOOLEAN NOT NULL DEFAULT false,
  cta_label_on_platform TEXT NOT NULL DEFAULT '',
  cta_label_off_platform TEXT NOT NULL DEFAULT '',
  footer_note TEXT,
  secondary_label_off_platform TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

ALTER TABLE public.platform_email_templates ENABLE ROW LEVEL SECURITY;

-- No policies for authenticated/anon: service role only (admin + send paths).

DROP TRIGGER IF EXISTS platform_email_templates_updated_at ON public.platform_email_templates;
CREATE TRIGGER platform_email_templates_updated_at
  BEFORE UPDATE ON public.platform_email_templates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

INSERT INTO public.platform_email_templates (
  key, name, description, subject, preview, banner, heading, greeting, body,
  quote_enabled, cta_label_on_platform, cta_label_off_platform, footer_note,
  secondary_label_off_platform
) VALUES
(
  'signup_verification',
  'Signup verification',
  'Sent after signup to confirm the email address.',
  'Confirm your Potentially account',
  'Confirm your email to start using Potentially',
  'Warm introductions. Stronger relationships. Built for teams.',
  'Welcome aboard',
  'Hi {{name}},',
  'Thanks for joining Potentially. Confirm your email to unlock AI search, warm introductions, and your relationship graph.',
  false,
  'Confirm email address',
  'Confirm email address',
  'This link expires in 24 hours. If you did not create an account, you can safely ignore this email.',
  NULL
),
(
  'password_reset',
  'Password reset',
  'Sent when a user requests a password reset.',
  'Reset your Potentially password',
  'Reset your Potentially password',
  NULL,
  'Reset your password',
  NULL,
  'We received a request to reset your password. Click the button below to choose a new one.',
  false,
  'Reset password',
  'Reset password',
  'If you did not request this, you can ignore this email. Your password will not change.',
  NULL
),
(
  'magic_link',
  'Magic link sign-in',
  'One-time sign-in link email.',
  'Your Potentially sign-in link',
  'Your secure sign-in link for Potentially',
  'Warm introductions. Stronger relationships. Built for teams.',
  'Sign in to Potentially',
  NULL,
  'Click below to sign in securely. No password needed. This one-time link takes you straight to your workspace.',
  false,
  'Sign in to Potentially',
  'Sign in to Potentially',
  'This link expires shortly and can only be used once.',
  NULL
),
(
  'workspace_invite',
  'Workspace invite',
  'Invite a teammate to a workspace.',
  'Join {{workspace_name}} on Potentially',
  'You have been invited to join {{workspace_name}} on Potentially',
  'Warm introductions. Stronger relationships. Built for teams.',
  'You''re invited',
  NULL,
  'You have been invited to collaborate on <strong style="font-weight:600;color:#1A1A1A;">{{workspace_name}}</strong>. Join the workspace to search your shared network and request warm introductions.',
  false,
  'Accept invitation',
  'Accept invitation',
  'This invitation expires in 7 days.',
  NULL
),
(
  'chat_message',
  'Chat message',
  'Email when someone receives a Potentially chat message.',
  'New message from {{sender_name}}',
  '{{sender_name}} sent you a message on Potentially',
  'Join Potentially to reply and grow your network with warm introductions',
  'New message',
  'Hi {{name}},',
  '<strong style="font-weight:600;color:#1A1A1A;">{{sender_line}}</strong> sent you a message on Potentially.',
  true,
  'Open conversation',
  'Join Potentially to reply',
  'Create a free account to reply and unlock relationship intelligence for your team.',
  'Already have an account? Open your inbox'
),
(
  'support_ticket_received',
  'Support ticket received',
  'Confirmation to the user after they open a support ticket.',
  'Ticket received: {{subject}}',
  'We received your support request: {{subject}}',
  NULL,
  'We got your request',
  'Hi {{name}},',
  'We received your support request <strong style="font-weight:600;color:#1A1A1A;">{{subject}}</strong>. Our team will reply soon.',
  false,
  'View ticket',
  'View ticket',
  'You can add more detail anytime from your support inbox.',
  NULL
),
(
  'support_admin_alert',
  'Support admin alert',
  'Notify platform admins about a support ticket event.',
  '{{title}}',
  '{{title}}',
  NULL,
  'Support alert',
  NULL,
  '{{message}}',
  false,
  'Open ticket',
  'Open ticket',
  NULL,
  NULL
),
(
  'ticket_status_update',
  'Ticket status update',
  'Sent from admin when a ticket status changes.',
  'Ticket update: {{subject}}',
  'Your support ticket status is now {{status}}',
  NULL,
  'Ticket update',
  'Hi {{name}},',
  'Your support ticket status is now <strong style="font-weight:600;color:#1A1A1A;">{{status}}</strong>.',
  false,
  'View ticket',
  'Join Potentially to view ticket',
  'Reply anytime from your support inbox in Potentially.',
  NULL
),
(
  'ticket_staff_reply',
  'Ticket staff reply',
  'Sent from admin when support replies on a ticket.',
  'Re: {{subject}}',
  'Potentially Support replied to: {{subject}}',
  'Warm introductions. Stronger relationships. Built for teams.',
  'Support replied',
  'Hi {{name}},',
  'Potentially Support replied to your ticket.',
  true,
  'View and reply',
  'Join Potentially to reply',
  'Open the ticket in Potentially to continue the conversation.',
  NULL
),
(
  'outreach_marketing_footer',
  'Outreach marketing footer',
  'Slim Potentially strip appended to playbook outreach. Heading = brand line, body = tagline, CTA labels = invite/open links.',
  'Sent with Potentially',
  'Sent with Potentially',
  NULL,
  'Sent with Potentially',
  NULL,
  'Relationship intelligence for teams',
  false,
  'Open Potentially',
  'Join Potentially',
  'Prefer a warmer intro next time?',
  NULL
)
ON CONFLICT (key) DO NOTHING;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260724150000_intro_request_email_template.sql
-- ----------------------------------------------------------------------------

-- Seed intro_request platform email template (admin CMS + send-time fallback still uses code defaults).
-- Email goes to the contact: someone on Potentially would like an introduction to them.

INSERT INTO public.platform_email_templates (
  key, name, description, subject, preview, banner, heading, greeting, body,
  quote_enabled, cta_label_on_platform, cta_label_off_platform, footer_note,
  secondary_label_off_platform
) VALUES
(
  'intro_request',
  'Introduction request',
  'Email a contact when someone on Potentially would like an introduction to them.',
  '{{requester_name}} on Potentially would like an introduction',
  '{{requester_name}} on Potentially would like an introduction to you',
  'Warm introductions. Stronger relationships. Built for teams.',
  'Introduction request',
  'Hi {{name}},',
  '<p style="margin:0 0 16px;"><strong style="font-weight:600;color:#1A1A1A;">{{requester_name}}</strong> is reaching out through Potentially and would like an introduction to you.</p><p style="margin:0 0 16px;">Potentially helps people find warm paths through their professional networks. {{requester_name}} came across your profile there and thought a short introduction would be a good next step.</p><p style="margin:0 0 16px;">If you are open to connecting, reply to this email and say hello. A quick note back is enough to get the conversation started. If now is not the right time, you can ignore this message with no further follow up from us.</p><p style="margin:0;">Thanks for considering it. We appreciate your time.</p>',
  true,
  'Open Potentially',
  'Learn about Potentially',
  'This message was sent because someone using Potentially asked to be introduced to you. Reply to continue the conversation, or ignore if you prefer not to connect.',
  null
)
ON CONFLICT (key) DO NOTHING;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260724200000_intro_recipient_visibility.sql
-- ----------------------------------------------------------------------------

-- Allow users to see introduction requests emailed to their address (even across workspaces).
-- Use SECURITY DEFINER helpers so policies do not re-enter profiles/contacts RLS (avoids 42P17 recursion).

CREATE OR REPLACE FUNCTION public.current_profile_email()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT lower(btrim(email))
  FROM public.profiles
  WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.contact_email_is_mine(contact_email text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    contact_email IS NOT NULL
    AND public.current_profile_email() IS NOT NULL
    AND lower(btrim(contact_email)) = public.current_profile_email();
$$;

CREATE OR REPLACE FUNCTION public.can_view_intro_as_recipient(p_target_contact_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.contacts c
    WHERE c.id = p_target_contact_id
      AND public.contact_email_is_mine(c.email)
  );
$$;

REVOKE ALL ON FUNCTION public.current_profile_email() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.contact_email_is_mine(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_view_intro_as_recipient(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_profile_email() TO authenticated;
GRANT EXECUTE ON FUNCTION public.contact_email_is_mine(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_view_intro_as_recipient(uuid) TO authenticated;

DROP POLICY IF EXISTS "Users can view intros targeting their email" ON public.introductions;
CREATE POLICY "Users can view intros targeting their email"
  ON public.introductions
  FOR SELECT
  USING (public.can_view_intro_as_recipient(target_contact_id));

DROP POLICY IF EXISTS "Users can view contacts matching their email" ON public.contacts;
CREATE POLICY "Users can view contacts matching their email"
  ON public.contacts
  FOR SELECT
  USING (public.contact_email_is_mine(email));

-- Do not add a profiles SELECT policy that joins contacts/introductions:
-- that re-enters RLS and causes infinite recursion (42P17).
DROP POLICY IF EXISTS "Users can view requester profiles for intros to them" ON public.profiles;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260727200000_thread_message_attachments.sql
-- ----------------------------------------------------------------------------

-- Chat thread message file attachments (private storage)

CREATE TABLE IF NOT EXISTS public.thread_message_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id uuid NOT NULL REFERENCES public.conversation_threads(id) ON DELETE CASCADE,
  message_id uuid NOT NULL REFERENCES public.thread_messages(id) ON DELETE CASCADE,
  uploaded_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  file_name text NOT NULL,
  file_size integer NOT NULL CHECK (file_size > 0),
  mime_type text NOT NULL,
  storage_path text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS thread_message_attachments_thread_id_idx
  ON public.thread_message_attachments(thread_id);
CREATE INDEX IF NOT EXISTS thread_message_attachments_message_id_idx
  ON public.thread_message_attachments(message_id);

ALTER TABLE public.thread_message_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS thread_message_attachments_select ON public.thread_message_attachments;
CREATE POLICY thread_message_attachments_select ON public.thread_message_attachments
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.conversation_threads t
      WHERE t.id = thread_id
        AND (
          public.is_workspace_member(t.workspace_id)
          OR t.recipient_user_id = auth.uid()
        )
    )
  );

DROP POLICY IF EXISTS thread_message_attachments_insert ON public.thread_message_attachments;
CREATE POLICY thread_message_attachments_insert ON public.thread_message_attachments
  FOR INSERT TO authenticated
  WITH CHECK (
    uploaded_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.thread_messages m
      JOIN public.conversation_threads t ON t.id = m.thread_id
      WHERE m.id = message_id
        AND m.thread_id = thread_id
        AND m.sender_user_id = auth.uid()
        AND (
          public.is_workspace_member(t.workspace_id)
          OR t.recipient_user_id = auth.uid()
        )
    )
  );

DROP POLICY IF EXISTS thread_message_attachments_delete ON public.thread_message_attachments;
CREATE POLICY thread_message_attachments_delete ON public.thread_message_attachments
  FOR DELETE TO authenticated
  USING (uploaded_by = auth.uid());

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chat-attachments',
  'chat-attachments',
  false,
  26214400,
  ARRAY[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'application/pdf',
    'text/plain',
    'text/csv',
    'application/zip',
    'application/x-zip-compressed',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'video/mp4',
    'video/webm',
    'video/quicktime',
    'audio/mpeg',
    'audio/mp4',
    'audio/wav',
    'audio/ogg',
    'audio/webm',
    'audio/x-wav'
  ]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE OR REPLACE FUNCTION public.can_access_thread_attachment_path(object_name text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.conversation_threads t
    WHERE t.id::text = (storage.foldername(object_name))[1]
      AND (
        public.is_workspace_member(t.workspace_id)
        OR t.recipient_user_id = auth.uid()
      )
  );
$$;

REVOKE ALL ON FUNCTION public.can_access_thread_attachment_path(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_access_thread_attachment_path(text) TO authenticated;

DROP POLICY IF EXISTS "Chat attachments readable by thread parties" ON storage.objects;
CREATE POLICY "Chat attachments readable by thread parties"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'chat-attachments'
  AND public.can_access_thread_attachment_path(name)
);

DROP POLICY IF EXISTS "Chat attachments upload by thread parties" ON storage.objects;
CREATE POLICY "Chat attachments upload by thread parties"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'chat-attachments'
  AND public.can_access_thread_attachment_path(name)
);

DROP POLICY IF EXISTS "Chat attachments delete by thread parties" ON storage.objects;
CREATE POLICY "Chat attachments delete by thread parties"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'chat-attachments'
  AND public.can_access_thread_attachment_path(name)
);

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260727210000_sync_source_apollo.sql
-- ----------------------------------------------------------------------------

-- Track contacts imported or enriched via Apollo connector

ALTER TYPE sync_source ADD VALUE IF NOT EXISTS 'apollo';

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260727220000_apollo_records.sql
-- ----------------------------------------------------------------------------

-- Apollo tab: workspace-scoped saved search/enrichment records (separate from contacts)

CREATE TYPE apollo_record_type AS ENUM ('person', 'organization');

CREATE TABLE apollo_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  saved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  record_type apollo_record_type NOT NULL,
  apollo_id TEXT NOT NULL,
  name TEXT NOT NULL,
  title TEXT,
  email TEXT,
  phone TEXT,
  company_name TEXT,
  location TEXT,
  linkedin_url TEXT,
  primary_domain TEXT,
  enrichment_status TEXT NOT NULL DEFAULT 'none',
  enriched_at TIMESTAMPTZ,
  contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
  imported_to_contacts_at TIMESTAMPTZ,
  saved_from TEXT,
  raw_apollo JSONB NOT NULL DEFAULT '{}',
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (workspace_id, record_type, apollo_id)
);

CREATE INDEX apollo_records_workspace_type_idx ON apollo_records (workspace_id, record_type);
CREATE INDEX apollo_records_workspace_created_idx ON apollo_records (workspace_id, created_at DESC);
CREATE INDEX apollo_records_contact_id_idx ON apollo_records (contact_id) WHERE contact_id IS NOT NULL;

ALTER TABLE apollo_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view apollo records" ON apollo_records
  FOR SELECT USING (is_workspace_member(workspace_id));

CREATE POLICY "Members can manage apollo records" ON apollo_records
  FOR ALL USING (
    is_workspace_member(workspace_id) AND get_workspace_role(workspace_id) != 'viewer'
  );

-- Backfill from existing Apollo-sourced contacts
INSERT INTO apollo_records (
  workspace_id,
  record_type,
  apollo_id,
  name,
  title,
  email,
  phone,
  company_name,
  location,
  linkedin_url,
  contact_id,
  imported_to_contacts_at,
  saved_from,
  enrichment_status,
  raw_apollo,
  metadata
)
SELECT
  c.workspace_id,
  'person'::apollo_record_type,
  COALESCE(
    NULLIF(REPLACE(c.external_id, 'apollo:', ''), ''),
    'contact:' || c.id::text
  ),
  c.full_name,
  c.title,
  c.email,
  c.phone,
  c.company_name,
  c.location,
  c.linkedin_url,
  c.id,
  c.created_at,
  'backfill',
  'none',
  COALESCE(c.metadata, '{}'::jsonb),
  jsonb_build_object('backfilled_from_contact', true)
FROM contacts c
WHERE c.source = 'apollo'
ON CONFLICT (workspace_id, record_type, apollo_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- MIGRATION: 20260728120000_platform_prospects.sql
-- ----------------------------------------------------------------------------

-- Global Potentially prospect database (deduped by Apollo ID)

CREATE TABLE platform_prospects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  apollo_id TEXT NOT NULL UNIQUE,
  record_type apollo_record_type NOT NULL DEFAULT 'person',
  name TEXT NOT NULL,
  title TEXT,
  email TEXT,
  phone TEXT,
  company_name TEXT,
  location TEXT,
  linkedin_url TEXT,
  primary_domain TEXT,
  enrichment_status TEXT NOT NULL DEFAULT 'none',
  enriched_at TIMESTAMPTZ,
  raw_apollo JSONB NOT NULL DEFAULT '{}',
  metadata JSONB NOT NULL DEFAULT '{}',
  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  search_hit_count INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX platform_prospects_apollo_id_idx ON platform_prospects (apollo_id);
CREATE INDEX platform_prospects_enrichment_status_idx ON platform_prospects (enrichment_status);
CREATE INDEX platform_prospects_last_seen_idx ON platform_prospects (last_seen_at DESC);

ALTER TABLE contacts ADD COLUMN IF NOT EXISTS platform_prospect_id UUID REFERENCES platform_prospects(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS contacts_platform_prospect_id_idx ON contacts (platform_prospect_id) WHERE platform_prospect_id IS NOT NULL;

ALTER TABLE platform_prospects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view platform prospects" ON platform_prospects
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can insert platform prospects" ON platform_prospects
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update platform prospects" ON platform_prospects
  FOR UPDATE USING (auth.uid() IS NOT NULL);

-- Migrate from workspace-scoped apollo_records when present
INSERT INTO platform_prospects (
  apollo_id,
  record_type,
  name,
  title,
  email,
  phone,
  company_name,
  location,
  linkedin_url,
  primary_domain,
  enrichment_status,
  enriched_at,
  raw_apollo,
  metadata,
  first_seen_at,
  last_seen_at,
  search_hit_count
)
SELECT DISTINCT ON (apollo_id)
  apollo_id,
  record_type,
  name,
  title,
  email,
  phone,
  company_name,
  location,
  linkedin_url,
  primary_domain,
  enrichment_status,
  enriched_at,
  raw_apollo,
  metadata,
  created_at,
  updated_at,
  1
FROM apollo_records
WHERE apollo_id NOT LIKE 'contact:%'
  AND apollo_id NOT LIKE 'stub:%'
  AND apollo_id NOT LIKE 'email:%'
  AND apollo_id NOT LIKE 'linkedin:%'
  AND apollo_id NOT LIKE 'domain:%'
  AND apollo_id NOT LIKE 'name:%'
ORDER BY apollo_id, enriched_at DESC NULLS LAST, updated_at DESC
ON CONFLICT (apollo_id) DO UPDATE SET
  title = COALESCE(EXCLUDED.title, platform_prospects.title),
  email = COALESCE(EXCLUDED.email, platform_prospects.email),
  phone = COALESCE(EXCLUDED.phone, platform_prospects.phone),
  company_name = COALESCE(EXCLUDED.company_name, platform_prospects.company_name),
  location = COALESCE(EXCLUDED.location, platform_prospects.location),
  linkedin_url = COALESCE(EXCLUDED.linkedin_url, platform_prospects.linkedin_url),
  primary_domain = COALESCE(EXCLUDED.primary_domain, platform_prospects.primary_domain),
  enrichment_status = CASE
    WHEN platform_prospects.enrichment_status = 'enriched' THEN platform_prospects.enrichment_status
    ELSE EXCLUDED.enrichment_status
  END,
  enriched_at = COALESCE(platform_prospects.enriched_at, EXCLUDED.enriched_at),
  raw_apollo = CASE
    WHEN platform_prospects.enrichment_status = 'enriched' THEN platform_prospects.raw_apollo
    ELSE EXCLUDED.raw_apollo
  END,
  updated_at = GREATEST(platform_prospects.updated_at, EXCLUDED.updated_at);

UPDATE contacts c
SET platform_prospect_id = pp.id
FROM apollo_records ar
JOIN platform_prospects pp ON pp.apollo_id = ar.apollo_id
WHERE ar.contact_id = c.id
  AND c.platform_prospect_id IS NULL;

DROP TABLE IF EXISTS apollo_records;
