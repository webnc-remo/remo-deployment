#!/bin/bash
set -e

# Define services and variables
frontend_service=frontend
backend_service=backend
backend_service_image=tantran308/remo-be
frontend_service_image=tantran308/remo-fe
web_server_name=nginx
migration_command="npm run migration:run"

# Get arguments
service=${1:-all} # Default to "all" if no argument is provided
backend_version=${2:-latest}
frontend_version=${2:-latest}

reload_nginx() {
  nginx_id=$(docker ps -f name=$web_server_name -q | tail -n1)
  docker exec $nginx_id nginx -s reload
}

deploy_backend() {
  echo "Deploying backend service..."

  # Pull the specified backend image
  echo "Pulling backend image..."
  docker pull $backend_service_image:$backend_version

  # Check if backend image has changed
  backend_image_updated=$(docker inspect --format='{{.Id}}' $backend_service_image:$backend_version)
  backend_container_id=$(docker ps -f name=$backend_service -q)
  if [ -n "$backend_container_id" ]; then
    current_backend_image=$(docker inspect --format='{{.Image}}' $backend_container_id)
    if [ "$current_backend_image" != "$backend_image_updated" ]; then
      echo "Backend image has been updated. Stopping the old backend container..."
      docker-compose stop $backend_service
      docker-compose rm -f $backend_service
    fi
  fi

  # Start backend container
  echo "Starting backend container..."
  VERSION=$backend_version docker-compose up -d $backend_service
}

deploy_frontend() {
  echo "Deploying frontend service..."

  # Pull the specified frontend image
  echo "Pulling frontend image..."
  docker pull $frontend_service_image:$frontend_version

  # Check if frontend image has changed
  frontend_image_updated=$(docker inspect --format='{{.Id}}' $frontend_service_image:$frontend_version)
  frontend_container_id=$(docker ps -f name=$frontend_service -q)
  if [ -n "$frontend_container_id" ]; then
    current_frontend_image=$(docker inspect --format='{{.Image}}' $frontend_container_id)
    if [ "$current_frontend_image" != "$frontend_image_updated" ]; then
      echo "Frontend image has been updated. Stopping the old frontend container..."
      docker-compose stop $frontend_service
      docker-compose rm -f $frontend_service
    fi
  fi

  # Start frontend container
  echo "Starting frontend container with version: $frontend_version"
  VERSION=$frontend_version docker-compose up -d $frontend_service
}

cleanup_images() {
  echo "Cleaning up unused Docker images..."
  docker image prune -a -f
}

# Main deploy function
deploy() {
  case $service in
    backend)
      deploy_backend
      ;;
    frontend)
      deploy_frontend
      ;;
    all)
      deploy_backend
      deploy_frontend
      ;;
    *)
      echo "Invalid service specified. Use 'backend', 'frontend', or 'all'."
      exit 1
      ;;
  esac

  # Reload nginx to apply changes
  echo "Reloading nginx..."
  reload_nginx

  # Clean up images
  cleanup_images

  echo "Deployment completed successfully!"
}

deploy
