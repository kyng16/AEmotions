import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import multer from 'multer';
import fs from 'fs';
import { OpenAI } from 'openai';

const app = express();
// Ensure uploads directory exists (Render ephemeral FS still needs the folder during request lifetime)
try { fs.mkdirSync('uploads', { recursive: true }); } catch {}

// Preserve original filename (with extension) so OpenAI can infer format correctly
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, 'uploads/'),
  filename: (_req, file, cb) => cb(null, `${Date.now()}_${file.originalname}`),
});
const upload = multer({ storage });

const PORT = process.env.PORT || 3000;
const OPENAI_MODEL = process.env.OPENAI_MODEL || 'gpt-4.1';
const OPENAI_TTS_MODEL = process.env.OPENAI_TTS_MODEL || 'tts-1';
const OPENAI_STT_MODEL = process.env.OPENAI_STT_MODEL || 'whisper-1';

if (!process.env.OPENAI_API_KEY) {
  console.warn('[WARN] OPENAI_API_KEY is not set. The service will fail on requests.');
}

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

app.use(cors({ origin: '*'}));
app.use(express.json({ limit: '10mb' }));

// Friendly landing page for root path
app.get('/', (_req, res) => {
  res.type('html').send(`
    <html>
      <head><meta charset="utf-8"><title>App Emotions Backend</title></head>
      <body style="font-family:system-ui,Segoe UI,Arial,sans-serif;padding:24px;">
        <h1>App Emotions Backend</h1>
        <p>Status endpoint: <a href="/health">/health</a></p>
        <h2>Endpoints</h2>
        <ul>
          <li>GET <code>/health</code></li>
          <li>POST <code>/chat</code> – { messages:[{role,content}], model?, temperature? }</li>
          <li>POST <code>/stt</code> – multipart: file, language?</li>
          <li>POST <code>/tts</code> – { text, voice?, format? } → audio/mpeg</li>
        </ul>
      </body>
    </html>
  `);
});

app.get('/health', (_req, res) => {
  res.json({ ok: true, model: OPENAI_MODEL });
});

app.post('/chat', async (req, res) => {
  try {
    const { messages, model, temperature } = req.body || {};
    if (!Array.isArray(messages)) {
      return res.status(400).json({ error: 'messages must be an array' });
    }

    const response = await openai.chat.completions.create({
      model: model || OPENAI_MODEL,
      messages,
      temperature: typeof temperature === 'number' ? temperature : 0.7,
    });

    const choice = response.choices?.[0];
    const content = choice?.message?.content ?? '';
    res.json({ content, usage: response.usage || null, id: response.id });
  } catch (err) {
    console.error('CHAT ERROR', err);
    res.status(500).json({ error: String(err?.message || err) });
  }
});

app.post('/stt', upload.single('file'), async (req, res) => {
  const file = req.file;
  if (!file) return res.status(400).json({ error: 'file is required' });
  try {
    const language = req.body?.language;
    const transcription = await openai.audio.transcriptions.create({
      // Ensure the stream path (includes extension) so SDK sends correct filename
      file: fs.createReadStream(file.path),
      model: OPENAI_STT_MODEL,
      ...(language ? { language } : {}),
    });

    res.json({ text: transcription.text || '' });
  } catch (err) {
    console.error('STT ERROR', err);
    res.status(500).json({ error: String(err?.message || err) });
  } finally {
    try { fs.unlinkSync(file.path); } catch {}
  }
});

app.post('/tts', async (req, res) => {
  try {
    const { text, voice, format } = req.body || {};
    if (!text || typeof text !== 'string') {
      return res.status(400).json({ error: 'text is required' });
    }

    const response = await openai.audio.speech.create({
      model: OPENAI_TTS_MODEL,
      voice: voice || 'alloy',
      input: text,
      format: format || 'mp3',
    });

    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);
    res.set('Content-Type', 'audio/mpeg');
    res.send(buffer);
  } catch (err) {
    console.error('TTS ERROR', err);
    res.status(500).json({ error: String(err?.message || err) });
  }
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
