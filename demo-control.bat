@echo off
chcp 65001 >nul
echo.
echo ========================================
echo   New Relic ワークロード デモ制御
echo ========================================
echo.

if "%1"=="" goto :menu

if "%1"=="failure-on" goto :failure_on
if "%1"=="failure-off" goto :failure_off
if "%1"=="slow-on" goto :slow_on
if "%1"=="slow-off" goto :slow_off
if "%1"=="status" goto :status
goto :help

:menu
echo 1. 決済エラーモード ON
echo 2. 決済エラーモード OFF
echo 3. スローモード ON
echo 4. スローモード OFF
echo 5. システム状態確認
echo 6. 終了
echo.
set /p choice="選択してください (1-6): "

if "%choice%"=="1" goto :failure_on
if "%choice%"=="2" goto :failure_off
if "%choice%"=="3" goto :slow_on
if "%choice%"=="4" goto :slow_off
if "%choice%"=="5" goto :status
if "%choice%"=="6" goto :end
goto :menu

:failure_on
echo.
echo 🔥 決済エラーモードを有効にしています...
curl -s -X POST -H "Content-Type: application/json" -d "{\"enable\":true}" http://localhost:3000/admin/failure
echo.
echo ✅ 決済エラーモードが有効になりました
echo    次の決済でタイムアウトエラーが発生します
echo.
pause
goto :menu

:failure_off
echo.
echo ✅ 決済エラーモードを無効にしています...
curl -s -X POST -H "Content-Type: application/json" -d "{\"enable\":false}" http://localhost:3000/admin/failure
echo.
echo ✅ 決済エラーモードが無効になりました
echo    決済が正常に動作します
echo.
pause
goto :menu

:slow_on
echo.
echo 🐌 スローモードを有効にしています...
curl -s -X POST -H "Content-Type: application/json" -d "{\"enable\":true}" http://localhost:3000/admin/slow
echo.
echo ✅ スローモードが有効になりました
echo    決済処理が2秒遅くなります
echo.
pause
goto :menu

:slow_off
echo.
echo ⚡ スローモードを無効にしています...
curl -s -X POST -H "Content-Type: application/json" -d "{\"enable\":false}" http://localhost:3000/admin/slow
echo.
echo ✅ スローモードが無効になりました
echo    決済処理が通常速度に戻ります
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
echo   failure-on   決済エラーモード ON
echo   failure-off  決済エラーモード OFF
echo   slow-on      スローモード ON
echo   slow-off     スローモード OFF
echo   status       システム状態確認
echo.
goto :end

:end
echo.
echo デモ制御を終了します
echo.