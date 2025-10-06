# デプロイとアクセス方法

## 1. スタックのデプロイ

```bash
cd demo-system/cloudformation

aws cloudformation create-stack \
  --stack-name newrelic-demo-stack \
  --template-body file://demo-infrastructure.yaml \
  --parameters \
    ParameterKey=NewRelicLicenseKey,ParameterValue=YOUR_LICENSE_KEY \
    ParameterKey=KeyPairName,ParameterValue=YOUR_KEY_PAIR \
  --capabilities CAPABILITY_IAM \
  --region ap-northeast-1
```

## 2. デプロイ状況の確認

```bash
# スタックの状態確認
aws cloudformation describe-stacks \
  --stack-name newrelic-demo-stack \
  --query 'Stacks[0].StackStatus' \
  --region ap-northeast-1

# CREATE_COMPLETEになるまで待機（約10-15分）
aws cloudformation wait stack-create-complete \
  --stack-name newrelic-demo-stack \
  --region ap-northeast-1
```

## 3. ALB DNS名の取得

```bash
# ALBのDNS名を取得
aws cloudformation describe-stacks \
  --stack-name newrelic-demo-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
  --output text \
  --region ap-northeast-1
```

出力例: `payment-demo-alb-1234567890.ap-northeast-1.elb.amazonaws.com`

## 4. アプリケーションへのアクセス

### ブラウザでアクセス
```
http://<ALB_DNS_NAME>
```

例: `http://payment-demo-alb-1234567890.ap-northeast-1.elb.amazonaws.com`

### ヘルスチェック
```bash
curl http://<ALB_DNS_NAME>/health
```

期待される応答:
```json
{"status":"ok","timestamp":"2024-01-10T12:00:00.000Z"}
```

### 決済APIテスト
```bash
curl -X POST http://<ALB_DNS_NAME>/api/payment \
  -H "Content-Type: application/json" \
  -d '{"amount": 1000, "cardNumber": "1234567890123456", "storeId": "STORE001"}'
```

## 5. EC2インスタンスの確認

### インスタンスIDの取得
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=PaymentDemoServer" \
           "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name]' \
  --output table \
  --region ap-northeast-1
```

### アプリケーションログの確認（SSH接続が必要）
```bash
# EC2にSSH接続
ssh -i your-key.pem ec2-user@<EC2_PUBLIC_IP>

# アプリケーションのステータス確認
sudo systemctl status payment-app

# アプリケーションログ確認
sudo journalctl -u payment-app -f

# アプリケーションディレクトリ確認
ls -la /home/ec2-user/demo-app/app/

# Node.jsプロセス確認
ps aux | grep node
```

## 6. トラブルシューティング

### ALBのターゲットヘルス確認
```bash
# ターゲットグループARNを取得
TG_ARN=$(aws elbv2 describe-target-groups \
  --names payment-demo-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text \
  --region ap-northeast-1)

# ターゲットのヘルス状態確認
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region ap-northeast-1
```

期待される状態: `"State": "healthy"`

### アプリケーションが起動しない場合

1. **EC2にSSH接続してログ確認**
```bash
ssh -i your-key.pem ec2-user@<EC2_PUBLIC_IP>
sudo journalctl -u payment-app -n 100 --no-pager
```

2. **手動でアプリケーション起動テスト**
```bash
cd /home/ec2-user/demo-app/app
node app.js
```

3. **依存関係の確認**
```bash
cd /home/ec2-user/demo-app/app
npm list
```

4. **環境変数の確認**
```bash
sudo systemctl show payment-app --property=Environment
```

### ALBヘルスチェックが失敗する場合

1. **セキュリティグループ確認**
```bash
# ALBからEC2への通信が許可されているか確認
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*WebServer*" \
  --region ap-northeast-1
```

2. **ローカルでヘルスチェック確認**
```bash
# EC2内から
curl http://localhost:3000/health
```

## 7. アクセス制限の確認

現在のセキュリティグループ設定:
- **ALBへのアクセス**: `103.4.10.234/32` のみ
- **EC2へのSSH**: `103.4.10.234/32` のみ

別のIPアドレスからアクセスする場合は、セキュリティグループを更新してください。

```bash
# セキュリティグループIDを取得
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*ALBSecurityGroup*" \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --region ap-northeast-1)

# 新しいIPアドレスを追加
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr YOUR_IP_ADDRESS/32 \
  --region ap-northeast-1
```

## 8. 動作確認チェックリスト

- [ ] CloudFormationスタックが`CREATE_COMPLETE`
- [ ] EC2インスタンスが2台起動中
- [ ] ALBターゲットヘルスが`healthy`
- [ ] `/health`エンドポイントが200を返す
- [ ] ブラウザでWebページが表示される
- [ ] 決済ボタンをクリックして成功する
- [ ] New RelicにAPMデータが表示される
- [ ] New RelicにInfrastructureデータが表示される

## 9. デモ実行

### 正常時の確認
```bash
# ブラウザで http://<ALB_DNS_NAME> を開く
# 「決済を実行」ボタンをクリック
# 成功メッセージが表示されることを確認
```

### 障害モードの有効化
```bash
curl -X POST http://<ALB_DNS_NAME>/admin/failure \
  -H "Content-Type: application/json" \
  -d '{"enable": true}'
```

### 負荷テスト
```bash
cd demo-system/scripts
chmod +x load-test.sh
./load-test.sh <ALB_DNS_NAME> 100
```

## 10. クリーンアップ

```bash
aws cloudformation delete-stack \
  --stack-name newrelic-demo-stack \
  --region ap-northeast-1

# 削除完了を待機
aws cloudformation wait stack-delete-complete \
  --stack-name newrelic-demo-stack \
  --region ap-northeast-1
```
