# 🔧 Guía de Troubleshooting - OpenMoxie Español

## Diagnóstico Rápido

### Script de Verificación Automática

```bash
#!/bin/bash
# Guardar como: scripts/check_system.sh

echo "=== DIAGNÓSTICO OPENMOXIE ESPAÑOL ==="

# Verificar servicios Docker
echo "🐳 Servicios Docker:"
docker compose ps

# Verificar servicio TTS
echo "🔊 Servicio TTS:"
systemctl --user is-active moxie-tts.service

# Verificar conectividad
echo "🌐 Conectividad:"
curl -s http://localhost:8000 >/dev/null && echo "✅ Web: OK" || echo "❌ Web: FAIL"
curl -s http://localhost:8787 >/dev/null && echo "✅ TTS Monitor: OK" || echo "❌ TTS Monitor: FAIL"
curl -s http://localhost:8001/health >/dev/null && echo "✅ STT: OK" || echo "❌ STT: FAIL"

# Verificar MQTT
echo "📡 MQTT:"
timeout 5 mosquitto_sub -h localhost -p 1883 -t "test" -C 1 >/dev/null 2>&1 && echo "✅ MQTT: OK" || echo "❌ MQTT: FAIL"

echo "=== FIN DIAGNÓSTICO ==="
```

## Problemas por Categoría

### 🚫 Servicios No Inician

#### Docker Compose Falla

**Síntomas**:
```
ERROR: Couldn't connect to Docker daemon
ERROR: Service 'web' failed to build
```

**Soluciones**:
```bash
# 1. Verificar Docker está corriendo
sudo systemctl status docker
sudo systemctl start docker

# 2. Verificar permisos de usuario
sudo usermod -aG docker $USER
newgrp docker

# 3. Limpiar y reconstruir
docker compose down
docker system prune -f
docker compose build --no-cache
docker compose up -d
```

#### Puertos Ocupados

**Síntomas**:
```
ERROR: Port 8000 is already in use
ERROR: Port 1883 is already in use
```

**Soluciones**:
```bash
# Encontrar procesos usando puertos
sudo netstat -tulpn | grep :8000
sudo netstat -tulpn | grep :1883

# Matar procesos específicos
sudo kill -9 <PID>

# O cambiar puertos en docker-compose.yml
ports:
  - "8001:8000"  # Cambiar puerto externo
```

### 🔇 Audio No Se Reproduce

#### Servicio TTS No Activo

**Síntomas**:
```bash
systemctl --user status moxie-tts.service
# Output: inactive (dead)
```

**Soluciones**:
```bash
# 1. Verificar logs de error
journalctl --user -u moxie-tts.service --no-pager -n 20

# 2. Reinstalar servicio
cp services/moxie-tts.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable moxie-tts.service
systemctl --user start moxie-tts.service

# 3. Verificar dependencias Python
cd services/moxie-tts-subscriber
pip3 install --user -r requirements.txt
```

#### Piper TTS No Funciona

**Síntomas**:
```
FileNotFoundError: [Errno 2] No such file or directory: 'piper'
```

**Soluciones**:
```bash
# 1. Verificar instalación de Piper
cd services/moxie-tts-subscriber/piper
ls -la piper
chmod +x piper

# 2. Reinstalar Piper
rm -rf piper/
mkdir piper && cd piper
curl -L "https://github.com/rhasspy/piper/releases/latest/download/piper_linux_x86_64.tar.gz" -o piper.tar.gz
tar -xzf piper.tar.gz --strip-components=1
chmod +x piper

# 3. Verificar modelo de voz
ls -la es_ES-davefx-medium.onnx*
```

#### Audio System Issues

**Síntomas**:
```
ALSA lib pcm_dmix.c:1032:(snd_pcm_dmix_open) unable to open slave
```

**Soluciones**:
```bash
# 1. Verificar dispositivos de audio
pactl list short sinks
aplay -l

# 2. Instalar PulseAudio si no está
sudo apt install pulseaudio pulseaudio-utils

# 3. Reiniciar audio system
pulseaudio --kill
pulseaudio --start

# 4. Test directo de audio
paplay /usr/share/sounds/alsa/Front_Left.wav
```

### 📡 Problemas MQTT

#### Broker No Accesible

**Síntomas**:
```
Connection refused (mqtt_tts_mirror:61)
```

**Soluciones**:
```bash
# 1. Verificar broker MQTT
docker compose logs mqtt
docker compose ps mqtt

# 2. Reiniciar broker
docker compose restart mqtt

# 3. Test manual
mosquitto_pub -h localhost -p 1883 -t "test" -m "hello"
mosquitto_sub -h localhost -p 1883 -t "test"

# 4. Verificar configuración de red
docker network ls
docker network inspect openmoxie_es_default
```

#### TTS Mirror No Conecta

**Síntomas**:
```
WARNING Error conectando a MQTT broker para TTS Mirror
```

**Soluciones**:
```bash
# 1. Verificar configuración en contenedor
docker compose exec web env | grep MQTT

# 2. Verificar código de conexión
docker compose exec web bash -c "cd /app/site && python -c 'from hive.mqtt.mqtt_tts_mirror import TTSMirrorPublisher; t=TTSMirrorPublisher(host=\"mqtt\"); print(\"OK\")'"

# 3. Reconstruir imagen web
docker compose build web
docker compose up -d web
```

### 🤖 Problemas de IA

#### Ollama No Responde

**Síntomas**:
```
Connection error to Ollama server
Model not found
```

**Soluciones**:
```bash
# 1. Verificar Ollama
docker compose logs ollama
curl http://localhost:11434/api/tags

# 2. Verificar modelos
docker compose exec ollama ollama list

# 3. Descargar modelos faltantes
docker compose exec ollama ollama pull llama3.1:8b
docker compose exec ollama ollama pull qwen2.5:7b

# 4. Test directo
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model": "llama3.1:8b", "prompt": "Hola", "stream": false}'
```

#### STT No Transcribe

**Síntomas**:
```
STT service not responding
Empty transcription
```

**Soluciones**:
```bash
# 1. Verificar servicio STT
curl -s http://localhost:8001/health
docker compose logs stt

# 2. Verificar modelos
ls -la site/services/stt/models/
curl -s http://localhost:8001/control/models

# 3. Test con archivo de audio
curl -X POST -F "audio=@test.wav" http://localhost:8001/stt

# 4. Cambiar modelo
curl -X POST -H "Content-Type: application/json" \
  --data '{"model":"/models/faster-whisper-base","device":"auto","compute":"int8"}' \
  http://localhost:8001/control/reload
```

### 🌐 Problemas Web

#### Interfaz No Carga

**Síntomas**:
```
This site can't be reached
500 Internal Server Error
```

**Soluciones**:
```bash
# 1. Verificar servicio web
docker compose logs web
curl -I http://localhost:8000

# 2. Verificar base de datos
docker compose exec web bash -c "cd /app/site && python manage.py check"

# 3. Aplicar migraciones
docker compose exec web bash -c "cd /app/site && python manage.py migrate"

# 4. Crear superuser si no existe
docker compose exec web bash -c "cd /app/site && python manage.py createsuperuser"
```

#### Login No Funciona

**Síntomas**:
```
Invalid username or password
CSRF token missing
```

**Soluciones**:
```bash
# 1. Verificar usuario admin
docker compose exec web bash -c "cd /app/site && python manage.py shell -c 'from django.contrib.auth.models import User; print(User.objects.filter(username=\"admin\").exists())'"

# 2. Resetear contraseña
docker compose exec web bash -c "cd /app/site && python manage.py changepassword admin"

# 3. Limpiar cookies del navegador
# Ir a Developer Tools > Application > Storage > Clear All

# 4. Verificar configuración Django
docker compose exec web bash -c "cd /app/site && python manage.py check --settings=openmoxie.settings"
```

## Logs Útiles

### Comandos de Logging

```bash
# Logs en tiempo real de todos los servicios
docker compose logs -f

# Logs específicos por servicio
docker compose logs web -f
docker compose logs mqtt -f
docker compose logs ollama -f
docker compose logs stt -f

# Logs del servicio TTS local
journalctl --user -u moxie-tts.service -f

# Logs del sistema
sudo journalctl -f

# Logs de Docker
sudo journalctl -u docker.service -f
```

### Archivos de Log Importantes

```bash
# Logs de aplicación
tail -f site/work/debug.log

# Logs de MQTT
tail -f local/work/mosquitto.log

# Logs del sistema
tail -f /var/log/syslog
tail -f /var/log/kern.log
```

## Herramientas de Diagnóstico

### Scripts Útiles

```bash
# Verificar recursos del sistema
free -h
df -h
top -p $(pgrep -d',' -f docker)

# Verificar red
ss -tulpn | grep -E ':(8000|1883|8787|8001|11434)'
ping -c 3 localhost

# Verificar Docker
docker system df
docker system events &
```

### Comandos de Limpieza

```bash
# Limpiar Docker
docker compose down
docker system prune -f
docker volume prune -f

# Limpiar logs
sudo journalctl --vacuum-time=7d
docker compose logs --tail=0 -f > /dev/null &

# Reinicio completo
docker compose down
sudo systemctl restart docker
docker compose up -d
```

## Recuperación de Emergencia

### Backup de Datos

```bash
# Backup de base de datos
cp site/work/db.sqlite3 backup/db_$(date +%Y%m%d_%H%M%S).sqlite3

# Backup de configuración
tar -czf backup/config_$(date +%Y%m%d_%H%M%S).tar.gz \
  site/work/ \
  services/ \
  docker-compose.yml
```

### Restauración Completa

```bash
# 1. Parar todos los servicios
docker compose down
systemctl --user stop moxie-tts.service

# 2. Limpiar datos
rm -rf site/work/
docker system prune -af

# 3. Restaurar desde backup
tar -xzf backup/config_YYYYMMDD_HHMMSS.tar.gz

# 4. Reinstalar
./scripts/install.sh
```

### Factory Reset

```bash
#!/bin/bash
# Script de reset completo

echo "⚠️  FACTORY RESET - Esto eliminará todos los datos"
read -p "¿Continuar? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Parar servicios
    docker compose down
    systemctl --user stop moxie-tts.service
    
    # Limpiar datos
    rm -rf site/work/
    rm -rf local/work/
    docker system prune -af
    
    # Reinstalar
    ./scripts/install.sh
    
    echo "✅ Factory reset completado"
fi
```

## Contacto y Soporte

### Información del Sistema

```bash
# Generar reporte del sistema
cat > system_report.txt << EOF
=== OPENMOXIE ESPAÑOL SYSTEM REPORT ===
Date: $(date)
OS: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)
Docker: $(docker --version)
Docker Compose: $(docker-compose --version)

=== SERVICES STATUS ===
$(docker compose ps)

=== TTS SERVICE ===
$(systemctl --user status moxie-tts.service --no-pager)

=== DISK USAGE ===
$(df -h)

=== MEMORY USAGE ===
$(free -h)

=== NETWORK ===
$(ss -tulpn | grep -E ':(8000|1883|8787|8001|11434)')
EOF

echo "📋 Reporte generado: system_report.txt"
```

### Canales de Soporte

- **GitHub Issues**: Para bugs y problemas técnicos
- **GitHub Discussions**: Para preguntas generales
- **Wiki**: Para documentación adicional
- **Discord/Telegram**: Para soporte en tiempo real (si disponible)
