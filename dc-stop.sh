#!/bin/bash

echo "Stopping Detector Controller Software"

# Check if the "gnirsdc" container is running and stop it
if docker ps --format '{{.Names}}' | grep -q "^gnirsdc$"; then
    echo "Stopping the 'gnirsdc' container..."
    docker stop gnirsdc > /dev/null 2>&1
    echo "The 'gnirsdc' container has been stopped."
else
    echo "The 'gnirsdc' container is not running."
fi

# Check if the "gnirsdc" container exists and remove it
if docker ps -a --format '{{.Names}}' | grep -q "^gnirsdc$"; then
    echo "Removing the 'gnirsdc' container..."
    docker rm -f gnirsdc > /dev/null 2>&1
    echo "The 'gnirsdc' container has been removed."
else
    echo "The 'gnirsdc' container does not exist."
fi

# Check if the "gmp" container is running and stop it
if docker ps --format '{{.Names}}' | grep -q "^gmp$"; then
    echo "Stopping the 'gmp' container..."
    docker stop gmp > /dev/null 2>&1
    echo "The 'gmp' container has been stopped."
else
    echo "The 'gmp' container is not running."
fi

# Check if the "gmp" container exists and remove it
if docker ps -a --format '{{.Names}}' | grep -q "^gmp$"; then
    echo "Removing the 'gmp' container..."
    docker rm -f gmp > /dev/null 2>&1
    echo "The 'gmp' container has been removed."
else
    echo "The 'gmp' container does not exist."
fi