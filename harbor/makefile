SCRIPTS_DIR := ./scripts
INSTALLER_DIR := ./harbor-installer

.PHONY: install up down restart logs ps ssl status uninstall docker-trust

## Cài đặt Harbor từ đầu (sinh cert + tải installer + deploy)
install:
	@cp -n .env.default .env 2>/dev/null || true
	@bash $(SCRIPTS_DIR)/install.sh

## Sinh SSL certificate (nếu chưa có)
ssl:
	@cp -n .env.default .env 2>/dev/null || true
	@bash $(SCRIPTS_DIR)/generate-ssl.sh

## Cấu hình Docker daemon trust cert
docker-trust:
	@. ./.env 2>/dev/null || . ./.env.default; \
	CERT_DIR="$${HARBOR_CERT_DIR:-./ssl}"; \
	HOST="$${HARBOR_HOST}"; \
	PORT="$${HARBOR_PORT:-443}"; \
	if [ "$$PORT" = "443" ]; then \
		DOCKER_DIR="/etc/docker/certs.d/$$HOST"; \
	else \
		DOCKER_DIR="/etc/docker/certs.d/$$HOST:$$PORT"; \
	fi; \
	sudo mkdir -p "$$DOCKER_DIR"; \
	sudo cp "$$CERT_DIR/$$HOST.cert" "$$DOCKER_DIR/"; \
	sudo cp "$$CERT_DIR/$$HOST.key" "$$DOCKER_DIR/"; \
	sudo cp "$$CERT_DIR/ca.crt" "$$DOCKER_DIR/"; \
	echo "✅ Cert đã copy vào $$DOCKER_DIR"; \
	sudo systemctl restart docker; \
	echo "✅ Docker daemon đã restart"

## Khởi động Harbor (sau khi đã install)
up:
	@cd $(INSTALLER_DIR) && docker compose up -d

## Tắt Harbor
down:
	@cd $(INSTALLER_DIR) && docker compose down

## Restart Harbor
restart:
	@cd $(INSTALLER_DIR) && docker compose restart

## Xem logs
logs:
	@cd $(INSTALLER_DIR) && docker compose logs -f --tail=100

## Xem trạng thái containers
ps:
	@cd $(INSTALLER_DIR) && docker compose ps

## Kiểm tra Harbor health
status:
	@. ./.env 2>/dev/null || . ./.env.default; \
	echo "🔍 Kiểm tra Harbor health..."; \
	curl -sk "https://$${HARBOR_HOST}:$${HARBOR_PORT:-443}/api/v2.0/health" | python3 -m json.tool 2>/dev/null || echo "❌ Harbor chưa sẵn sàng"

## Gỡ cài đặt Harbor
uninstall:
	@bash $(SCRIPTS_DIR)/uninstall.sh
