import { makeWASocket, useMultiFileAuthState, fetchLatestBaileysVersion, makeCacheableSignalKeyStore, DisconnectReason } from 'baileys';
import pino from 'pino';
import { Boom } from '@hapi/boom';
import { Ollama } from 'ollama'; 
import dotenv from 'dotenv';
import fs from 'fs';

dotenv.config();

// Inicialización de IA (Corrección de sintaxis para v0.5.0)
const ollama = new Ollama({ host: 'http://127.0.0.1:11434' });
let ownerJid = null;

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

    // 1. SOLICITUD DE CÓDIGO (Sólo si no está registrado)
    if (!sock.authState.creds.registered) {
        const botNumber = process.env.BOT_NUMBER;
        setTimeout(async () => {
            try {
                let code = await sock.requestPairingCode(botNumber);
                console.log(`\n============================================`);
                console.log(`CÓDIGO DE VINCULACIÓN: ${code}`);
                console.log(`============================================\n`);
            } catch (err) {
                console.error("Error al generar código:", err);
            }
        }, 5000);
    }

    sock.ev.on('creds.update', saveCreds);

    // 2. MONITOREO DE CONEXIÓN
    sock.ev.on('connection.update', (update) => {
        const { connection, lastDisconnect } = update;
        
        if (connection === 'open') {
            console.log('\n✅ BOT CONECTADO.');
            console.log(`--------------------------------------------`);
            console.log(`ESPERANDO MENSAJE DEL DUEÑO (${process.env.OWNER_RAW_NUMBER})`);
            console.log(`Envía "ACTIVAR" para validar tu ID.`);
            console.log(`--------------------------------------------\n`);
        }

        if (connection === 'close') {
            const shouldReconnect = (lastDisconnect.error instanceof Boom)?.output?.statusCode !== DisconnectReason.loggedOut;
            if (shouldReconnect) startBot();
        }
    });

    // 3. LÓGICA DE MENSAJES Y REGISTRO SECUENCIAL
    sock.ev.on('messages.upsert', async ({ messages }) => {
        const m = messages[0];
        if (!m.message || m.key.fromMe) return;

        const sender = m.key.remoteJid;
        const text = m.message.conversation || m.message.extendedTextMessage?.text || "";
        const ownerRaw = process.env.OWNER_RAW_NUMBER;

        // Registro del dueño mediante mensaje físico
        if (text.toUpperCase() === "ACTIVAR" && sender.includes(ownerRaw)) {
            ownerJid = sender;
            fs.appendFileSync('.env', `\nOWNER_JID=${sender}`);
            await sock.sendMessage(sender, { text: "✅ Identidad confirmada. El Bot ahora te reconoce como dueño." });
            console.log(`Dueño registrado: ${sender}`);
            return;
        }

        // Procesamiento con IA (Sólo responde si la IA está lista)
        try {
            const response = await ollama.chat({
                model: 'llama3.2:1b',
                messages: [{ role: 'user', content: text }],
            });
            await sock.sendMessage(sender, { text: response.message.content });
        } catch (error) {
            // IA en proceso de carga
        }
    });
}

startBot();
