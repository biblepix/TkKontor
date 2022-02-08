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
  set invToken [pg_exec $db "SELECT 
    ref,
    cond,
    f_date,
    items,
    customeroid
  FROM invoice WHERE f_number = $invNo"
  ]

  if { [pg_result $invToken -error] != ""} {
    NewsHandler::QueryNews "[mc invRecovErr $invNo]\n[pg_result $invToken -error]" red
    return 1
  }
  
  set ref       [lindex [pg_result $invToken -list] 0]
  set cond      [lindex [pg_result $invToken -list] 1]
  set auftrDat  [lindex [pg_result $invToken -list] 2]
  
  #make sure below signs are escaped since they interfere with LaTex commands
  set itemsHex  [lindex [pg_result $invToken -list] 3]
  set adrNo     [lindex [pg_result $invToken -list] 4]

  #3.Get address data from DB & format for Latex
  set adrToken [pg_exec $db "SELECT 
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
  pg_result $invToken -clear
  pg_result $adrToken -clear

  return 0
  
} ;#END recoverInvData


# viewDocument
##runs detectViewer & opens file with appropriate app
##works with PDF
##called by ? for vixewing Abschluss.pdf ?
#proc viewDocument {file type} {
#  
#  set viewer [detectViewer $type]

#  #TODO warum kommt diese MSg erst am Schluss??????????????'''
#  NewsHandler::QueryNews "Wir versuchen nun, das Dokument $file anzuzeigen." orange

#  #open in $viewer if found, else use xdg-open
#  if {$viewer==1} {
#    set viewer "xdg-open"
#  }

#  #hier ein after?
#  if [catch {exec $viewer $file}] {
#    NewsHandler::QueryNews "Kann $file nicht anzeigen. Öffnen Sie die Datei eigenhändig." red
#    return 1
#  }

#  return 0
#}

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
  
  #View pdf / PS_
  if [catch {exec xdg-open $docPath}] {
    set viewer [detectViewer $docType]
  }

  if {$viewer == ""} {
    NewsHandler::QueryNews "Kein Anzeigeprogramm gefunden! 
    Das Dokumen befindet sich in $docPath zur Weiterbearbeitung." red
  }

} ;# END printDocument

# printPdf
##sends PDF to printer / viewer
##called by printDocument
#proc printPdf {pdfPath} {

#  #catch {namespace delete Latex}
#  namespace eval Latex {}
#  set Latex::pdfPath $pdfPath
#  set Latex::pdfFile [file tail $pdfPath]

##  NewsHandler::QueryNews "Das Dokument $Latex::pdfFile wird zum Drucker geschickt..." orange

#  # A) View if no lpr found
#  if {[auto_execok lpr] == ""} {
#    NewsHandler::QueryNews "Kein Drucker gefunden!\nDas Dokument $Latex::pdfFile wird zur Weiterbearbeitung angezeigt..." orange
#    after 7000 viewDocument $pdfPath pdf
#    return 1
#  }

#  # B) Try printing
#  proc tryPrint {pdfPath} {
#    return [catch {exec lpr $pdfPath}]
##    NewsHandler::QueryNews "Kein Drucker?" blue
#  }

#  ##1. Versuch
#  if [tryPrint $pdfPath] {
#    set run 1
#    #NewsHandler::QueryNews "Das Dokument $Latex::pdfFile wurde möglicherweise nicht gedruckt.\nIst der Drucker eingeschaltet?" red
#  #after 5000
#  }

#  ##2.-4. Versuch
#  set V 0

#  while { [tryPrint $pdfPath] && $run < 4} {

#    incr run
#NewsHandler::QueryNews $run green
#    after 3000
#    if {$run == 4} {
#      after idle set V 1
#    }
#  }

#puts $V

##  if {! $V} {
##  puts gösteremiyorum
##    return 0
##  }

## C) Try viewing
#  vwait V
#  #NewsHandler::QueryNews "Das Dokument $Latex::pdfFile wurde möglicherweise nicht gedruckt. \nWir versuchen es jetzt zwecks Weiterbearbeitung anzuzeigen." orange
#  after idle viewDocument $Latex::pdfPath pdf
#  return 1



#} ;#END printPdf

# doPrintReport
##called by .abschlussPrintB
proc doPrintReport {jahr} {

  latexReport $jahr
  NewsHandler::QueryNews "Das Dokument Abschluss ${jahr} wird zum Drucker geschickt..." orange
  after 3000 printDocument $jahr rep
  return 0
}
	
