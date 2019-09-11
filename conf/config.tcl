set auftragDir $env(HOME)/tkoffice
cd $auftragDir

set HOME $env(HOME)
set db kontordb
set dbname kontordb
set dbuser postgres
set company "Vollmar Übersetzungs-Service"
set spoolDir [file join $auftragDir spool]
set dumpDir [file join $auftragDir dumps]
set vorlage [file join $spoolDir rechnung-vorlage.rtf]
set printCmd bas



