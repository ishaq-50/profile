-- ============================================================
--  Portfolio Database Schema
--  Run: psql $DATABASE_URL -f migrations/001_init.sql
-- ============================================================

-- ── projects ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS projects (
  id          SERIAL PRIMARY KEY,
  title       VARCHAR(120)  NOT NULL,
  slug        VARCHAR(120)  NOT NULL UNIQUE,
  description TEXT          NOT NULL,
  long_desc   TEXT,
  tags        TEXT[]        DEFAULT '{}',
  github_url  VARCHAR(255),
  live_url    VARCHAR(255),
  image_url   VARCHAR(255),
  featured    BOOLEAN       DEFAULT false,
  published   BOOLEAN       DEFAULT true,
  sort_order  SMALLINT      DEFAULT 100,
  created_at  TIMESTAMPTZ   DEFAULT NOW(),
  updated_at  TIMESTAMPTZ   DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_projects_featured   ON projects (featured) WHERE published = true;
CREATE INDEX IF NOT EXISTS idx_projects_sort_order ON projects (sort_order, created_at DESC);

-- ── experience ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS experience (
  id           SERIAL PRIMARY KEY,
  company      VARCHAR(80)   NOT NULL,
  role         VARCHAR(120)  NOT NULL,
  location     VARCHAR(80),
  start_date   DATE          NOT NULL,
  end_date     DATE,                          -- NULL means current job
  bullets      TEXT[]        DEFAULT '{}',
  company_url  VARCHAR(255),
  sort_order   SMALLINT      DEFAULT 100
);

-- ── contact_messages ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS contact_messages (
  id         SERIAL PRIMARY KEY,
  name       VARCHAR(100)  NOT NULL,
  email      VARCHAR(255)  NOT NULL,
  message    TEXT          NOT NULL,
  read       BOOLEAN       DEFAULT false,
  created_at TIMESTAMPTZ   DEFAULT NOW()
);

-- ── auto-update updated_at ───────────────────────────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_projects_updated_at ON projects;
CREATE TRIGGER trg_projects_updated_at
  BEFORE UPDATE ON projects
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── seed data ────────────────────────────────────────────────────
INSERT INTO projects (title, slug, description, tags, github_url, live_url, featured, sort_order)
VALUES
  ('Launchpad SaaS',     'launchpad-saas',     'Full-stack SaaS boilerplate with auth, billing, and team management.',
   ARRAY['Next.js','TypeScript','Supabase','Stripe'], 'https://github.com', 'https://example.com', true,  10),
  ('DataPulse Analytics','datapulse-analytics','Real-time analytics dashboard processing 50k+ events/minute.',
   ARRAY['React','FastAPI','ClickHouse','WebSocket'],  'https://github.com', 'https://example.com', false, 20),
  ('Storefront Commerce','storefront-commerce', 'Headless e-commerce platform with custom CMS and multi-currency checkout.',
   ARRAY['Next.js','Node.js','PostgreSQL','Vercel'],   'https://github.com', 'https://example.com', false, 30),
  ('DevBot CLI',         'devbot-cli',          'AI-powered CLI for automated code review and test generation.',
   ARRAY['Node.js','OpenAI API','CLI','npm'],           'https://github.com', 'https://npmjs.com',   false, 40)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO experience (company, role, location, start_date, end_date, bullets, company_url, sort_order)
VALUES
  ('Stripe',    'Senior Software Engineer', 'San Francisco, CA', '2023-01-01', NULL,
   ARRAY[
     'Architected new merchant dashboard serving 2M+ businesses.',
     'Led migration to microservices on Kubernetes, cutting deploy time 40 → 4 min.',
     'Built fraud detection pipeline processing $10B+ in transactions.'
   ], 'https://stripe.com', 10),
  ('Vercel',    'Software Engineer',        'Remote',            '2022-07-01', '2022-12-31',
   ARRAY[
     'Contributed to Next.js App Router rollout; resolved 30+ beta issues.',
     'Improved edge runtime cold-start by 35% via dependency pruning.'
   ], 'https://vercel.com', 20),
  ('Freelance', 'Full-Stack Developer',     'Remote',            '2020-02-01', '2022-06-30',
   ARRAY[
     'Delivered 15+ client projects (e-commerce, SaaS, marketing).',
     '100% job success score on Upwork, $180K+ earned.'
   ], NULL, 30)
ON CONFLICT DO NOTHING;
