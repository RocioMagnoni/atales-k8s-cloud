#!/bin/bash

# Script para desplegar el proyecto completo en Minikube

set -e  # Salir si algún comando falla

echo "🚀 Iniciando despliegue en Minikube..."

# 1. Verificar que Minikube esté corriendo
if ! minikube status > /dev/null 2>&1; then
    echo "❌ Minikube no está corriendo. Iniciando..."
    minikube start
fi

# 2. Obtener la IP de Minikube
MINIKUBE_IP=$(minikube ip)
echo "🔍 IP de Minikube: $MINIKUBE_IP"

# 3. Configurar Docker para usar el registro de Minikube
eval $(minikube docker-env)

# 4. Actualizar ConfigMap con la IP real
sed "s/MINIKUBE_IP_PLACEHOLDER/$MINIKUBE_IP/g" k8s/configmap-backend.yaml > k8s/configmap-backend-temp.yaml

# 5. Crear archivo de configuración dinámico para el frontend
cat > proyecto-Atales/frontend/js/config.js << EOF
// Configuración automática para Minikube
const API_CONFIG = {
    getBaseURL: function() {
        const hostname = window.location.hostname;
        
        // Si estamos en localhost (desarrollo)
        if (hostname === 'localhost' || hostname === '127.0.0.1') {
            return 'http://localhost:3000';
        }
        
        // Si estamos en Minikube
        return 'http://' + hostname + ':30000';
    }
};

const API_BASE_URL = API_CONFIG.getBaseURL();
window.API_BASE_URL = API_BASE_URL;

console.log('🔧 API Base URL:', API_BASE_URL);
EOF

# 6. Construir imágenes Docker
echo "🔨 Construyendo imágenes Docker..."

# Backend
cd proyecto-Atales
docker build -t backend-atales:latest .

# Frontend  
cd frontend
docker build -t frontend-atales:latest .
cd ..

# 7. Aplicar manifiestos de Kubernetes en orden
echo "⚙️ Desplegando en Kubernetes..."

kubectl apply -f ../k8s/namespace-dev.yaml
kubectl apply -f ../k8s/secret-backend.yaml
kubectl apply -f ../k8s/configmap-backend-temp.yaml
kubectl apply -f ../k8s/pvc-mysql.yaml

# MySQL primero
kubectl apply -f ../k8s/deployment-mysql.yaml
kubectl apply -f ../k8s/service-mysql.yaml

echo "⏳ Esperando que MySQL esté listo..."
kubectl wait --for=condition=ready pod -l app=mysql -n dev --timeout=180s

# Backend
kubectl apply -f ../k8s/deployment-backend.yaml
kubectl apply -f ../k8s/service-backend.yaml
kubectl apply -f ../k8s/service-backend.yaml

echo "⏳ Esperando que el backend esté listo..."
kubectl wait --for=condition=ready pod -l app=backend -n dev --timeout=120s

# Frontend
kubectl apply -f ../k8s/deployment-frontend.yaml
kubectl apply -f ../k8s/service-frontend.yaml

echo "⏳ Esperando que el frontend esté listo..."
kubectl wait --for=condition=ready pod -l app=frontend -n dev --timeout=120s

# 8. Limpiar archivos temporales
rm -f ../k8s/configmap-backend-temp.yaml

# 9. Mostrar información de acceso
echo "✅ ¡Despliegue completado!"
echo ""
echo "📋 Información de acceso:"
echo "   🌐 Frontend: http://$MINIKUBE_IP:30080"
echo "   🔧 Backend:  http://$MINIKUBE_IP:30000"
echo ""
echo "🔍 Comandos útiles:"
echo "   kubectl get pods -n dev"
echo "   kubectl logs -f deployment/backend -n dev"
echo "   kubectl logs -f deployment/frontend -n dev"
echo ""
echo "🚀 Accede a tu aplicación en: http://$MINIKUBE_IP:30080"
