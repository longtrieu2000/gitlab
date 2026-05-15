DOCKER_COMPOSE := docker compose

.PHONY: all up down logs restart ps reconfigure backup bash version

all: up

## Copy env nếu chưa có và khởi động
up:
	@cp -n .env.default .env 2>/dev/null || true
	@$(DOCKER_COMPOSE) up -d

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
