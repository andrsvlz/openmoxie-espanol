#!/bin/bash
# OpenMoxie Español - Script de Preparación para Git
# Versión: 1.0
# Descripción: Prepara el repositorio para ser subido a Git

set -e

# ===== COLORES =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

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

# ===== VERIFICAR ESTADO ACTUAL =====
check_git_status() {
    print_header "VERIFICANDO ESTADO DE GIT"
    
    if [ ! -d ".git" ]; then
        print_step "Inicializando repositorio Git..."
        git init
        print_success "Repositorio Git inicializado"
    else
        print_success "Repositorio Git ya existe"
    fi
    
    # Verificar si hay cambios
    if [ -n "$(git status --porcelain)" ]; then
        print_warning "Hay cambios sin commitear"
        git status --short
    else
        print_success "Directorio de trabajo limpio"
    fi
}

# ===== LIMPIAR ARCHIVOS TEMPORALES =====
clean_temp_files() {
    print_header "LIMPIANDO ARCHIVOS TEMPORALES"
    
    # Archivos de configuración temporal
    print_step "Eliminando archivos de configuración temporal..."
    rm -f config_espanol.py
    rm -f configurar_espanol.py
    
    # Logs y archivos temporales
    print_step "Limpiando logs y temporales..."
    find . -name "*.log" -type f -delete 2>/dev/null || true
    find . -name "*.tmp" -type f -delete 2>/dev/null || true
    find . -name "*~" -type f -delete 2>/dev/null || true
    
    # Cache de Python
    print_step "Limpiando cache de Python..."
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -type f -delete 2>/dev/null || true
    
    print_success "Archivos temporales eliminados"
}

# ===== VERIFICAR ESTRUCTURA =====
verify_structure() {
    print_header "VERIFICANDO ESTRUCTURA DEL PROYECTO"
    
    # Directorios principales
    local dirs=("scripts" "services" "docs" "samples" "site")
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_success "Directorio $dir existe"
        else
            print_warning "Directorio $dir no existe"
        fi
    done
    
    # Archivos importantes
    local files=("README.md" ".gitignore" ".gitattributes" "docker-compose.yml")
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            print_success "Archivo $file existe"
        else
            print_warning "Archivo $file no existe"
        fi
    done
}

# ===== VERIFICAR SECRETOS =====
check_secrets() {
    print_header "VERIFICANDO SECRETOS Y DATOS SENSIBLES"
    
    # Buscar posibles claves API
    print_step "Buscando claves API..."
    if grep -r -i "api[_-]key\|secret\|password" --include="*.py" --include="*.js" --include="*.json" . 2>/dev/null | grep -v "example\|sample\|template"; then
        print_warning "Posibles secretos encontrados - revisar antes de subir"
    else
        print_success "No se encontraron secretos obvios"
    fi
    
    # Verificar base de datos
    if [ -f "site/work/db.sqlite3" ]; then
        print_warning "Base de datos SQLite presente - será ignorada por .gitignore"
    fi
}

# ===== GENERAR DOCUMENTACIÓN =====
generate_docs() {
    print_header "GENERANDO DOCUMENTACIÓN ADICIONAL"
    
    # Crear CHANGELOG si no existe
    if [ ! -f "CHANGELOG.md" ]; then
        print_step "Creando CHANGELOG.md..."
        cat > CHANGELOG.md << 'EOF'
# Changelog

## [1.0.0] - 2025-09-18

### Añadido
- ✅ Configuración automática en español
- ✅ TTS local con Piper y voz española
- ✅ Mirroring MQTT para reproducción de audio
- ✅ Interfaz web completamente funcional
- ✅ Soporte para Faster-Whisper multilingüe
- ✅ Integración con Ollama para LLM
- ✅ Script de instalación automática
- ✅ Documentación completa en español
- ✅ Servicio systemd para TTS local
- ✅ Monitor web para TTS en tiempo real

### Basado en
- [openmoxie-ollama](https://github.com/moxie-robot/openmoxie-ollama)
- [jbeghtol/openmoxie](https://github.com/jbeghtol/openmoxie)
EOF
        print_success "CHANGELOG.md creado"
    fi
    
    # Crear CONTRIBUTING.md si no existe
    if [ ! -f "CONTRIBUTING.md" ]; then
        print_step "Creando CONTRIBUTING.md..."
        cat > CONTRIBUTING.md << 'EOF'
# Contribuir a OpenMoxie Español

## Cómo Contribuir

1. **Fork** el repositorio
2. **Crea** una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. **Commit** tus cambios (`git commit -am 'Añadir nueva funcionalidad'`)
4. **Push** a la rama (`git push origin feature/nueva-funcionalidad`)
5. **Crea** un Pull Request

## Estándares de Código

- **Python**: Seguir PEP 8
- **JavaScript**: Usar ES6+
- **Documentación**: En español
- **Commits**: Mensajes descriptivos en español

## Testing

Antes de enviar un PR:
1. Ejecutar `./scripts/install.sh` en un entorno limpio
2. Verificar que todos los servicios inicien correctamente
3. Probar Puppet Mode y TTS local
4. Verificar que no hay errores en logs

## Reportar Bugs

Usar GitHub Issues con:
- Descripción clara del problema
- Pasos para reproducir
- Logs relevantes
- Información del sistema
EOF
        print_success "CONTRIBUTING.md creado"
    fi
}

# ===== PREPARAR COMMIT INICIAL =====
prepare_initial_commit() {
    print_header "PREPARANDO COMMIT INICIAL"
    
    # Añadir archivos al staging
    print_step "Añadiendo archivos al staging..."
    git add .
    
    # Mostrar estado
    print_step "Estado actual:"
    git status --short
    
    # Preparar mensaje de commit
    local commit_msg="🎉 Initial commit: OpenMoxie Español v1.0.0

✅ Características principales:
- Configuración automática en español
- TTS local con Piper y voz española  
- Mirroring MQTT para reproducción de audio
- Interfaz web completamente funcional
- Soporte para Faster-Whisper multilingüe
- Integración con Ollama para LLM

🚀 Instalación:
- Script automático: ./scripts/install.sh
- Docker Compose para servicios
- Servicio systemd para TTS local

📚 Documentación:
- README.md completo en español
- Guías de arquitectura y troubleshooting
- Ejemplos de configuración

Basado en openmoxie-ollama con mejoras para español"

    echo -e "\n${YELLOW}Mensaje de commit preparado:${NC}"
    echo "$commit_msg"
    
    echo -e "\n${BLUE}¿Realizar commit inicial? (y/N):${NC}"
    read -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git commit -m "$commit_msg"
        print_success "Commit inicial realizado"
    else
        print_warning "Commit cancelado - archivos en staging"
    fi
}

# ===== INFORMACIÓN FINAL =====
show_final_info() {
    print_header "INFORMACIÓN PARA SUBIR A GIT"
    
    echo -e "${CYAN}Próximos pasos para subir a GitHub:${NC}"
    echo -e "1. Crear repositorio en GitHub"
    echo -e "2. Añadir remote: ${YELLOW}git remote add origin https://github.com/tu-usuario/openmoxie-espanol.git${NC}"
    echo -e "3. Push inicial: ${YELLOW}git push -u origin main${NC}"
    
    echo -e "\n${CYAN}Archivos importantes incluidos:${NC}"
    echo -e "• README.md - Documentación principal"
    echo -e "• scripts/install.sh - Instalación automática"
    echo -e "• services/ - Servicio TTS y configuración"
    echo -e "• docs/ - Documentación técnica"
    echo -e "• samples/ - Configuraciones de ejemplo"
    
    echo -e "\n${CYAN}Archivos excluidos (.gitignore):${NC}"
    echo -e "• site/work/ - Base de datos y logs"
    echo -e "• Archivos temporales y cache"
    echo -e "• Modelos de IA grandes"
    echo -e "• Configuraciones locales"
    
    echo -e "\n${GREEN}¡Repositorio listo para Git! 🚀${NC}"
}

# ===== FUNCIÓN PRINCIPAL =====
main() {
    print_header "PREPARACIÓN DE OPENMOXIE ESPAÑOL PARA GIT"
    
    check_git_status
    clean_temp_files
    verify_structure
    check_secrets
    generate_docs
    prepare_initial_commit
    show_final_info
}

# Ejecutar función principal
main "$@"
