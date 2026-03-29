#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# BLOQUE 2: VINCULACIÓN, DUEÑO Y FILTRO GRUPOS
# PROYECTO: COMIDABOT - INSTALACIÓN DESDE CERO
# ==========================================

echo -e "\n\e[1;32m[+] Iniciando FASE DE VINCULACIÓN (Bloque 2)...\e[0m"

# Entrar a la carpeta del proyecto creada en el Bloque 1
cd $HOME/comidabot

# 1. Crear archivo de configuración inicial (Base de Datos)
cat <<EOT > config.json
{
  "botNumber": "",
  "ownerNumber": "",
  "ownerJID": "",
  "isConfigured": false
}
EOT

# 2. Generar el script de conexión index.js
cat <<EOT > index.js
const { default: makeWASocket, useMultiFileAuthState, delay, fetchLatestBaileysVersion, disconnectReason } = require("@whiskeysockets/baileys");
const pino = require("pino");
const fs = require("fs");
const readline = require("readline");

// Configuración de interfaz de lectura (No se cerrará hasta terminar el proceso)
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const question = (text) => new Promise((resolve) => rl.question(text, resolve));

async function iniciarBot() {
    const { state, saveCreds } = await useMultiFileAuthState('sesion_auth');
    const { version } = await fetchLatestBaileysVersion();

    const sock = makeWASocket({
        version,
        auth: state,
        printQRInTerminal: false,
        logger: pino({ level: "silent" }),
        browser: ["Ubuntu", "Chrome", "20.0.04"]
    });

    // PASO 1: SOLICITAR NÚMERO DEL BOT PARA EMPAREJAMIENTO
    if (!sock.authState.creds.registered) {
        console.log("\n\x1b[1;32m--- VINCULACIÓN DE WHATSAPP ---\x1b[0m");
        const numeroBot = await question("\x1b[1;34m[?] Introduce el número del BOT (ej: 521XXXXXXXXXX): \x1b[0m");
        
        try {
            const codigo = await sock.requestPairingCode(numeroBot.trim());
            console.log("\n\x1b[1;33m[!] TU CÓDIGO DE VINCULACIÓN ES:\x1b[0m \x1b[1;32m" + codigo + "\x1b[0m");
            console.log("\x1b[1;36m[i] Ingrésalo en tu WhatsApp (Dispositivos vinculados).\x1b[0m\n");
        } catch (e) {
            console.log("\x1b[1;31m[!] Error al generar código. Verifica el formato del número.\x1b[0m");
            process.exit(1);
        }
    }

    sock.ev.on("creds.update", saveCreds);

    sock.ev.on("connection.update", async (update) => {
        const { connection, lastDisconnect } = update;
        
        if (connection === "open") {
            console.log("\n\x1b[1;32m[✔] ¡BOT CONECTADO EXITOSAMENTE!\x1b[0m");
            
            // PASO 2: SOLICITAR NÚMERO DEL DUEÑO EN TERMINAL
            const numDueño = await question("\x1b[1;34m[?] Introduce el número del DUEÑO que dará las instrucciones (ej: 521XXXXXXXXXX): \x1b[0m");
            
            let config = JSON.parse(fs.readFileSync("./config.json"));
            config.ownerNumber = numDueño.trim();
            fs.writeFileSync("./config.json", JSON.stringify(config, null, 2));
            
            console.log("\n\x1b[1;33m[!] PASO FINAL:\x1b[0m Envía la palabra \x1b[1;32m'CONFIGURAR'\x1b[0m desde tu número personal al chat del BOT para extraer tu ID.");
        }
        
        if (connection === "close") {
            const shouldReconnect = lastDisconnect.error?.output?.statusCode !== 401;
            if (shouldReconnect) iniciarBot();
        }
    });

    sock.ev.on("messages.upsert", async (m) => {
        const msg = m.messages[0];
        if (!msg.message || msg.key.fromMe) return;

        const jidRemoto = msg.key.remoteJid;
        const texto = msg.message.conversation || msg.message.extendedTextMessage?.text || "";

        // BLOQUEO DE GRUPOS: El bot ignora cualquier mensaje que no sea chat individual
        if (jidRemoto.endsWith("@g.us")) return;

        let config = JSON.parse(fs.readFileSync("./config.json"));

        // PASO 3: EXTRACCIÓN DEL JID DEL DUEÑO POR MENSAJE
        if (texto.toUpperCase() === "CONFIGURAR" && !config.isConfigured) {
            // Verificar que el mensaje provenga del número registrado en el paso 2
            if (jidRemoto.includes(config.ownerNumber)) {
                config.ownerJID = jidRemoto;
                config.isConfigured = true;
                fs.writeFileSync("./config.json", JSON.stringify(config, null, 2));
                
                await sock.sendMessage(jidRemoto, { text: "✅ ¡ID DE DUEÑO REGISTRADO!\n\nID: " + jidRemoto + "\nDesde ahora solo aceptaré instrucciones de este número." });
                console.log("\n\x1b[1;32m[✔] PROCESO COMPLETADO: Dueño vinculado y JID guardado.\x1b[0m");
            }
        }
    });
}

iniciarBot();
EOT

# 3. Ejecutar el proceso
echo -e "\e[1;32m[+] Ejecutando Motor de Conexión...\e[0m"
node index.js
