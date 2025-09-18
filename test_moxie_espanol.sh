#!/bin/bash

# Script de pruebas de aceptación para Moxie en español
echo "🧪 Pruebas de Aceptación - Moxie en Español"
echo "=========================================="

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

test_pass() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
}

test_fail() {
    echo -e "${RED}❌ FAIL:${NC} $1"
}

test_info() {
    echo -e "${BLUE}ℹ️ INFO:${NC} $1"
}

test_warn() {
    echo -e "${YELLOW}⚠️ WARN:${NC} $1"
}

echo ""
echo "1. 🔍 Verificando servicios Docker..."

# Verificar que los servicios están corriendo
if docker compose ps | grep -q "Up"; then
    test_pass "Servicios Docker están corriendo"
else
    test_fail "Servicios Docker no están corriendo"
    echo "   Ejecutar: docker compose up -d"
fi

# Verificar servicio web
if curl -s http://localhost:8000 > /dev/null; then
    test_pass "Servicio web accesible en http://localhost:8000"
else
    test_fail "Servicio web no accesible"
fi

# Verificar MQTT
if mosquitto_pub -h localhost -p 1883 -t test -m "test" 2>/dev/null; then
    test_pass "Broker MQTT accesible en localhost:1883"
else
    test_fail "Broker MQTT no accesible"
fi

echo ""
echo "2. 🗣️ Verificando STT multilingüe..."

# Verificar servicio STT
if curl -s http://localhost:8001/health | grep -q '"ok": true'; then
    test_pass "Servicio STT está funcionando"
    
    # Verificar modelo multilingüe
    model=$(curl -s http://localhost:8001/health | grep -o '"model": "[^"]*"' | cut -d'"' -f4)
    if [[ "$model" == *"faster-whisper-base"* ]] && [[ "$model" != *".en"* ]]; then
        test_pass "Modelo STT multilingüe configurado: $model"
    else
        test_warn "Modelo STT puede no ser multilingüe: $model"
    fi
else
    test_fail "Servicio STT no está funcionando"
fi

echo ""
echo "3. 🤖 Verificando LLM en español..."

# Verificar Ollama
if curl -s http://localhost:11434/api/tags 2>/dev/null | grep -q "llama3.1:8b\|qwen2.5:7b"; then
    test_pass "Modelos LLM en español disponibles"
else
    test_warn "Modelos LLM recomendados no encontrados"
    test_info "Descargar con: docker exec -it \$(docker compose ps -q ollama) ollama pull llama3.1:8b"
fi

echo ""
echo "4. 📡 Verificando espejo MQTT TTS..."

# Verificar servicio TTS local
if systemctl is-active --quiet moxie-tts.service; then
    test_pass "Servicio TTS local está corriendo"
else
    test_fail "Servicio TTS local no está corriendo"
    test_info "Iniciar con: sudo systemctl start moxie-tts.service"
fi

# Verificar monitor web TTS
if curl -s http://localhost:8787 > /dev/null; then
    test_pass "Monitor TTS accesible en http://localhost:8787"
else
    test_warn "Monitor TTS no accesible"
fi

# Verificar Piper TTS
if [ -f "$HOME/piper/piper" ] && [ -f "$HOME/piper/es_ES-vera-medium.onnx" ]; then
    test_pass "Piper TTS y modelo español instalados"
else
    test_fail "Piper TTS o modelo español no encontrados"
fi

echo ""
echo "5. 🧪 Pruebas funcionales..."

echo ""
test_info "Prueba 1: Publicar mensaje de prueba en MQTT"
mosquitto_pub -h localhost -p 1883 -t moxie/tts/text -m "Hola, esta es una prueba del sistema TTS en español"
echo "   ✓ Mensaje enviado. Verificar que se reproduce audio."

echo ""
test_info "Prueba 2: Verificar recepción MQTT (10 segundos)"
echo "   Ejecutando: mosquitto_sub -h localhost -p 1883 -t moxie/tts/text -W 10"
timeout 10 mosquitto_sub -h localhost -p 1883 -t moxie/tts/text || true

echo ""
test_info "Prueba 3: Mensaje largo (>400 caracteres)"
LONG_MSG="Este es un mensaje muy largo para probar la división automática en chunks de máximo 400 caracteres. El sistema debe dividir este texto en múltiples mensajes MQTT manteniendo el orden correcto. Esta funcionalidad es importante para evitar que se pierdan partes del mensaje cuando Moxie dice frases largas o explicaciones detalladas. El texto debe llegar completo al sistema de reproducción local."
mosquitto_pub -h localhost -p 1883 -t moxie/tts/text -m "$LONG_MSG"
echo "   ✓ Mensaje largo enviado (${#LONG_MSG} caracteres)"

echo ""
echo "6. 📋 Checklist manual..."

echo ""
echo "Por favor, verifica manualmente:"
echo ""
echo "□ 1. Abrir http://localhost:8000 y configurar:"
echo "     - STT Backend: Local"
echo "     - STT Language: es"
echo "     - STT Model: faster-whisper-base"
echo ""
echo "□ 2. Importar configuración española:"
echo "     - Ir a http://localhost:8000/hive/setup"
echo "     - Subir samples/moxie_espanol_sample.json"
echo "     - Importar schedules y chats"
echo ""
echo "□ 3. Asignar schedule español al dispositivo:"
echo "     - Devices → [tu dispositivo]"
echo "     - Schedule: solo_chat_ollama_espanol"
echo ""
echo "□ 4. Probar conversación:"
echo "     - Hablar con Moxie en español"
echo "     - Verificar que responde en español"
echo "     - Verificar que el texto aparece en MQTT"
echo "     - Verificar que se reproduce audio local"
echo ""
echo "□ 5. Verificar logs:"
echo "     - sudo journalctl -u moxie-tts.service -f"
echo "     - docker compose logs -f web"
echo ""

echo ""
echo "🔧 Comandos útiles para debugging:"
echo ""
echo "# Ver logs del servicio TTS:"
echo "sudo journalctl -u moxie-tts.service -f"
echo ""
echo "# Reiniciar servicio TTS:"
echo "sudo systemctl restart moxie-tts.service"
echo ""
echo "# Ver logs de Docker:"
echo "docker compose logs -f web"
echo ""
echo "# Probar MQTT manualmente:"
echo "mosquitto_pub -h localhost -p 1883 -t moxie/tts/text -m 'Prueba manual'"
echo ""
echo "# Escuchar MQTT:"
echo "mosquitto_sub -h localhost -p 1883 -t moxie/tts/text"
echo ""
echo "# Monitor web:"
echo "http://localhost:8787"
echo ""

echo "🎯 Pruebas completadas. Revisar resultados arriba."
