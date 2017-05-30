for %%x in (
bpi_csp, 
bpi_dpl, 
bpi_duke,
bpi_fe,
bpi_flp,
bpi_im,
bpi_op) do (
sqlcmd -S "usdbsvr6" -v myName=%%x -i "C:\Users\sspinetto\Desktop\BuckeyeDAvsRT.sql" -o "C:\Users\sspinetto\Desktop\Buckeye Outputs\%%x_DAvsRT.csv" -s ",")
