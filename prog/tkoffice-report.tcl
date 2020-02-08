# ~/TkOffice/prog/tkoffice-report.tcl
# called by tkoffice-gui.tcl
# Updated: 8feb20

#sSrced by abschlussPrintB button & ?

################################################################################################
### A B S C H L Ü S S E 
################################################################################################

# setAbschlussjahrSB
##configures Abschlussjahr spinbox ('select distinct' shows only 1 per year)
##includes actual business years up till now
proc setAbschlussjahrSB {} {
  global db
  set heuer [clock format [clock seconds] -format %Y]
  set token [pg_exec $db "SELECT DISTINCT EXTRACT(year FROM f_date) FROM invoice"]
  set jahresliste [pg_result $token -list]
  lappend jahresliste $heuer
   
  .abschlussJahrSB conf -values [lsort -decreasing $jahresliste]
  .abschlussJahrSB set [expr $heuer - 1]
}

# manageExpenses
##shows general expenses (Auslagen) from DB
##shows Add + Delete buttons for managing
##called by createAbschluss
proc manageExpenses {} {
  global db
  .expnameE conf -bg beige -fg grey -width 60 -textvar ::expname
  .expvalueE conf -bg beige -fg grey -width 7 -textvar ::expval

  #pack Listbox & buttons
  pack forget .spesenAbbruchB .abschlussT .abschlussScr .abschlussPrintB .expnameE .expvalueE
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

# createAbschluss
##Creates yearly report for display in text window
##called by .abschlussCreateB button
proc createAbschluss {} {
  global db myComp currency vat texDir reportDir
  pack forget .spesenLB .spesenAbbruchB .spesenAddB .spesenDeleteB
  
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


  # C r e a t e      t e x t w i n
  set t .abschlussT
#  set c .abschlussC
  set sb .abschlussScr
  destroy $t $sb
  text .abschlussT
#  canvas .abschlussC
  scrollbar .abschlussScr -orient vertical
  
	#Textwin dimensions Tk scaling factor:
	##requires LETTER height + LINE width!
	set scaling [tk scaling]
	set winLetH 35
  set winLetW [expr round(3.5 * $winLetH)]
	set winLetY [expr round($winLetH * $scaling)]
 	set winLetX [expr round($winLetW * $scaling)]
  
  #Configure widgets & scroll bar
  $t conf -bd 0 -width $winLetX -height $winLetY -padx 10 -pady 10 -yscrollcommand "$sb set"
  $sb conf -command "$t yview"
  
  #Pack all
  pack $t $sb -in .n.t3.mainF -side left -fill both
	pack .abschlussPrintB -in .n.t3.botF -anchor se
	
	# F i l l   t e x t w i n
#	raise $t
#	update
#	$t delete 1.0 end
  
  #Compute tabs for landscape layout (c=cm m=mm)
	$t configure -tabs {
	1.5c
	4.0c
	16c numeric
	19c numeric
	22c numeric
	25c numeric
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
  
  $t insert end "Rch.Nr.\tDatum\tAnschrift\tNetto ${currency}\tMwst. ${vat}%\tSpesen\tBezahlt ${currency}\tTotal ${currency}\n" T3


#TODO  'finalsum' is exclusive vat & Auslagen - list Auslagen anyway because payedsum may differ
  	
	#compute sum total & insert text lines
	for {set no 0;set sumtotal 0} {$no <$maxTuples} {incr no} {
		set total $j($no,payedsum)
		catch {set sumtotal [expr $sumtotal + $total]}
		
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
    append spesenList "$name\t\t\t\t-${value}\n"
    lappend spesenAmounts $value
    ##2.prepare for LateX
    append auslagenTex {\multicolumn{3}{l}} \{ $name \} &&& \{ \$ \- $value \$ \} {\\} \n
  }
 
  if {$spesenAmounts == ""} {
    set spesenAmounts 0.00
  } else {
    set spesenTotal 0
      foreach i $spesenAmounts {
        set spesenTotal [expr $spesenTotal + $i]
      }
  }
	#TODO insert further  ...
	$t insert end "\n\Einnahmen total\t\t\t\t\t\t\t $sumtotal" T3
	$t insert end "\n\nAuslagen\n" T2
	$t insert end $spesenList

  ##compute Reingewinn
  set netProfit [expr $sumtotal - $spesenTotal]
#  namespace eval auslagen {}
#  if {$netProfit < 0} {set auslagen::netProfit 0.00} {set auslagen::netProfit $netProfit}

  $t insert end "\nAuslagen total\t\t\t\t\t\t\t-${spesenTotal}\n\n" T3
  $t insert end "Reingewinn\t\t\t\t\t\t\t$netProfit" T2
  $t conf -state disabled

  #Save Einnahmen & Auslagen to LateX for printAbschluss
  set chan [open $einnahmenTexFile w]
  puts $chan $einnahmenTex
  close $chan
  set chan [open $auslagenTexFile w]
  puts $chan $auslagenTex
  close $chan

} ;#END createAbschluss 

# abschluss2latex
##recreates abschlussEinnahmen.tex & abschlussAuslagen.tex
##recreates Abschluss.tex from above files
##called by printAbschluss
proc abschluss2latex {} {
  global db myComp currency vat texDir reportDir
  
  set jahr [.abschlussJahrSB get]
  set einnahmenTexFile [file join $texDir abschlussEinnahmen.tex]
  set auslagenTexFile  [file join $texDir abschlussAuslagen.tex]
  set abschlussTexFile [file join $texDir Abschluss.tex]
  set abschlussPdfFile [file join $reportDir Abschluss${jahr}.pdf]
  
  set einnahmenTex [read [open $einnahmenTexFile]]
  set auslagenTex  [read [open $auslagenTexFile]]
  
  #get netTot vatTot spesTot from DB
  ##TODO? Bedingung 'year = payeddate' könnte dazu führen, dass Gesamtbetrag in 2 Jahren aufgeführt wird, wenn Teilzahlung vorhanden!
  set token [pg_exec $db "SELECT sum(vatlesssum),sum(finalsum),sum(auslage),sum(payedsum) 
    FROM invoice AS total
    WHERE EXTRACT(YEAR from f_date) = $jahr OR
          EXTRACT(YEAR from payeddate) = $jahr
  "]

  ##compute all values for Abschluss
  set vatlessTot [lindex [pg_result $token -list] 0]
  set bruTot [lindex [pg_result $token -list] 1]
  set expTot [lindex [pg_result $token -list] 2]
  set payTot [lindex [pg_result $token -list] 3]
  set vatTot [expr $bruTot - $vatlessTot]
  set netTot [expr $payTot - $vatTot - $expTot]

  set netProfit [expr $netTot - $expTot]
  
  #R E C R E A T E   A B S C H L U S S . T E X 
  ##header data
  append abschlTex {\documentclass[10pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage{german}
\usepackage{longtable}
\author{}
}
append abschlTex {\title} \{ $myComp {\\} Erfolgsrechnung { } $jahr \}
append abschlTex { 
\begin{document}
\maketitle
\begin{small}
\begin{longtable}{ll p{0.4\textwidth} rrrr}
%1. Einnahmen
\caption{Einnahmen} \\
\textbf{R.Nr} & \textbf{Datum} & \textbf{Adresse} & 
\textbf{Netto} &  
\textbf{Mwst.} & 
\textbf{Spesen} & 
\textbf{Bezahlt} \\
\endhead
}
  ##1.Einnahmen
  append abschlTex $einnahmenTex
#  append abschlTex {\\}
  append abschlTex {\multicolumn{3}{l}{\textbf{Einnahmen total}}} &
  append abschlTex {\textbf} \{ $bruTot \} &
  append abschlTex {\textbf} \{ $vatTot \} &
  append abschlTex {\textbf} \{ $expTot \} &
  append abschlTex [expr $bruTot - $vatTot - $expTot] {\\} \n
  append abschlTex {&&abzügl. Mwst.&&&} \{ \$ \- $vatTot \$ \} {\\} \n
  append abschlTex {&&abzügl. Spesen&&&} \{ \$ \- $expTot \$ \} {\\} \n
  append abschlTex {\multicolumn{3}{l}{\textbf{EINNAHMEN TOTAL NETTO}}&&&&\textbf} \{ $netTot \} {\\} \n
  ##2.Auslagen
  append abschlTex {\caption{Auslagen} \\}
  append abschlTex $auslagenTex
  append abschlTex {\multicolumn{3}{l}{\textbf{AUSLAGEN TOTAL}} &&&& \textbf} \{ \- $expTot \} {\\\\} \n
  ##3. Reingewinn
  append abschlTex {\multicolumn{3}{l}{\textbf{REINGEWINN}} &&&& \textbf} \{ $netProfit \} {\\} \n
  ##4. End
  append abschlTex {
\end{longtable}
\end{small}
\end{document}
  }
  
  #Save to file
  set chan [open $abschlussTexFile w]
  puts $chan $abschlTex
  close $chan
  
  #TODO: for testing only > need PDF!
  NewsHandler::QueryNews "$abschlussTexFile gespeichert" green
  return 0
} ;#END abschluss2latex

# printAbschluss
##runs abschluss2latex & produces Print dialog
##called by .abschlussPrintB button
proc printAbschluss {} {
  global texDir reportDir
  
  #TODO: globalize paths (see calling prog)
  set abschlussTexFile Abschluss.tex
  set abschlussTexPath [file join $texDir $abschlussTexFile]
  append abschlussPdfPath [file join $reportDir [file tail $abschlussTexFile]] . pdf
       
  #1. run abschluss2latex
  if [catch abschluss2latex] {
    NewsHandler::QueryNews "Es ist ein Fehler aufgetreten..." red
    return 1
  }
  
  #2. latex2pdf
    eval exec -- pdflatex -interaction nonstopmode -output-directory=$reportDir $abschlussTexPath
    NewsHandler::QueryNews "Das PDF ist nun unter $abschlussPdfPath bereit. Wir versuchen es nun für Sie zur Weiterbearbeitung zu öffnen." green

#TODO get goodies from ...?
  #3. View PDF / ?PS / Print to Lpr
set betrachter evince
exec $betrachter $abschlussPdfPath
  return 0
}
