# viewDocument
##runs detectViewer & opens file with appropriate app
##works with PDF
##called by ? for viewing Abschluss.pdf ?
##not to be confused with viewInvoice which allows for canvas viewing!
proc viewDocument {file type} {
  set viewer [detectViewer $type]

  #TODO warum kommt diese MSg erst am Schluss??????????????'''
  NewsHandler::QueryNews "Wir versuchen nun, das Dokument $file anzuzeigen." orange

  #open in $viewer if found, else use xdg-open
  if {$viewer==1} {
    set viewer "xdg-open"
  }

  #hier ein after?
  if [catch {exec $viewer $file}] {
    NewsHandler::QueryNews "Kann $file nicht anzeigen. Öffnen Sie die Datei eigenhändig." red
    return 1
  }

  return 0
}

# detectViewer
##looks for DVI/PDF viewer
##returns name or nothing 1 if none found
##called by showInvoice (DVI) + ? ?
proc detectViewer {type} {

  #Viewers for DVI+PDF (needed by viewInvoice)
  if {$type == "dvi"} {
    lappend viewerList evince okular xdvi

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

#  NewsHandler::QueryNews "Das Dokument $Latex::pdfFile wird zum Drucker geschickt..." orange

  # A) View if no lpr found
  if {[auto_execok lpr] == ""} {
    NewsHandler::QueryNews "Kein Drucker gefunden!\nDas Dokument $Latex::pdfFile wird zur Weiterbearbeitung angezeigt..." orange
    after 7000 viewDocument $pdfPath pdf
    return 1
  }

  # B) Try printing
  proc tryPrint {pdfPath} {
    return [catch {exec lpr $pdfPath}]
#    NewsHandler::QueryNews "Kein Drucker?" blue
  }

  ##1. Versuch
  if [tryPrint $pdfPath] {
    set run 1
    #NewsHandler::QueryNews "Das Dokument $Latex::pdfFile wurde möglicherweise nicht gedruckt.\nIst der Drucker eingeschaltet?" red
  #after 5000
  }

  ##2.-4. Versuch
  set V 0

  while { [tryPrint $pdfPath] && $run < 4} {

    incr run
NewsHandler::QueryNews $run green
    after 3000
    if {$run == 4} {
      after idle set V 1
    }
  }

puts $V

#  if {! $V} {
#  puts gösteremiyorum
#    return 0
#  }

# C) Try viewing
  vwait V
  #NewsHandler::QueryNews "Das Dokument $Latex::pdfFile wurde möglicherweise nicht gedruckt. \nWir versuchen es jetzt zwecks Weiterbearbeitung anzuzeigen." orange
  after idle viewDocument $Latex::pdfPath pdf
  return 1



} ;#END printPdf

# doPrintReport
##called by .abschlussPrintB
proc doPrintReport {jahr} {

  latexReport $jahr
  NewsHandler::QueryNews "Das Dokument Abschluss ${jahr} wird zum Drucker geschickt..." orange
  after 3000 printDocument $jahr rep
  return 0
}
