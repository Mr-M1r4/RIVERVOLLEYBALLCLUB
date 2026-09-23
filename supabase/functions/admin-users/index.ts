import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const headers={"content-type":"application/json","access-control-allow-origin":"*","access-control-allow-headers":"authorization, x-client-info, apikey, content-type"};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok",{headers});
  if (req.method !== "POST") return new Response(JSON.stringify({error:"POST required"}),{status:405,headers});
  try {
    const url=Deno.env.get("SUPABASE_URL")!;
    const key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader=req.headers.get("Authorization")||"";
    const token=authHeader.replace(/^Bearer\s+/i,"");
    if(!token) return new Response(JSON.stringify({error:"Unauthorized"}),{status:401,headers});
    const db=createClient(url,key);
    const {data:{user},error:userError}=await db.auth.getUser(token);
    if(userError||!user) return new Response(JSON.stringify({error:"Unauthorized"}),{status:401,headers});
    const {data:profile}=await db.from("profiles").select("role").eq("id",user.id).single();
    if(!profile || !["owner","admin"].includes(profile.role)) return new Response(JSON.stringify({error:"Forbidden"}),{status:403,headers});
    const body=await req.json().catch(()=>({}));
    const action=body.action||"list";
    if(action==="list"){
      const {data:users,error}=await db.auth.admin.listUsers({page:1,perPage:200});
      if(error) throw error;
      const ids=(users.users||[]).map(u=>u.id);
      const {data:profiles}=ids.length?await db.from("profiles").select("id,full_name,role,created_at").in("id",ids):{data:[]};
      const byId=new Map((profiles||[]).map(p=>[p.id,p]));
      return new Response(JSON.stringify({users:(users.users||[]).map(u=>({id:u.id,email:u.email,created_at:u.created_at,last_sign_in_at:u.last_sign_in_at,full_name:byId.get(u.id)?.full_name||"",role:byId.get(u.id)?.role||"staff"}))}),{headers});
    }
    if(profile.role!=="owner") return new Response(JSON.stringify({error:"Only the owner can change users or roles"}),{status:403,headers});
    if(action==="create"){
      const email=String(body.email||"").trim().toLowerCase();
      const password=String(body.password||"");
      const full_name=String(body.full_name||"").trim();
      const role=["owner","admin","staff"].includes(body.role)?body.role:"staff";
      if(!email||password.length<8) return new Response(JSON.stringify({error:"Email y contraseña de mínimo 8 caracteres son obligatorios"}),{status:400,headers});
      const {data:created,error}=await db.auth.admin.createUser({email,password,email_confirm:true});
      if(error) throw error;
      await db.from("profiles").upsert({id:created.user.id,full_name,role});
      return new Response(JSON.stringify({ok:true,id:created.user.id}),{headers});
    }
    if(action==="role"){
      const id=String(body.id||"");
      const role=["owner","admin","staff"].includes(body.role)?body.role:"staff";
      if(id===user.id && role!=="owner") return new Response(JSON.stringify({error:"No puedes quitarte el rol owner a ti mismo"}),{status:400,headers});
      const {error}=await db.from("profiles").update({role}).eq("id",id);
      if(error) throw error;
      return new Response(JSON.stringify({ok:true}),{headers});
    }
    if(action==="disable"){
      const id=String(body.id||"");
      if(id===user.id) return new Response(JSON.stringify({error:"No puedes desactivar tu propio usuario"}),{status:400,headers});
      const {error}=await db.auth.admin.updateUserById(id,{ban_duration:"876000h"});
      if(error) throw error;
      return new Response(JSON.stringify({ok:true}),{headers});
    }
    return new Response(JSON.stringify({error:"Acción no soportada"}),{status:400,headers});
  } catch(e) {
    return new Response(JSON.stringify({error:e instanceof Error?e.message:"Internal error"}),{status:500,headers});
  }
});