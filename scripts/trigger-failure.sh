#!/bin/bash
# 障害を意図的に発生させるスクリプト

ALB_DNS=$1

if [ -z "$ALB_DNS" ]; then
  echo "Usage: $0 <ALB_DNS_NAME>"
  echo "Example: $0 payment-demo-alb-123456789.ap-northeast-1.elb.amazonaws.com"
  exit 1
fi

echo "=== 障害モード有効化 ==="
curl -X POST http://$ALB_DNS/admin/failure \
  -H "Content-Type: application/json" \
  -d '{"enable": true}'

echo ""
echo "障害モードが有効になりました。決済APIは3秒の遅延後にエラーを返します。"
echo ""
echo "=== テストリクエスト送信 ==="
for i in {1..5}; do
  echo "リクエスト $i:"
  curl -X POST http://$ALB_DNS/payment \
    -H "Content-Type: application/json" \
    -w "\nHTTP Status: %{http_code}\nTime: %{time_total}s\n\n"
done

echo "=== 障害モード無効化 ==="
curl -X POST http://$ALB_DNS/admin/failure \
  -H "Content-Type: application/json" \
  -d '{"enable": false}'

echo ""
echo "障害モードが無効になりました。"
