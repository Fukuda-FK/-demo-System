#!/bin/bash

echo "=== EC2インスタンス診断 ==="

# インスタンスID取得
INSTANCE_ID=$(aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:ap-northeast-1:272128256293:targetgroup/payment-demo-tg/00d30f8c35b7996f --region ap-northeast-1 --query 'TargetHealthDescriptions[0].Target.Id' --output text)

echo "インスタンスID: $INSTANCE_ID"

# インスタンス情報取得
aws ec2 describe-instances --instance-ids $INSTANCE_ID --region ap-northeast-1 --query 'Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress,PrivateIpAddress]' --output table

# Systems Manager経由でアプリケーション状態確認
echo -e "\n=== アプリケーション状態確認 ==="
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["sudo systemctl status payment-app","ps aux | grep node","curl -s http://localhost:3000/health || echo \"Health check failed\"","sudo journalctl -u payment-app --no-pager -n 20"]' \
  --region ap-northeast-1 \
  --query 'Command.CommandId' \
  --output text > /tmp/command-id.txt

COMMAND_ID=$(cat /tmp/command-id.txt)
echo "コマンドID: $COMMAND_ID"

# 結果待機
sleep 10

# 結果取得
aws ssm get-command-invocation \
  --command-id $COMMAND_ID \
  --instance-id $INSTANCE_ID \
  --region ap-northeast-1 \
  --query 'StandardOutputContent' \
  --output text