# escape=`

#
# This Dockerfile is provided for demonstration purposes only and it is not supported by Microsoft
# PHP 7.1 x64 running on IIS
#

FROM mcr.microsoft.com/windows/servercore/iis AS php71

LABEL Author="glzjin <i@zhaoj.in>" Blog="https://www.zhaoj.in"

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

RUN `
    try { `
        # Install PHP `
        Invoke-WebRequest 'https://buu-1251267611.file.myqcloud.com/docker/php-7.1.7-nts-Win32-VC14-x64.zip' -UserAgent '' -OutFile C:\php.zip; `
        Invoke-WebRequest 'https://buu-1251267611.file.myqcloud.com/docker/vc_redist.x64.exe' -UserAgent '' -OutFile C:\vc_redist-x64.exe; `
        Invoke-WebRequest 'https://buu-1251267611.file.myqcloud.com/docker/wincachewpi-2.0.0.8-7.1-nts-vc14-x64.exe' -UserAgent '' -OutFile C:\php_wincache.exe; `
        Expand-Archive -Path c:\php.zip -DestinationPath C:\PHP; `
        `
        # Install PHP Win Cache `
        C:\php_wincache.exe /Q /C "/T:C:\php_wincache_msi"; `
        Start-Process -FilePath msiexec -ArgumentList '/a C:\php_wincache_msi\wincache71x64wpi.msi /qb TARGETDIR=C:\php_wincache_msi\extracted' -NoNewWindow -PassThru -Wait; `
        Copy-Item C:\php_wincache_msi\extracted\PFiles\php_wincache.dll c:\PHP\ext; `
        `
        # Configure PHP `
        Copy-Item C:\PHP\php.ini-production C:\PHP\php.ini; `
    } `
    catch { `
        $_.Exception; `
        $_; `
        exit 1; `
    }

FROM microsoft/iis
 
COPY --from=php71 ["/php/", "/php/"]
COPY --from=php71 ["/vc_redist-x64.exe", "/vc_redist-x64.exe"]

#
# Enable required IIS Features
# Install VC Redist 14
# Configure IIS
# Configure system PATH
#
RUN dism.exe /Online /Enable-Feature /FeatureName:IIS-CGI /All && `
    C:\vc_redist-x64.exe /quiet /install && `
    del C:\vc_redist-x64.exe && `
    %windir%\system32\inetsrv\appcmd.exe set config /section:system.webServer/fastCgi /+[fullPath='c:\PHP\php-cgi.exe'] && `
    %windir%\system32\inetsrv\appcmd.exe set config /section:system.webServer/handlers /+[name='PHP_via_FastCGI',path='*.php',verb='*',modules='FastCgiModule',scriptProcessor='c:\PHP\php-cgi.exe',resourceType='Either'] && `
    %windir%\system32\inetsrv\appcmd.exe set config -section:system.webServer/fastCgi /[fullPath='c:\PHP\php-cgi.exe'].instanceMaxRequests:10000 && `
    %windir%\system32\inetsrv\appcmd.exe set config -section:system.webServer/fastCgi /+[fullPath='c:\PHP\php-cgi.exe'].environmentVariables.[name='PHP_FCGI_MAX_REQUESTS',value='10000'] && `
    %windir%\system32\inetsrv\appcmd.exe set config -section:system.webServer/fastCgi /+[fullPath='c:\PHP\php-cgi.exe'].environmentVariables.[name='PHPRC',value='C:\PHP'] && `
    %windir%\system32\inetsrv\appcmd.exe set config /section:defaultDocument /enabled:true /+files.[value='index.php'] && `
    setx PATH /M %PATH%;C:\PHP && `
    setx PHP /M "C:\PHP" && `
    del C:\inetpub\wwwroot\* /Q

# Optional: Add a starter page
# RUN powershell.exe -Command "'<?php phpinfo(); ?>' | Out-File C:\inetpub\wwwroot\index.php -Encoding UTF8"

#
#ADD any application content and perform any configuration below


WORKDIR /inetpub/wwwroot

COPY ./files/html .

ENTRYPOINT ["powershell", "(icacls 'C:\\inetpub\\wwwroot\\sess' /grant IIS_IUSRS:F /T); (icacls 'C:\\inetpub\\wwwroot\\files' /grant IIS_IUSRS:F /T); ((Get-Content /inetpub/wwwroot/flag.php).replace('flag_here', $env:FLAG) | Set-Content /inetpub/wwwroot/flag.php); (del env:FLAG); (C:\\ServiceMonitor.exe w3svc)"]
