#!/bin/bash
set -e

echo "=== Building documentation container ==="
docker build -t docs-builder -f Dockerfile.docs .

echo "=== Running documentation build ==="
# Run the container with the current directory mounted
docker run --rm -v $(pwd):/docs docs-builder

echo "=== Documentation build complete ==="
echo "Generated files are in the ./public directory" 