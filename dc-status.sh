#!/bin/bash

echo "Checking Detector Controller Software Status"


# Check if the "gnirsdc" container is running
if docker ps --format '{{.Names}}' | grep -q "^gnirsdc$"; then
    echo "The 'gnirsdc' container is running."
else
    echo "The 'gnirsdc' container is NOT running."
fi

# Check if the "gmp" container is running
if docker ps --format '{{.Names}}' | grep -q "^gmp$"; then
    echo "The 'gmp' container is running."
else
    echo "The 'gmp' container is NOT running."
fi

echo 
docker ps
