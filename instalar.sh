#!/bin/bash

# === SCRIPT DE INSTALACIÓN PARA COMIDABOT ===
# Ejecutar en Termux después de clonar el repositorio

echo "======================================"
echo "   COMIDABOT - INSTALACIÓN COMPLETA"
echo "======================================"
echo ""

# Paso 1: Actualizar Termux
echo "[1/9] Actualizando Termux..."
pkg update -y && pkg upgrade -y
echo "✅ Termux actualizado"
echo ""

# Paso 2: Instalar herramientas base
echo "[2/9] Instalando herramientas base (git, nodejs, python, ffmpeg)..."
pkg install git nodejs-lts python ffmpeg sox opus-tools tmux cmake clang make -y
echo "✅ Herramientas base instaladas"
echo ""

# Paso 3: Instalar y compilar Whisper.cpp (reemplaza Vosk)
echo "[3/9] Instalando Whisper.cpp para transcripción de voz offline..."
cd ~
if [ ! -d "whisper.cpp" ]; then
    git clone --depth 1 https://github.com/ggerganov/whisper.cpp.git
fi
cd whisper.cpp

# Compilar whisper.cpp (sin OpenMP para compatibilidad con Termux)
cmake -S . -B build -DGGML_NO_OPENMP=ON
cmake --build build -j"$(nproc)"

# Descargar modelo pequeño en español
cd models
if [ ! -f "ggml-base.bin" ]; then
    bash download-ggml-model.sh base
fi
cd ~
echo "✅ Whisper.cpp instalado y compilado"
echo ""

# Paso 4: Crear enlace simbólico para whisper-cli
echo "[4/9] Configurando acceso global a whisper-cli..."
mkdir -p ~/.local/bin
ln -sf ~/whisper.cpp/build/bin/whisper-cli ~/.local/bin/whisper-cli
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"
echo "✅ whisper-cli configurado"
echo ""

# Paso 5: Volver al directorio del proyecto
cd ~/comidabot

# Paso 6: Inicializar proyecto Node.js
echo "[5/9] Inicializando proyecto Node.js..."
npm init -y
echo "✅ Proyecto inicializado"
echo ""

# Paso 7: Instalar dependencias de Node.js (usando yskj-sqlite-android)
echo "[6/9] Instalando dependencias de Node.js..."
npm install @whiskeysockets/baileys qrcode-terminal pino yskj-sqlite-android wav @mapbox/node-pre-gyp
echo "✅ Dependencias instaladas"
echo ""

# Paso 8: Crear directorios necesarios
echo "[7/9] Creando directorios para sesión y base de datos..."
mkdir -p auth_info
mkdir -p db
mkdir -p temp_audio
echo "✅ Directorios creados"
echo ""

# Paso 9: Dar permisos de ejecución al bot
echo "[8/9] Dando permisos de ejecución..."
chmod +x bot.js
echo "✅ Permisos asignados"
echo ""

# Paso 10: Verificar instalación
echo "[9/9] Verificando instalación..."
if command -v whisper-cli &> /dev/null; then
    echo "✅ Whisper-cli: OK"
else
    echo "⚠️ Whisper-cli no encontrado, revisar instalación"
fi

if [ -d "node_modules" ]; then
    echo "✅ Node.js dependencias: OK"
else
    echo "❌ Node.js dependencias: ERROR"
fi

echo ""
echo "======================================"
echo "   INSTALACIÓN COMPLETA"
echo "======================================"
echo ""
echo "Para iniciar el bot, ejecuta:"
echo "  source ~/.bashrc"
echo "  node bot.js"
echo ""
echo "Nota: La primera ejecución pedirá vincular el bot y el dueño"
