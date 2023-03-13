# ~/TkOffice/prog/tkoffice-report.tcl
# called by tkoffice-gui.tcl
# Updated: 7mch23

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
 	set jahresliste [lsort -unique [db eval "SELECT strftime('%Y', f_date) FROM invoice"]]
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
#  J A H R E S S P E S E N
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
  pack forget .abschlussM .spesenAbbruchB .reportT .abschlussScr .expnameE .expvalueE .spesenB
  pack .spesenM -side left
  pack .spesenAddB .spesenDeleteB -in .n.t6 -side right -anchor se
  pack .spesenLB -in .n.t6 -fill y -pady 50
  
  .spesenAddB conf -text "Eintrag hinzufügen" -command {addExpenses}
  .spesenLB delete 0 end
  
  #get listbox values from DB
  set numL  [db eval "Select ROW_NUMBER() OVER() from spesen"]
  #db eval "SELECT count() from spesen" - for num of entries
  
  foreach num $numL {
    set row [db eval "select * FROM (                            
      select ROW_NUMBER() OVER() as row_num,name,value from spesen ) t 
      where row_num=$num" ]

#puts $t
#puts $name
#puts $value
  
 #   set name [db eval "SELECT name FROM spesen WHERE num=$num"]
 #   set value [db eval "SELECT value FROM spesen WHERE num=$num"]
    .spesenLB insert end $row
  }
}

proc addExpenses {} {
  pack .spesenAbbruchB .spesenAddB .expvalueE .expnameE -in .n.t6 -side right -anchor se
  pack forget .spesenDeleteB
  .spesenAddB conf -text "[mc save]" -command {saveExpenses}
  set ::expname "[mc description]"
  set ::expval "[mc betrag]"
  .expnameE conf -fg grey -validate focusin -vcmd {%W delete 0 end;%W conf -fg black;return 0}
  .expvalueE conf -fg grey -validate focusin -vcmd {%W delete 0 end; %W conf -fg black; return 0}

#  manageExpenses
}

proc saveExpenses {} {
  global db

  set name [.expnameE get]
  set value [.expvalueE get]
 
  db eval "INSERT INTO spesen (name,value) VALUES ('$name',$value)"

	if [db errorcode] {
	  NewsHandler::QueryNews "Ging nicht..." red
	} else {
  	reportResult "Ging doch" "Eintrag gespeichert."
  }
  manageExpenses
}

proc deleteExpenses {} {
  global db

  #1 delete from DB
  set value [lindex [.spesenLB get active] end]
  set token [db eval "DELETE FROM spesen WHERE value=$value"]
 
 #TODO check errorcode, s.o. 
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
  
  set jahr [.abschlussJahrSB get]
  set einnahmenTexFile [file join $texDir abschlussEinnahmen.tex]
  set auslagenTexFile  [file join $texDir abschlussAuslagen.tex]
  set h [expr [winfo height .n.t3] - 100]
  set w [expr int(1.5 * $h)]
  
  # Prepare canvas & textwin dimensions
  set t .reportT
  $t delete 1.0 end
  .reportC conf -width $w -height $h -bg blue
  .reportC create window 0 0 -tags repwin -window .reportT -anchor nw -width $w -height $h
  .reportC itemconf repwin -width $w -height $h

  #Get annual invoice & expenditure data from DB
  ## invoice data stored in report${jahr} namespace
  listInvoices $jahr
  listExpenses
  
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
    
  
 	# F i l l   t e x t w i n

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
  
  ##Titel
  $t insert end "Rch.Nr.\tDatum\tAnschrift\tNetto ${currency}\tMwst. ${vat}%\tSpesen\tEingänge ${currency}\n" T3
puts $currency


#TODO  'finalsum' is exclusive vat & Auslagen - list Auslagen anyway because payedsum may differ


  #compute sum total & insert text lines
 

  namespace eval report {

    variable sumtotal 0
    
    foreach n $invL {
   
      #set vars from array
      set payedsum [lindex [array get $n payedsum] 1]
      set invDat [lindex [array get $n invDat] 1]
      set invAdr [lindex [array get $n invAdr] 1]
      set netto [lindex [array get $n netto] 1]
      set vat [lindex [array get $n VAT] 1]
      set auslage [lindex [array get $n auslage] 1]
      
      #Update sum total
      set sumtotal [roundDecimal [expr $sumtotal + $payedsum]]
	    
      if ![ string is double $auslage ] {
        set auslage ""
      }

      #Insert row in text window
	    .reportT insert end "\n${n}\t${invDat}\t${invAdr}\t${netto}\t${vat}\t ${auslage}\t${payedsum}"

    }
	  
	  .reportT insert end "\n\nEinnahmen total\t\t\t\t\t\t\t $sumtotal" T3

  } ;# END report ns
	
	$t insert end "\n\nAuslagen\n" T2
	$t insert end $report::spesenList

  ##compute Reingewinn
  set sumtotal $report::sumtotal
  set spesenTotal $report::spesenTotal
  set netProfit [roundDecimal [expr $sumtotal - $spesenTotal]]
  if {$netProfit < 0} {
    set netProfit 0.00
  }

  $t insert end "\nAuslagen total\t\t\t\t\t\t\t-${spesenTotal} \n\n" T3
  $t insert end "Reingewinn\t\t\t\t\t\t\t$netProfit" T2

  #Pack & configure print button
  pack .reportPrintBtn -in .n.t3.rightF -side bottom -anchor sw
 .reportPrintBtn conf -command "canvas2ps .reportC .reportT $jahr"
 .reportT conf -borderwidth 3 -padx 7 -pady 7
   
  namespace delete report
  
} ;#END createReport


proc listInvoices {jahr} { 

 
  namespace eval report {

    upvar #0 ::jahr jahr
  
    
#TODO: WHAT ABOUT payeddate vs. f_date ?????????????????????
##is this still functional?
    
	  #get data from $jahr's invoices + 'payeddate = $jahr' from any previous invoices
	  
	  set res [db eval "SELECT
	  f_number,
	  f_date,
	  addressheader,
	  finalsum,
	  vatlesssum,
	  payedsum,
	  auslage 
	  FROM invoice 
	  WHERE strftime('%Y', payeddate) = '$jahr'
	  OR strftime('%Y', f_date) = '$jahr'
	  ORDER BY f_number ASC"]

	  #set num. of entries for textwin & put values into arrays per No.
	  set invL [db eval	"SELECT f_number FROM invoice WHERE strftime('%Y', f_date) = '$jahr'"]
	  
	  
	  foreach invNo $invL {
	  
		  # f_date currency vatlesssum finalsum payedsum auslage
		  set date [db eval "SELECT f_date FROM invoice WHERE f_number = $invNo"] 
		  array set $invNo "invDat $date" 
	  
		  set adr [db eval "SELECT addressheader FROM invoice WHERE f_number = $invNo"] 
		  array set $invNo "invAdr $adr" 
	  
		  set netto [db eval "SELECT vatlesssum FROM invoice WHERE f_number = $invNo"] 
		  array set $invNo "netto $netto"
	   	
		  set currency [db eval "SELECT currency FROM invoice WHERE f_number = $invNo"] 
		  array set $invNo "currency $currency"
			   	
		  set finalsum [db eval "SELECT finalsum FROM invoice WHERE f_number = $invNo"] 
		  array set $invNo "finalsum $finalsum"
		  
		  set payedsum [db eval "SELECT payedsum FROM invoice WHERE f_number = $invNo"] 
		  array set $invNo "payedsum $payedsum"
	   	
		  set auslage [db eval "SELECT auslage FROM invoice WHERE f_number = $invNo"] 
		  array set $invNo "auslage $auslage" 
	  
		  ##compute finalsum on basis of $vat from config
		  if {! $vat > 0} {
    		array set $invNo {VAT 0}
    		array set $invNo "netto $finalsum"
		  } else {
			  array	set $invNo "VAT [expr $finalsum - $netto]"
    	}
    	
	  }
	  
  } ;#END ns report
  	
} ;#END listInvoices


### A U S G A B E N
##Note: code copied from manageExpenses

  proc listExpenses {} {

    set numL [db eval "Select ROW_NUMBER() OVER() from spesen"] 
   
    foreach num $numL {
   
      set row [db eval "select * FROM (                            
        select ROW_NUMBER() OVER() as row_num,name,value from spesen ) t 
        where row_num=$num" ]
      
      ##1.prepare for text window
      set row [linsert $row 2 "          "]
      append report::spesenList $row \n

    }
    
    set report::spesenTotal [db eval "SELECT SUM(value) FROM spesen"]

} ;#END listExpenses


proc canvas2ps {c w year} {

  global tmpDir reportDir

#  set tmpDir /tmp
#  set c .reportC
#  set w .reportT

  $w conf -bg white
  $w yview moveto 1.0
  set numLines [$w count -lines 1.0 end]  
  set pageNo 1
  
  set tmpfile $tmpDir/report_${year}_${pageNo}.ps
  set reportPath $reportDir/Report_${year}.pdf
  set cmd "$c postscript -rotate 1 -file $tmpfile"  
  
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
    
    $w conf -bg white
    $c postscript -rotate 1 -file $reportPs
    NewsHandler::QueryNews "Wir versuchen nun, den Bericht anzuzeigen. Im Anzeigeprogramm können Sie ihn ausdrucken." orange
    
    exec xdg-open $reportPs
    set res [tk_messageBox -type yesno -message "Wollen Sie die Datei $reportPs abschliessend in $reportDir speichern?"]
    
    if {$res == "yes"} {
      
#      exec ps2pdf $reportPs $reportPdf
      file copy $reportPs $reportDir
    
      NewsHandler::QueryNews "Falls der Bericht noch nicht gedruckt ist, können Sie die Datei $reportDir/$reportPs drucken oder im blauen Fenster nochmals bearbeiten." orange
      
    }

  } else {
  
  ###############################
  # Handle multiple pages
  ###############################
  $w tag conf hide -elide 1
  $w tag conf show -elide 0

  #divide text by fix page height
  set wholeBlocks [expr $::numLines / 40]
  
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
    $c postscript -rotate 1 -file $tmpDir/report_${year}_${pageNo}.ps
    
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
  $c postscript -rotate 1 -file $tmpDir/report_${year}_${pageNo}.ps
  
  
  ## 4. View full document in PDF 
  ##Postscript all *ps in landscape format to *.ps in one batch:  
## -c "<</Orientation 3>> setpagedevice" - seems unnecessary
  exec gs -dNOPAUSE -dAutoRotatePages=/None -sDEVICE=pdfwrite -sOUTPUTFILE=$tmpDir/Report_${year}.ps -dBATCH $tmpDir/report_${year}*.ps
  
  NewsHandler::QueryNews "Wir versuchen nun, den Bericht anzuzeigen. Im Anzeigeprogramm können Sie ihn dann ausdrucken." orange
    
  exec xdg-open $tmpDir/Report_${year}.ps
  set res [tk_messageBox -type yesno -message "Wollen Sie die Datei Report_${year}.ps abschliessend in $reportDir speichern?"]
  if {$res == "yes"} {
    file copy $report_${year}.ps $reportDir
  }
 }
 
  ## 5. Final cleanup
  $w conf -bg lightblue
  $w tag delete hide
  $w yview moveto 0.0

} ;#END canvas2ps





# O B S O L E T E ###########################################################

## canvas2ps
# # Capture a window into an image
# # Author: David Easton
###called by .reportPrintBtn
#proc canvas2ps {canv jahr} {
#  global reportDir tmpDir
#  set win .reportT
#  set origCanvHeight [winfo height $canv]
#    
#  #1. move win to top position + make first PS page
#    raise $win
#    update
#    $win yview moveto 0.0 
#    raise $win
#    update

#  set pageNo 1

#  #A) Für 1st page 
#  set file [file join $tmpDir abschluss_$pageNo.ps]
#  $canv postscript -colormode mono -file $file 
#  #exec ps2pdf $file
#   
#  #move 1 page for multiple pages
#  set visFraction [$win yview]
#  set begVisible [lindex $visFraction 0] 
#  set endVisible [lindex $visFraction 1]
#  $win yview moveto $endVisible


#set lastVisible $endVisible

#  while {$endVisible < 1.0} {

#    incr pageNo
#        
#    set lastVisible $endVisible
#    raise $win
#    update
#    
#    set file [file join $tmpDir abschluss_$pageNo.ps]
#    $canv postscript -colormode gray -file $file
#    #exec ps2pdf $file

#    #move 1 page
#    set visFraction [$win yview]
#    set begVisible $endVisible
#    set endVisible [lindex $visFraction 1]
#    $win yview moveto $endVisible      
#    
#	}

##puts $endVisible
##puts $lastVisible	

#	#3. Compute remaining page height & adapt window dimension
#    if {$begVisible < $lastVisible} {
#        set cutoutPercent [expr $begVisible - $lastVisible]
#        set hiddenHeight [expr round($cutoutPercent * $origCanvHeight)]
#        set visHeight [expr $origCanvHeight - $hiddenHeight]
#        $canv itemconf repwin -height $visHeight
#        $canv conf -height $visHeight 
#    }

#  incr pageNo
#  
#  #4. Make last page  ????
#  raise $win
#  update
#    $canv postscript -colormode gray -rotate 1 -file $reportPath
#    
#    #5. Make full report ????
#  append reportName report . $jahr _ $pageNo . ps
#  set reportPath [file join $tmpDir $reportName]
#  
##Postscript all *ps in landscape format to *.ps in one batch:  
#exec gs -dNOPAUSE -dAutoRotatePages=/None -sDEVICE=pdfwrite -sOUTPUTFILE=ABSCHLUSS.pdf -dBATCH $tmpDir/abschluss*.ps
## -c "<</Orientation 3>> setpagedevice" - seems unnecessary

#  #Join postscript files
##  lappend fileL [glob $tmpDir/abschluss_*]
##  exec psjoin $tmpDir/abschluss_1.ps $tmpDir/abschluss_2.ps > $tmpDir/ABSCHLUSS.ps
#  
#  
#  exec xdg-open $tmpDir/ABSCHLUSS.pdf
# 
#  
#  #5. Restore original dimensions
#  $canv itemconf textwin -height $origCanvHeight
#  $canv conf -height $origCanvHeight 

#} ;#END canvas2ps
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


