import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response(JSON.stringify({error:"POST required"}),{status:405,headers:{"content-type":"application/json"}});
  const url=Deno.env.get("SUPABASE_URL")!;
  const key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const db=createClient(url,key);
  const today=new Date();
  const dates=[0,1,3,7].map(n=>{const d=new Date(today);d.setDate(d.getDate()+n);return d.toISOString().slice(0,10)});
  const {data:memberships,error}=await db.from("memberships").select("id,athlete_id,end_date").eq("status","active").in("end_date",dates);
  if(error) return new Response(JSON.stringify({error:error.message}),{status:500,headers:{"content-type":"application/json"}});
  let created=0;
  for(const m of memberships||[]){
    const {data:athlete}=await db.from("athletes").select("full_name,email,phone").eq("id",m.athlete_id).single();
    for(const channel of ["email","whatsapp","sms"]){
      const {data:existing}=await db.from("notifications").select("id").eq("athlete_id",m.athlete_id).eq("channel",channel).eq("template","membership_expiry").gte("created_at",new Date(Date.now()-86400000).toISOString()).limit(1);
      if(!existing?.length){await db.from("notifications").insert({athlete_id:m.athlete_id,channel,template:"membership_expiry",scheduled_for:new Date().toISOString(),status:"pending",payload:{membership_id:m.id,end_date:m.end_date,full_name:athlete?.full_name,email:athlete?.email,phone:athlete?.phone}});created++;}
    }
  }
  return new Response(JSON.stringify({ok:true,checked:(memberships||[]).length,created}),{headers:{"content-type":"application/json"}});
});
