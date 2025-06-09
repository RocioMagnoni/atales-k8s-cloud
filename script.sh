#!/bin/bash

# 🚀 Script de Despliegue (CI + CD) – infrastructura-Atales

set -e  # Detener si algún comando falla

echo "🌐 Iniciando despliegue del entorno dev en Minikube..."

# 1. Verificar que Minikube esté corriendo
if ! minikube status > /dev/null 2>&1; then
    echo "🟡 Minikube no está corriendo. Iniciando..."
    minikube start
fi

# 2. Establecer Docker env para usar imágenes locales
eval $(minikube docker-env)

# 3. Obtener IP de Minikube (solo para referencia)
MINIKUBE_IP=$(minikube ip)
echo "📌 IP de Minikube: $MINIKUBE_IP"

# 4. Habilitar Ingress si no está activo
if ! minikube addons list | grep ingress | grep -q enabled; then
    echo "⚙️ Habilitando addon de Ingress en Minikube..."
    minikube addons enable ingress
else
    echo "✅ Ingress ya está habilitado en Minikube"
fi

# 5. Verificar y agregar entrada a /etc/hosts si falta
HOST_ENTRY="127.0.0.1 atales.local"
if ! grep -q "atales.local" /etc/hosts; then
    echo "🔧 Agregando atales.local a /etc/hosts (requiere permisos sudo)"
    echo "$HOST_ENTRY" | sudo tee -a /etc/hosts > /dev/null
else
    echo "✅ atales.local ya está presente en /etc/hosts"
fi

# 6. Construir imágenes Docker para backend y frontend
echo "🔨 Construyendo imágenes Docker..."

cd ../proyecto-Atales

echo "📦 Backend:"
docker build -t backend-atales:latest .

echo "📦 Frontend:"
cd frontend
docker build -t frontend-atales:latest .
cd ../..

cd infrastructura-Atales

# 7. Aplicar manifiestos de Kubernetes usando Kustomize
echo "📦 Aplicando manifiestos de Kubernetes con Kustomize..."

kubectl apply -k overlays/dev

echo "✅ Todos los recursos fueron aplicados correctamente."

echo ""
echo "📂 Recursos actuales en el namespace dev:"
kubectl get all -n dev

echo ""
echo "🌐 Accedé a tu aplicación en el navegador:"
echo "   https://atales.local"

echo ""
echo "ℹ️ Importante: ejecutá esto en otra terminal para habilitar la red de Ingress:"
echo "   minikube tunnel"