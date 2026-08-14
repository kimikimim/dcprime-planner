import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error(
    "🚨 [Supabase] 환경 변수를 찾을 수 없습니다! Cloudflare 설정을 확인하세요.",
    { url: supabaseUrl, key: supabaseAnonKey ? "있음" : "없음" }
  );
}

const client = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
  },
});

// 플래너 전용 테이블/RPC는 전부 `planner` 스키마에 있음 (dcprime-academy 메인 DB와 공유, 스키마로만 분리)
export const planner = client.schema('planner');
