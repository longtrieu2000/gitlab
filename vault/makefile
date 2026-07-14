DOCKER_COMPOSE := docker compose

.PHONY: all up down logs restart ps ssl ssl-renew init unseal status bash snapshot restore

all: up

## Sinh/import SSL cert và khởi động Vault
up: ssl
	@cp -n .env.default .env 2>/dev/null || true
	@$(DOCKER_COMPOSE) up -d
	@echo ""
	@echo "🚀 Vault đang khởi động tại https://$$(. ./.env 2>/dev/null || . ./.env.default; echo $${VAULT_HOST}):$$(. ./.env 2>/dev/null || . ./.env.default; echo $${VAULT_API_PORT})"
	@echo "📝 Nếu lần đầu, chạy: make init"

## Sinh SSL certificate (tự động phát hiện SSL_TYPE)
ssl:
	@cp -n .env.default .env 2>/dev/null || true
	@. ./.env 2>/dev/null || . ./.env.default; \
	if [ "$${SSL_TYPE}" = "letsencrypt" ]; then \
		if [ ! -f "./ssl/fullchain.pem" ]; then \
			echo "🔐 Thiết lập SSL Let's Encrypt..."; \
			bash scripts/setup-letsencrypt.sh; \
		else \
			echo "✅ Let's Encrypt SSL cert đã có: ./ssl/fullchain.pem"; \
		fi \
	else \
		if [ ! -f "./ssl/fullchain.pem" ]; then \
			echo "🔐 Sinh SSL Self-Signed Certificate..."; \
			bash scripts/generate-ssl.sh; \
		else \
			echo "✅ Self-Signed SSL cert đã có: ./ssl/fullchain.pem"; \
		fi \
	fi

## Sinh lại hoặc import lại SSL cert (force)
ssl-renew:
	@. ./.env 2>/dev/null || . ./.env.default; \
	if [ "$${SSL_TYPE}" = "letsencrypt" ]; then \
		bash scripts/renew-cert.sh; \
	else \
		bash scripts/generate-ssl.sh; \
	fi

## Tắt Vault
down:
	@$(DOCKER_COMPOSE) down

## Xem logs
logs:
	@$(DOCKER_COMPOSE) logs -f --tail=100

## Restart Vault
restart:
	@$(DOCKER_COMPOSE) restart

## Trạng thái containers
ps:
	@$(DOCKER_COMPOSE) ps

## Khởi tạo Vault lần đầu (tạo unseal keys + root token)
init:
	@echo "🔑 Đang khởi tạo Vault..."
	@$(DOCKER_COMPOSE) exec vault vault operator init \
		-key-shares=5 \
		-key-threshold=3 \
		-tls-skip-verify \
		-format=json | tee vault-init-keys.json
	@echo ""
	@echo "⚠️  QUAN TRỌNG: Lưu file vault-init-keys.json ở nơi an toàn!"
	@echo "   File này chứa unseal keys và root token."
	@echo "   Xóa file khỏi server sau khi đã backup an toàn."
	@chmod 600 vault-init-keys.json

## Unseal Vault (cần chạy 3 lần với 3 key khác nhau)
unseal:
	@read -p "🔑 Nhập Unseal Key: " KEY && \
	$(DOCKER_COMPOSE) exec vault vault operator unseal -tls-skip-verify "$$KEY"

## Auto-unseal bằng vault-init-keys.json (DEV ONLY - không dùng cho production thật)
unseal-auto:
	@if [ ! -f vault-init-keys.json ]; then \
		echo "❌ Không tìm thấy vault-init-keys.json. Chạy 'make init' trước."; \
		exit 1; \
	fi
	@echo "🔓 Đang auto-unseal Vault..."
	@for i in 0 1 2; do \
		KEY=$$(jq -r ".unseal_keys_b64[$$i]" vault-init-keys.json); \
		$(DOCKER_COMPOSE) exec vault vault operator unseal -tls-skip-verify "$$KEY"; \
	done
	@echo "✅ Vault đã unseal!"

## Kiểm tra trạng thái Vault
status:
	@$(DOCKER_COMPOSE) exec vault vault status -tls-skip-verify || true

## Shell vào container Vault
bash:
	@$(DOCKER_COMPOSE) exec vault sh

## Tạo Raft snapshot (backup)
snapshot:
	@. ./.env 2>/dev/null || . ./.env.default; \
	FILENAME="vault-snapshot-$$(date +%Y%m%d-%H%M%S).snap"; \
	$(DOCKER_COMPOSE) exec vault vault operator raft snapshot save \
		-tls-skip-verify "/vault/data/$${FILENAME}"; \
	docker cp vault:"/vault/data/$${FILENAME}" "./$${FILENAME}"; \
	echo "✅ Snapshot saved: $${FILENAME}"

## Restore Raft snapshot
restore:
	@read -p "📂 Nhập đường dẫn file snapshot: " SNAP && \
	docker cp "$$SNAP" vault:/vault/data/restore.snap && \
	$(DOCKER_COMPOSE) exec vault vault operator raft snapshot restore \
		-tls-skip-verify -force /vault/data/restore.snap && \
	echo "✅ Snapshot đã restore!"
