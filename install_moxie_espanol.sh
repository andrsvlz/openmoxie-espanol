#!/bin/bash
set -e

echo "🤖 Instalador de Moxie en Español con MQTT TTS Mirror"
echo "=================================================="

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[PASO]${NC} $1"
}

# Verificar que estamos en el directorio correcto
if [ ! -f "docker-compose.yml" ] || [ ! -d "site" ]; then
    log_error "Este script debe ejecutarse desde el directorio raíz del repositorio openmoxie-ollama"
    exit 1
fi

log_step "1. Instalando Piper TTS en el sistema host"

# Crear directorio para Piper
PIPER_DIR="$HOME/piper"
mkdir -p "$PIPER_DIR"

# Descargar Piper si no existe
if [ ! -f "$PIPER_DIR/piper" ]; then
    log_info "Descargando Piper TTS..."
    cd "$PIPER_DIR"
    
    # Detectar arquitectura
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        PIPER_URL="https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_amd64.tar.gz"
    elif [ "$ARCH" = "aarch64" ]; then
        PIPER_URL="https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_arm64.tar.gz"
    else
        log_error "Arquitectura no soportada: $ARCH"
        exit 1
    fi
    
    wget -O piper.tar.gz "$PIPER_URL"
    tar -xzf piper.tar.gz --strip-components=1
    rm piper.tar.gz
    chmod +x piper
    
    log_info "Piper instalado en $PIPER_DIR/piper"
else
    log_info "Piper ya está instalado"
fi

# Descargar modelo de voz española si no existe
if [ ! -f "$PIPER_DIR/es_ES-davefx-medium.onnx" ]; then
    log_info "Descargando modelo de voz española (davefx-medium)..."
    cd "$PIPER_DIR"

    wget -O es_ES-davefx-medium.onnx "https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/davefx/medium/es_ES-davefx-medium.onnx"
    wget -O es_ES-davefx-medium.onnx.json "https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/davefx/medium/es_ES-davefx-medium.onnx.json"

    log_info "Modelo de voz española descargado"
else
    log_info "Modelo de voz española ya existe"
fi

# Volver al directorio del proyecto
cd - > /dev/null

log_step "2. Configurando servicio systemd para TTS local"

# Crear directorio para el servicio
sudo mkdir -p /opt/moxie-tts-subscriber

# Copiar archivos del servicio
sudo cp moxie-tts-subscriber/app.py /opt/moxie-tts-subscriber/
sudo chown -R $USER:$USER /opt/moxie-tts-subscriber

# Crear entorno virtual para el servicio
if [ ! -d "/opt/moxie-tts-subscriber/venv" ]; then
    log_info "Creando entorno virtual para el servicio TTS..."
    cd /opt/moxie-tts-subscriber
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install paho-mqtt flask waitress
    deactivate
    cd - > /dev/null
else
    log_info "Entorno virtual ya existe"
fi

# Instalar archivo de servicio systemd
log_info "Instalando servicio systemd..."
sudo cp moxie-tts.service /etc/systemd/system/

# Actualizar rutas en el servicio para el usuario actual
sudo sed -i "s|User=steve|User=$USER|g" /etc/systemd/system/moxie-tts.service
sudo sed -i "s|Group=steve|Group=$USER|g" /etc/systemd/system/moxie-tts.service
sudo sed -i "s|/home/steve/piper|$PIPER_DIR|g" /etc/systemd/system/moxie-tts.service

# Recargar systemd
sudo systemctl daemon-reload

log_step "3. Iniciando servicios Docker"

# Parar servicios existentes si están corriendo
log_info "Parando servicios existentes..."
docker compose down 2>/dev/null || true

# Iniciar servicios
log_info "Iniciando servicios Docker..."
docker compose up -d model-init data-init stt mqtt ollama ollama-init web

# Esperar a que los servicios estén listos
log_info "Esperando a que los servicios estén listos..."
sleep 30

# Verificar que los servicios están corriendo
log_info "Verificando servicios..."
docker compose ps

log_step "4. Habilitando e iniciando servicio TTS local"

# Habilitar e iniciar el servicio
sudo systemctl enable moxie-tts.service
sudo systemctl start moxie-tts.service

# Verificar estado
sleep 5
if sudo systemctl is-active --quiet moxie-tts.service; then
    log_info "✅ Servicio TTS iniciado correctamente"
else
    log_warn "⚠️ El servicio TTS puede tener problemas. Verificar con: sudo systemctl status moxie-tts.service"
fi

log_step "5. Configuración completada"

echo ""
echo "🎉 ¡Instalación completada!"
echo ""
echo "📋 PRÓXIMOS PASOS:"
echo ""
echo "1. Abrir el panel web: http://localhost:8000"
echo ""
echo "2. Ir a Setup → Speech-to-Text y configurar:"
echo "   - Backend: Local (faster-whisper)"
echo "   - Default language: es (español)"
echo "   - Model: faster-whisper-base"
echo ""
echo "3. Importar configuración en español:"
echo "   - Ir a http://localhost:8000/hive/setup"
echo "   - Subir archivo: samples/moxie_espanol_sample.json"
echo "   - Importar schedules y chats"
echo ""
echo "4. Asignar schedule en español a tu dispositivo:"
echo "   - Ir a Devices → [tu dispositivo]"
echo "   - Seleccionar: solo_chat_ollama_espanol"
echo ""
echo "🔧 COMANDOS ÚTILES:"
echo ""
echo "# Ver logs del servicio TTS:"
echo "sudo journalctl -u moxie-tts.service -f"
echo ""
echo "# Estado del servicio TTS:"
echo "sudo systemctl status moxie-tts.service"
echo ""
echo "# Monitor web del TTS:"
echo "http://localhost:8787"
echo ""
echo "# Probar MQTT manualmente:"
echo "mosquitto_pub -h localhost -p 1883 -t moxie/tts/text -m 'Hola, esto es una prueba'"
echo ""
echo "# Ver mensajes MQTT:"
echo "mosquitto_sub -h localhost -p 1883 -t moxie/tts/text"
echo ""
echo "# Ver logs de Docker:"
echo "docker compose logs -f web"
echo ""
echo "🎯 VERIFICACIÓN:"
echo ""
echo "1. Habla con Moxie en español"
echo "2. Verifica que el texto aparece en: mosquitto_sub -h localhost -p 1883 -t moxie/tts/text"
echo "3. Verifica que se reproduce audio localmente"
echo "4. Revisa el monitor en: http://localhost:8787"
echo ""
echo "¡Disfruta de tu Moxie en español! 🤖🇪🇸"
