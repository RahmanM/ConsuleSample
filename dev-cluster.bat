for /f "delims=[] tokens=2" %%a in ('ping -4 -n 1 %ComputerName% ^| findstr [') do set NetworkIP=%%a
consul agent -bind %NetworkIP% -config-file=configs/dev_server_config.json