#!/data/data/com.termux/files/usr/bin/bash

# =========================================================
# SCRIPT DE INSTALACIÓN AUTOMÁTICA - BOT IA LOCAL (GRATIS)
# =========================================================
# Orden: 1. Sistema -> 2. IA (Ollama) -> 3. Librerías -> 4. Vinculación
# =========================================================

echo "[1/5] Actualizando sistema Termux..."
pkg update -y && pkg upgrade -y

echo "[2/5] Instalando herramientas base (Node.js, Python, Git)..."
pkg install -y nodejs git python wget proot-distro
termux-setup-storage

echo "[3/5] Configurando el motor de IA Local (Ollama)..."
# Instalamos Ubuntu interno para que Ollama corra sin errores de librerías
if [ ! -d "$(pwd)/ubuntu-fs" ]; then
    proot-distro install ubuntu
fi

# Comando para instalar Ollama dentro del contenedor de forma silenciosa
proot-distro login ubuntu -- bash -c "curl -fsSL https://ollama.com/install.sh | sh"

# Iniciamos Ollama en segundo plano para descargar el modelo inicial
echo "Descargando modelo de IA (Llama 3.2 - Ligero)..."
proot-distro login ubuntu -- bash -c "ollama serve > /dev/null 2>&1 & sleep 5 && ollama pull llama3.2:1b"

echo "[4/5] Instalando OpenClaw y dependencias de WhatsApp..."
# Clonamos o descargamos las dependencias necesarias
npm install -g npm@latest
npm install # Esto leerá tu package.json automáticamente cuando el repo esté listo

# Creamos la carpeta de configuración si no existe
mkdir -p config

echo "---------------------------------------------------------"
echo " INSTALACIÓN DE LIBRERÍAS Y MOTOR DE IA COMPLETADA "
echo "---------------------------------------------------------"
echo "El sistema está listo. Ahora procederemos a la vinculación."
echo ""

# Fase Final: Petición de datos al usuario
read -p "Introduce tu número de WhatsApp (ej. 521XXXXXXXXXX): " USER_PHONE

# Ejecución del bot para generar el Pairing Code
# Aquí llamamos al inicio de OpenClaw con el número proporcionado
echo "Generando código de emparejamiento para: $USER_PHONE..."
echo "Espera un momento a que aparezca el código de 8 dígitos..."

# Comando para iniciar el proceso de vinculación
# Se asume que el archivo start.sh o el comando de node ya está configurado
node index.js --phone "$USER_PHONE" --pairing
