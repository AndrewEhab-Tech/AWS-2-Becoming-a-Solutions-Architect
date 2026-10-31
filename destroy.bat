@echo off
echo ========================================================
echo  AWS Serverless Image Processing Pipeline - Teardown
echo ========================================================
echo.
echo WARNING: This will delete all provisioned AWS resources.
echo.
set /p confirm="Are you sure you want to destroy all resources? (y/N): "
if /i not "%confirm%"=="y" (
    echo Destruction cancelled.
    pause
    exit /b 0
)

cd /d "%~dp0terraform"
terraform destroy -auto-approve
echo.
echo ========================================================
echo  All resources have been deleted cleanly.
echo ========================================================
pause
