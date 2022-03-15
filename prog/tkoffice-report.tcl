# ~/TkOffice/prog/tkoffice-report.tcl
# called by tkoffice-gui.tcl
# Updated: 15mch22

#sSrced by .abschlussPrintB button & ?

################################################################################
### A B S C H L Ü S S E  &  E X P E N S E S
################################################################################

# setAbschlussjahrSB
##configures Abschlussjahr spinbox ('select distinct' shows only 1 per year)
##includes actual business years up till now
##called by manageExpenses & createAbschluss
proc setAbschlussjahrSB {} {
  global db
  set heuer [clock format [clock seconds] -format %Y]
  set token [pg_exec $db "SELECT DISTINCT EXTRACT(year FROM f_date) FROM invoice"]
  set jahresliste [pg_result $token -list]
  lappend jahresliste $heuer

  .abschlussJahrSB conf -values [lsort -decreasing $jahresliste]
  .abschlussJahrSB set [expr $heuer - 1]
}

# setReportPsPath
##adds year to reportName & gives out PS path
##called by various Abschluss procs
proc setReportPsPath {jahr} {
  global reportDir
  
  #TODO Mc
  append reportName report _ $jahr . ps
  set reportPath [file join $reportDir $reportName] 
  
  return $reportPath
}

#################################
# A U S L A G E N
#################################

# manageExpenses
##shows general expenses (Auslagen) from DB
##shows Add + Delete buttons for managing
##called by createAbschluss
proc manageExpenses {} {
  global db
  .expnameE conf -bg beige -fg grey -width 60 -textvar ::expname
  .expvalueE conf -bg beige -fg grey -width 7 -textvar ::expval

  #pack Listbox & buttons
  pack forget .abschlussM .spesenAbbruchB .reportT .abschlussScr .reportPrintB .expnameE .expvalueE
  pack .spesenM -side left
  pack .spesenAddB .spesenDeleteB -in .n.t3.mainF -side right -anchor se
  pack .spesenLB -in .n.t3.mainF

  .spesenAddB conf -text "Eintrag hinzufügen" -command {addExpenses}

  .spesenLB delete 0 end
  #get listbox values from DB
  set token [pg_exec $db "SELECT * FROM spesen"]

  foreach tuple [pg_result $token -llist] {
    #set tuple [pg_result $token -getTuple $tupleNo]
    set name [lindex $tuple 1]
    set value [lindex $tuple 2]
    .spesenLB insert end "$name       $value"
  }
}

proc addExpenses {} {
  pack .spesenAbbruchB .spesenAddB .expvalueE .expnameE -in .n.t3.mainF -side right -anchor se
  pack forget .spesenDeleteB
  .spesenAddB conf -text "Speichern" -command {saveExpenses}
  set ::expname "Bezeichnung"
  set ::expval "Betrag"
  .expnameE conf -fg grey -validate focusin -vcmd {%W delete 0 end;%W conf -fg black;return 0}
  .expvalueE conf -fg grey -validate focusin -vcmd {%W delete 0 end; %W conf -fg black; return 0}
}
proc saveExpenses {} {
  global db

  set name [.expnameE get]
  set value [.expvalueE get]
  set token [pg_exec $db "INSERT INTO spesen (name,value) VALUES ('$name',$value)"]

  NewsHandler::QueryNews [pg_result $token -error] red
  #reportResult $token "Eintrag gespeichert."
  manageExpenses
}
proc deleteExpenses {} {
  global db

  #1 delete from DB
  set value [lindex [.spesenLB get active] end]
  set token [pg_exec $db "DELETE FROM spesen WHERE value=$value"]
  reportResult $token "Eintrag gelöscht"

  #2 update LB
  manageExpenses
#  return 0
}


############################
# A B S C H L U S S
############################

# createReport
##Creates yearly report for display in text window
##called by .abschlussCreateB button
proc createReport {} {
  global db myComp currency vat texDir reportDir
  pack forget .spesenM .spesenLB .spesenAbbruchB .spesenAddB .spesenDeleteB
  pack .abschlussM -side top

  # C r e a t e      t e x t w i n
  #catch {destroy $t $sb}
#packed later by canvasReport
  catch {text .reportT}
  set t .reportT
  $t delete 1.0 end
#  $t conf -width -height
  
  set jahr [.abschlussJahrSB get]
  set einnahmenTexFile [file join $texDir abschlussEinnahmen.tex]
  set auslagenTexFile  [file join $texDir abschlussAuslagen.tex]

	#get data from $jahr's invoices + 'payeddate = $jahr' from any previous invoices
	set res [pg_exec $db "SELECT
	f_number,
	f_date,
	addressheader,
	finalsum,
	vatlesssum,
	payedsum,
	auslage FROM invoice
	WHERE EXTRACT(YEAR from payeddate) = $jahr
	OR EXTRACT(YEAR from f_date) = $jahr
	ORDER BY f_number ASC"]

	#save result to var
	if {[pg_result $res -error] != ""} {
	  NewsHandler::QueryNews "[pg_result $res -error]" red
	  return 1
  }

	pg_result $res -assign j
	set maxTuples [pg_result $res -numTuples]

	#Textwin dimensions Tk scaling factor:
	##requires no of LETTERS as height + no. of LETTER as width!
	#TODO conflicts with [winfo height/width ...] for proper A4-dimensions
	#TODO A4 = 210 x 297 mm
	set scaling [tk scaling]
	set winLetH 35
  set winLetW [expr round(3.5 * $winLetH)]
	set winLetY [expr round($winLetH * $scaling)]
 	set winLetX [expr round($winLetW * $scaling)]

  #Configure widgets & scroll bar
  $t conf -bg lightblue -bd 0 
  
  
  
  #TODO testing
    catch {scrollbar .reportSB -orient vertical}
  $t conf -width $winLetX -height $winLetY -padx 10 -pady 10 -yscrollcommand {.reportSB set}
  #$t conf -padx 10 -pady 10 -yscrollcommand {.reportSB set}
  
  #Pack all
  pack $t -in .n.t3.mainF -side left  
	#pack .abschlussPrintB -in .n.t3.botF -anchor se

	# F i l l   t e x t w i n
#	raise $t
#	update
#	$t delete 1.0 end

  #Compute tabs for landscape layout (c=cm m=mm)
	$t configure -tabs {
	1.5c
	4.0c
	11c numeric
	14c numeric
	17c numeric
  }

  #Configure font tags
  $t tag conf T1 -font "TkHeadingFont 20"
  $t tag conf T2 -font "TkCaptionFont 16"
  $t tag conf T3 -font "TkSmallCaptionFont 10 bold"

  #B u i l d   w i n d o w
	$t insert 1.0 "$myComp\n" T1
	$t insert end "Erfolgsrechnung $jahr\n\n" T1
  $t insert end "Einnahmen\n" T2

  # E I N N A H M E N
  $t insert end "Rch.Nr.\tDatum\tAnschrift\tNetto ${currency}\tMwst. ${vat}%\tSpesen\tEingänge ${currency}\n" T3


#TODO  'finalsum' is exclusive vat & Auslagen - list Auslagen anyway because payedsum may differ

	#compute sum total & insert text lines
	#TODO use sum(...) from DB instaead!
	for {set no 0;set sumtotal 0} {$no <$maxTuples} {incr no} {
		set total $j($no,payedsum)
		catch {set sumtotal [expr $sumtotal + $total]}
		set sumtotal [roundDecimal $sumtotal]

		##compute Mwst
		set VAT $j($no,vatlesssum)
		set finalsum $j($no,finalsum)

		if {! $vat > 0} {
  		set VAT ""
  		set vatlesssum $finalsum
		} else {
  		set VAT [expr $finalsum - $vatlesssum]
  	}

		##set spesen tab
		set spesen $j($no,auslage)
    if ![string is double $spesen] {
	    set spesen ""
	  } else {
   		set spesen $j($no,auslage)
	  }
		set invNo $j($no,f_number)
		set invDat $j($no,f_date)
		set invAdr $j($no,addressheader)
		set payedsum $j($no,payedsum)

		#1. list in text window
		$t insert end "\n${invNo}\t${invDat}\t${invAdr}\t${vatlesssum}\t${VAT}\t${spesen}\t${payedsum}"

		#2.export to Latex
    append einnahmenTex $invNo & $invDat & $invAdr & $vatlesssum & $spesen & $VAT & $payedsum {\\} \n
	}

### A U S L A G E N

	#Get 'spesen' from DB
	set token [pg_exec $db "SELECT * FROM spesen"]

  foreach tuple [pg_result $token -llist] {
    set name [lindex $tuple 1]
    set value [lindex $tuple 2]
    
    ##1.prepare for text window
    
    append spesenList "$name\t\t\t\t\t\t-${value}\n"
    lappend spesenAmounts $value
    ##2.prepare for LateX
    append auslagenTex {\multicolumn{3}{l}} \{ $name \} &&& \{ \$ \- $value \$ \} {\\} \n
  }

  if {$spesenAmounts == ""} {
    set spesenAmounts 0.00
  } else {
    set spesenTotal 0.00
      foreach i $spesenAmounts {
        set spesenTotal [expr $spesenTotal + $i]
      }
  }
  set spesenTotal [roundDecimal $spesenTotal]

	#TODO insert further  ...
	$t insert end "\n\Einnahmen total\t\t\t\t\t\t\t $sumtotal" T3
	$t insert end "\n\nAuslagen\n" T2
	$t insert end $spesenList

  ##compute Reingewinn
  set netProfit [roundDecimal [expr $sumtotal - $spesenTotal]]
  if {$netProfit < 0} {
    set netProfit 0.00
  }

  $t insert end "\nAuslagen total\t\t\t\t\t\t\t-${spesenTotal}\n\n" T3
  $t insert end "Reingewinn\t\t\t\t\t\t\t$netProfit" T2
  
  #TODO for testing
#  $t conf -state disabled

#Canvas report & PS
  canvasReport $t
 # canv2ps .reportC  



  #Save Einnahmen & Auslagen to LateX for printAbschluss
#  set chan [open $einnahmenTexFile w]
#  puts $chan $einnahmenTex
#  close $chan
#  set chan [open $auslagenTexFile w]
#  puts $chan $auslagenTex
#  close $chan

  #Configure print button
  #TODO zis aynt workin!
  #TODO prepack from beginning
  #moved to canvasReport
  #catch {button .reportPrintB}
  #.reportPrintB conf -text "Bericht als PDf zum Druck darstellen" -command "doPrintReport $jahr"
  
  #pack .reportPrintB -in .n.t3.mainF -side right

} ;#END createReport

proc canvasReport {t} {
  update
  set jahr [.abschlussJahrSB get]  
  
  #Set height & width to A4
  set h [winfo height $t]
  set w [expr int(1.5 * $h)]
  
  #Create canvas & put report into window, trying to get A4 dimensions
  catch {canvas .reportC -width $w -height $h}
  
  .reportC create window 0 0 -tags repwin -window $t -anchor nw -width $w -height $h
  .reportC itemconf repwin -height $h -width $w
    
  #Create scrollbar
 # catch {scrollbar .reportSB -orient vertical}
  .reportC conf -yscrollcommand {.reportSB set}
  .reportSB conf -command {.reportC yview}
  
  #Create print button
  catch {button .reportPrintB}

#TODO testing 1 page optoin
#  .reportPrintB conf -text "Bericht drucken" -command "canvas2ps .reportC $jahr"
   #TODO add -pageheight & -pagewidth for A4 !
   set docPath [setReportPsPath $jahr]
   .reportPrintB conf -text [mc reportPrint] -command "printDocument $jahr rep"
   
  #Final packing of canvas & scrollbar
  pack .reportC -in .n.t3.mainF -side left -fill none
  pack .reportSB -in .n.t3.mainF -fill y -side left
  pack .reportPrintB -in .n.t3.mainF -side right

  raise $t

} ;#END canvasReport

# canv2ps
 # Capture a window into an image
 # Author: David Easton
##called by .reportPrintBtn
#TODO get PS into viewer!
proc canvas2ps {canv jahr} {
  global reportDir tmpDir
  set win .reportT

#TODO testing
#set win .reportC

  set origCanvHeight [winfo height $canv]
    
  #1. move win to top position + make first PS page
    raise $win
    update
    $win yview moveto 0.0 
    raise $win
    update

  #A) Für 1 page 
  #$canv postscript -colormode gray -file [file join $tmpDir abschluss_$pageNo.ps]
  $canv postscript -file [file join $tmpDir abschluss_$jahr.ps]
  
  #move 1 page for multiple pages
  set visFraction [$win yview]
  set begVisible [lindex $visFraction 0] 
  set endVisible [lindex $visFraction 1]
  $win yview moveto $endVisible

set pageNo 1
set lastVisible $endVisible

  while {$endVisible < 1.0} {

    incr pageNo
        
    set lastVisible $endVisible
    raise $win
    update
    $canv postscript -colormode gray -file [file join $tmpDir abschluss_$pageNo.ps]

    #move 1 page
    set visFraction [$win yview]
    set begVisible $endVisible
    set endVisible [lindex $visFraction 1]
    $win yview moveto $endVisible      
    
	}

#puts $endVisible
#puts $lastVisible	

	#3. Compute remaining page height & adapt window dimension
    if {$begVisible < $lastVisible} {
        set cutoutPercent [expr $begVisible - $lastVisible]
        set hiddenHeight [expr round($cutoutPercent * $origCanvHeight)]
        set visHeight [expr $origCanvHeight - $hiddenHeight]
        $canv itemconf textwin -height $visHeight
        $canv conf -height $visHeight 
    }

  incr pageNo
  
  #4. Make last page
  raise $win
  update
  
  append reportName report . $jahr _ $pageNo . ps
  set reportPath [file join $reportDir $reportName]
  
  #Postscript in landscape format for easy printing
  $canv postscript -colormode gray -rotate 1 -file $reportPath
  printDocument $jahr rep
  
  #5. Restore original dimensions
  $canv itemconf textwin -height $origCanvHeight
  $canv conf -height $origCanvHeight 

} ;#END canv2ps


# latexReport
##recreates (abschlussEinnahmen.tex) + (abschlussAuslagen.tex) > Abschluss.tex
##called by printAbschluss
#proc latexReport {jahr} {
#  global db myComp currency vat texDir reportDir reportTexFile
#  set reportTexPath [file join $texDir $reportTexFile]

##  set jahr [.abschlussJahrSB get]
#  set einnahmenTexFile [file join $texDir abschlussEinnahmen.tex]
#  set auslagenTexFile  [file join $texDir abschlussAuslagen.tex]
#  set einnahmenTex [read [open $einnahmenTexFile]]
#  set auslagenTex  [read [open $auslagenTexFile]]

#  #get netTot vatTot spesTot from DB
#  ##TODO? Bedingung 'year = payeddate' könnte dazu führen, dass Gesamtbetrag in 2 Jahren aufgeführt wird, wenn Teilzahlung vorhanden!
#  set token [pg_exec $db "SELECT sum(vatlesssum),sum(finalsum),sum(auslage),sum(payedsum)
#    FROM invoice AS total
#    WHERE EXTRACT(YEAR from f_date) = $jahr OR
#          EXTRACT(YEAR from payeddate) = $jahr
#  "]

#  set yearlyExpTot [pg_result [pg_exec $db "SELECT sum(value) from spesen"] -list]

#  ##compute all values for Abschluss
#  set vatlessTot [lindex [pg_result $token -list] 0]
#  set bruTot [roundDecimal [lindex [pg_result $token -list] 1]]
#  set custExpTot [lindex [pg_result $token -list] 2]
#  set payTot [lindex [pg_result $token -list] 3]
#  set vatTot [roundDecimal [expr $bruTot - $vatlessTot]]
#  set netTot [roundDecimal [expr $payTot - $vatTot - $custExpTot]]

#  set netProfit [roundDecimal [expr $netTot - $yearlyExpTot]]
#  if {$netProfit < 0} {
#    set netProfit 0.00
#  }

#  #R E C R E A T E   A B S C H L U S S . T E X
#  ##header data
#  append abschlTex {\documentclass[10pt,a4paper]{article}
#\usepackage[utf8]{inputenc}
#\usepackage{german}
#\usepackage{longtable}
#\author{}
#}
#append abschlTex {\title} \{ $myComp {\\} Erfolgsrechnung { } $jahr \}
#append abschlTex {
#\begin{document}
#\maketitle
#\begin{small}
#\begin{longtable}{ll p{0.4\textwidth} rrrr}
#%1. Einnahmen
#\caption{\textbf{EINNAHMEN}} \\
#\textbf{R.Nr} & \textbf{Datum} & \textbf{Adresse} &
#\textbf{Netto} &
#\textbf{Mwst.} &
#\textbf{Spesen} &
#\textbf{Bezahlt} \\
#\endhead
#}
#  ##1.Einnahmen
#  append abschlTex $einnahmenTex
#  append abschlTex {\multicolumn{3}{l}{\textbf{Einnahmen total}}} &
#  append abschlTex {\textbf} \{ $bruTot \} &
#  append abschlTex {\textbf} \{ $vatTot \} &
#  append abschlTex {\textbf} \{ $custExpTot \} &

#  append abschlTex [expr $bruTot - ($vatTot - $custExpTot)] {\\} \n
#  append abschlTex {&&abzügl. Mehrwertsteuer&&&} \{ \$ \- $vatTot \$ \} {\\} \n
#  append abschlTex {&&abzügl. Spesen&&&} \{ \$ \- $custExpTot \$ \} {\\} \n
#  append abschlTex {\multicolumn{3}{l}{\textbf{EINNAHMEN TOTAL NETTO}}&&&&\textbf} \{ $netTot \} {\\} \n
#  ##2.Auslagen
#  append abschlTex {\caption{\textbf{AUSLAGEN}} \\} \n
#  append abschlTex $auslagenTex
#  append abschlTex {\multicolumn{3}{l}{\textbf{AUSLAGEN TOTAL}} &&&& \textbf} \{ \- $yearlyExpTot \} {\\\\} \n
#  ##3. Reingewinn
#  append abschlTex {\multicolumn{3}{l}{\textbf{REINGEWINN}} &&&& \textbf} \{ $netProfit \} {\\} \n
#  ##4. End
#  append abschlTex {
#\end{longtable}
#\end{small}
#\end{document}
#  }

##puts $abschlTex
##puts $reportTexPath

#  #Save to file
#  set chan [open $reportTexPath w]
#  puts $chan $abschlTex
#  close $chan

##Latex2pdf
##latex2pdf $jahr rep

##TODO: latex catches don't work!!!!!!!!!!!!!!!!!!!!!!!!!!! - check all progs + find better solution.
##  if [catch {latex2pdf $jahr rep}] {

##    NewsHandler::QueryNews "$reportTexFile konnte nicht nach PDF umgewandelt werden." red
##    return 1
##  }

#  return 0
#} ;#END latexReport


