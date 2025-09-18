# 🤖 Moxie en Español con Espejo MQTT TTS

Esta es una modificación del repositorio [vapors/openmoxie-ollama](https://github.com/vapors/openmoxie-ollama) para configurar Moxie completamente en español con espejo MQTT del texto TTS.

## 🎯 Características

- **STT multilingüe**: Reconocimiento de voz en español usando Faster-Whisper
- **LLM en español**: Modelos Ollama configurados para responder en español
- **Espejo MQTT TTS**: Publica el texto que Moxie va a decir en `moxie/tts/text`
- **Reproducción local**: Servicio systemd que reproduce el audio con Piper TTS
- **División automática**: Textos >400 caracteres se dividen en múltiples mensajes
- **Monitor web**: Interfaz en http://localhost:8787 para ver mensajes TTS

## 🚀 Instalación Rápida

```bash
# 1. Clonar el repositorio
git clone https://github.com/vapors/openmoxie-ollama.git
cd openmoxie-ollama

# 2. Ejecutar instalador automático
./install_moxie_espanol.sh

# 3. Ejecutar pruebas
./test_moxie_espanol.sh
```

## 📋 Instalación Manual

### 1. Paquetes del sistema

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget python3 python3-venv python3-pip sox ffmpeg mosquitto-clients

# Docker y Docker Compose
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker
```

### 2. Servicios Docker

```bash
# Iniciar servicios
docker compose up -d model-init data-init stt mqtt ollama ollama-init web

# Verificar que están corriendo
docker compose ps
```

### 3. Modelos recomendados

**STT multilingüe:**
- `faster-whisper-base` (ya configurado en docker-compose.yml)

**LLM en español:**
```bash
# Descargar modelos que responden bien en español
docker exec -it $(docker compose ps -q ollama) ollama pull llama3.1:8b
docker exec -it $(docker compose ps -q ollama) ollama pull qwen2.5:7b
```

### 4. Piper TTS (host local)

```bash
# Crear directorio
mkdir -p ~/piper
cd ~/piper

# Descargar Piper (AMD64)
wget https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_amd64.tar.gz
tar -xzf piper_amd64.tar.gz --strip-components=1
chmod +x piper

# Descargar modelo de voz española
wget -O es_ES-vera-medium.onnx "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/es/es_ES/vera/medium/es_ES-vera-medium.onnx"
wget -O es_ES-vera-medium.onnx.json "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/es/es_ES/vera/medium/es_ES-vera-medium.onnx.json"
```

### 5. Servicio TTS local

```bash
# Crear directorio del servicio
sudo mkdir -p /opt/moxie-tts-subscriber
sudo cp moxie-tts-subscriber/app.py /opt/moxie-tts-subscriber/
sudo chown -R $USER:$USER /opt/moxie-tts-subscriber

# Crear entorno virtual
cd /opt/moxie-tts-subscriber
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install paho-mqtt flask waitress
deactivate

# Instalar servicio systemd
sudo cp moxie-tts.service /etc/systemd/system/
sudo sed -i "s|User=steve|User=$USER|g" /etc/systemd/system/moxie-tts.service
sudo sed -i "s|Group=steve|Group=$USER|g" /etc/systemd/system/moxie-tts.service
sudo sed -i "s|/home/steve/piper|$HOME/piper|g" /etc/systemd/system/moxie-tts.service

# Habilitar e iniciar
sudo systemctl daemon-reload
sudo systemctl enable moxie-tts.service
sudo systemctl start moxie-tts.service
```

## ⚙️ Configuración en Español

### 1. Panel web (http://localhost:8000)

**Setup → Speech-to-Text:**
- Backend: `Local (faster-whisper)`
- Default language: `es`
- Model: `faster-whisper-base`

### 2. Importar configuración española

1. Ir a http://localhost:8000/hive/setup
2. Subir archivo: `samples/moxie_espanol_sample.json`
3. Seleccionar schedules y chats → **Import**

### 3. Asignar schedule español

1. Ir a **Devices** → [tu dispositivo Moxie]
2. Seleccionar schedule: `solo_chat_ollama_espanol`

## 🔧 Modificaciones del Código

### Archivos modificados:

1. **`site/hive/mqtt/moxie_server.py`**:
   - Agregado import de `TTSMirrorPublisher`
   - Modificado `send_telehealth_speech()` para publicar en MQTT

2. **`site/hive/mqtt/moxie_remote_chat.py`**:
   - Agregado import de `TTSMirrorPublisher`
   - Modificadas funciones que envían `remote_chat` para publicar en MQTT

3. **`site/hive/mqtt/mqtt_tts_mirror.py`** (nuevo):
   - Clase para publicar texto TTS en MQTT con reconexión automática
   - División automática de textos >400 caracteres
   - Manejo robusto de errores

4. **`docker-compose.yml`**:
   - Modelos STT multilingües
   - Modelos LLM en español
   - Puerto 1883 para MQTT sin SSL
   - Configuración STT en español

5. **`site/data/openmoxie.conf`**:
   - Listener adicional en puerto 1883 sin SSL

## 🧪 Pruebas de Aceptación

```bash
# Ejecutar suite de pruebas
./test_moxie_espanol.sh

# Probar MQTT manualmente
mosquitto_pub -h localhost -p 1883 -t moxie/tts/text -m "Hola, esta es una prueba"

# Escuchar mensajes MQTT
mosquitto_sub -h localhost -p 1883 -t moxie/tts/text

# Ver logs del servicio TTS
sudo journalctl -u moxie-tts.service -f

# Monitor web
http://localhost:8787
```

## 🔍 Verificación

### Checklist de funcionamiento:

- [ ] Moxie responde en español
- [ ] El texto aparece en `mosquitto_sub -t moxie/tts/text`
- [ ] Se reproduce audio localmente
- [ ] Textos >400 chars se dividen correctamente
- [ ] Monitor web muestra mensajes en http://localhost:8787
- [ ] Servicio TTS se reinicia automáticamente

### Comandos de debugging:

```bash
# Estado del servicio TTS
sudo systemctl status moxie-tts.service

# Logs del servicio TTS
sudo journalctl -u moxie-tts.service -f

# Logs de Docker
docker compose logs -f web

# Reiniciar servicio TTS
sudo systemctl restart moxie-tts.service

# Verificar MQTT
mosquitto_pub -h localhost -p 1883 -t test -m "test"
```

## 🎯 Arquitectura

```
[Moxie Robot] ←→ [OpenMoxie Web] → [MQTT Broker] → [TTS Subscriber] → [Piper TTS] → [Audio Local]
                       ↓
                [mqtt_tts_mirror.py]
                       ↓
                [moxie/tts/text]
```

## 📝 Notas Técnicas

- **QoS 1**: Garantiza entrega de mensajes MQTT
- **Reconexión automática**: Cliente MQTT se reconecta si se pierde conexión
- **Manejo de errores**: Sistema continúa funcionando aunque MQTT falle
- **División de texto**: Mantiene orden en mensajes largos
- **Monitor web**: Flask + Waitress para interfaz de monitoreo

## 🤝 Contribuciones

Basado en el excelente trabajo de:
- [jbeghtol/openmoxie](https://github.com/jbeghtol/openmoxie)
- [vapors/openmoxie-ollama](https://github.com/vapors/openmoxie-ollama)

## 📄 Licencia

Mismo que el proyecto original.
