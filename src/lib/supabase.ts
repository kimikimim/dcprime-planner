import { createClient } from '@supabase/supabase-js';

// dcprime-academy와 같은 Supabase 프로젝트(anon key라 클라이언트 노출 전제).
// Cloudflare Workers(정적 자산 전용)는 빌드 환경변수 주입 UI가 막혀 있어 기본값으로 고정.
const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL || 'https://smnakhjdtbqgwocwlluz.supabase.co';
const supabaseAnonKey =
  import.meta.env.PUBLIC_SUPABASE_ANON_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtbmFraGpkdGJxZ3dvY3dsbHV6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY4NDc2MDQsImV4cCI6MjA5MjQyMzYwNH0._jfUSWEVlMr8oapYLul33LRrhEnRJBSgppGNR1jshnA';

const client = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
  },
});

// 플래너 전용 테이블/RPC는 전부 `planner` 스키마에 있음 (dcprime-academy 메인 DB와 공유, 스키마로만 분리)
export const planner = client.schema('planner');
