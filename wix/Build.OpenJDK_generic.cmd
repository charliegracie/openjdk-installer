@ECHO OFF

REM Set version numbers and build option here if being run manually:
SET PRODUCT_MAJOR_VERSION=8
SET PRODUCT_MINOR_VERSION=1
SET PRODUCT_MAINTENANCE_VERSION=202
SET PRODUCT_PATCH_VERSION=08
SET ARCH=x64
SET JVM=openj9
SET PRODUCT_CATEGORY=jdk

SETLOCAL ENABLEEXTENSIONS
SET ERR=0
IF NOT DEFINED PRODUCT_MAJOR_VERSION SET ERR=1
IF NOT DEFINED PRODUCT_MINOR_VERSION SET ERR=2
IF NOT DEFINED PRODUCT_MAINTENANCE_VERSION SET ERR=3
IF NOT DEFINED PRODUCT_PATCH_VERSION SET ERR=4
IF NOT DEFINED ARCH SET ERR=5
IF NOT DEFINED JVM SET ERR=6
IF NOT DEFINED PRODUCT_CATEGORY SET ERR=7
IF NOT %ERR% == 0 ( echo Missing args/variable ERR:%ERR% && GOTO FAILED )

IF NOT "%ARCH%" == "x64" (
	IF NOT "%ARCH%" == "x86" (
		IF NOT "%ARCH%" == "x86 x64" (
			IF NOT "%ARCH%" == "x64 x86" (
				ECHO ARCH %ARCH% not supported : valid values : x86, x64, x86 x64, x64 x86
				GOTO FAILED
			)
		)
	)
)

IF NOT "%JVM%" == "hotspot" (
	IF NOT "%JVM%" == "openj9" (
		IF NOT "%JVM%" == "openj9 hotspot" (
			IF NOT "%JVM%" == "hotspot openj9" (
				ECHO JVM "%JVM%" not supported : valid values : hotspot, openj9, hotspot openj9, openj9 hotspot
				GOTO FAILED
			)
		)
	)
)

IF NOT "%PRODUCT_CATEGORY%" == "jre" (
	IF NOT "%PRODUCT_CATEGORY%" == "jdk" (
		ECHO PRODUCT_CATEGORY "%PRODUCT_CATEGORY%" not supported : valid values : jre, jdk
		GOTO FAILED
	)
)



REM Configure available SDK version:
REM See folder e.g. "C:\Program Files (x86)\Windows Kits\[10]\bin\[10.0.16299.0]\x64"
SET WIN_SDK_MAJOR_VERSION=10
SET WIN_SDK_FULL_VERSION=10.0.17763.0

REM
REM Nothing below this line need to be changed normally.
REM

REM Cultures: https://msdn.microsoft.com/de-de/library/ee825488(v=cs.20).aspx
SET PRODUCT_SKU=OpenJDK
SET PRODUCT_VERSION=%PRODUCT_MAJOR_VERSION%.%PRODUCT_MINOR_VERSION%.%PRODUCT_MAINTENANCE_VERSION%.%PRODUCT_PATCH_VERSION%
SET ICEDTEAWEB_DIR=.\SourceDir\icedtea-web-image


REM Generate platform specific builds (x86,x64)
SETLOCAL ENABLEDELAYEDEXPANSION
FOR %%G IN (%ARCH%) DO (
  REM We could build both "hotspot,openj9" in one script, but it is not clear if release cycle is the same.
  FOR %%H IN (%JVM%) DO (
    ECHO Generate OpenJDK setup "%%H" for "%%G" platform
    ECHO ****************************************************
    SET CULTURE=en-us
    SET LANGIDS=1033
    SET PLATFORM=%%G
    SET PACKAGE_TYPE=%%H
    SET SETUP_RESOURCES_DIR=.\Resources
	IF !PRODUCT_MAJOR_VERSION! == 11 (
			SET REPRO_DIR=.\SourceDir\!PRODUCT_SKU!!PRODUCT_MAJOR_VERSION!\!PACKAGE_TYPE!\!PLATFORM!\jdk-%PRODUCT_MAJOR_VERSION%+%PRODUCT_PATCH_VERSION%
		)
	IF !PRODUCT_MAJOR_VERSION! == 8 (
		SET REPRO_DIR=.\SourceDir\!PRODUCT_SKU!!PRODUCT_MAJOR_VERSION!\!PACKAGE_TYPE!\!PLATFORM!\jdk%PRODUCT_MAJOR_VERSION%u%PRODUCT_MAINTENANCE_VERSION%-b%PRODUCT_PATCH_VERSION%
	)
	IF !PRODUCT_CATEGORY! == jre (
	    SET REPRO_DIR=!REPRO_DIR!-!PRODUCT_CATEGORY!
	)
    SET OUTPUT_BASE_FILENAME=!PRODUCT_SKU!!PRODUCT_MAJOR_VERSION!-!PRODUCT_CATEGORY!_!PLATFORM!_windows_!PACKAGE_TYPE!-!PRODUCT_VERSION!
    SET CACHE_BASE_FOLDER=Cache
    REM Each build his own cache for concurrent build
    SET CACHE_FOLDER=!CACHE_BASE_FOLDER!\!OUTPUT_BASE_FILENAME!

    REM Generate one ID per release. But do NOT use * as we need to keep the same number for all languages, but not platforms.
    FOR /F %%I IN ('POWERSHELL -COMMAND "$([guid]::NewGuid().ToString('b').ToUpper())"') DO (
      SET PRODUCT_ID=%%I
      ECHO PRODUCT_ID: !PRODUCT_ID!
    )
    FOR /F %%F IN ('POWERSHELL -COMMAND "$([guid]::NewGuid().ToString('b').ToUpper())"') DO (
      SET PRODUCT_UPGRADE_CODE=%%F
      ECHO PRODUCT_UPGRADE_CODE: !PRODUCT_UPGRADE_CODE!
    )

    REM Prevent concurrency issues if multiple builds are running in parallel.
	ECHO copy "Main.!PACKAGE_TYPE!.wxs"
    COPY /Y "Main.!PACKAGE_TYPE!.wxs" "Main-!OUTPUT_BASE_FILENAME!.wxs"

    REM Build with extra Source Code feature (needs work)
    REM "!WIX!bin\heat.exe" file "!REPRO_DIR!\lib\src.zip" -out Src-!OUTPUT_BASE_FILENAME!.wxs -gg -srd -cg "SrcFiles" -var var.ReproDir -dr INSTALLDIR -platform !PLATFORM!
    REM "!WIX!bin\heat.exe" dir "!REPRO_DIR!" -out Files-!OUTPUT_BASE_FILENAME!.wxs -t "!SETUP_RESOURCES_DIR!\heat.tools.xslt" -gg -sfrag -scom -sreg -srd -ke -cg "AppFiles" -var var.ProductMajorVersion -var var.ProductMinorVersion -var var.ProductMaintenanceVersion -var var.ProductPatchVersion -var var.ReproDir -dr INSTALLDIR -platform !PLATFORM!
    REM "!WIX!bin\candle.exe" -arch !PLATFORM! Main-!OUTPUT_BASE_FILENAME!.wxs Files-!OUTPUT_BASE_FILENAME!.wxs Src-!OUTPUT_BASE_FILENAME!.wxs -ext WixUIExtension -ext WixUtilExtension -dProductSku="!PRODUCT_SKU!" -dProductMajorVersion="!PRODUCT_MAJOR_VERSION!" -dProductMinorVersion="!PRODUCT_MINOR_VERSION!" -dProductMaintenanceVersion="!PRODUCT_MAINTENANCE_VERSION!" -dProductPatchVersion="!PRODUCT_PATCH_VERSION!" -dProductId="!PRODUCT_ID!" -dReproDir="!REPRO_DIR!" -dSetupResourcesDir="!SETUP_RESOURCES_DIR!" -dCulture="!CULTURE!"
    REM "!WIX!bin\light.exe" Main-!OUTPUT_BASE_FILENAME!.wixobj Files-!OUTPUT_BASE_FILENAME!.wixobj Src-!OUTPUT_BASE_FILENAME!.wixobj -cc !CACHE_FOLDER! -ext WixUIExtension -ext WixUtilExtension -spdb -out "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi" -loc "Lang\!PRODUCT_SKU!.Base.!CULTURE!.wxl" -loc "Lang\!PRODUCT_SKU!.!PACKAGE_TYPE!.!CULTURE!.wxl" -cultures:!CULTURE!

    REM Clean .cab cache for each run .. Cache is only used inside BuildSetupTranslationTransform.cmd to speed up MST generation
    IF EXIST !CACHE_FOLDER! rmdir /S /Q !CACHE_FOLDER!
    MKDIR !CACHE_FOLDER!
	IF ERRORLEVEL 1 (
		echo "Unable to create cache folder : !CACHE_FOLDER!"
	    GOTO FAILED
	)

	ECHO HEAT
    "!WIX!bin\heat.exe" dir "!ICEDTEAWEB_DIR!" -out Files-IcedTeaWeb.wxs -t "!SETUP_RESOURCES_DIR!\heat.icedteaweb.xslt" -gg -sfrag -scom -sreg -srd -ke -cg "IcedTeaWebFiles" -var var.IcedTeaWebDir -dr INSTALLDIR -platform !PLATFORM!
    IF ERRORLEVEL 1 (
        ECHO "Failed to generating Windows Installer XML Source files for IcedTea-Web (.wxs)"
        GOTO FAILED
    )

    REM Build AdoptOpenJDK without extra Source Code feature
	ECHO HEAT
    "!WIX!bin\heat.exe" dir "!REPRO_DIR!" -out Files-!OUTPUT_BASE_FILENAME!.wxs -gg -sfrag -scom -sreg -srd -ke -cg "AppFiles" -var var.ProductMajorVersion -var var.ProductMinorVersion -var var.ProductMaintenanceVersion -var var.ProductPatchVersion -var var.ReproDir -dr INSTALLDIR -platform !PLATFORM!
	IF ERRORLEVEL 1 (
		ECHO "Failed to generating Windows Installer XML Source files (.wxs)"
	    GOTO FAILED
	)
	ECHO CANDLE
    "!WIX!bin\candle.exe" -arch !PLATFORM! Main-!OUTPUT_BASE_FILENAME!.wxs Files-!OUTPUT_BASE_FILENAME!.wxs Files-IcedTeaWeb.wxs -ext WixUIExtension -ext WixUtilExtension -dIcedTeaWebDir="!ICEDTEAWEB_DIR!" -dProductSku="!PRODUCT_SKU!" -dProductMajorVersion="!PRODUCT_MAJOR_VERSION!" -dProductMinorVersion="!PRODUCT_MINOR_VERSION!" -dProductMaintenanceVersion="!PRODUCT_MAINTENANCE_VERSION!" -dProductPatchVersion="!PRODUCT_PATCH_VERSION!" -dProductId="!PRODUCT_ID!" -dProductUpgradeCode="!PRODUCT_UPGRADE_CODE!" -dReproDir="!REPRO_DIR!" -dSetupResourcesDir="!SETUP_RESOURCES_DIR!" -dCulture="!CULTURE!"
	IF ERRORLEVEL 1 (
	    ECHO "Failed to preprocesses and compiles WiX source files into object files (.wixobj)"
	    GOTO FAILED
	)
	ECHO "LIGHT"
    "!WIX!bin\light.exe" Main-!OUTPUT_BASE_FILENAME!.wixobj Files-!OUTPUT_BASE_FILENAME!.wixobj Files-IcedTeaWeb.wixobj -cc !CACHE_FOLDER! -sval -ext WixUIExtension -ext WixUtilExtension -spdb -out "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi" -loc "Lang\!PRODUCT_SKU!.Base.!CULTURE!.wxl" -loc "Lang\!PRODUCT_SKU!.!PACKAGE_TYPE!.!CULTURE!.wxl" -cultures:!CULTURE!
	IF ERRORLEVEL 1 (
	    ECHO "Failed to links and binds one or more .wixobj files and creates a Windows Installer database (.msi or .msm)"
	    GOTO FAILED
	)

    REM Generate setup translations
    CALL BuildSetupTranslationTransform.cmd de-de 1031
	IF ERRORLEVEL 1 (
	    GOTO FAILED
	)
    CALL BuildSetupTranslationTransform.cmd es-es 3082
	IF ERRORLEVEL 1 (
	    GOTO FAILED
	)
    CALL BuildSetupTranslationTransform.cmd fr-fr 1036
	IF ERRORLEVEL 1 (
	    GOTO FAILED
	)
    REM CALL BuildSetupTranslationTransform.cmd it-it 1040
	REM IF ERRORLEVEL 1 (
	REM     GOTO FAILED
	REM )
    CALL BuildSetupTranslationTransform.cmd ja-jp 1041
	IF ERRORLEVEL 1 (
	    GOTO FAILED
	)
    REM CALL BuildSetupTranslationTransform.cmd ko-kr 1042
	REM IF ERRORLEVEL 1 (
	REM     GOTO FAILED
	REM )
    REM CALL BuildSetupTranslationTransform.cmd ru-ru 1049
	REM IF ERRORLEVEL 1 (
	REM     GOTO FAILED
	REM )
    CALL BuildSetupTranslationTransform.cmd zh-cn 2052
	IF ERRORLEVEL 1 (
	    GOTO FAILED
	)
    CALL BuildSetupTranslationTransform.cmd zh-tw 1028
	IF ERRORLEVEL 1 (
	    GOTO FAILED
	)


    REM To validate MSI only once at the end
    "!WIX!bin\smoke.exe" "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi"
    IF ERRORLEVEL 1 (
		ECHO Failed to validate MSI
	    GOTO FAILED
	)
    REM Add all supported languages to MSI Package attribute
    CSCRIPT "%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_MAJOR_VERSION%\bin\%WIN_SDK_FULL_VERSION%\x64\WiLangId.vbs" ReleaseDir\!OUTPUT_BASE_FILENAME!.msi Package !LANGIDS!
    IF ERRORLEVEL 1 (
		ECHO Failed to pack all languages into MSI : !LANGIDS!
	    GOTO FAILED
	)

    REM SIGN the MSIs with digital signature.
    REM Dual-Signing with SHA-1/SHA-256 requires Win 8.1 SDK or later.
    "%ProgramFiles(x86)%\Windows Kits\8.1\bin\x64\signtool.exe" sign -f "%SIGNING_CERTIFICATE%" -p "%SIGN_PASSWORD%" -fd sha1 -d "AdoptOpenJDK" -t http://timestamp.verisign.com/scripts/timstamp.dll "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi"
    IF ERRORLEVEL 1 (
	    ECHO Failed to sign with SHA1
	    GOTO FAILED
	)
    "%ProgramFiles(x86)%\Windows Kits\8.1\bin\x64\signtool.exe" sign -f "%SIGNING_CERTIFICATE%" -p "%SIGN_PASSWORD%" -fd sha256 -d "AdoptOpenJDK" -t http://timestamp.verisign.com/scripts/timstamp.dll "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi"
    IF ERRORLEVEL 1 (
        ECHO Failed to sign with SHA256
	    GOTO FAILED
	)
	
    REM Remove files we do not need any longer.
    DEL "Files-!OUTPUT_BASE_FILENAME!.wxs"
    DEL "Files-!OUTPUT_BASE_FILENAME!.wixobj"
    DEL "Main-!OUTPUT_BASE_FILENAME!.wxs"
    DEL "Main-!OUTPUT_BASE_FILENAME!.wixobj"
    DEL "Files-IcedTeaWeb.wxs"
    DEL "FilesIcedTeaWeb.wixobj"
    RMDIR /S /Q !CACHE_FOLDER!
  )
)
ENDLOCAL

REM Cleanup variables
SET CULTURE=
SET LANGIDS=
SET OUTPUT_BASE_FILENAME=
SET PACKAGE_TYPE=
SET PRODUCT_CATEGORY=
SET PRODUCT_SKU=
SET PRODUCT_MAJOR_VERSION=
SET PRODUCT_MINOR_VERSION=
SET PRODUCT_MAINTENANCE_VERSION=
SET PRODUCT_PATCH_VERSION=
SET PRODUCT_ID=
SET PRODUCT_VERSION=
SET PLATFORM=
SET REPRO_DIR=
SET ICEDTEAWEB_DIR=
SET SETUP_RESOURCES_DIR=
SET WIN_SDK_FULL_VERSION=
SET WIN_SDK_MAJOR_VERSION=

EXIT /b 0

:FAILED
EXIT /b 2


