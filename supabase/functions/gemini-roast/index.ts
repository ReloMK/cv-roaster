// SECURE GEMINI FUNCTION: this code runs on Supabase, never in the browser.
const allowedOrigins = new Set([
  'https://relomk.github.io',
  'http://localhost:5500',
  'http://127.0.0.1:5500',
]);

function corsHeaders(origin: string | null) {
  // Only the deployed site (and local development) receive browser CORS access.
  const allowedOrigin = origin && allowedOrigins.has(origin) ? origin : 'https://relomk.github.io';
  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Content-Type': 'application/json',
    'Vary': 'Origin',
  };
}

Deno.serve(async (request) => {
  const origin = request.headers.get('origin');
  const headers = corsHeaders(origin);

  if (request.method === 'OPTIONS') return new Response('ok', { headers });
  if (request.method !== 'POST' || (origin && !allowedOrigins.has(origin))) {
    return new Response(JSON.stringify({ error: 'Request not allowed.' }), { status: 403, headers });
  }

  try {
    const { prompt } = await request.json();
    if (typeof prompt !== 'string' || prompt.trim().length < 20 || prompt.length > 24000) {
      return new Response(JSON.stringify({ error: 'Invalid roast request.' }), { status: 400, headers });
    }

    const geminiKey = Deno.env.get('GEMINI_API_KEY');
    if (!geminiKey) throw new Error('GEMINI_API_KEY secret is not configured.');

    const response = await fetch(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': geminiKey },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.7, maxOutputTokens: 2048 },
        }),
      },
    );
    const payload = await response.json();
    if (!response.ok) {
      console.error('Gemini error:', response.status, payload?.error?.message);
      return new Response(JSON.stringify({ error: 'Gemini could not generate a roast. Please try again.' }), { status: 502, headers });
    }

    const text = payload?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) return new Response(JSON.stringify({ error: 'Gemini returned no usable response.' }), { status: 502, headers });
    return new Response(JSON.stringify({ text }), { status: 200, headers });
  } catch (error) {
    console.error('gemini-roast error:', error instanceof Error ? error.message : error);
    return new Response(JSON.stringify({ error: 'Unable to process your roast.' }), { status: 500, headers });
  }
});
