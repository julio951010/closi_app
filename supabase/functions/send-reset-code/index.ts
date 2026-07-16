import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import nodemailer from "npm:nodemailer@6.9.16";

function b64(str: string): string {
  const bytes = new TextEncoder().encode(str);
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Metodo no permitido" }), {
        status: 405,
        headers: { "Content-Type": "application/json" },
      });
    }

    const rawText = await req.text();
    const body = JSON.parse(rawText);

    if (!body.email || !body.codigo) {
      return new Response(JSON.stringify({ error: "email y codigo requeridos" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const host = Deno.env.get("SMTP_HOST") ?? "";
    const port = parseInt(Deno.env.get("SMTP_PORT") ?? "465");
    const user = Deno.env.get("SMTP_USER") ?? "";
    const pass = Deno.env.get("SMTP_PASS") ?? "";
    const from = Deno.env.get("SMTP_FROM") ?? "";
    const fromName = Deno.env.get("SMTP_FROM_NAME") ?? "Closi";

    if (!user || !pass || !from) {
      return new Response(JSON.stringify({
        recibido: true,
        email: body.email,
        codigo: body.codigo,
        nota: "SMTP no configurado - modo dev",
      }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
    });

    await transporter.sendMail({
      from: `${fromName} <${from}>`,
      to: body.email,
      subject: "=?UTF-8?B?" + b64("Codigo de recuperacion - Closi") + "?=",
      text: "Tu codigo de verificacion es: " + body.codigo + "\n\nExpira en 10 minutos.",
      html: `<!DOCTYPE html><html><head><meta charset="UTF-8"><style>
body{font-family:Arial,sans-serif;background:#f4f4f4;margin:0;padding:0}
.container{max-width:480px;margin:40px auto;background:#fff;border-radius:12px;overflow:hidden}
.header{background:linear-gradient(135deg,#0A2E6E,#1E6FE8);padding:24px;text-align:center}
.header h1{color:#fff;margin:0;font-size:22px}
.content{padding:32px 24px;text-align:center}
.content p{color:#555;font-size:15px;line-height:1.6;margin:0 0 20px}
.codigo{font-size:36px;font-weight:700;letter-spacing:8px;color:#1245A8;background:#f0f4ff;padding:16px;border-radius:12px;display:inline-block;margin:8px 0}
.footer{padding:16px 24px;text-align:center;font-size:12px;color:#999}
</style></head><body>
<div class="container">
<div class="header"><h1>Closi</h1></div>
<div class="content">
<p>Hemos recibido una solicitud para restablecer tu contrasena.</p>
<p>Tu codigo de verificacion es:</p>
<div class="codigo">${body.codigo}</div>
<p>Este codigo expira en <strong>10 minutos</strong>.</p>
<p>Si no solicitaste este cambio, ignora este mensaje.</p>
</div>
<div class="footer"><p>&copy; ${new Date().getFullYear()} Closi</p></div>
</div></body></html>`,
    });

    return new Response(JSON.stringify({ success: true, email: body.email }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Error interno";
    console.error("Error:", msg);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
