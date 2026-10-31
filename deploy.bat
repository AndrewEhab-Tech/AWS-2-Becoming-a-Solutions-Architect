@echo off
echo ========================================================
echo  AWS Serverless Image Processing Pipeline - Deployment
echo ========================================================
echo.

cd /d "%~dp0terraform"

echo [1/3] Initializing Terraform...
terraform init
if %errorlevel% neq 0 (
    echo [ERROR] Terraform initialization failed. Ensure Terraform is installed and in your PATH.
    pause
    exit /b %errorlevel%
)

echo.
echo [2/3] Validating configuration...
terraform validate

echo.
echo [3/3] Applying infrastructure on AWS...
terraform apply -auto-approve
if %errorlevel% neq 0 (
    echo [ERROR] Deployment encountered an error.
    pause
    exit /b %errorlevel%
)

echo.
echo ========================================================
echo  Deployment Completed Successfully!
echo ========================================================
pause
