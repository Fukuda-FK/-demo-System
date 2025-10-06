# New Relic デモシステム セットアップガイド

## 概要
このデモシステムは、決済サービスを模擬したシンプルなWebアプリケーションです。
New RelicのAPM、Infrastructure、Browser Monitoringを統合し、ワークロード機能のデモに使用できます。

## システム構成
```
インターネット
    ↓
Application Load Balancer
    ↓
EC2 Auto Scaling Group (2台)
├─ Node.js アプリケーション
├─ New Relic APM Agent
└─ New Relic Infrastructure Agent
    ↓
RDS PostgreSQL (プライベートサブネット)
```

## 前提条件
- AWSアカウント
- AWS CLI設定済み
- New Relicアカウントとライセンスキー
- EC2キーペア作成済み

## デプロイ手順

### 1. New Relicライセンスキーの準備
New Relicアカウントから以下を取得:
- License Key: `Settings > API Keys`

### 2. EC2キーペアの作成（未作成の場合）
```bash
aws ec2 create-key-pair --key-name newrelic-demo-key --query 'KeyMaterial' --output text > newrelic-demo-key.pem
chmod 400 newrelic-demo-key.pem
```

### 3. CloudFormationスタックのデプロイ
```bash
cd demo-system/cloudformation

aws cloudformation create-stack \
  --stack-name newrelic-demo-stack \
  --template-body file://demo-infrastructure.yaml \
  --parameters \
    ParameterKey=NewRelicLicenseKey,ParameterValue=YOUR_LICENSE_KEY \
    ParameterKey=KeyPairName,ParameterValue=newrelic-demo-key \
  --capabilities CAPABILITY_IAM \
  --region ap-northeast-1
```

### 4. デプロイ状況の確認
```bash
aws cloudformation describe-stacks \
  --stack-name newrelic-demo-stack \
  --query 'Stacks[0].StackStatus' \
  --region ap-northeast-1
```

ステータスが `CREATE_COMPLETE` になるまで待機（約10-15分）

### 5. ALBのDNS名を取得
```bash
aws cloudformation describe-stacks \
  --stack-name newrelic-demo-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
  --output text \
  --region ap-northeast-1
```

### 6. アプリケーションの動作確認
```bash
# ヘルスチェック
curl http://<ALB_DNS>/health

# Webページにアクセス
# ブラウザで http://<ALB_DNS> を開く
```

## New Relic設定

### 1. APM設定
各EC2インスタンスにSSH接続して設定:
```bash
ssh -i newrelic-demo-key.pem ec2-user@<EC2_PUBLIC_IP>

# New Relic APM設定ファイル作成
cat > /home/ec2-user/newrelic.js << EOF
'use strict'
exports.config = {
  app_name: ['Payment Demo Service'],
  license_key: 'YOUR_LICENSE_KEY',
  logging: {
    level: 'info'
  },
  distributed_tracing: {
    enabled: true
  }
}
EOF

# アプリケーション再起動
sudo systemctl restart payment-app
```

### 2. Browser Monitoring設定
New Relic UIから:
1. `Browser > Add data` を選択
2. アプリケーション名を入力
3. JavaScriptスニペットをコピー
4. `index.html` の `<head>` タグ内に貼り付け

### 3. Workload作成
New Relic UIから:
1. `Workloads > Create a workload` を選択
2. 名前: `Payment Service Demo`
3. エンティティを追加:
   - APM: `Payment Demo Service`
   - Infrastructure: EC2インスタンス
   - Browser: ブラウザアプリ

## デモシナリオ実行

### シナリオ1: 正常時の監視
```bash
# 負荷テスト実行
cd demo-system/scripts
chmod +x load-test.sh
./load-test.sh <ALB_DNS> 100
```

New Relic Workload画面で確認:
- すべてのコンポーネントが緑色
- 正常なスループットとレスポンスタイム

### シナリオ2: 障害発生シミュレーション
```bash
# 障害モード有効化
chmod +x trigger-failure.sh
./trigger-failure.sh <ALB_DNS>
```

New Relic Workload画面で確認:
- APMが赤色に変化
- エラー率が15%に上昇
- レスポンスタイムが3秒に増加
- インフラは正常（緑色）のまま

### シナリオ3: セッションリプレイ確認
1. ブラウザで `http://<ALB_DNS>` を開く
2. 「Pay Now」ボタンを複数回クリック
3. New Relic Browser画面でセッションリプレイを確認
4. ユーザーの操作とエラー発生を動画で確認

## 障害パターン

### パターン1: API遅延
```bash
curl -X POST http://<ALB_DNS>/admin/failure \
  -H "Content-Type: application/json" \
  -d '{"enable": true}'
```
効果: 決済APIが3秒遅延してタイムアウト

### パターン2: 負荷増加
```bash
./load-test.sh <ALB_DNS> 1000
```
効果: 高負荷によるレスポンス劣化

### パターン3: インスタンス停止
```bash
# Auto Scaling Groupから1台を手動で停止
aws ec2 stop-instances --instance-ids <INSTANCE_ID>
```
効果: 可用性低下とトラフィック集中

## トラブルシューティング

### アプリケーションが起動しない
```bash
# ログ確認
sudo journalctl -u payment-app -f

# 手動起動テスト
cd /home/ec2-user
node app.js
```

### New Relicにデータが表示されない
```bash
# Infrastructure Agentステータス確認
sudo systemctl status newrelic-infra

# ライセンスキー確認
sudo cat /etc/newrelic-infra.yml
```

### ALBヘルスチェック失敗
```bash
# ローカルでヘルスチェック確認
curl http://localhost:3000/health

# セキュリティグループ確認
aws ec2 describe-security-groups --group-ids <SG_ID>
```

## クリーンアップ

### スタック削除
```bash
aws cloudformation delete-stack \
  --stack-name newrelic-demo-stack \
  --region ap-northeast-1
```

### 削除確認
```bash
aws cloudformation describe-stacks \
  --stack-name newrelic-demo-stack \
  --region ap-northeast-1
```

## デモ実演のポイント

### 準備
1. 事前にスタックをデプロイ（10-15分前）
2. New Relic Workloadを作成
3. ブラウザタブを準備:
   - Workload画面
   - APM画面
   - Browser画面
   - Infrastructure画面

### 実演フロー
1. **正常時**: Workload画面で全体が緑色を確認
2. **負荷テスト**: 正常なトラフィックを流す
3. **障害発生**: `trigger-failure.sh` 実行
4. **影響確認**: Workload画面で赤色に変化
5. **詳細分析**: APM画面でエラー詳細確認
6. **ユーザー影響**: セッションリプレイで確認
7. **復旧**: 障害モード無効化
8. **復旧確認**: Workload画面で緑色に戻る

### 強調ポイント
- 一画面で全体状況を把握できる
- 問題箇所が一目で分かる（赤色表示）
- インフラは正常でもアプリに問題がある場合を識別
- セッションリプレイでユーザー体験を確認

## 参考情報

### コスト概算（東京リージョン）
- EC2 t3.small × 2: 約$60/月
- RDS db.t3.micro: 約$15/月
- ALB: 約$20/月
- データ転送: 約$5/月
- **合計**: 約$100/月

### 推奨設定
- デモ後は必ずスタック削除
- 本番環境では適切なインスタンスサイズを選択
- セキュリティグループを適切に設定
- RDSのバックアップを有効化
