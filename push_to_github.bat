@echo off
setlocal enabledelayedexpansion

echo ====================================================================
echo   Push Project to GitHub: AWS 2: Becoming a Solutions Architect
echo ====================================================================
echo.

cd /d "%~dp0"

set /p GH_USER="Enter your GitHub username (e.g. itstechn-source): "
if "%GH_USER%"=="" (
    echo [ERROR] GitHub username cannot be empty.
    pause
    exit /b 1
)

set REPO_URL=https://github.com/%GH_USER%/AWS-2-Becoming-a-Solutions-Architect.git

echo.
echo Setting remote origin to: %REPO_URL%
git remote remove origin 2>nul
git remote add origin %REPO_URL%

echo.
echo Pushing branch 'main' to GitHub...
echo (If prompted, click 'Sign in with your browser' in the GitHub window)
echo.

git branch -M main
git push -u origin main

if %errorlevel% equ 0 (
    echo.
    echo ====================================================================
    echo   SUCCESS! Your project has been pushed to:
    echo   https://github.com/%GH_USER%/AWS-2-Becoming-a-Solutions-Architect
    echo ====================================================================
) else (
    echo.
    echo [ERROR] Push failed. Make sure you created the repo on GitHub first:
    echo https://github.com/new (Name: AWS-2-Becoming-a-Solutions-Architect)
)

echo.
pause
