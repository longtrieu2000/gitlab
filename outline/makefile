DOCKER_COMPOSE := docker compose

.PHONY: all up down logs restart ps ssl ssl-renew bash

all: up

## Sinh/import SSL cert và khởi động Outline Wiki
up: ssl
	@cp -n .env.default .env 2>/dev/null || true
	@$(DOCKER_COMPOSE) up -d
	@echo ""
	@echo "🚀 Outline Wiki đang khởi động tại https://$$(. ./.env 2>/dev/null || . ./.env.default; echo $${OUTLINE_HOST:-outline.cloudsb.space})"

## Sinh SSL certificate (tự động phát hiện SSL_TYPE)
ssl:
	@cp -n .env.default .env 2>/dev/null || true
	@. ./.env 2>/dev/null || . ./.env.default; \
	if [ "$${SSL_TYPE:-self-signed}" = "letsencrypt" ]; then \
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
	if [ "$${SSL_TYPE:-self-signed}" = "letsencrypt" ]; then \
		bash scripts/renew-cert.sh; \
	else \
		bash scripts/generate-ssl.sh; \
	fi

## Tắt Outline
down:
	@$(DOCKER_COMPOSE) down

## Xem logs
logs:
	@$(DOCKER_COMPOSE) logs -f --tail=100

## Restart Outline
restart:
	@$(DOCKER_COMPOSE) restart

## Trạng thái containers
ps:
	@$(DOCKER_COMPOSE) ps

## Shell vào container Outline
bash:
	@$(DOCKER_COMPOSE) exec outline sh
