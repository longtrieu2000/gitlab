DOCKER_COMPOSE := docker compose

.PHONY: up down logs restart ps register register-shell unregister list

## Khởi động runner
up:
	@cp -n .env.default .env 2>/dev/null || true
	@$(DOCKER_COMPOSE) up -d

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
	@echo "Nhập GitLab URL và Registration Token khi được hỏi..."
	@$(DOCKER_COMPOSE) exec runner gitlab-runner register \
		--non-interactive \
		--url "$${GITLAB_URL}" \
		--token "$${REGISTRATION_TOKEN}" \
		--executor docker \
		--docker-image alpine:latest \
		--docker-privileged \
		--docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
		--description "runner-${GITLAB_HOST}" \
		--tag-list "docker,linux"

## Đăng ký runner với Shell executor (chạy trực tiếp trên host)
register-shell:
	@echo "=== Đăng ký GitLab Runner (Shell executor) ==="
	@$(DOCKER_COMPOSE) exec runner gitlab-runner register \
		--non-interactive \
		--url "$${GITLAB_URL}" \
		--token "$${REGISTRATION_TOKEN}" \
		--executor shell \
		--description "runner-shell-${GITLAB_HOST}" \
		--tag-list "shell,linux"

## Xoá đăng ký runner
unregister:
	@$(DOCKER_COMPOSE) exec runner gitlab-runner unregister --all-runners

## Liệt kê runners đã đăng ký
list:
	@$(DOCKER_COMPOSE) exec runner gitlab-runner list
