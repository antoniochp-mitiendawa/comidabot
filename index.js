import { makeWASocket, useMultiFileAuthState, fetchLatestBaileysVersion, makeCacheableSignalKeyStore, DisconnectReason } from '@whiskeysockets/baileys';
import pino from 'pino';
import { Boom } from '@hapi/boom';
import { ollama } from 'ollama'; 
import dotenv from 'dotenv';

dotenv.config();

const OWNER_NUMBER = process.env.OWNER_RAW_NUMBER + "@s.whatsapp.net";
const BOT_NUMBER = process.env.BOT_NUMBER;

async function startBot() {
    const { state, saveCreds } = await useMultiFileAuthState('session_auth');
    const { version } = await fetchLatestBaileysVersion();

    const sock = makeWASocket({
        version,
        logger: pino({ level: 'silent' }),
        printQRInTerminal: false,
        auth: {
            creds: state.creds,
            keys: makeCacheableSignalKeyStore(state.keys, pino({ level: 'silent' })),
        },
        browser: ["Ubuntu", "Chrome", "20.0.04"],
    });

    // Solicitar Código de Emparejamiento
    if (!sock.authState.creds.registered) {
        setTimeout(async () => {
            let code = await sock.requestPairingCode(BOT_NUMBER);
            console.log(`\n============================================`);
            console.log(`CÓDIGO PARA WHATSAPP: ${code}`);
            console.log(`============================================\n`);
        }, 5000);
    }

    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('messages.upsert', async ({ messages }) => {
        const m = messages[0];
        if (!m.message || m.key.fromMe) return;

        const sender = m.key.remoteJid;
        const text = m.message.conversation || m.message.extendedTextMessage?.text || "";

        // Seguridad del Dueño
        if (sender === OWNER_NUMBER) {
            if (text.toUpperCase() === "ACTIVAR CONFIGURACION") {
                return await sock.sendMessage(sender, { text: "✅ Sistema activado para el dueño." });
            }
        }

        // Respuesta con IA (Ollama)
        try {
            const response = await ollama.chat({
                model: 'llama3.2:1b',
                messages: [{ role: 'user', content: text }],
            });
            await sock.sendMessage(sender, { text: response.message.content });
        } catch (err) {
            console.log("Esperando respuesta de IA local...");
        }
    });

    sock.ev.on('connection.update', (update) => {
        const { connection, lastDisconnect } = update;
        if (connection === 'close') {
            const shouldReconnect = (lastDisconnect.error instanceof Boom)?.output?.statusCode !== DisconnectReason.loggedOut;
            if (shouldReconnect) startBot();
        } else if (connection === 'open') {
            console.log('✅ Conectado a WhatsApp correctamente.');
        }
    });
}

startBot();
