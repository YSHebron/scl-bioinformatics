@echo off

set mode=%1
shift
set pool_thresh=%1
shift
set num_procs=%1
shift

if "%mode%"=="" (
	echo Mode undefined
	exit /b
)

set maindir=%CD%

echo ==========================================
echo ================= PC2P ===================
echo ==========================================
echo. 

python PC2P/main_Function.py %mode% %pool_thresh% %num_procs%