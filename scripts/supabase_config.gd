class_name SupabaseConfig
extends RefCounted
## Paste your Supabase project's details here (Project Settings -> API).
## The "anon public" key is meant to be in the app; security comes from the
## database rules in supabase/schema.sql. NEVER put the "service_role" key here.

const URL := ""  # e.g. "https://abcdefghijkl.supabase.co"
const ANON_KEY := ""  # the long "anon public" key
