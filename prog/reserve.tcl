proc canvasReport {jahr} {
  update
  set h [expr [winfo height .n.t3] - 100]
  set w [expr int(1.5 * $h)]
  
  canvas .reportC -width $w -height $h
  .reportC create window 0 0 -tags repwin -window .reportT -anchor nw
  .reportC itemconf repwin -height $h -width $w
   
   set docPath [setReportPsPath $jahr]
   
   
  #Final packing of canvas
  #pack forget .reportT
  pack .reportC -in .n.t3.leftF
  pack .reportPrintBtn -in .n.t3.rightF -anchor se -side right

  #raise $t

} ;#END canvasReport

# viewInvoice - TODO why not provide PDF view?!
##checks out DVI/PS capable viewer
##sends rechnung.dvi / rechnung.ps to prog for viewing
##called by "Ansicht" & "Rechnung drucken" buttons
proc viewInvoice {invNo} {
  set invDviPath [setInvPath $invNo dvi]
	set invPdfPath [setInvPath $invNo pdf]
	
	
	#TODO wo ist Tex-Datei?????????????????????????
	
	#Convert to pdf
	if [catch {dvipdf $invDviPath}] {
	
		#Try viewing PDF
		if ![catch {$pdfviewer ?$invpath? }] {
  	
	  	set pdfViewer [detectViewer pdf]
	  	set dviViewer [detectViewer dvi]
	  	
	  	if {$pdfViewer == ""} {	

 	  		exec $dviViewer $invDviPath ?AUSGABEDATEI?
  		
  			#B) Show warning
  			}	 else {
  		
	  			NewsHandler::QueryNews "No PDF viewer found. Please open ?$file? from your file manager ..." red
  			}
  		}
  	}
   	

  
} ;#END viewInvoice


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


#TODO this type is never pdf-ed!
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


##latexes Abschluss.tex + Invoice[NR].tex & sends to Printer/Viewer
## A)  type "rep" / num=jahr
## B)  type "inv" / num=invNo
##called by .newinvprintB & .repPrintB
proc printDocument {num type} {
  global texDir vorlageTex reportDir tmpDir spoolDir templateDir
  set invNo $num
      
  #A.  A b s c h l u s s
  if {$type == "rep"} {

    set jahr $num
    set docPath [setReportPsPath $jahr]
    set docType ps
		set c .reportC
		set w .reportT
		
    #Postscript canvas for printout in landscape format
#TODO exec detectViewer here instead? can the batch?
#    eval [list exec gs -dNOPAUSE -dAutoRotatePages=/None -sDEVICE=pdfwrite -sOUTPUTFILE=$tmpDir/Report_${year}.ps -dBATCH $tmpDir/report_${year}*.ps]
    
    ##TODO this only works for 1 page, multiple pages should be handled by canvas2ps (which doesn't work properly yet)
    
#    update
#    .reportC postscript -rotate 1 -file $docPath

.reportT conf -bg white
canvas2ps $c $w $jahr
 
    
  # B. I n v o i c e
  } elseif {$type == "inv"} {

    #A) file not found in spooldir: view
    set docPath [setInvPath $invNo pdf]
    set docType pdf
 
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

  } ;#END main clause
  
  
  # View document for printing
  after idle detectViewer $invNo inv
	
} ;# END printDocument
