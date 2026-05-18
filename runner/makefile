DOCKER_COMPOSE := docker compose

.PHONY: up down logs restart ps register register-shell unregister list check-cert

## Khởi động runner
up: check-cert
	@cp -n .env.default .env 2>/dev/null || true
	@mkdir -p ./config
	@touch ./config/config.toml
	@$(DOCKER_COMPOSE) up -d

## Kiểm tra cert trước khi khởi động
check-cert:
	@. ./.env 2>/dev/null || . ./.env.default; \
	if [ ! -f "./ssl/$${GITLAB_HOST}.crt" ]; then \
		echo "❌ Chưa có SSL cert!"; \
		echo "   Copy cert từ GitLab Server:"; \
		echo "   scp user@$${GITLAB_HOST}:~/gitlab/ssl/$${GITLAB_HOST}.crt ./ssl/"; \
		exit 1; \
	else \
		echo "✅ Cert found: ./ssl/$${GITLAB_HOST}.crt"; \
	fi

## Tắt runner
down:
	@$(DOCKER_COMPOSE) down

## Xem logs
logs:
	@$(DOCKER_COMPOSE) logs -f --tail=100

## Restart runner
restart:
	@$(DOCKER_COMPOSE) restart

## Xem trạng thái
ps:
	@$(DOCKER_COMPOSE) ps

## Đăng ký runner với Docker executor (dùng cho CI/CD container-based)
register:
	@echo "=== Đăng ký GitLab Runner (Docker executor) ==="
	@. ./.env; \
	$(DOCKER_COMPOSE) exec runner gitlab-runner register \
		--non-interactive \
		--url "$${GITLAB_URL}" \
		--token "$${REGISTRATION_TOKEN}" \
		--executor docker \
		--docker-image alpine:latest \
		--docker-privileged \
		--docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
		--description "runner-docker" \
		--tls-ca-file "/etc/gitlab-runner/certs/$${GITLAB_HOST}.crt"

## Đăng ký runner với Shell executor (chạy trực tiếp trên host)
register-shell:
	@echo "=== Đăng ký GitLab Runner (Shell executor) ==="
	@. ./.env; \
	$(DOCKER_COMPOSE) exec runner gitlab-runner register \
		--non-interactive \
		--url "$${GITLAB_URL}" \
		--token "$${REGISTRATION_TOKEN}" \
		--executor shell \
		--description "runner-shell" \
		--tls-ca-file "/etc/gitlab-runner/certs/$${GITLAB_HOST}.crt"

## Xoá đăng ký runner
unregister:
	@$(DOCKER_COMPOSE) exec runner gitlab-runner unregister --all-runners

## Liệt kê runners đã đăng ký
list:
	@$(DOCKER_COMPOSE) exec runner gitlab-runner list
