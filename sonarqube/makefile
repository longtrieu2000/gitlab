DOCKER_COMPOSE := docker compose

.PHONY: all up down logs restart ps ssl ssl-renew bash db-bash

all: up

## Sinh/import SSL cert và khởi động SonarQube
up: ssl
	@cp -n .env.default .env 2>/dev/null || true
	@$(DOCKER_COMPOSE) up -d
	@echo ""
	@echo "🚀 SonarQube đang khởi động tại https://$$(. ./.env 2>/dev/null || . ./.env.default; echo $${SONARQUBE_HOST}):$$(. ./.env 2>/dev/null || . ./.env.default; echo $${SONARQUBE_PORT})"
	@echo "📝 Vui lòng đợi khoảng 1-2 phút để SonarQube hoàn tất khởi động và migrations."

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

## Tắt SonarQube
down:
	@$(DOCKER_COMPOSE) down

## Xem logs
logs:
	@$(DOCKER_COMPOSE) logs -f --tail=100

## Restart SonarQube
restart:
	@$(DOCKER_COMPOSE) restart

## Trạng thái containers
ps:
	@$(DOCKER_COMPOSE) ps

## Shell vào container SonarQube
bash:
	@$(DOCKER_COMPOSE) exec sonarqube bash

## Shell vào container DB
db-bash:
	@$(DOCKER_COMPOSE) exec db sh
