#!/bin/bash
set -e

frontend_service=frontend
backend_service_image=image-name-backend
frontend_service_image=image-name-frontend
web_server_name=webserver
migration_command="npm run migrate:run:prod"


reload_nginx() {
 nginx_id=$(docker ps -f name=$web_server_name -q | tail -n1)
 docker exec $nginx_id nginx -s reload
}


deploy() {
  ideploy() {
  echo "Deploying the latest version of frontend and backend..."

  # Pull the latest images for backend and frontend
  echo "Pulling latest images for backend and frontend..."
  docker pull $backend_service_image:latest
  docker pull $frontend_service_image:latest

  echo "Checking for updated images and stopping containers for updated services..."


  # Check if backend image has changed
  backend_image_updated=$(docker inspect --format='{{.Id}}' $backend_service_image:latest)
  backend_container_id=$(docker ps -f name=$backend_service -q)
  if [ -n "$backend_container_id" ]; then
    current_backend_image=$(docker inspect --format='{{.Image}}' $backend_container_id)
    if [ "$current_backend_image" != "$backend_image_updated" ]; then
      echo "Backend image has been updated. Stopping the old backend container..."
      docker-compose stop $backend_service
      docker-compose rm -f $backend_service
    fi
  fi

  # Check if frontend image has changed
  frontend_image_updated=$(docker inspect --format='{{.Id}}' $frontend_service_image:latest)
  frontend_container_id=$(docker ps -f name=$frontend_service -q)
  if [ -n "$frontend_container_id" ]; then
    current_frontend_image=$(docker inspect --format='{{.Image}}' $frontend_container_id)
    if [ "$current_frontend_image" != "$frontend_image_updated" ]; then
      echo "Frontend image has been updated. Stopping the old frontend container..."
      docker-compose stop $frontend_service
      docker-compose rm -f $frontend_service
    fi
  fi

  # Deploy new containers with the latest images
  echo "Deploying new containers with latest images..."
  docker-compose up -d --scale $backend_service=1 --scale $frontend_service=1


  # Check if backend container is running
  echo "Checking backend container..."
  backend_container_id=$(docker ps -f name=$backend_service -q)
  if [ -z "$backend_container_id" ]; then
    echo "Backend container failed to start, rolling back to previous version..."
    # Rollback by recreating the old containers
    docker-compose up -d --scale $backend_service=1 --scale $frontend_service=1
    exit 1
  fi


  # Check if frontend container is running
  echo "Checking frontend container..."
  frontend_container_id=$(docker ps -f name=$frontend_service -q)
  if [ -z "$frontend_container_id" ]; then
    echo "Frontend container failed to start, rolling back to previous version..."
    # Rollback by recreating the old containers
    docker-compose up -d --scale $backend_service=1 --scale $frontend_service=1
    exit 1
  fi

  # Run backend migrations
  echo "Running backend migrations..."
  docker-compose exec $backend_service $migration_command


  # Reload nginx to apply changes
  echo "Reloading nginx..."
  reload_nginx


  echo "Clean up image"
  docker image prune -a -f


  echo "Deployment completed successfully!"
}

deploy $1
