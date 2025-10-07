@echo off
chcp 65001 >nul
echo.
echo ========================================
echo   New Relic ワークロード デモ制御
echo ========================================
echo.

if "%1"=="" goto :menu

if "%1"=="frontend-error" goto :frontend_error
if "%1"=="frontend-slow" goto :frontend_slow
if "%1"=="frontend-normal" goto :frontend_normal
if "%1"=="backend-error" goto :backend_error
if "%1"=="backend-slow" goto :backend_slow
if "%1"=="backend-normal" goto :backend_normal
if "%1"=="status" goto :status
goto :help

:menu
echo 📱 フロントエンド障害:
echo   1. フロントJS エラー ON
echo   2. フロント遅延 ON  
echo   3. フロント正常化
echo.
echo 🛠️ バックエンド障害:
echo   4. API タイムアウト ON
echo   5. API 遅延 ON
echo   6. API 正常化
echo.
echo 📊 システム:
echo   7. システム状態確認
echo   8. 終了
echo.
set /p choice="選択してください (1-8): "

if "%choice%"=="1" goto :frontend_error
if "%choice%"=="2" goto :frontend_slow
if "%choice%"=="3" goto :frontend_normal
if "%choice%"=="4" goto :backend_error
if "%choice%"=="5" goto :backend_slow
if "%choice%"=="6" goto :backend_normal
if "%choice%"=="7" goto :status
if "%choice%"=="8" goto :end
goto :menu

:frontend_error
echo.
echo 🔴 フロントエンドJSエラーモードを有効にします
echo    ブラウザでJavaScriptエラーが発生します
echo    New Relic Browser Monitoringで確認できます
echo.
pause
goto :menu

:frontend_slow
echo.
echo 🟠 フロントエンド遅延モードを有効にします
echo    ページ読み込みが遅くなります
echo    New Relic Browser Monitoringで確認できます
echo.
pause
goto :menu

:frontend_normal
echo.
echo 🟢 フロントエンドを正常化しました
echo    ブラウザが正常に動作します
echo.
pause
goto :menu

:backend_error
echo.
echo 🔴 APIタイムアウトエラーモードを有効にしています...
curl -s -X POST -H "Content-Type: application/json" -d "{\"enable\":true}" http://localhost:3000/admin/failure
echo.
echo ✅ APIタイムアウトエラーモードが有効になりました
echo    New Relic APMでタイムアウトエラーが確認できます
echo.
pause
goto :menu

:backend_slow
echo.
echo 🟡 API遅延モードを有効にしています...
curl -s -X POST -H "Content-Type: application/json" -d "{\"enable\":true}" http://localhost:3000/admin/slow
echo.
echo ✅ API遅延モードが有効になりました
echo    New Relic APMで処理時間の増加が確認できます
echo.
pause
goto :menu

:backend_normal
echo.
echo 🟢 バックエンドAPIを正常化しています...
curl -s -X POST -H "Content-Type: application/json" -d "{\"enable\":false}" http://localhost:3000/admin/failure
curl -s -X POST -H "Content-Type: application/json" -d "{\"enable\":false}" http://localhost:3000/admin/slow
echo.
echo ✅ バックエンドAPIが正常化されました
echo.
pause
goto :menu

:status
echo.
echo 📊 システム状態を確認しています...
curl -s http://localhost:3000/admin/status
echo.
echo.
pause
goto :menu

:help
echo.
echo 使用方法:
echo   demo-control.bat [コマンド]
echo.
echo コマンド:
echo   frontend-error   フロントエンドJSエラー ON
echo   frontend-slow    フロントエンド遅延 ON
echo   frontend-normal  フロントエンド正常化
echo   backend-error    APIタイムアウト ON
echo   backend-slow     API遅延 ON
echo   backend-normal   バックエンド正常化
echo   status          システム状態確認
echo.
goto :end

:end
echo.
echo デモ制御を終了します
echo.