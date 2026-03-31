import { makeWASocket, useMultiFileAuthState, fetchLatestBaileysVersion, makeCacheableSignalKeyStore, DisconnectReason } from '@whiskeysockets/baileys';
import pino from 'pino';
import { Boom } from '@hapi/boom';
import fs from 'fs';
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
        printQRInTerminal: false, // Desactivado para usar Pairing Code
        auth: {
            creds: state.creds,
            keys: makeCacheableSignalKeyStore(state.keys, pino({ level: 'silent' })),
        },
        browser: ["Ubuntu", "Chrome", "20.0.04"],
    });

    // LÓGICA DE EMPAREJAMIENTO POR CÓDIGO
    if (!sock.authState.creds.registered) {
        const phoneNumber = BOT_NUMBER;
        setTimeout(async () => {
            let code = await sock.requestPairingCode(phoneNumber);
            console.log(`\n--------------------------------------------`);
            console.log(`TU CÓDIGO DE VINCULACIÓN ES: ${code}`);
            console.log(`--------------------------------------------\n`);
        }, 3000);
    }

    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('messages.upsert', async ({ messages }) => {
        const m = messages[0];
        if (!m.message || m.key.fromMe) return;

        const sender = m.key.remoteJid;
        const text = m.message.conversation || m.message.extendedTextMessage?.text;

        // SEGURIDAD: Reconocer al dueño
        if (sender === OWNER_NUMBER) {
            if (text.toUpperCase() === "ACTIVAR CONFIGURACION") {
                await sock.sendMessage(sender, { text: "✅ ID de Dueño verificado y guardado en memoria técnica." });
                // Aquí se dispararía la lógica de grabación en SQLite
                return;
            }
            
            if (text.toLowerCase().startsWith("memoriza")) {
                await sock.sendMessage(sender, { text: "🧠 Entendido. Guardando instrucción en mi base de datos..." });
                // Lógica para guardar en SQLite
                return;
            }
        }

        // RESPUESTA DE IA PARA CLIENTES
        try {
            const response = await ollama.chat({
                model: 'llama3.2:1b',
                messages: [{ role: 'user', content: text }],
            });
            await sock.sendMessage(sender, { text: response.message.content });
        } catch (error) {
            console.error("Error en IA:", error);
        }
    });

    sock.ev.on('connection.update', (update) => {
        const { connection, lastDisconnect } = update;
        if (connection === 'close') {
            const shouldReconnect = (lastDisconnect.error instanceof Boom)?.output?.statusCode !== DisconnectReason.loggedOut;
            if (shouldReconnect) startBot();
        } else if (connection === 'open') {
            console.log('✅ ComidaBot conectado exitosamente a WhatsApp');
        }
    });
}

startBot();
