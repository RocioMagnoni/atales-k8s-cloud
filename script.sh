#!/bin/bash

# 🚀 Script de Despliegue Local – entorno dev (Minikube + Docker local + Kustomize)
set -e  # Detener ejecución ante errores

# 🎨 Colores para mensajes bonitos en consola
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Sin color

echo -e "${GREEN}🌐 Iniciando despliegue del entorno dev en Minikube...${NC}"

# 1. Verificar si Minikube está activo
if ! minikube status > /dev/null 2>&1; then
  echo -e "${YELLOW}🟡 Minikube no está corriendo. Iniciando...${NC}"
  minikube start --memory=2500 --cpus=2 --profile=atales-dev
else
  echo -e "${GREEN}✅ Minikube ya está activo${NC}"
fi

# 2. Configurar entorno Docker para Minikube
eval "$(minikube docker-env)"
echo -e "${GREEN}🐳 Docker ahora apunta al daemon de Minikube${NC}"

# 3. Obtener IP de Minikube
MINIKUBE_IP=$(minikube ip)
echo -e "${GREEN}📌 IP de Minikube: $MINIKUBE_IP${NC}"

# 4. Habilitar Ingress si no está activo
if ! minikube addons list | grep ingress | grep -q enabled; then
  echo -e "${YELLOW}⚙️ Habilitando addon de Ingress...${NC}"
  minikube addons enable ingress
else
  echo -e "${GREEN}✅ Ingress ya está habilitado${NC}"
fi

# 5. Verificar /etc/hosts
HOST_ENTRY="$(minikube ip) atales.local"
if ! grep -q "atales.local" /etc/hosts; then
  echo -e "${YELLOW}🔧 Agregando entrada a /etc/hosts (requiere sudo)...${NC}"
  if echo "$HOST_ENTRY" | sudo tee -a /etc/hosts > /dev/null; then
    echo -e "${GREEN}✅ Entrada agregada exitosamente${NC}"
  else
    echo -e "${RED}❌ Error al modificar /etc/hosts. Hacelo manualmente si es necesario.${NC}"
  fi
else
  echo -e "${GREEN}✅ Entrada atales.local ya existe en /etc/hosts${NC}"
fi

# 6. Construcción de imágenes Docker
BACKEND_PATH="../atales-code-cloud"
FRONTEND_PATH="../atales-code-cloud/frontend"

# Validación de rutas
if [ ! -f "$BACKEND_PATH/Dockerfile" ]; then
  echo -e "${RED}❌ No se encontró el Dockerfile del backend en $BACKEND_PATH${NC}"
  exit 1
fi

if [ ! -f "$FRONTEND_PATH/Dockerfile" ]; then
  echo -e "${RED}❌ No se encontró el Dockerfile del frontend en $FRONTEND_PATH${NC}"
  exit 1
fi

echo -e "${GREEN}🔨 Construyendo imágenes Docker...${NC}"

echo -e "${GREEN}📦 Backend:${NC}"
docker build -t backend-atales:REPLACEME "$BACKEND_PATH"

echo -e "${GREEN}📦 Frontend:${NC}"
docker build -t frontend-atales:REPLACEME "$FRONTEND_PATH"

# 7. Aplicar manifiestos con Kustomize en namespace dev
echo -e "${GREEN}📦 Aplicando manifiestos Kubernetes (overlay dev)...${NC}"
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml
kubectl apply -k overlays/dev -n dev

# 8. Ver recursos desplegados
echo -e "${GREEN}\n📂 Recursos en namespace dev:${NC}"
kubectl get all -n dev

# 9. Recordatorio de acceso
echo -e "${GREEN}\n🌐 Accedé a la app en el navegador:${NC}"
echo "   https://atales.local"

echo -e "${YELLOW}\nℹ️ Ejecutá esto en otra terminal para exponer el Ingress:${NC}"
echo "   minikube tunnel"
