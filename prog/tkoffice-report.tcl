# ~/TkOffice/prog/tkoffice-report.tcl
# called by tkoffice-gui.tcl
# Updated: 7feb20

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

# mangeExpenses
##
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

#TODO 
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
	
	#get -spesen- from DB
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
##recreates Abschluss.tex
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
  #TODO: was ist das? - jesch balagan im ha-sechumim!
#TODO why no work with payedsum???
#  append abschlTex & & & & & & $auslagen::netProfit

} ;#END abschluss2latex

# auslagen2latex
##extract Auslagen from .abschlussT window & save to TeX
##called by printAbschluss
proc auslagen2latex {} {
  global tkofficeDir tmpDir texDir 
  set w .abschlussT
  set auslagenTex [file join $texDir abschlussAuslagen.tex]
  
  #Mark beginning + end of "Auslagen"
#  set begAuslagenI [$w search "Auslagen" 1.0 end]  
#  $w mark set begAuslagen [string map {0 end} $begAuslagenI]
#  #search special char for end of text, must remain in file!
#  set endAuslagenI [$w search \u80 1.0 end]
#  $w mark set endAuslagen $endAuslagenI

  #Extract dump & prepare for LateX table
  #set beg [lindex [$w dump -mark begAuslagen] 2]
  #set end [lindex [$w dump -mark endAuslagen] 2]
  
  set t [$w dump -text $auslagen::begPos $auslagen::endPos]
  regsub -line -all {.*(text.\u007B)(.*)} $t {\2} t
  regsub -all {\t} $t {\&} t
  regsub -all {[{}]} $t {} t

  #cut any tailing line number
  set startSearch [expr [string length $t] - 5]
  regsub -start $startSearch { \d.*$} $t {} t
  
  #Save to auslagen.tex
  set chan [open $auslagenTex w]
  puts $chan $t
  close $chan
  
  #TODO: testing:
  return $t
  
} ;#END auslagenLatex






proc printAbschluss {} {
  global reportDir texDir myComp
  
  set jahr [.abschlussJahrSB get]
  set einnahmenTexFile [file join $texDir abschlussEinnahmen.tex]
  set auslagenTexFile  [file join $texDir abschlussAuslagen.tex]
  set abschlussTexFile [file join $texDir Abschluss.tex]
  set abschlussPdfFile [file join $reportDir Abschluss${jahr}.pdf]
  
  set einnahmenTex [read [open $einnahmenTexFile]]
  set auslagenTex  [read [open $auslagenTexFile]]
  
  #Recreate Abschluss.tex
  append abschlTex {
\documentclass[12pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage{amsmath}
\usepackage{amsfonts}
\usepackage{amssymb}
}
append abschlTex \\ title \{ $myComp \\\\ Erfolgsrechnung { } $jahr \}
append abschlTex {
\begin{document}
\maketitle
\begin{table}{}
\caption{EINNAHMEN}
\begin{tabular}{lllrrrrr}
}
#append abschlTex {\\} include \{ $einnahmenTexFile \}
append abschlTex $einnahmenTex
append abschlTex {
\end{tabular}
\caption{AUSLAGEN}
\begin{tabular}{lr}
}
#append abschlTex {\\} include \{ $auslagenTexFile \}
append abschlTex $auslagenTex
append abschlTex {
\end{tabular}
\caption{REINGEWINN}
}
append abschlTex & & & & & & $auslagen::netProfit
append abschlTex {
\end{table}
\end{document}
}

  #Save to Abschluss.tex
  set chan [open $abschlussTexFile w]
  puts $chan $abschlTex
  close $chan
  
  #Latex to pdf
  catch {eval exec pdflatex $abschlussTexFile $abschlussPdfFile}

} ;#END printAbschluss


##a)exports text from Abschluss text widget and writes it to TEXT FILE
##b)tries printing via lpr
proc printAbschluss-ALT {} {

  
#get expenses list from text window
#set beg [$t index begExpenses]
#set end [$t index endExpenses]

#Extract raw text for export to LateX
regsub -all -line {(^.*text )\{} $T "" T
regsub -all {[{}]} $T "" T
#TODO
#warum geht das nicht? will mittleren Teil ohne {} extrahieren
regsub -all -line {(^.*text )(\{.*\})(.*$)} $T "\1"
regsub {(^.*text )(.*)} $t {\2} - das geht, aber Text in {...}

#das geht 100% :-)
#regsub -all -line {(^.*text.[{}])(.*)([{}].*$)} $t {\2}
regsub -line -all {.*(text.\u007B)(.*)} $t {\2}
regsub -all {\t} $r {\&}

set abschlussTagsDump [$t dump -tag 1.0 end]
regexp {tagon expenses} $abschlussTagsDump
regexp {tagoff expenses} $abschlussTagsDump

set index1 [string first {tagon expenses} $abschlussTagsDump]
set in1 [expr $index1 + 14]
set in2 [expr $in1 + 6]
 
set index2 [string first {tagoff expenses} $abschlussTagsDump]
regsub ... $abschlussRohTxt abschlussTxt
  
  #format for LateX
  
  
  
  set win .n.t3.abschlussT
  set reportsDir [file join $tkofficeDir reports]
  file mkdir $reportsDir
  set abschlusstext [$win get 1.0 end]
  set jahr [.abschlussJahrSB get]
  set abschlussTxt [file join $reportsDir abschluss${jahr}.txt]
 # append abschlussPs [file root $abschlussTxt] . ps
  append abschlussPdf [file root $abschlussTxt] . pdf
  append abschlussPng [file root $abschlussTxt] . png

  
  #1.Write to text file
  set chan [open $abschlussTxt w]
  puts $chan $abschlusstext
  close $chan

  #2.Try screenshot, hiding last top win from last page to avoid doubling
  $win tag conf hide -elide 1
  
  ##move win to top & get visible window coords
  $win yview moveto 0.0
  set visibleFraction [$win yview]
  set begVisible [lindex $visibleFraction 0] 
  set endVisible [lindex $visibleFraction 1]
  set totalLines [$win count -lines 1.0 end]

  #Check presence of Netpbm & GhostScript  
  if {[auto_execok ps2pdf] == ""} {lappend missing {ps2pdf (aus GhostScript)}}
  if {[auto_execok ppmtopgm] == ""} {lappend missing Netpbm} {
    NewsHandler::QueryNews "Für Ausdrucke in hoher Qualität muss '$missing' installiert sein." orange
    NewsHandler::QueryNews "Sie können vorläufig die Textdatei $abschlussTxt in einem Textbearbeitungsprogramm nach Wunsch formatieren und ausdrucken." lightblue
    return 1
  }


  set pageNo 0
  
  while {$endVisible < 1.0} {
    
#    incr pageNo
    captureWindow $win $pageNo
    
    $win yview moveto $endVisible
    set begVisible $endVisible
    set endVisible [lindex [$win yview] 1]
  }
  
  #After end is visible, hide top section for last remainder to avoid line duplication
  set fraction [lindex [$win yview ] 0]
  set begVisible [expr round($fraction * $totalLines)] 
  $win tag add hide 0.0 $begVisible.end
  
  #Try saving to PS&PDF - TODO clarify paths
  #exec pnmcrop 'letztes Bild'
  catch {exec pnmtops $abschlussPpm > $abschlussPs}
  catch {exec ps2pdf $abschlussPs}

	#check results 
	if [file exists $abschlussPng] {append fileList "\n[file tail $abschlussPng]"}
	if [file exists $abschlussPs] {append fileList "\n[file tail $abschlussPs]"}
	if [file exists $abschlussPdf] {append fileList "\n[file tail $abschlussPdf"}
	if {$fileList == ""} {set fileList $abschlussPpm; set extra "\nFür ein besseres Resultat müssen Netpbm und GhostScript installiert sein."} {set extra ""}
  NewsHandler::QueryNews "Der Jahresabschluss konnte unter folgenden Formaten in $reportDir gespeichert werden: $fileList $extra" green 



#TODO geht nicht wegen Grösse!!!
  set pnmtops [auto_execok pnmtops]
#  set pnmdir $tmpDir/tkoffice_pnm
#  cd $pnmDir
  foreach f $pnmList {
    catch {
    exec cat $f | $pnmtops -imagewidth 7  >> $tmpDir/abschluss2019.ps} 
  }
#  foreach f $pnmList {
#    set chan [open $f]
#    set pnm [read $chan]
#    close $chan
#    puts $pnmChan $pnm
#  }
#  close $pnmChan
  
return
  
  #TODO send PDF to printer
  catch {exec ps2pdf > $abschlussPdf} 
  NewsHandler::QueryNews "Abschluss als $abschlussPdf gespeichert." green

  #Try converting to PS
  if {[auto_execok paps] == ""} {
    set path $abschlussTxt
  } else {
    set path $abschlussPs
    exec paps --landscape --font="Monospace10" $abschlussTxt > $abschlussPs
  }
  NewsHandler::QueryNews "Abschluss in $path gespeichert." green
   
  #Try printing PS or TXT
  set printer [auto_execok lpr]
  if {$printer != ""} {
    NewsHandler::QueryNews "Abschluss wird jetzt gedruckt..." lightblue
    if [catch {exec $printer $path}] {
      NewsHandler::QueryNews "Datei konnte nicht gedruckt werden.\nSie finden den Jahresabschluss unter $abschlussPath zur weiteren Bearbeitung." orange
    }
  }
} ;#END printAbschluss

