#!/bin/bash
# 負荷テストスクリプト

ALB_DNS=$1
REQUESTS=${2:-100}

if [ -z "$ALB_DNS" ]; then
  echo "Usage: $0 <ALB_DNS_NAME> [REQUESTS]"
  echo "Example: $0 payment-demo-alb-123456789.ap-northeast-1.elb.amazonaws.com 100"
  exit 1
fi

echo "=== 負荷テスト開始 ==="
echo "対象: http://$ALB_DNS"
echo "リクエスト数: $REQUESTS"
echo ""

SUCCESS=0
FAILURE=0

for i in $(seq 1 $REQUESTS); do
  RESPONSE=$(curl -s -X POST http://$ALB_DNS/payment \
    -H "Content-Type: application/json" \
    -w "%{http_code}" \
    -o /dev/null)
  
  if [ "$RESPONSE" = "200" ]; then
    SUCCESS=$((SUCCESS + 1))
  else
    FAILURE=$((FAILURE + 1))
  fi
  
  if [ $((i % 10)) -eq 0 ]; then
    echo "進捗: $i/$REQUESTS (成功: $SUCCESS, 失敗: $FAILURE)"
  fi
done

echo ""
echo "=== 負荷テスト完了 ==="
echo "総リクエスト数: $REQUESTS"
echo "成功: $SUCCESS"
echo "失敗: $FAILURE"
echo "成功率: $(awk "BEGIN {printf \"%.2f\", ($SUCCESS/$REQUESTS)*100}")%"
