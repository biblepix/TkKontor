# ~/TkOffice/prog/tkoffice-print.tcl
# called by 
# Salvaged: 1nov17
# Updated to use SQLite: 6sep22
# Updated 11mch23

# fetchInvData
##1.retrieves invoice data from DB
##2.gets some vars from Config
##3.saves dataFile & itemFile for Latex processing
##called by latexInvoice
proc fetchInvData {invNo} {
  global db texDir confFile itemFile dataFile

  #1.get some vars from config
  source $confFile
  if {![string is digit $vat]} {set vat 0.0}
  if {$currency=="$"} {set currency \\textdollar}
  if {$currency=="£"} {set currency \\textsterling}
  if {$currency=="€"} {set currency \\texteuro}
  if {$currency=="CHF"} {set currency {Fr.}}

  #2.Get invoice data from DB
  set invToken [db eval "SELECT 
    ref,
    cond,
    f_date,
    items,
    customeroid
  FROM invoice WHERE f_number = $invNo"
  ]

  if [db errorcode] {
    NewsHandler::QueryNews "[mc invRecovErr $invNo]\n$invToken" red
    return 1
  }
  
  set ref       [lindex [pg_result $invToken -list] 0]
  set cond      [lindex [pg_result $invToken -list] 1]
  set auftrDat  [lindex [pg_result $invToken -list] 2]
  
  #make sure below signs are escaped since they interfere with LaTex commands
  set itemsHex  [lindex [pg_result $invToken -list] 3]
  set adrNo     [lindex [pg_result $invToken -list] 4]

  #3.Get address data from DB & format for Latex
  set adrToken [db eval "SELECT 
    name1,
    name2,
    street,
    zip,
    city 
  FROM address WHERE ts=$adrNo"
  ]

  lappend custAdr [lindex [pg_result $adrToken -list] 0] {\\}
  lappend custAdr [lindex [pg_result $adrToken -list] 1] {\\}
  lappend custAdr [lindex [pg_result $adrToken -list] 2] {\\}
  lappend custAdr [lindex [pg_result $adrToken -list] 3] { }
  lappend custAdr [lindex [pg_result $adrToken -list] 4]
    
  #4.set dataList for usepackage letter
  append dataList \\newcommand\{\\referenz\} \{ $ref \} \n
  append dataList \\newcommand\{\\cond\} \{ $cond \} \n
  append dataList \\newcommand\{\\dat\} \{ $auftrDat \} \n
  append dataList \\newcommand\{\\invNo\} \{ $invNo \} \n
  append dataList \\newcommand\{\\custAdr\} \{ $custAdr \} \n
  append dataList \\newcommand\{\\myBank\} \{ $myBank \} \n
  append dataList \\newcommand\{\\myName\} \{ $myComp \} \n
  append dataList \\newcommand\{\\myAddress\} \{ $myAdr \} \n
  append dataList \\newcommand\{\\myPhone\} \{ $myPhone \} \n
  append dataList \\newcommand\{\\vat\} \{ $vat \} \n
  append dataList \\newcommand\{\\currency\} \{ $currency \} \n

  ##save dataList to dataFile
  set chan [open $dataFile w] 
  puts $chan $dataList
  close $chan

  #save itemList to itemFile  
  set itemList [binary decode hex $itemsHex]
  if {$itemList == ""} {
    reportResult "Keine Posten für Rechnung $invNo gefunden. Kann Rechnung nicht anzeigen oder ausdrucken." red 
    return 1
  }
  #get rid of Latex code signs
  regsub -all {%} $itemList {\%} itemList
  regsub -all {&} $itemList {\&} itemList
  regsub -all {$} $itemList {\$} itemList
  regsub -all {#} $itemList {\#} itemList
  regsub -all {_} $itemList {\_} itemList
  
  set chan [open $itemFile w]
  puts $chan $itemList
  close $chan

  #Cleanup
  #pg_result $invToken -clear
  #pg_result $adrToken -clear
unset invToken adrToken
	
  return 0
  
} ;#END recoverInvData


# detectViewer
##looks for PDF or PS viewers (args=type: ps OR pdf)
##returns name or nothing 1 if none found
##called by printDocument
proc detectViewer {type} {

  if {$type == "ps"} {
   	lappend viewerL evince okular gs gv acroread ghostview Kghostview
  } elseif {$type == "pdf"} {
    lappend viewerL evince okular gs xpdf qpdf mupdf acroread zathura qpdfview pqiv pdf-reader
  }
 	foreach prog $viewerL {
  	if {[auto_execok $prog] != ""} {
    	set viewer $prog
    	break
  	}
	}
	
  if [info exists viewer] {
    return $viewer 
  }
  
} ;#END detectPdfViewer

# printDocument
##latexes Abschluss.tex + Invoice[NR].tex & sends to Printer/Viewer
## A)  type "rep" / num=jahr
## B)  type "inv" / num=invNo
##called by .newinvprintB & .abschlussPrintB
proc printDocument {num type} {
  global texDir reportDir tmpDir spoolDir
  set invNo $num
      
  #A.  A b s c h l u s s
  if {$type == "rep"} {

    set jahr $num
    set docPath [setReportPsPath $jahr]
    set docType ps

    #Postscript canvas for printout in landscape format
    ##TODO this only works for 1 page, multiple pages should be handled by canvas2ps (which doesn't work properly yet)
    .reportT conf -bg white
    update
    .reportC postscript -rotate 1 -file $docPath
    
  # B. I n v o i c e
  } elseif {$type == "inv"} {

    #A) file not found in spooldir: view
    set docPath [setInvPath $invNo pdf]
    set docType pdf
    
    if ![file exists $docPath] {

      if [catch "fetchInvData $invNo"] {
        NewsHandler::QueryNews "Unable to retrieve invoice data from DB." red 
        return 1
      }
      
      #Run latex     
      set texPath [setInvPath $invNo tex]
      latexInvoice $invNo
    }
  } ;#END main clause
  
  #View pdf / PS TODO: consider ps2pdf for all cases!_

  #TODO consider embedding viewer window:
#  https://wiki.tcl-lang.org/page/Combining+GUI+applications+developed+with+Tk+and+'native'+Windows+toolkits

   # package require BLT

     # Create a unique name for the new process
    # set name "EmbedTk[pid][clock seconds]"
    # eval blt::bgexec wait [list Eterm -n $name -e vi] $argv
    # pack [blt::container .c -name $name] -fill both
    # wm title . "Vim running in Tk"
    # # Wait for app to exit (could use trace + callback here)
    # vwait wait
    # destroy .
 
  if [catch {exec xdg-open $docPath}] {}
  if [catch {exec gv $docPath} {
    
    set viewer [detectViewer $docType]
    if {$viewer == ""} {
      NewsHandler::QueryNews "Kein Anzeigeprogramm gefunden! 
      Das Dokumen befindet sich in $docPath zur Weiterbearbeitung." red
    }
  }

} ;# END printDocument


# doPrintReport
##called by .abschlussPrintB
proc doPrintReport {jahr} {

  latexReport $jahr
  NewsHandler::QueryNews "Das Dokument Abschluss ${jahr} wird zum Drucker geschickt..." orange
  after 3000 printDocument $jahr rep
  return 0
}
	
	
	# latex2pdf - TODO obsolete?
##produces PDF of any TeX file
## args = invNo OR jahr
##called by printDocument
proc latex2pdf {num type} {
  global tmpDir spoolDir reportDir texDir

  #A. Abschluss
  if {$type == "rep"} {

    set jahr $num
    set texName "Abschluss.tex"
    set texPath [file join $texDir $texName]
    append pdfName [file root $texName] . pdf
    set pdfPath [file join $tmpDir $pdfName]
    set targetDir $reportDir

  #B. Invoice
  } elseif {$type == "inv"} {

    set invNo $num
    set texPath [setInvPath $invNo tex]
    set pdfPath [setInvPath $invNo pdf]
    set pdfName [file tail $pdfPath]
    set targetDir $spoolDir
  }

  #Latex > PDF
#  catch {namespace delete Latex}
  namespace eval Latex {}
  set Latex::texPath $texPath
  set Latex::tmpDir $tmpDir
  #set Latex::targetDir $targetDir

  namespace eval Latex {
    eval exec -- pdflatex -interaction nonstopmode -output-directory $tmpDir $texPath
  }

  #Rename 'Abschluss.pdf' to include year
  if {$type == "rep"} {
    while ![file exists $pdfPath] {
      after 2000
    }

    append pdfNewName [file root $pdfName] $jahr . pdf
    cd $tmpDir
    file rename -force $pdfName $pdfNewName
    set pdfName $pdfNewName
  }

  #Copy any type PDF from $tmpDir to $targetDir
  cd $tmpDir
  file copy -force $pdfName $targetDir

  #TODO include here tkoffice-reports.tcl p. 378 to catch any failure !!!
  ###NewsHandler::QueryNews "Die Datei $pdfName befindet sich in $targetDir zur weiteren Bearbeitung." lightgreen
  return 0

} ;#END latex2pdf
