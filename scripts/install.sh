#!/bin/bash
# OpenMoxie Español - Script de Instalación Completa
# Versión: 1.0
# Autor: Augment Agent
# Descripción: Instala y configura OpenMoxie con soporte completo para español y TTS local

set -e  # Salir en caso de error

# ===== COLORES PARA OUTPUT =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ===== FUNCIONES DE UTILIDAD =====
print_header() {
    echo -e "\n${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}\n"
}

print_step() {
    echo -e "${BLUE}🔧 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        print_success "$1 está instalado"
        return 0
    else
        print_warning "$1 no está instalado"
        return 1
    fi
}

# ===== VERIFICACIÓN DE REQUISITOS =====
check_requirements() {
    print_header "VERIFICANDO REQUISITOS DEL SISTEMA"
    
    local missing_deps=()
    
    # Verificar Docker
    if ! check_command "docker"; then
        missing_deps+=("docker")
    fi
    
    # Verificar Docker Compose
    if ! check_command "docker-compose" && ! docker compose version >/dev/null 2>&1; then
        missing_deps+=("docker-compose")
    fi
    
    # Verificar Git
    if ! check_command "git"; then
        missing_deps+=("git")
    fi
    
    # Verificar Python
    if ! check_command "python3"; then
        missing_deps+=("python3")
    fi
    
    # Verificar curl
    if ! check_command "curl"; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Faltan dependencias: ${missing_deps[*]}"
        echo -e "\n${YELLOW}Instala las dependencias faltantes:${NC}"
        echo "sudo apt update && sudo apt install -y ${missing_deps[*]}"
        exit 1
    fi
    
    print_success "Todos los requisitos están instalados"
}

# ===== INSTALACIÓN DE HERRAMIENTAS MQTT =====
install_mqtt_tools() {
    print_header "INSTALANDO HERRAMIENTAS MQTT"
    
    print_step "Instalando mosquitto-clients..."
    sudo apt update
    sudo apt install -y mosquitto-clients
    
    print_success "Herramientas MQTT instaladas"
}

# ===== INSTALACIÓN DE PIPER TTS =====
install_piper_tts() {
    print_header "INSTALANDO PIPER TTS"
    
    print_step "Descargando Piper TTS..."
    
    # Crear directorio para Piper
    mkdir -p services/moxie-tts-subscriber/piper
    cd services/moxie-tts-subscriber/piper
    
    # Descargar Piper para Linux x64
    if [ ! -f "piper" ]; then
        curl -L "https://github.com/rhasspy/piper/releases/latest/download/piper_linux_x86_64.tar.gz" -o piper.tar.gz
        tar -xzf piper.tar.gz --strip-components=1
        rm piper.tar.gz
        chmod +x piper
    fi
    
    # Descargar modelo de voz en español
    if [ ! -f "es_ES-davefx-medium.onnx" ]; then
        print_step "Descargando modelo de voz español..."
        curl -L "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/es/es_ES/davefx/medium/es_ES-davefx-medium.onnx" -o es_ES-davefx-medium.onnx
        curl -L "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/es/es_ES/davefx/medium/es_ES-davefx-medium.onnx.json" -o es_ES-davefx-medium.onnx.json
    fi
    
    cd ../../..
    print_success "Piper TTS instalado"
}

# ===== INSTALACIÓN DEL SERVICIO TTS =====
install_tts_service() {
    print_header "INSTALANDO SERVICIO TTS LOCAL"
    
    print_step "Instalando dependencias Python..."
    cd services/moxie-tts-subscriber
    pip3 install --user -r requirements.txt
    cd ../..
    
    print_step "Configurando servicio systemd..."
    
    # Crear directorio para servicios de usuario
    mkdir -p ~/.config/systemd/user
    
    # Copiar archivo de servicio
    cp services/moxie-tts.service ~/.config/systemd/user/
    
    # Recargar systemd y habilitar servicio
    systemctl --user daemon-reload
    systemctl --user enable moxie-tts.service
    systemctl --user start moxie-tts.service
    
    print_success "Servicio TTS instalado y iniciado"
}

# ===== CONFIGURACIÓN DE DOCKER =====
setup_docker() {
    print_header "CONFIGURANDO SERVICIOS DOCKER"
    
    print_step "Construyendo imágenes Docker..."
    docker compose build
    
    print_step "Iniciando servicios..."
    docker compose up -d
    
    print_step "Esperando que los servicios inicien..."
    sleep 30
    
    print_success "Servicios Docker configurados"
}

# ===== CONFIGURACIÓN ESPAÑOLA =====
configure_spanish() {
    print_header "CONFIGURANDO VALORES POR DEFECTO EN ESPAÑOL"
    
    print_step "Aplicando migraciones de base de datos..."
    docker compose exec web bash -c "cd /app/site && python manage.py migrate"
    
    print_step "Creando usuario administrador..."
    docker compose exec web bash -c "cd /app/site && python manage.py shell -c \"
from django.contrib.auth.models import User
from hive.models import HiveConfiguration
import os

# Crear usuario admin si no existe
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@localhost', 'admin123')
    print('✅ Usuario admin creado')
else:
    print('ℹ️ Usuario admin ya existe')

# Configurar valores por defecto en español
config, created = HiveConfiguration.objects.get_or_create(pk=1)
config.stt_backend = 'local'
config.stt_lang = 'es'
config.stt_model = '/models/faster-whisper-base'
config.stt_compute = 'float16'
config.stt_device = 'auto'
config.stt_url = 'http://stt:8001/stt'
config.save()

print('🎯 Configuración española aplicada')
\""
    
    print_success "Configuración española completada"
}

# ===== VERIFICACIÓN FINAL =====
verify_installation() {
    print_header "VERIFICANDO INSTALACIÓN"
    
    print_step "Verificando servicios Docker..."
    docker compose ps
    
    print_step "Verificando servicio TTS..."
    if systemctl --user is-active --quiet moxie-tts.service; then
        print_success "Servicio TTS activo"
    else
        print_warning "Servicio TTS no está activo"
    fi
    
    print_step "Verificando conectividad..."
    if curl -s http://localhost:8000 >/dev/null; then
        print_success "Interfaz web accesible en http://localhost:8000"
    else
        print_warning "Interfaz web no accesible"
    fi
    
    if curl -s http://localhost:8787 >/dev/null; then
        print_success "Monitor TTS accesible en http://localhost:8787"
    else
        print_warning "Monitor TTS no accesible"
    fi
}

# ===== FUNCIÓN PRINCIPAL =====
main() {
    print_header "INSTALACIÓN DE OPENMOXIE ESPAÑOL"
    echo -e "${CYAN}Este script instalará OpenMoxie con soporte completo para español${NC}"
    echo -e "${CYAN}Incluye TTS local con Piper y mirroring MQTT${NC}\n"
    
    read -p "¿Continuar con la instalación? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Instalación cancelada"
        exit 0
    fi
    
    # Ejecutar pasos de instalación
    check_requirements
    install_mqtt_tools
    install_piper_tts
    install_tts_service
    setup_docker
    configure_spanish
    verify_installation
    
    print_header "¡INSTALACIÓN COMPLETADA!"
    echo -e "${GREEN}🎉 OpenMoxie Español está listo para usar${NC}"
    echo -e "\n${CYAN}Accesos:${NC}"
    echo -e "• Interfaz web: ${YELLOW}http://localhost:8000${NC}"
    echo -e "• Usuario: ${YELLOW}admin${NC}"
    echo -e "• Contraseña: ${YELLOW}admin123${NC}"
    echo -e "• Monitor TTS: ${YELLOW}http://localhost:8787${NC}"
    echo -e "\n${CYAN}Para usar Puppet Mode:${NC}"
    echo -e "1. Ve a http://localhost:8000"
    echo -e "2. Inicia sesión con admin/admin123"
    echo -e "3. Usa Puppet Mode para enviar texto"
    echo -e "4. El audio se reproducirá automáticamente en español"
    echo -e "\n${GREEN}¡Disfruta de Moxie hablando en español! 🤖🇪🇸${NC}"
}

# Ejecutar función principal
main "$@"
