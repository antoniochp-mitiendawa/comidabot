#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# BLOQUE 2: VINCULACIÓN Y REGISTRO DE DUEÑO
# PROYECTO: COMIDABOT - VOZ E INSTRUCCIONES
# ==========================================

echo -e "\n\e[1;32m[+] Iniciando FASE DE VINCULACIÓN (Bloque 2)...\e[0m"

cd $HOME/comidabot

# 1. Crear base de datos inicial si no existe
if [ ! -f config.json ]; then
cat << 'EOF' > config.json
{
  "botNumber": "",
  "ownerNumber": "",
  "ownerJID": "",
  "isConfigured": false
}
EOF
fi

# 2. Generar el script index.js con Lógica de Conexión Blindada
cat << 'EOF' > index.js
const { default: makeWASocket, useMultiFileAuthState, delay, fetchLatestBaileysVersion, DisconnectReason } = require("@whiskeysockets/baileys");
const pino = require("pino");
const fs = require("fs");
const readline = require("readline");

// Función para capturar datos ANTES de arrancar el socket
async function prepararDatos() {
    let config = JSON.parse(fs.readFileSync("./config.json"));
    
    // Si ya tenemos los números, no preguntamos nada
    if (config.botNumber && config.ownerNumber) return config;

    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    const question = (text) => new Promise((resolve) => rl.question(text, resolve));

    console.log("\n\x1b[1;32m--- CONFIGURACIÓN DE SEGURIDAD ---\x1b[0m");
    
    if (!config.botNumber) {
        const nBot = await question("👉 Introduce el número del BOT (521...): ");
        config.botNumber = nBot.trim();
    }
    
    if (!config.ownerNumber) {
        const nDueño = await question("👉 Introduce el número del DUEÑO (521...): ");
        config.ownerNumber = nDueño.trim();
    }

    fs.writeFileSync("./config.json", JSON.stringify(config, null, 2));
    rl.close(); // Cerramos la interfaz para que no choque con Baileys
    return config;
}

async function iniciarBot() {
    // CAPTURA PREVIA: Esto garantiza que no haya ERR_USE_AFTER_CLOSE
    const config = await prepararDatos();
    
    const { state, saveCreds } = await useMultiFileAuthState('sesion_auth');
    const { version } = await fetchLatestBaileysVersion();

    const sock = makeWASocket({
        version,
        auth: state,
        printQRInTerminal: false,
        logger: pino({ level: "silent" }),
        browser: ["Ubuntu", "Chrome", "20.0.04"]
    });

    sock.ev.on("creds.update", saveCreds);

    // PASO 1: VINCULACIÓN POR CÓDIGO
    if (!sock.authState.creds.registered) {
        console.log("\n\x1b[1;33m[!] Generando código de emparejamiento...\x1b[0m");
        await delay(5000);
        try {
            const codigo = await sock.requestPairingCode(config.botNumber);
            console.log(`\n\x1b[1;33m🔑 CÓDIGO DE VINCULACIÓN:\x1b[0m \x1b[1;32m${codigo}\x1b[0m`);
            console.log("\x1b[1;36m[i] Ingrésalo en tu WhatsApp ahora.\x1b[0m\n");
        } catch (e) {
            console.log("\x1b[1;31m[!] Error. Reinicia el script.\x1b[0m");
            process.exit(1);
        }
    }

    sock.ev.on("connection.update", async (update) => {
        const { connection, lastDisconnect } = update;
        if (connection === "open") {
            console.log("\n\x1b[1;32m✅ BOT CONECTADO EXITOSAMENTE\x1b[0m");
            console.log("\x1b[1;33m👉 PASO FINAL: Envía 'CONFIGURAR' desde tu número personal al BOT...\x1b[0m");
        }
        if (connection === "close") {
            const debeReconectar = lastDisconnect?.error?.output?.statusCode !== DisconnectReason.loggedOut;
            if (debeReconectar) iniciarBot();
        }
    });

    sock.ev.on("messages.upsert", async (m) => {
        const msg = m.messages[0];
        if (!msg.message || msg.key.fromMe) return;

        const jidRemoto = msg.key.remoteJid;
        const texto = (msg.message.conversation || msg.message.extendedTextMessage?.text || "").toUpperCase();

        if (jidRemoto.endsWith("@g.us")) return;

        let conf = JSON.parse(fs.readFileSync("./config.json"));

        // PASO 2: REGISTRO DE ID DEL DUEÑO (JID)
        if (texto === "CONFIGURAR" && !conf.isConfigured) {
            if (jidRemoto.includes(conf.ownerNumber)) {
                conf.ownerJID = jidRemoto;
                conf.isConfigured = true;
                fs.writeFileSync("./config.json", JSON.stringify(conf, null, 2));
                
                await sock.sendMessage(jidRemoto, { text: "✅ ID DUEÑO REGISTRADO.\n\nDesde ahora acepto tus instrucciones de voz y texto." });
                console.log(`\n\x1b[1;32m[✔] DUEÑO VINCULADO: ${jidRemoto}\x1b[0m`);
            }
        }
    });
}

iniciarBot();
EOF

# 3. Lanzamiento con acceso a terminal
echo -e "\e[1;32m[+] Ejecutando Motor de Conexión...\e[0m"
node index.js
