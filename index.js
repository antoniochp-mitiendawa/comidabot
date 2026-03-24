const { 
    default: makeWASocket, 
    useMultiFileAuthState, 
    fetchLatestBaileysVersion, 
    makeCacheableSignalKeyStore,
    delay,
    DisconnectReason
} = require("@whiskeysockets/baileys");
const pino = require("pino");
const readline = require("readline");
const fs = require("fs");

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const question = (text) => new Promise((resolve) => rl.question(text, resolve));

if (!fs.existsSync("./base_datos.json")) {
    fs.writeFileSync("./base_datos.json", JSON.stringify({ bot_num: null, propietario_num: null, nombre_negocio: "Mi Negocio" }));
}
let db = JSON.parse(fs.readFileSync("./base_datos.json", "utf-8"));

async function iniciarBot() {
    const { state, saveCreds } = await useMultiFileAuthState('sesion_auth');
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
        // ESTO EVITA EL BUCLE DE TU CONSOLA:
        syncFullHistory: false,
        shouldSyncHistoryGroupMessages: false,
        patchMessageBeforeSending: (message) => {
            const requiresPatch = !!(message.buttonsMessage || message.templateMessage || message.listMessage);
            if (requiresPatch) {
                message = { viewOnceMessage: { message: { messageContextInfo: { deviceListMetadataVersion: 2, deviceListMetadata: {}, }, ...message, }, }, };
            }
            return message;
        },
    });

    if (!sock.authState.creds.registered) {
        console.log("\n--- CONFIGURACIÓN INICIAL ---");
        const bNum = await question('Número del BOT (ej: 521...): ');
        db.bot_num = bNum.replace(/[^0-9]/g, '');
        const pNum = await question('Número del DUEÑO (ej: 521...): ');
        db.propietario_num = pNum.replace(/[^0-9]/g, '');
        fs.writeFileSync("./base_datos.json", JSON.stringify(db, null, 2));
        
        const codigo = await sock.requestPairingCode(db.bot_num);
        console.log("\nTU CÓDIGO: " + codigo + "\n");
    }

    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('connection.update', (update) => {
        const { connection, lastDisconnect } = update;
        if (connection === 'close') {
            if (lastDisconnect.error?.output?.statusCode !== DisconnectReason.loggedOut) iniciarBot();
        } else if (connection === 'open') {
            console.log("\n[!] INTERCEPTOR CONECTADO Y LISTO\n");
        }
    });

    sock.ev.on('messages.upsert', async ({ messages }) => {
        const m = messages[0];
        if (!m.message) return;

        // Capturar el texto de cualquier tipo de mensaje
        const tipo = Object.keys(m.message)[0];
        if (tipo === 'protocolMessage' || tipo === 'senderKeyDistributionMessage') return; // Ignorar basura técnica

        const texto = m.message.conversation || m.message.extendedTextMessage?.text || m.message.imageMessage?.caption || "";
        const idRemitente = m.key.remoteJid;
        const numLimpio = idRemitente.replace(/[^0-9]/g, '');

        console.log(`[Mensaje Recibido] De: ${numLimpio} | Texto: ${texto}`);

        // DETECCIÓN DE AUTORIDAD (Dueño o Bot mismo)
        const esAutoridad = numLimpio.includes(db.bot_num) || numLimpio.includes(db.propietario_num) || m.key.fromMe;

        if (esAutoridad && texto.toLowerCase() === 'test') {
            await sock.sendPresenceUpdate('composing', idRemitente);
            await delay(1500);
            await sock.sendMessage(idRemitente, { text: "✅ Sistema interceptado. Te reconozco como Autoridad." });
        }
    });
}

iniciarBot();
