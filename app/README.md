# Payment Demo Service

決済システムのデモアプリケーション

## ファイル構成

```
app/
├── app.js              # メインアプリケーション
├── package.json        # 依存関係定義
├── newrelic.js         # New Relic設定
├── .env.example        # 環境変数サンプル
└── public/
    └── index.html      # フロントエンドUI
```

## ローカル開発

### 1. 依存関係のインストール
```bash
npm install
```

### 2. 環境変数の設定
```bash
cp .env.example .env
# .envファイルを編集してライセンスキーとDB情報を設定
```

### 3. アプリケーション起動
```bash
npm start
```

### 4. ブラウザでアクセス
```
http://localhost:3000
```

## API エンドポイント

### GET /health
ヘルスチェック
```bash
curl http://localhost:3000/health
```

### POST /api/payment
決済処理
```bash
curl -X POST http://localhost:3000/api/payment \
  -H "Content-Type: application/json" \
  -d '{"amount": 1000, "cardNumber": "1234567890123456", "storeId": "STORE001"}'
```

### GET /api/transactions
取引履歴取得
```bash
curl http://localhost:3000/api/transactions
```

### POST /admin/failure
障害モード切替
```bash
# 有効化
curl -X POST http://localhost:3000/admin/failure \
  -H "Content-Type: application/json" \
  -d '{"enable": true}'

# 無効化
curl -X POST http://localhost:3000/admin/failure \
  -H "Content-Type: application/json" \
  -d '{"enable": false}'
```

### POST /admin/slow
スローモード切替
```bash
# 有効化
curl -X POST http://localhost:3000/admin/slow \
  -H "Content-Type: application/json" \
  -d '{"enable": true}'
```

### GET /admin/status
システムステータス確認
```bash
curl http://localhost:3000/admin/status
```

## 障害シミュレーション

### パターン1: タイムアウトエラー
```bash
# 障害モード有効化
curl -X POST http://localhost:3000/admin/failure \
  -H "Content-Type: application/json" \
  -d '{"enable": true}'

# 決済実行（3秒遅延後にエラー）
curl -X POST http://localhost:3000/api/payment \
  -H "Content-Type: application/json" \
  -d '{"amount": 1000, "storeId": "STORE001"}'
```

### パターン2: レスポンス遅延
```bash
# スローモード有効化
curl -X POST http://localhost:3000/admin/slow \
  -H "Content-Type: application/json" \
  -d '{"enable": true}'

# 決済実行（2秒遅延）
curl -X POST http://localhost:3000/api/payment \
  -H "Content-Type: application/json" \
  -d '{"amount": 1000, "storeId": "STORE001"}'
```

## New Relic統合

### APM設定
`newrelic.js`ファイルでAPM設定を管理

### Browser Monitoring
`index.html`の`<head>`タグ内にNew RelicのBrowserスニペットを追加

### カスタムイベント
アプリケーション内で自動的にトランザクションとエラーを記録

## データベーススキーマ

```sql
CREATE TABLE transactions (
  id SERIAL PRIMARY KEY,
  transaction_id VARCHAR(50) UNIQUE NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  card_number VARCHAR(20),
  store_id VARCHAR(20),
  status VARCHAR(20),
  created_at TIMESTAMP DEFAULT NOW()
);
```

## トラブルシューティング

### ポート3000が使用中
```bash
# 別のポートを使用
PORT=3001 npm start
```

### データベース接続エラー
```bash
# 環境変数を確認
echo $DB_HOST
echo $DB_USER

# PostgreSQLの接続テスト
psql -h $DB_HOST -U $DB_USER -d $DB_NAME
```

### New Relicにデータが表示されない
```bash
# ライセンスキーを確認
echo $NEW_RELIC_LICENSE_KEY

# ログを確認
tail -f newrelic_agent.log
```
