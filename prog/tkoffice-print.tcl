# ~/TkOffice/prog/tkoffice-print.tcl
# called by tkoffice
# Salvaged: 1nov17
# Upgraded to use SQLite: 6sep22
# Updated 21mch23

# detectViewer
##Tries viewing document via 1) xdg-open, 2) via random viewer list
##Since Ghostscript is a pre-requisite, all users should have a 'gv' installed
##called by printDocument
proc detectViewer {docPath docType} {

	if ![catch {exec xdg-open $docPath}] {
		return 0
	}
	
  if {$docType == "ps"} {
   	lappend viewerL evince okular gs gv acroread ghostview Kghostview
  } elseif {$docType == "pdf"} {
    lappend viewerL evince okular gs gv xpdf qpdf mupdf acroread zathura qpdfview pqiv pdf-reader
  }
 	foreach prog $viewerL {
  	if {[auto_execok $prog] != ""} {
    	set viewer $prog
    	break
  	}
	}
	
  if [info exists viewer] {
    exec $viewer $docPath 
  } else {
  	 NewsHandler::QueryNews "Kein Anzeigeprogramm gefunden! 
 	   Das Dokument befindet sich in $docPath zur Weiterbearbeitung." red
  }
  
} ;#END detectViewer



# printReport
##postscripts report in page setup
##called by .repPrintBtn
proc printReport {jahr} {
  global texDir reportDir tmpDir
  
#  set reportPdfName Report_${jahr}.pdf
#  set reportTmpPs [file join $tmpDir $reportname]
#  set reportFullPdf [file join $reportDir $reportPdfName]

#TODO tsteisng
set repFullPs Report_${jahr}.ps
set repPartfile report_${jahr}
#set pageNo 4
  
  #1) postscript report canvas
  .repT conf -bg white
  report2ps $jahr

  #2) if several pages: assemble ps pages to Report...ps
  if ![file exists $tmpDir/blabla] {
    
#ns schon da von report2ps!
 #   set report::reportPdfName $reportPdfName
#    set report::tmpDir $tmpDir
    set report::jahr $jahr
    set report::repFullPs $repFullPs
    cd $tmpDir
    
    namespace eval report {

  #    set cmd "gs -dNOPAUSE -dAutoRotatePages=/None -sDEVICE=pdfwrite -sOUTPUTFILE=Report_${jahr}.ps -dBATCH -f "
set cmd {exec psjoin}

      set num 1
      for {set max $pageNo} {$num <= $max} {incr num} { puts $num
      
        append filename $repPartfile _ $num . ps
puts $filename
        lappend cmd $filename
        unset filename

puts $cmd
      }

 
#      eval [exec $cmd]

#This requires psutils:
eval $cmd > $repFullPs
    
    } ;#END namespace
    
    namespace delete report
  }
    


  #3) View full report for printing
  while ![file exists $repFullPs] {
    after 1000
  }
  
#  exec gv $reportTmpPs
  exec xdg-open $repFullPs   
 
  #4) if wanted: move tmpfile to $reportDir
  set res [tk_messageBox -type yesno -message "Wollen Sie die Datei $reportTmpPs abschliessend in $reportDir speichern?"]
  if {$res == "yes"} {
    file copy -force $repFullPs [file join $reportDir $repFullPs]
    file delete $reportFullPs
  }

} ;# END printReport

# printInvoice
##fetches InvData for invNo OR ???
##called by .... in Invoices window & .invPrintBtn?
proc printInvoice {} {
  global texDir ?vorlageTex reportDir tmpDir spoolDir templateDir

#TODO testing alsways retrieving   TODO this can be dangerous > always fetchData???
#    if ![file exists $docPath] {

      if [catch "fetchInvData $invNo"] {
  puts Notfetched
  
        NewsHandler::QueryNews "Unable to retrieve invoice data from DB." red 
        return 1
      }
      
      #Run latex     
      set texPath [setInvPath $invNo tex]
      cd $texDir
      
			catch {latexInvoice $invNo }
  
    
#    }


}
	

# latexInvoice
##executes latex on vorlageTex OR dvips OR dvipdf on vorlageDvi
##with end type: PDF
##called by doPrintNewInv & doPrintOldInv
#code from DKF: " With plenty of experience, 'nonstopmode' or 'batchmode' are most useful
# eval [list exec -- pdflatex --interaction=nonstopmode] $args
proc latexInvoice {invNo} {

  global db adrSpin spoolDir vorlageTex texDir tmpDir invTex

  #catch {namespace delete Latex}
  namespace eval Latex {}
  set Latex::invTexPath [setInvPath $invNo tex]
  set Latex::tmpDir $tmpDir
  set Latex::spoolDir $spoolDir

	#Copy original template each time to texDir
	file copy -force $vorlageTex $texDir

  namespace eval Latex {
    eval [list exec -- pdflatex -interaction nonstopmode -output-directory $tmpDir $invTexPath]
  }  

	set invPdfTmpPath [setInvPath $invNo pdftmp] 
  set invPdfPath [setInvPath $invNo pdf]

	#copy PDF to spool
	while ![file exists $invPdfTmpPath] {
		after 2000
	}

  file copy -force $invPdfTmpPath $invPdfPath
  
  namespace delete Latex
    
} ;#END latexInvoice


# report2ps
## postscripts report canvas in visible steps
## reworked on basis of 40? lines per page
## called by .repPrintBtn
proc report2ps {year} {

  global tmpDir reportDir
  set c .repC
  set w .repT
  #Page height in lines
  set pageH 40
  
  $w conf -bg white
  $w yview moveto 1.0
  set numLines [$w count -lines 1.0 end]
  
  set pageNo 1
  
  set repPartfile [file join $tmpDir report_${year}]
  set repFullfile [file join $reportDir Report_${year}.pdf]

#TODO mantik ne?
  set reportPs $tmpDir/Report_${year}.ps
  set reportPdf [string trimright $reportPs .ps].pdf
  
puts $reportPs
puts $reportPdf
  
  ###############################
  # Handle single page report
  ###############################
  
  # check if report is in full view
  if { [$w yview] == "0.0 1.0"} {
  
    puts "Printing single page..."
    
    update
    eval [list $c postscript -rotate 1 -file $reportPs]
    

  } else {
  
  ###############################
  # Handle multiple pages
  ###############################
    
    puts "Printing multiple pages..."
      
    $w tag conf hide -elide 1
    $w tag conf show -elide 0

    #divide text by fix page height
    set wholeBlocks [expr $numLines / $pageH]
    
    ## 1. Handle whole 40 blocks
    
    #Prepare page 1
    set top 1
    set bot 40
    set pageNo 1
    $w yview moveto 0.0
    $w tag add hide [expr $bot + 1].0 end
    
    ## 2. Handle following pages
    for {set tot $wholeBlocks} {$pageNo <= $tot} {incr pageNo} {
      
     # $w yview moveto $top.0
      update
      eval [list $c postscript -rotate 1 -file ${repPartfile}_${pageNo}.ps]
  
      #hide section just done
      $w tag remove hide 1.0 end
      $w tag add hide $top.0 $bot.end
      
      set top [expr $bot + 1]
      set bot [expr $top + 40]
      
      #hide section below current
      $w tag add hide [expr $bot + 1].0 end
         
    }

    ## 3. Handle last page
    $w tag remove hide 1.0 end
    $w tag add hide 1.0 $top.end

    update
    $c postscript -rotate 1 -file ${repPartfile}_${pageNo}.ps

#export final page number for printReport
namespace eval report {}
set report::pageNo $pageNo
set report::repPartfile $repPartfile
      
 } ;#END main clause
 
  ## 5. Final cleanup
  $w conf -bg lightblue
  $w tag delete hide
  $w yview moveto 0.0

} ;#END report2ps

