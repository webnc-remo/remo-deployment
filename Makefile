alias = ticketplus

# ignore folder: deploy when deploy
.PHONY: deploy transfer

default: up

bootstrap:
	cp .env.example .env
	make container-up

container-up:
	docker compose -f docker-compose.yml up -d 

container-down:
	docker compose -f docker-compose.yml down

monitor-container-up:
	docker compose -f docker-compose-monitoring.yml up -d

monitor-container-down:
	docker compose -f docker-compose-monitoring.yml down
ps:
	docker compose ps

deploy:
	bash deploy.sh
