@echo off
REM 1:Check Connection with server
REM Log File name generation - Start
set logMvdir=D:\Programs\FormsLettersTemplate\Log
REM Get log file name
set logFileName=""
set logdt=%DATE:~10,4%-%DATE:~4,2%-%DATE:~7,2%
set logdt=%logdt: =0%
call:funcLogFileNameConstruct %logFileName%
echo %logFileName%
REM Log File name generation - End
REM max. reconnect count
set /A maxretry=2
set /A conntry=0
set /A retryintvl=10
set mmdd=%DATE:~4,2%%DATE:~7,2%
cd C:\Windows\System32\WindowsPowerShell\v1.0
set homedir=D:\Programs\FormsLettersTemplate
:CheckConnect
start /w powershell -command "Test-NetConnection -ComputerName 10.147.120.32 -Port 22 > %homedir%\%mmdd%connstat.tmp" 
REM %mmdd%connstat.tmp will have ascii characters from powershell and to remove that copying the file into new txt.
type %homedir%\%mmdd%connstat.tmp > %homedir%\%mmdd%connstatcp.tmp
>%homedir%\%mmdd%connvalue.tmp c:\windows\SysWOW64\findstr /C:"TcpTestSucceeded : True" %homedir%\%mmdd%connstatcp.tmp
for /f %%i in ("%homedir%\%mmdd%connvalue.tmp") do set size=%%~zi
if %size% gtr 0 (
    call:funcMsgToLog "SUCCESS Have connection and will continue the process."
) else (   
                set /A conntry+=1
                if %conntry% LSS %maxretry% (
                                call:funcMsgToLog "FAILURE Have NOT connected. connection retrying..%conntry%"
                                timeout /t %retryintvl% /nobreak > NUL
                                goto CheckConnect 
                ) else (
                                call:funcMsgToLog "ERROR Could NOT connected to 10.147.120.32:22. Tried max reconnection done and Exit the process."
                                exit /b
                )
)
del %homedir%\%mmdd%conn*.tmp
REM 2:Files' Count validation will be done here..
REM PDF Export folder
set pdfdir="\\znwwbcdq06300v\CognitiveClaims\Export"
REM The folder, where this script is placed
set currdir="D:\Programs\FormsLettersTemplate"
REM log files, which would be generated on OCR process
set logdir=\\caawa00643\FormLetterExportQA2\log
REM Delay in Seconds to look for 'pdfdir' folder
set delayInSec=10
REM Current Date in YYYYMMDD format for log file
REM %DATE:~10,4%%DATE:~4,2%%DATE:~7,2%
echo %dayminus:~10,4%%dayminus:~4,2%%dayminus:~7,2%
set dt=%dayminus:~10,4%%dayminus:~4,2%%dayminus:~7,2%
set dt=%dt: =0%
REM Get (.Net component) log file name
pushd %logdir%
del %currdir%\latestfile.tmp
for /f "tokens=*" %%a in ('dir /b /od') do set newest=%%a
copy "%newest%" %currdir%\latestfile.tmp
popd
echo "%newest%"
set yourExt=%newest%
REM pushd %logdir%
for %%a in (%yourExt%) do set fileName=%%a
call:funcMsgToLog "INFO Log(.Net Component) file name..%fileName%"
REM Search 'Total Results:' on the file
set /A maxRetryForPdf=2
set /A retryCount=0
:LoopToReadLog
pushd %logdir%
cd %logdir%
>%logMvdir%\count.tmp c:\windows\SysWOW64\findstr /c:"File Created:" %fileName%
<%logMvdir%\count.tmp set /p "countInLog="
DEL %logMvdir%\count.tmp
del %currdir%\latestfile.tmp
popd
REM 
set "x=%countInLog:File Created:=" & set "trimspace=%"
REM Trailing Spaces
set "countInLog=%trimspace: =%"
call:funcMsgToLog "INFO Pdf Files count in the log file..%countInLog%"
if "%countInLog%" == " =" (
   if %retryCount% LSS %maxRetryForPdf% (
		set /A retryCount+=1
		call:funcMsgToLog "INFO Re-read the Log(.Net Component) file for checking PDF files count..%retryCount%"
		timeout /t %delayInSec% /nobreak > NUL
		goto LoopToReadLog                     
   ) else (
		call:funcMsgToLog "ERROR .NET Log file is not having Pdf files count."
		cd %currdir%
		exit /b
   )
)
rem
cd %pdfdir%

set filePattern="FRMTMPL_*.pdf"
set /A maxRetryForPdf=5
set /A retryCount=0
REM loop to get total no. of pdfs 
:Loop
pushd %pdfdir%
for /f %%A in ('dir %filePattern% ^| c:\Windows\SysWOW64\find "File(s)"') do set cntInDir=%%A
call:funcMsgToLog "INFO Total pdf file in Export folder..%cntInDir%"
popd
if not %cntInDir%==%countInLog% (
   if %retryCount% LSS %maxRetryForPdf% (
                                set /A retryCount+=1
                                timeout /t %delayInSec% /nobreak > NUL
                                call:funcMsgToLog "INFO Rechecking PDF files count on Export folder..%retryCount%"
                                goto Loop                            
   ) else (
								call:funcMsgToLog "INFO The Directory - %pdfdir% has '%cntInDir% files'."
								call:funcMsgToLog "INFO Log File - %logdir%\%fileName% file has '%countInLog%' count."
								call:funcMsgToLog "ERROR ** The PDF files' counts are not matching between the Export folder and in the log file."
								call:funcMsgToLog "ERROR The process got **STOPPED**."
                                cd %currdir%
                                exit /b
   )
) else (
   REM delete old files from backup folder
   cd D:\CognitiveClaims\Export\backup
   DEL /F/Q/S *. * > NUL
   REM copy the files to backup folder
   cd D:\CognitiveClaims\Export
   copy *.pdf D:\CognitiveClaims\Export\backup

   call:funcMsgToLog "SUCCESS Pdf Files count validation done."
   call:funcMsgToLog "INFO Pdf Files movement Process starts."
   cd %currdir%
   :LoopNFS
   REM 3.PDF Files movement Process
   "C:\Program Files (x86)\WinSCP\WinSCP.com" /ini=nul /script=%homedir%\PdfFilesUpload.script
    REM Check .PDF file Counts in NFS Folder
   "C:\Program Files (x86)\WinSCP\WinSCP.com" /command "open k8node" "ls /devopsshare-np/app/claimselk/data/fscrawler-qa/CognitiveClaims/Export/IN/" "exit"|c:\windows\SysWOW64\find /c ".pdf" > %homedir%\nfscount.tmp
   <%homedir%\nfscount.tmp set /p "cntInNFS="
   call:funcMsgToLog "INFO Pdf Files count in NFS Mount Folder.. %cntInNFS%"
   del %homedir%\nfscount.tmp
   echo %cntInNFS%
   set /A cntInNFS=%cntInNFS%
   
   if not %cntInDir%==%cntInNFS% (
		if %retryCount% LSS %maxRetryForPdf% (
			set /A retryCount+=1
			timeout /t %delayInSec% /nobreak > NUL
			call:funcMsgToLog "INFO Rechecking PDF files count in NFS Mount folder..%retryCount%"
			goto LoopNFS
		) else (
			call:funcMsgToLog "INFO Total pdf file in Export folder..%cntInDir%"
			call:funcMsgToLog "INFO The NFS mount Folder(../CognitiveClaims/Export/IN/) has '%cntInNFS% files'."
			call:funcMsgToLog "ERROR ** The PDF files' counts are not matching between the Export and NFS folders."
			call:funcMsgToLog "ERROR The process got **STOPPED**."
			cd %currdir%
			exit /b
		)
   ) else (
		call:funcMsgToLog "INFO Total pdf file in Export folder..%cntInDir%"
		call:funcMsgToLog "INFO The NFS mount Folder(../CognitiveClaims/Export/IN/) has '%cntInNFS% files'."
		call:funcMsgToLog "SUCCESS The PDF files' counts are same between the Export and NFS folders."
   )
)



goto:eof
REM 4.Process End.

REM Function to log Messages
:funcMsgToLog
set logtm=%TIME: =0%
echo %logdt% %logtm% %~1
echo %logdt% %logtm% %~1 >> %logFileName%
goto:eof

REM Function to construct log file name for PDFs movement
:funcLogFileNameConstruct
set dtfname=%DATE:~10,4%%DATE:~4,2%%DATE:~7,2%
set dtfname=%dtfname: =0%
set tmfname=%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set tmfname=%tmfname: =0%
set logFileName=%logMvdir%\PDFsMovntForElastic_%dtfname%%tmfname%.txt
echo #### Created Log File Name: '%logFileName%' ####
set logtm=%TIME: =0%
echo %logdt% %logtm% INFO *** Process starts ***
echo %logdt% %logtm% INFO *** Process starts *** > %logFileName%
set "%~1 = %logFileName%"
goto:eof
