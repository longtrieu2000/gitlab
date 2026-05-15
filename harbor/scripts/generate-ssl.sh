#!/bin/bash
# ================================================================
# Sinh SSL Self-Signed Certificate cho Harbor
# Bao gồm: CA cert + Server cert (theo chuẩn Harbor docs)
# ================================================================

set -euo pipefail

# Load biến từ .env
if [ -f .env ]; then
    source .env
elif [ -f .env.default ]; then
    source .env.default
else
    echo "❌ Không tìm thấy .env hoặc .env.default"
    exit 1
fi

HARBOR_HOST="${HARBOR_HOST:-harbor.local}"
CERT_DIR="${HARBOR_CERT_DIR:-./ssl}"
CERT_DAYS=3650

echo "================================================"
echo "  Sinh SSL Certificate cho Harbor"
echo "  Host: ${HARBOR_HOST}"
echo "  Thư mục: ${CERT_DIR}"
echo "  Hiệu lực: ${CERT_DAYS} ngày (10 năm)"
echo "================================================"

mkdir -p "${CERT_DIR}"

# ---- 1. Sinh CA (Certificate Authority) ----
echo ""
echo "📜 [1/4] Sinh CA private key..."
openssl genrsa -out "${CERT_DIR}/ca.key" 4096

echo "📜 [2/4] Sinh CA certificate..."
openssl req -x509 -new -nodes -sha512 \
    -days ${CERT_DAYS} \
    -subj "/C=VN/ST=HoChiMinh/L=HoChiMinh/O=Self-Hosted/OU=Harbor-CA/CN=Harbor-CA" \
    -key "${CERT_DIR}/ca.key" \
    -out "${CERT_DIR}/ca.crt"

# ---- 2. Sinh Server Certificate ----
echo "🔑 [3/4] Sinh server private key + CSR..."
openssl genrsa -out "${CERT_DIR}/${HARBOR_HOST}.key" 4096

openssl req -sha512 -new \
    -subj "/C=VN/ST=HoChiMinh/L=HoChiMinh/O=Self-Hosted/OU=Harbor/CN=${HARBOR_HOST}" \
    -key "${CERT_DIR}/${HARBOR_HOST}.key" \
    -out "${CERT_DIR}/${HARBOR_HOST}.csr"

# ---- 3. Tạo v3 extensions file (SAN) ----
cat > "${CERT_DIR}/v3.ext" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = ${HARBOR_HOST}
DNS.1 = ${HARBOR_HOST}
DNS.2 = localhost
IP.2 = 127.0.0.1
EOF

echo "📄 [4/4] Ký server certificate với CA..."
openssl x509 -req -sha512 \
    -days ${CERT_DAYS} \
    -extfile "${CERT_DIR}/v3.ext" \
    -CA "${CERT_DIR}/ca.crt" \
    -CAkey "${CERT_DIR}/ca.key" \
    -CAcreateserial \
    -in "${CERT_DIR}/${HARBOR_HOST}.csr" \
    -out "${CERT_DIR}/${HARBOR_HOST}.crt"

# ---- 4. Tạo .cert cho Docker daemon ----
echo ""
echo "🐳 Tạo cert dạng .cert cho Docker daemon..."
openssl x509 -inform PEM -in "${CERT_DIR}/${HARBOR_HOST}.crt" \
    -out "${CERT_DIR}/${HARBOR_HOST}.cert"

# ---- 5. Đặt quyền ----
chmod 600 "${CERT_DIR}/ca.key" "${CERT_DIR}/${HARBOR_HOST}.key"
chmod 644 "${CERT_DIR}/ca.crt" "${CERT_DIR}/${HARBOR_HOST}.crt" "${CERT_DIR}/${HARBOR_HOST}.cert"

echo ""
echo "✅ Certificate đã sinh thành công!"
echo ""
echo "📁 Files:"
echo "   CA cert:     ${CERT_DIR}/ca.crt"
echo "   CA key:      ${CERT_DIR}/ca.key"
echo "   Server cert: ${CERT_DIR}/${HARBOR_HOST}.crt"
echo "   Server key:  ${CERT_DIR}/${HARBOR_HOST}.key"
echo "   Docker cert: ${CERT_DIR}/${HARBOR_HOST}.cert"
echo ""
echo "📋 Thông tin server cert:"
openssl x509 -in "${CERT_DIR}/${HARBOR_HOST}.crt" -noout -subject -dates -ext subjectAltName
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BƯỚC TIẾP THEO - Cấu hình Docker daemon trust:"
echo ""
echo "  sudo mkdir -p /etc/docker/certs.d/${HARBOR_HOST}"
echo "  sudo cp ${CERT_DIR}/${HARBOR_HOST}.cert /etc/docker/certs.d/${HARBOR_HOST}/"
echo "  sudo cp ${CERT_DIR}/${HARBOR_HOST}.key /etc/docker/certs.d/${HARBOR_HOST}/"
echo "  sudo cp ${CERT_DIR}/ca.crt /etc/docker/certs.d/${HARBOR_HOST}/"
echo "  sudo systemctl restart docker"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
