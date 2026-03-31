```sql
-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users table (maps to Supabase auth.users)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Organizations table
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Organization members (many-to-many between users and orgs)
CREATE TABLE organization_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member', -- 'member', 'admin', 'owner'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, organization_id)
);

-- API projects
CREATE TABLE api_projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (organization_id, slug)
);

-- API endpoints
CREATE TABLE api_endpoints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES api_projects(id) ON DELETE CASCADE,
  path TEXT NOT NULL,
  method TEXT NOT NULL, -- 'GET', 'POST', etc.
  description TEXT,
  cost_per_call NUMERIC(10, 6) NOT NULL DEFAULT 0.0001, -- cost in dollars
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (project_id, path, method)
);

-- API keys
CREATE TABLE api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES api_projects(id) ON DELETE CASCADE,
  key_prefix TEXT NOT NULL,
  key_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  revoked BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- API usage logs
CREATE TABLE api_usage_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  endpoint_id UUID NOT NULL REFERENCES api_endpoints(id) ON DELETE CASCADE,
  api_key_id UUID REFERENCES api_keys(id) ON DELETE SET NULL,
  status_code INTEGER NOT NULL,
  response_time_ms INTEGER NOT NULL,
  cost NUMERIC(10, 6) NOT NULL,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Monthly usage summaries
CREATE TABLE monthly_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES api_projects(id) ON DELETE CASCADE,
  month DATE NOT NULL,
  total_calls BIGINT NOT NULL DEFAULT 0,
  total_cost NUMERIC(10, 2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (project_id, month)
);

-- Create indexes for performance
CREATE INDEX idx_api_usage_logs_endpoint_id ON api_usage_logs(endpoint_id);
CREATE INDEX idx_api_usage_logs_api_key_id ON api_usage_logs(api_key_id);
CREATE INDEX idx_api_usage_logs_created_at ON api_usage_logs(created_at);
CREATE INDEX idx_monthly_usage_project_id ON monthly_usage(project_id);
CREATE INDEX idx_monthly_usage_month ON monthly_usage(month);
CREATE INDEX idx_organization_members_user_id ON organization_members(user_id);
CREATE INDEX idx_organization_members_organization_id ON organization_members(organization_id);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_endpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_usage_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_usage ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can only see themselves
CREATE POLICY user_select_policy ON users
  FOR SELECT USING (id = auth.uid());

-- Organizations: members can see their orgs
CREATE POLICY organization_select_policy ON organizations
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM organization_members
      WHERE organization_members.organization_id = organizations.id
      AND organization_members.user_id = auth.uid()
    )
  );

-- Organization members: users can see their own memberships
CREATE POLICY organization_members_select_policy ON organization_members
  FOR SELECT USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM organization_members
      WHERE organization_members.organization_id = organization_members.organization_id
      AND organization_members.user_id = auth.uid()
      AND organization_members.role IN ('admin', 'owner')
    )
  );

-- API projects: org members can see their projects
CREATE POLICY api_projects_select_policy ON api_projects
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM organization_members
      WHERE organization_members.organization_id = api_projects.organization_id
      AND organization_members.user_id = auth.uid()
    )
  );

-- API endpoints: org members can see their endpoints
CREATE POLICY api_endpoints_select_policy ON api_endpoints
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      JOIN api_projects ap ON ap.organization_id = om.organization_id
      WHERE om.user_id = auth.uid()
      AND ap.id = api_endpoints.project_id
    )
  );

-- API keys: org members can see their keys
CREATE POLICY api_keys_select_policy ON api_keys
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      JOIN api_projects ap ON ap.organization_id = om.organization_id
      WHERE om.user_id = auth.uid()
      AND ap.id = api_keys.project_id
    )
  );

-- API usage logs: org members can see their logs
CREATE POLICY api_usage_logs_select_policy ON api_usage_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      JOIN api_projects ap ON ap.organization_id = om.organization_id
      JOIN api_endpoints ae ON ae.project_id = ap.id
      WHERE om.user_id = auth.uid()
      AND ae.id = api_usage_logs.endpoint_id
    )
  );

-- Monthly usage: org members can see their usage
CREATE POLICY monthly_usage_select_policy ON monthly_usage
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      JOIN api_projects ap ON ap.organization_id = om.organization_id
      WHERE om.user_id = auth.uid()
      AND ap.id = monthly_usage.project_id
    )
  );

-- Seed data for testing
INSERT INTO users (id, email) VALUES
  ('11111111-1111-1111-1111-111111111111', 'test@example.com');

INSERT INTO organizations (id, name, slug) VALUES
  ('22222222-2222-2222-2222-222222222222', 'Test Org', 'test-org');

INSERT INTO organization_members (user_id, organization_id, role) VALUES
  ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'owner');

INSERT INTO api_projects (id, organization_id, name, slug) VALUES
  ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'Test Project', 'test-project');

INSERT INTO api_endpoints (id, project_id, path, method, description, cost_per_call) VALUES
  ('44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333', '/users', 'GET', 'Get all users', 0.0001),
  ('55555555-5555-5555-5555-555555555555', '33333333-3333-3333-3333-333333333333', '/users', 'POST', 'Create user', 0.0002);

-- Create a trigger to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add triggers to all tables with updated_at
CREATE TRIGGER update_users_timestamp
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_organizations_timestamp
BEFORE UPDATE ON organizations
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_organization_members_timestamp
BEFORE UPDATE ON organization_members
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_api_projects_timestamp
BEFORE UPDATE ON api_projects
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_api_endpoints_timestamp
BEFORE UPDATE ON api_endpoints
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_api_keys_timestamp
BEFORE UPDATE ON api_keys
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_monthly_usage_timestamp
BEFORE UPDATE ON monthly_usage
FOR EACH ROW EXECUTE FUNCTION update_timestamp();
```