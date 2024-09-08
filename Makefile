up:
	docker compose -f devops/docker-compose.local.yml --project-name touchpoint up
down:
	docker compose -f devops/docker-compose.local.yml --project-name touchpoint down