require('newrelic');
const express = require('express');
const { Pool } = require('pg');
const path = require('path');

const app = express();
const port = process.env.PORT || 3000;

// Database connection
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'payment_demo',
  user: process.env.DB_USER || 'dbadmin',
  password: process.env.DB_PASSWORD || 'DemoPassword123!',
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
  ssl: false
});

// Middleware
app.use(express.json());
app.use(express.static('public'));

// Global failure mode flag
let failureMode = false;
let slowMode = false;

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Home page
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Payment API - Main business logic
app.post('/api/payment', async (req, res) => {
  const startTime = Date.now();
  const { amount, cardNumber, storeId } = req.body;

  // Log payment attempt for demo purposes
  console.log(`💳 Payment attempt: ¥${amount} at ${storeId} [Failure: ${failureMode}, Slow: ${slowMode}]`);

  try {
    // Simulate failure mode with more realistic timeout
    if (failureMode) {
      await new Promise(resolve => setTimeout(resolve, 3000));
      console.log('❌ Payment failed due to failure mode');
      return res.status(500).json({
        error: 'Payment gateway timeout',
        message: '外部決済サービスとの通信がタイムアウトしました',
        errorCode: 'GATEWAY_TIMEOUT',
        timestamp: new Date().toISOString()
      });
    }

    // Validate input
    if (!amount || amount <= 0) {
      return res.status(400).json({ 
        error: 'Invalid amount',
        message: '決済金額が無効です'
      });
    }

    // Simulate external payment gateway call (includes slow mode logic)
    await simulateExternalPaymentGateway(amount);

    // Save transaction to database
    const transactionId = await saveTransaction(amount, cardNumber, storeId);

    const processingTime = Date.now() - startTime;
    console.log(`✅ Payment successful: ${transactionId} (${processingTime}ms)`);

    res.json({
      success: true,
      transactionId,
      amount,
      storeId,
      processingTime,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    const processingTime = Date.now() - startTime;
    console.error(`❌ Payment error (${processingTime}ms):`, error.message);
    res.status(500).json({
      error: 'Payment processing failed',
      message: error.message,
      processingTime,
      timestamp: new Date().toISOString()
    });
  }
});

// Get transaction history
app.get('/api/transactions', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM transactions ORDER BY created_at DESC LIMIT 50'
    );
    res.json({ transactions: result.rows });
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

// Database connection test
app.get('/api/db-test', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW() as current_time, version() as db_version');
    const countResult = await pool.query('SELECT COUNT(*) as total FROM transactions');
    res.json({
      status: 'connected',
      currentTime: result.rows[0].current_time,
      dbVersion: result.rows[0].db_version,
      totalTransactions: countResult.rows[0].total,
      connectionInfo: {
        host: process.env.DB_HOST,
        database: process.env.DB_NAME,
        user: process.env.DB_USER
      }
    });
  } catch (error) {
    console.error('Database test error:', error);
    res.status(500).json({
      status: 'error',
      error: error.message,
      connectionInfo: {
        host: process.env.DB_HOST,
        database: process.env.DB_NAME,
        user: process.env.DB_USER
      }
    });
  }
});

// Execute custom SQL query (for testing only)
app.post('/api/db-query', async (req, res) => {
  const { query } = req.body;
  
  if (!query) {
    return res.status(400).json({ error: 'Query is required' });
  }
  
  // Only allow SELECT queries for safety
  if (!query.trim().toUpperCase().startsWith('SELECT')) {
    return res.status(400).json({ error: 'Only SELECT queries are allowed' });
  }
  
  try {
    const result = await pool.query(query);
    res.json({
      success: true,
      rowCount: result.rowCount,
      rows: result.rows
    });
  } catch (error) {
    console.error('Query execution error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Admin endpoint - Enable/disable failure mode
app.post('/admin/failure', (req, res) => {
  failureMode = req.body.enable === true;
  const status = failureMode ? 'enabled' : 'disabled';
  const emoji = failureMode ? '🔥' : '✅';
  console.log(`${emoji} Failure mode ${status}`);
  res.json({
    failureMode,
    message: `決済エラーモードが${failureMode ? '有効' : '無効'}になりました`,
    timestamp: new Date().toISOString()
  });
});

// Admin endpoint - Enable/disable slow mode
app.post('/admin/slow', (req, res) => {
  slowMode = req.body.enable === true;
  console.log(`Slow mode ${slowMode ? 'enabled' : 'disabled'}`);
  res.json({
    slowMode,
    message: `Slow mode ${slowMode ? 'enabled' : 'disabled'}`,
    timestamp: new Date().toISOString()
  });
});

// Admin endpoint - Get current status
app.get('/admin/status', async (req, res) => {
  let dbStatus = 'unknown';
  let transactionCount = 0;
  try {
    await pool.query('SELECT 1');
    const countResult = await pool.query('SELECT COUNT(*) as total FROM transactions');
    dbStatus = 'connected';
    transactionCount = countResult.rows[0].total;
  } catch (error) {
    dbStatus = 'disconnected';
  }
  
  res.json({
    failureMode,
    slowMode,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    database: dbStatus,
    transactionCount,
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
    version: '1.0.0'
  });
});

// Demo endpoint - Reset all modes
app.post('/admin/reset', (req, res) => {
  failureMode = false;
  slowMode = false;
  console.log('All demo modes reset to normal');
  res.json({
    message: 'All modes reset to normal',
    failureMode: false,
    slowMode: false,
    timestamp: new Date().toISOString()
  });
});

// Demo endpoint - Simulate database error
app.post('/admin/db-error', (req, res) => {
  const { enable } = req.body;
  // This would simulate database connectivity issues
  // For demo purposes, we'll just return a status
  res.json({
    message: `Database error simulation ${enable ? 'enabled' : 'disabled'}`,
    timestamp: new Date().toISOString()
  });
});

// Demo endpoint - Get demo statistics
app.get('/admin/demo-stats', async (req, res) => {
  try {
    const recentTransactions = await pool.query(
      'SELECT COUNT(*) as count, AVG(amount) as avg_amount FROM transactions WHERE created_at > NOW() - INTERVAL \'1 hour\''
    );
    const errorRate = failureMode ? 100 : (Math.random() * 5); // 0-5% normal error rate
    
    res.json({
      recentTransactions: recentTransactions.rows[0].count || 0,
      averageAmount: parseFloat(recentTransactions.rows[0].avg_amount || 0),
      errorRate: Math.round(errorRate * 100) / 100,
      responseTime: slowMode ? 2000 : Math.floor(Math.random() * 500) + 100,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      error: 'Failed to get demo statistics',
      message: error.message
    });
  }
});

// Simulate external payment gateway
async function simulateExternalPaymentGateway(amount) {
  // Random delay between 100-500ms (unless in slow mode)
  const baseDelay = Math.floor(Math.random() * 400) + 100;
  const delay = slowMode ? baseDelay + 1500 : baseDelay; // Add 1.5s in slow mode
  
  await new Promise(resolve => setTimeout(resolve, delay));

  // Simulate occasional gateway errors (5% chance in normal mode)
  const errorRate = failureMode ? 1.0 : 0.05; // 100% error in failure mode, 5% normally
  if (Math.random() < errorRate) {
    const errorMessages = [
      'External payment gateway timeout',
      'Payment service unavailable',
      'Network connection failed',
      'Gateway authentication failed'
    ];
    const randomError = errorMessages[Math.floor(Math.random() * errorMessages.length)];
    throw new Error(randomError);
  }

  return true;
}

// Save transaction to database
async function saveTransaction(amount, cardNumber, storeId) {
  const transactionId = `TXN${Date.now()}${Math.floor(Math.random() * 1000)}`;
  const maskedCard = cardNumber ? `****${cardNumber.slice(-4)}` : '****0000';

  try {
    await pool.query(
      'INSERT INTO transactions (transaction_id, amount, card_number, store_id, status, created_at) VALUES ($1, $2, $3, $4, $5, NOW())',
      [transactionId, amount, maskedCard, storeId || 'STORE001', 'completed']
    );
    return transactionId;
  } catch (error) {
    console.error('Database insert error:', error);
    // Return transaction ID even if DB insert fails
    return transactionId;
  }
}

// Initialize database
async function initializeDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS transactions (
        id SERIAL PRIMARY KEY,
        transaction_id VARCHAR(50) UNIQUE NOT NULL,
        amount DECIMAL(10, 2) NOT NULL,
        card_number VARCHAR(20),
        store_id VARCHAR(20),
        status VARCHAR(20),
        created_at TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('Database initialized successfully');
  } catch (error) {
    console.error('Database initialization error:', error);
  }
}

// Start server
app.listen(port, async () => {
  console.log('========================================');
  console.log('  New Relic ワークロード デモシステム');
  console.log('========================================');
  console.log(`🚀 Payment Demo Service running on port ${port}`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔗 URL: http://localhost:${port}`);
  console.log(`🔧 Admin: http://localhost:${port}/#admin`);
  console.log('========================================');
  console.log('📋 デモ制御コマンド:');
  console.log('   demo-control.bat failure-on   # 障害発生');
  console.log('   demo-control.bat failure-off  # 障害復旧');
  console.log('   demo-control.bat status       # 状態確認');
  console.log('========================================');
  await initializeDatabase();
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, closing server...');
  pool.end();
  process.exit(0);
});
