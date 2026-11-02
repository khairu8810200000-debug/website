import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
Deno.serve(async (req) => {
 if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
 try {
  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const token = Deno.env.get("WHATSAPP_ACCESS_TOKEN")!;
  const phoneId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID")!;
  const template = Deno.env.get("WHATSAPP_TEMPLATE_NAME") || "payment_reminder";
  const version = Deno.env.get("WHATSAPP_API_VERSION") || "v23.0";
  const db = createClient(url, serviceKey);
  const today = new Date().toISOString().slice(0,10);
  const { data: customers, error } = await db.from("payment_customers").select("*").eq("active",true).eq("whatsapp_opt_in",true);
  if (error) throw error;
  const results = [];
  for (const c of customers || []) {
   const due = c.next_due_date;
   const days = Math.round((new Date(due+"T00:00:00Z").getTime()-new Date(today+"T00:00:00Z").getTime())/86400000);
   const type = days===3?"3_days":days===1?"1_day":days===0?"due_today":days<0?"overdue":null;
   if (!type) continue;
   const { data: exists } = await db.from("payment_reminder_logs").select("id").eq("customer_id",c.id).eq("due_date",due).eq("reminder_type",type).maybeSingle();
   if (exists) continue;
   const dateText = new Date(due+"T00:00:00").toLocaleDateString("ms-MY");
   const body = { messaging_product:"whatsapp", to:c.phone, type:"template", template:{ name:template, language:{code:"ms"}, components:[{type:"body",parameters:[{type:"text",text:c.name},{type:"text",text:c.vehicle_model},{type:"text",text:"RM "+Number(c.monthly_amount).toFixed(2)},{type:"text",text:dateText}]}] } };
   const response = await fetch("https://graph.facebook.com/"+version+"/"+phoneId+"/messages",{method:"POST",headers:{"Authorization":"Bearer "+token,"Content-Type":"application/json"},body:JSON.stringify(body)});
   const payload = await response.json();
   if (!response.ok) { results.push({customer:c.name,error:payload}); continue; }
   await db.from("payment_reminder_logs").insert({customer_id:c.id,due_date:due,reminder_type:type,whatsapp_message_id:payload.messages?.[0]?.id||null});
   results.push({customer:c.name,sent:true,type});
  }
  return new Response(JSON.stringify({date:today,results}),{headers:{...cors,"Content-Type":"application/json"}});
 } catch (e) { return new Response(JSON.stringify({error:String(e)}),{status:500,headers:{...cors,"Content-Type":"application/json"}}); }
});