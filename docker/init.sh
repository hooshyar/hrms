#!/bin/bash

set -e

echo "🚀 Starting HRMS Docker setup..."

# Wait for MariaDB to be ready
echo "⏳ Waiting for MariaDB..."
while ! mysqladmin ping -h mariadb -uroot -p123 --silent 2>/dev/null; do
    echo "Waiting for MariaDB to start..."
    sleep 3
done
echo "✅ MariaDB is ready!"

# Wait for Redis to be ready  
echo "⏳ Waiting for Redis..."
while ! redis-cli -h redis ping >/dev/null 2>&1; do
    echo "Waiting for Redis to start..."
    sleep 2
done
echo "✅ Redis is ready!"

# Change to frappe user home directory
cd /home/frappe

# Check if bench already exists
if [ -d "/home/frappe/frappe-bench" ] && [ -f "/home/frappe/frappe-bench/apps/frappe/frappe/__init__.py" ]; then
    echo "✅ Bench already exists, skipping initialization"
    cd frappe-bench
else
    echo "📦 Creating new bench..."
    
    # Initialize bench
    bench init --skip-redis-config-generation frappe-bench
    cd frappe-bench
    
    echo "🔧 Configuring database and cache..."
    # Configure database and Redis connections
    bench set-config -g db_host mariadb
    bench set-config -g db_port 3306
    bench set-config -g redis_cache "redis://redis:6379"
    bench set-config -g redis_queue "redis://redis:6379" 
    bench set-config -g redis_socketio "redis://redis:6379"
    
    echo "🛠️ Modifying Procfile for container environment..."
    # Remove redis and watch from Procfile (they run in separate containers)
    sed -i '/redis/d' ./Procfile
    sed -i '/watch/d' ./Procfile
    
    echo "📱 Getting ERPNext app..."
    bench get-app --branch version-15 erpnext
    
    echo "👥 Getting HRMS app..."
    bench get-app --branch version-15 hrms
    
    echo "🌐 Creating new site..."
    bench new-site hrms.localhost \
        --force \
        --mariadb-root-password 123 \
        --admin-password admin \
        --no-mariadb-socket
    
    echo "📦 Installing HRMS app..."
    bench --site hrms.localhost install-app erpnext
    bench --site hrms.localhost install-app hrms
    
    echo "⚙️ Configuring site..."
    bench --site hrms.localhost set-config developer_mode 1
    bench --site hrms.localhost enable-scheduler
    bench --site hrms.localhost clear-cache
    
    echo "🎯 Setting default site..."
    bench use hrms.localhost
    
    echo "✅ Setup completed successfully!"
fi

echo "🚀 Starting Frappe bench..."
bench start
