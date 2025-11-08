#!/bin/bash

APP_DIR="/home/ubuntu/quotes-app"

echo "========================================"
echo "  Health Check - Quotes Application"
echo "========================================"
echo "Directory: $APP_DIR"
echo "Timestamp: $(date)"
echo "========================================"

cd $APP_DIR

MAX_ATTEMPTS=30
ATTEMPT=0

# Health check functions
check_containers() {
    RUNNING=$(docker-compose ps -q | wc -l)
    EXPECTED=3
    [ $RUNNING -eq $EXPECTED ]
}

check_nginx() {
    systemctl is-active --quiet nginx
}

check_nginx_config() {
    sudo nginx -t > /dev/null 2>&1
}

check_health_endpoint() {
    curl -f -s http://localhost/health > /dev/null 2>&1
}

check_api() {
    curl -f -s http://localhost/api/ > /dev/null 2>&1
}

check_frontend() {
    curl -f -s http://localhost/ > /dev/null 2>&1
}

check_database() {
    docker-compose exec -T db mysqladmin ping -h localhost -uroot -proot > /dev/null 2>&1
}

# Run health checks
echo "Starting health checks..."
echo ""

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT+1))
    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS"
    
    echo -n "  ├─ Docker containers... "
    if check_containers; then 
        echo "✅"
    else 
        echo "❌ (retrying)"
        sleep 10
        continue
    fi
    
    echo -n "  ├─ Nginx service... "
    if check_nginx; then 
        echo "✅"
    else 
        echo "❌ (retrying)"
        sleep 10
        continue
    fi
    
    echo -n "  ├─ Nginx config... "
    if check_nginx_config; then 
        echo "✅"
    else 
        echo "❌ (retrying)"
        sleep 10
        continue
    fi
    
    echo -n "  ├─ Database... "
    if check_database; then 
        echo "✅"
    else 
        echo "❌ (retrying)"
        sleep 10
        continue
    fi
    
    echo -n "  ├─ Health endpoint... "
    if check_health_endpoint; then 
        echo "✅"
    else 
        echo "❌ (retrying)"
        sleep 10
        continue
    fi
    
    echo -n "  ├─ API... "
    if check_api; then 
        echo "✅"
    else 
        echo "❌ (retrying)"
        sleep 10
        continue
    fi
    
    echo -n "  └─ Frontend... "
    if check_frontend; then 
        echo "✅"
    else 
        echo "❌ (retrying)"
        sleep 10
        continue
    fi
    
    # All checks passed
    echo ""
    echo "========================================"
    echo "✅ ALL HEALTH CHECKS PASSED!"
    echo "========================================"
    echo ""
    
    echo "Deployment Information:"
    curl -s http://localhost/deployment-info | jq '.' 2>/dev/null || curl -s http://localhost/deployment-info
    echo ""
    
    echo "Service Status:"
    echo "  ├─ Nginx: Active on port 80"
    echo "  ├─ Frontend: Proxied to http://localhost:5002"
    echo "  ├─ API: Proxied to http://localhost:5001"
    echo "  └─ Database: MySQL in Docker"
    echo ""
    
    echo "Container Status:"
    docker-compose ps
    echo ""
    
    echo "Recent Application Logs:"
    docker-compose logs --tail=10
    echo ""
    
    echo "========================================"
    exit 0
done

# Health checks failed
echo ""
echo "========================================"
echo "❌ HEALTH CHECKS FAILED"
echo "========================================"
echo ""

echo "Container Status:"
docker-compose ps
echo ""

echo "Container Logs:"
docker-compose logs --tail=100
echo ""

echo "Nginx Logs:"
sudo tail -50 /var/log/nginx/error.log
echo ""

echo "========================================"
exit 1
