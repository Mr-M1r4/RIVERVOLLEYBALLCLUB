import {createClient} from '@supabase/supabase-js'
const url=process.env.NEXT_PUBLIC_SUPABASE_URL||'https://ewsygagytkicxdhykjfw.supabase.co'
const key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY||'sb_publishable_7lsAhSgheKjMpsBPGPYZKA_jzXrAASH'
export const supabase=createClient(url,key,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}})
