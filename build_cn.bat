@echo off
chcp 65001
rmdir /s /q %~dp0\public

del %~dp0\config_bak.yml
copy %~dp0\config.yml %~dp0\config_bak.yml
echo. >> %~dp0\config.yml
echo title: 电脑星人的编程技术分享 >> %~dp0\config.yml
echo baseURL: 'https://kenorizon.cn/' >> %~dp0\config.yml

set HUGO_BUILD_CN=1
hugo

echo User-agent: * > %~dp0\public\robots.txt
echo Disallow: / >> %~dp0\public\robots.txt

del %~dp0\config.yml
copy %~dp0\config_bak.yml %~dp0\config.yml
del %~dp0\config_bak.yml

