DOCKER_COMPOSE := docker compose

.PHONY: all up down logs restart ps reconfigure backup bash version password ssl

all: up

## Sinh SSL cert và khởi động
up: ssl
	@cp -n .env.default .env 2>/dev/null || true
	@$(DOCKER_COMPOSE) up -d

## Sinh self-signed SSL certificate (nếu chưa có)
ssl:
	@. ./.env 2>/dev/null || . ./.env.default; \
	if [ ! -f "./ssl/$${GITLAB_HOST}.crt" ]; then \
		echo "🔐 Sinh SSL Self-Signed Certificate..."; \
		bash scripts/generate-ssl.sh; \
	else \
		echo "✅ SSL cert đã tồn tại: ./ssl/$${GITLAB_HOST}.crt"; \
	fi

## Sinh lại SSL cert (force)
ssl-renew:
	@bash scripts/generate-ssl.sh

down:
	@$(DOCKER_COMPOSE) down

logs:
	@$(DOCKER_COMPOSE) logs -f --tail=100

restart:
	@$(DOCKER_COMPOSE) restart

ps:
	@$(DOCKER_COMPOSE) ps

reconfigure:
	@$(DOCKER_COMPOSE) exec gitlab gitlab-ctl reconfigure

backup:
	@$(DOCKER_COMPOSE) exec gitlab gitlab-rake gitlab:backup:create

bash:
	@$(DOCKER_COMPOSE) exec gitlab /bin/bash

version:
	@$(DOCKER_COMPOSE) exec gitlab cat /opt/gitlab/version-manifest.txt | head -5

## Xem initial root password (chỉ dùng lần đầu)
password:
	@$(DOCKER_COMPOSE) exec gitlab cat /etc/gitlab/initial_root_password 2>/dev/null || echo "File không tồn tại - password đã bị xóa sau 24h hoặc đã đổi."
