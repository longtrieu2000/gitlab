DOCKER_COMPOSE := docker compose

.PHONY: all up down logs restart ps reconfigure backup bash version password ssl

all: up

## Sinh SSL cert và khởi động
up: ssl
	@cp -n .env.default .env 2>/dev/null || true
	@$(DOCKER_COMPOSE) up -d

## Sinh SSL certificate (tự động phát hiện loại SSL_TYPE)
ssl:
	@. ./.env 2>/dev/null || . ./.env.default; \
	if [ "$${SSL_TYPE}" = "letsencrypt" ]; then \
		if [ ! -f "./ssl/$${GITLAB_HOST}.crt" ]; then \
			echo "🔐 Thiết lập SSL Let's Encrypt..."; \
			bash scripts/setup-letsencrypt.sh; \
		else \
			echo "✅ Let's Encrypt SSL cert đã có: ./ssl/$${GITLAB_HOST}.crt"; \
		fi \
	else \
		if [ ! -f "./ssl/$${GITLAB_HOST}.crt" ]; then \
			echo "🔐 Sinh SSL Self-Signed Certificate..."; \
			bash scripts/generate-ssl.sh; \
		else \
			echo "✅ Self-Signed SSL cert đã có: ./ssl/$${GITLAB_HOST}.crt"; \
		fi \
	fi

## Sinh lại hoặc import lại SSL cert (force)
ssl-renew:
	@. ./.env 2>/dev/null || . ./.env.default; \
	if [ "$${SSL_TYPE}" = "letsencrypt" ]; then \
		bash scripts/setup-letsencrypt.sh; \
	else \
		bash scripts/generate-ssl.sh; \
	fi

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
