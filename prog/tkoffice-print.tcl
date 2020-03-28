# viewDocument
##runs detectViewer & opens file with appropriate app
##works with PDF
##called by ? for viewing Abschluss.pdf ?
##not to be confused with viewInvoice which allows for canvas viewing!
proc viewDocument {file type} {
  set viewer [detectViewer $type]
  #open in $viewer if found, else use xdg-open
  if {$viewer==1} {
    set viewer "xdg-open"
  }

  if [catch {exec $viewer $file}] {
    NewsHandler::QueryNews "Kann $file nicht anzeigen. Öffnen Sie die Datei eigenhändig." red
    return 1
  }
  
  return 0
}

# detectViewer
##looks for DVI/PDF viewer
##returns 1 if none found
##called by showInvoice (DVI) + ? ?
proc detectViewer {type} {
  
  #Viewers for DVI+PDF (needed by viewInvoice)
  if {$type == "dvi"} {
    lappend viewerList evince okular

  #Extra PDF viewers (needed by viewDocument)
  } elseif {$type == "pdf" } {
    lappend viewerList evince okular xpdf qpdf mupdf acroread zathura qpdfview pqiv gspdf pdf-reader
  }
  
  #Detect 1st installed viewer
  foreach p $viewerList {
    if {[auto_execok $p] != ""} {
      set viewer $p
      break
    }
  }
    
  if [info exists viewer] {
    return $viewer
  } else {
    return 1
  }

} ;#END detectViewer

# printDocument
##latexes Abschluss.tex + Invoice[NR].tex & sends to Printer/Viewer
## A)  type "rep" / num=jahr 
## B)  type "inv" / num=invNo
##called by .newinvprintB & .abschlussPrintB
proc printDocument {num type} {
  global texDir reportDir tmpDir spoolDir
 
  #A.  A b s c h l u s s
  if {$type == "rep"} {
 
    set jahr $num
    set texName Abschluss.tex
    set texPath [file join $texDir $texName]
    append pdfName [file root $texName] $jahr . pdf 
    set pdfPath [file join $reportDir $pdfName]
    
    #1. run latexReport
    latexReport $jahr
    after 1000
    latex2pdf $jahr $type

    
  # B. I n v o i c e 
  } elseif {$type == "inv"} { 

    #Get data from DB
    set invNo $num
    if [catch "fetchInvData $invNo"] {
      return 1
    }
    #Set paths
    set texPath [setInvPath $invNo tex]
    set pdfPath [setInvPath $invNo pdf]
     
    #Run latex2pdf
    latex2pdf $invNo $type

  }
  
  #3. Try printing OR view
  while ![file exists $pdfPath] {
    after 2000
  }
  printPdf $pdfPath

} ;# END printDocument

# printPdf
##sends PDF to printer / viewer
##called by printDocument
proc printPdf {pdfPath} {
  
  #catch {namespace delete Latex}
  namespace eval Latex {}
  set Latex::pdfPath $pdfPath
  set Latex::pdfFile [file tail $pdfPath]
  
  NewsHandler::QueryNews "Das Dokument $Latex::pdfFile wird zum Drucker geschickt..." orange
    
  # A) View if no lpr found
  if {[auto_execok lpr] == ""} {
    NewsHandler::QueryNews "Kein Drucker gefunden!\nDas Dokument $pdfFile wird zur Weiterverarbeitung angezeigt..." orange
    viewDocument $pdfPath pdf
    return 1
  }
    
  # B) Try printing
  proc tryPrint {pdfPath} {
    return [catch {exec lpr $pdfPath}]
  }
  
  ##1. Versuch
  if [tryPrint $pdfPath] {
    NewsHandler::QueryNews "Das Dokument $Latex::pdfFile wurde möglicherweise nicht gedruckt.\nIst der Drucker eingeschaltet?" red
    set run 1
    after 5000
  }
  
  ##2.-4. Versuch
  while { [tryPrint $pdfPath] && $run < 4} {
    incr run
    puts $run
    after 3000
  } 
    
  # C) Try viewing
  if {$run} { 
    after 3000
    NewsHandler::QueryNews "Das Dokument $Latex::pdfFile wurde möglicherweise nicht gedruckt. \nWir versuchen es jetzt zwecks Weiterbearbeitung anzuzeigen." orange
    viewDocument $Latex::pdfPath pdf
    return 1
  }
  
} ;#END printPdf

