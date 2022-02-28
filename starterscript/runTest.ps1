$infile = "config_tmpl.ini"
$outfile = "config.ini"
$reportfile = "C:\Users\Daniel\AppData\Roaming\MetaQuotes\Terminal\Common\Files\JFX-Indicator\indicator-runs.log"
$indicatorID4Test=36

$symbols = @("AUDCAD", "AUDUSD", "AUDCHF", "AUDJPY", "AUDNZD", "CADCHF", "CADJPY", "CHFJPY", "EURAUD", "EURCAD", "EURCHF", "EURGBP", "EURJPY", "EURNZD", "EURUSD", "GBPAUD","GBPCHF", "GBPCAD", "GBPJPY", "GBPNZD", "GBPUSD", "NZDCAD", "NZDCHF","NZDJPY","NZDUSD", "USDCAD", "USDJPY", "USDCHF", "BTCUSD", "ETHUSD", "DE30", "US500")
$periods = @("H1", "H4", "D1")


# for ($indi=35; $indi -lt 37; $indi++) {
	#$indicatorID4Test=$indi
	echo "Indicator $indicatorID4Test"
for ($i=0; $i -lt $symbols.Length;$i++) {
  echo $symbols[$i]
  $s = $symbols[$i]
  for ($j=0; $j -lt $periods.Length; $j++) {
	  $t = $periods[$j]
	  echo "   Period $t"
	  (gc $infile) -replace 'Symbol=SYMBOL', "Symbol=$s" -replace 'Period=PERIOD', "Period=$t" -replace 'inp_ConfirmationIndicator1=0', "inp_ConfirmationIndicator1=$indicatorID4Test" | Out-File -encoding ASCII "$outfile"
      Start-Process -FilePath "C:\Program Files\FXFlat MetaTrader 5\terminal64.exe" -Wait -ArgumentList "/profile:Tester /config:$outfile"
  }
}
# }