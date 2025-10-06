#!/bin/bash
# RDSインスタンスにpayment_demoデータベースを作成

DB_HOST="payment-demo-db.cm711nipgl4d.ap-northeast-1.rds.amazonaws.com"
DB_USER="dbadmin"
DB_PASSWORD="DemoPassword123!"

echo "Creating payment_demo database..."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d postgres -c "CREATE DATABASE payment_demo;" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "Database created successfully"
else
    echo "Database may already exist or connection failed"
fi

echo "Verifying database..."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d postgres -c "\l" | grep payment_demo
