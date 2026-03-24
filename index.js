const { 
    default: makeWASocket, 
    useMultiFileAuthState, 
    fetchLatestBaileysVersion, 
    makeCacheableSignalKeyStore 
} = require("@whiskeysockets/baileys");
const pino = require("pino");
const readline = require("readline");
const fs = require("fs");

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const question = (text) => new Promise((resolve) => rl.question(text, resolve));

// Cargar Memoria Local
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
    });

    // CONFIGURACIÓN INICIAL (Solo si no está registrado)
    if (!sock.authState.creds.registered) {
        console.log("\n--- CONFIGURACIÓN DE IDENTIDAD ---");
        
        // 1. Número del Bot (para el Pairing)
        const numBotInput = await question('1. Introduce el número del BOT (ej: 5215512345678): ');
        const numBotLimpio = numBotInput.replace(/[^0-9]/g, '');
        db.bot_num = numBotLimpio + "@s.whatsapp.net";

        // 2. Número del Propietario (el que manda audios)
        const numPropInput = await question('2. Introduce el número del PROPIETARIO (puede ser el mismo): ');
        const numPropLimpio = numPropInput.replace(/[^0-9]/g, '');
        db.propietario_num = numPropLimpio + "@s.whatsapp.net";

        // Guardar configuración
        fs.writeFileSync("./base_datos.json", JSON.stringify(db, null, 2));
        console.log(`[+] Registrado: Bot (${db.bot_num}) | Propietario (${db.propietario_num})`);

        try {
            const codigo = await sock.requestPairingCode(numBotLimpio);
            console.log("\n************************************");
            console.log("TU CODIGO DE VINCULACION ES: " + codigo); 
            console.log("************************************\n");
        } catch (error) {
            console.log("Error: ", error);
        }
    }

    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('connection.update', (update) => {
        const { connection } = update;
        if (connection === 'close') iniciarBot();
        else if (connection === 'open') {
            console.log("\n[!] BOT ACTIVADO Y ESCUCHANDO LOCALMENTE\n");
        }
    });

    sock.ev.on('messages.upsert', async ({ messages }) => {
        const m = messages[0];
        if (!m.message) return;

        const idRemitente = m.key.remoteJid;
        
        // RECONOCIMIENTO DE AUTORIDAD (Bot mismo o Propietario Externo)
        const esAutoridad = (idRemitente === db.bot_num || idRemitente === db.propietario_num);
        const mensajeTipo = Object.keys(m.message)[0];

        if (esAutoridad) {
            // Si es audio, confirmamos recepción (el procesado local viene después)
            if (mensajeTipo === 'audioMessage') {
                await sock.sendMessage(idRemitente, { text: "Audio recibido, Propietario. Iniciando procesamiento local de información..." });
            } 
            // Comando de prueba en texto
            else {
                const texto = m.message.conversation || m.message.extendedTextMessage?.text || "";
                if (texto.toLowerCase() === 'test') {
                    await sock.sendMessage(idRemitente, { text: "✅ Identidad confirmada. Tienes permisos de Administrador." });
                }
            }
        } 
        
        // LÓGICA PARA CLIENTES
        else {
            const textoCliente = m.message.conversation || m.message.extendedTextMessage?.text || "";
            if (textoCliente.toLowerCase().includes("hola") || textoCliente.toLowerCase().includes("menu")) {
                let respuesta = `*${db.nombre_negocio}*\n\n🍴 *Menú de hoy:* ${db.menu}\n🕒 *Horario:* ${db.horario}`;
                await sock.sendMessage(idRemitente, { text: respuesta });
            }
        }
    });
}

iniciarBot();
