# ~/TkOffice/prog/invoice-procs.tcl
# called by tkoffice-gui.tcl
# Aktualisiert: 1nov17
# Restored: 6dez19

source $confFile
################################################################################################################
################# N E W   I N V O I C E   P R O C S ############################################################
################################################################################################################

set vorlageTex [file join $texDir rechnung-vorlage.tex]
set dataFile [file join $texDir invdata.tex]
set itemFile [file join $texDir invitems.tex]
 
# resetNewInvDialog
##called by Main + "Abbruch Rechnung"
proc resetNewInvDialog {} {
  #Cleanup ::rows & frame
  catch {namespace delete rows}
  foreach w [pack slaves .invoiceFrame] {
    pack forget $w
  }

  #Set vars to 0
  namespace eval rows {
    set bill 0
    set buch 0
    set auslage 0
    set rabatt 0
  }
  
  updateArticleList
  
  #Configure message labels & pack
  .subtotalM conf -textvar rows::bill
  .abzugM conf -textvar rows::auslage
  .totalM conf -textvar rows::buch
  pack .subtotalL .subtotalM .abzugL .abzugM .totalL .totalM -side left -in .n.t2.bottomF

  #create Addrow button
  catch {button .addrowB -width 100 -text "Posten hinzufügen" -command addInvRow}
  catch {message .einheit -textvariable unit}
  catch {message .einzel -textvariable einzel}

  #Configure Menge entry
  set menge "Menge"
  .mengeE configure -validate focusin -validatecommand {
    %W conf -fg black
    set menge ""
    return 0
  }

  pack .invcondL .invcondSB .invauftrdatL .invauftrdatE .invrefL .invrefE .invcomL .invcomE -in .n.t2.f1 -side left -fill x 
  pack .invArtlistL -in .n.t2.f1 -before .n.t2.f2 -anchor w 
  pack .invArtNumSB .mengeE .invArtUnitL .invArtNameL .invArtPriceL -in .n.t2.f2 -side left -fill x
  pack .addrowB -in .n.t2.f2 -side right
  
  #Reset Buttons
  .abbruchInvB conf -state disabled
  .saveInvB conf -state disabled -command "
    .saveInvB conf -activebackground #ececec -state normal
    doSaveInv
    "

} ;#END resetNewInvDialog

# addInvRow
##called by setupNewInvDialog
proc addInvRow {} {
  
  #Configure Abbruch button
  pack .abbruchInvB .saveInvB -in .n.t2.bottomF -side right
  .saveInvB conf -activebackground skyblue -state normal
  .abbruchInvB conf -activebackground red -state normal -command {resetNewInvDialog}

  if [catch {namespace children rows}] {
    set lastrow 0
 #   set rowtot 0
  }  else {
    #get last namespace no.
    set lastrow [namespace tail [lindex [namespace children rows] end]]
  }

  #add new namespace no.
  namespace eval rows {
    variable rowtot
    variable rabatt
    set rowNo [incr lastrow 1]

    namespace eval $rowNo  {

      #get global vars
      set artName [.invArtNameL cget -text]
      set menge [.mengeE get]

#TODO bu gerek mi?
      if ![string is double $menge] {
        set menge 1
      }
      
      set artPrice [.invArtPriceL cget -text]
      set artUnit [.invArtUnitL cget -text]
      set artType [.invArtTypeL cget -text]
      set rowNo $::rows::rowNo
      
      set rowtot [expr $menge * $artPrice]

      #Create row frame
      catch {frame .invF${rowNo}}
      pack .invF${rowNo} -in .invoiceFrame -fill x -anchor w    

      #Create labels per row
      catch {label .mengeL${rowNo} -text $menge -bg lightblue -width 20 -justify left -anchor w}
      catch {label .artnameL${rowNo} -text $artName -bg lightblue -width 53 -justify left -anchor w}
      catch {label .artpriceL${rowNo} -text $artPrice -bg lightblue -width 10 -justify right -anchor w}
      catch {label .artunitL${rowNo} -text $artUnit -bg lightblue -width 5 -justify left -anchor w}
      catch {label .arttypeL${rowNo} -text $artType -bg lightblue -width 20 -justify right -anchor e}

      #Get current values from GUI
      set bill $rows::bill
      set buch $rows::buch
      set auslage $rows::auslage

      #Handle types
      set type [.arttypeL${rowNo} cget -text]
       
      ##a) normal     
      if {$type == ""} {
        set ::rows::bill [expr $bill + $rowtot]
        set ::rows::buch [expr $buch + $rowtot]

      ##b) "Rabatt" types - compute from $buch (abzgl. Spesen)
      } elseif {$type == "R"} {
    
        set rabatt [expr ($buch * $artPrice / 100)]
        set ::rows::buch [expr $buch - $rabatt]
        set ::rows::bill [expr $bill - $rabatt]
        set ::rows::rabatt $rabatt
        .arttypeL${rowNo} conf -bg yellow
        .artpriceL${rowNo} conf -text "-${rabatt}"   
        .mengeE conf -state disabled
        set menge 1
        
      ##c) "Auslage" types - add to $bill, not to $buch     
      } elseif {$type == "A"} {
        
          set ::rows::auslage "-[expr $auslage + $rowtot]"
          set ::rows::bill [expr $bill + $rowtot]
          .arttypeL${rowNo} conf -bg orange
      }

      catch {label .rowtotL${rowNo} -text $rowtot -bg lightblue  -width 50 -justify left -anchor w}
      pack .artnameL${rowNo} .artpriceL${rowNo} .mengeL${rowNo} -in .invF${rowNo} -anchor w -fill x -side left
      pack .artunitL${rowNo} .rowtotL${rowNo} .arttypeL${rowNo} -in .invF${rowNo} -anchor w -fill x -side left

      #Reduce amounts to 2 decimal points
      set ::rows::bill [expr {double(round(100*$rows::bill))/100}]
      set ::rows::buch [expr {double(round(100*$rows::buch))/100}]
      if {[info exists rabatt] && $rabatt >0} {
        set ::rows::rabatt [expr {double(round(100*$rows::rabatt))/100}]
      }
      
      #Export beschr cumulatively for use in saveInv2DB & fillAdrInvWin
      set separator {}
      if [info exists ::rows::beschr] {
        set separator { /}
      }
      append ::rows::beschr $separator ${menge} { } $artName
    }
  }

} ;#END addInvRow

# doSaveInv
##coordinates invoice saving + printing progs
##evaluates exit codes
##called by .saveInvB button
proc doSaveInv {} {
#TODO: remove catches, getting DVIPS and LATEX errors which are NOT errors!
  #1.Save to DB
  if [catch saveInv2DB res] {
    NewsHandler::QueryNews $res red
    return 1
  } 
  #2. LatexInvoice
  if [catch {latexInvoice $::Latex::invNo dvi} res] {
    NewsHandler::QueryNews $res red
    return 1
  }
  
  #3. ? NO! doPrintInv ?
  # ? doViewInvoice ?

  return 0
}

# saveInv2DB
##saves new invoice to DB
##called by doSaveInv
proc saveInv2DB {} {
  global db adrNo env msg texDir itemFile
  global cond ref comm auftrDat vat

  #1. Get invNo & export to ::Latex 
  #TODO: incorporate in DB as 'SERIAL', starting with %YY
	set invNo [createNewNumber invoice]
	namespace eval Latex {}
	set ::Latex::invNo $invNo
	
	#Get current vars from GUI
  set shortAdr "$::name1 $::name2, $::city"
  set shortDesc $rows::beschr
  set subtot $rows::buch
  set auslage $rows::auslage
  
  #Create itemList for itemFile (needed for LaTeX)
  foreach w [namespace children rows] {
    set artUnit [.artunitL[namespace tail $w] cget -text]
    set artPrice [.artpriceL[namespace tail $w] cget -text]
    set artType [.arttypeL[namespace tail $w] cget -text]
    set artName [.artnameL[namespace tail $w] cget -text]
    set menge [.mengeL[namespace tail $w] cget -text]
    #Check if Discount
    if {$artType==""} {
      append itemList \\Fee\{ $artName { } \( pro { } $artUnit \) \} \{ $artPrice \} \{ $menge \} \n
    } elseif {$artType=="R"} {
      append itemList \\Discount\{ $artName \} \{ $rows::rabatt \} \n
    #Check if Auslage
    } elseif {$artType=="A"} {
      append itemList \\EBC\{ $artName \} \{ $artPrice \} \n
    }
  } ;#END foreach w

  #1. Save itemList to ItemFile & convert to Hex for DB
  set chan [open $itemFile w]
  puts $chan $itemList
  close $chan
  set itemListHex [binary encode hex $itemList]

  #2. Set payedsum=finalsum and ts=3 if cond="bar"
	if {$cond=="bar"} {
    set ts 3
    set payedsum $subtot
  } else {
    set ts 1
    set payedsum 0
  }	

  #3. Make entry for vatlesssum if different from finalsum
  set vatlesssum $subtot
  if {$vat < 0} {
    set vatlesssum [expr ($vat * $finalsum)/100]
  }

  #3. Save new invoice to DB
  set token [pg_exec $db "INSERT INTO invoice 
    (
    objectid,
    ts,
    customeroid, 
    addressheader, 
    shortdescription, 
    finalsum, 
    payedsum,
    vatlesssum,
    auslage,
    f_number,
    f_date,
    f_comment,
    ref,
    cond,
    items
    ) 
  VALUES 
    (
    $invNo,
    $ts,
    $adrNo,
    '$shortAdr',
    '$shortDesc',
    $subtot,
    $payedsum,
    $vatlesssum,
    $auslage,
    $invNo,
    to_date('$auftrDat','DD MM YYYY'),
    '$comm',
    '$ref',
    '$cond',
    '$itemListHex'
    )"]

 
  proc meyutar {} {
   #4.Update credit in 'address'
  set adrId [pg_result [pg_exec $db "SELECT customeroid FROM invoice WHERE f_number=$invNo"] -list]
  set creditT [pg_exec $db "SELECT credit from address WHERE objectid=$adrId"]
  set currCredit [pg_result $creditT -list]
  if ![string is double $currCredit] {
    set currCredit 0
  }
  ##Deduce new debit from credit -ginge auch so: SET credit = (credit - $subtot)
  #This is not necessary, credit is updated when entry made
  set newCredit [expr $credit - $subtot]
  set newCreditT [pg_exec $db "UPDATE address SET credit = $newCredit WHERE objectid=$adrId"]
  set ::credit $newCredit
  reportResult $newCreditT "Kundenguthaben aktualisiert: $newCredit" 
  }
  
#TODO does this belong here? should we use reportResult instead?
  if {[pg_result $token -error] != ""} {
    NewsHandler::QueryNews "Rechnung $invNo nicht gespeichert:\n[pg_result $token -error ]" red
    return 1
  } else {
   	NewsHandler::QueryNews "Rechnung $invNo gespeichert" lightgreen
    fillAdrInvWin $adrNo
    .saveInvB conf -text "Rechnung drucken" -command "doPrintNewInv $invNo"
    return 0
  } 

} ;#END saveInv2DB

# latexInvoice
##executes latex on vorlageTex OR dvips OR dvipdf on vorlageDvi
##with end types: DVI / PS / PDF
##called by doPrintNewInv & doPrintOldInv
#code from DKF: " With plenty of experience, 'nonstopmode' or 'batchmode' are most useful
# eval [list exec -- pdflatex --interaction=nonstopmode] $args
proc latexInvoice {invNo type} {

  global db adrSpin spoolDir vorlageTex texDir tmpDir
    
  #Prepare general vars & ::Latex namespace 
  set invDviPath [setInvPath $invNo dvi]
  
  namespace eval Latex {}
  set Latex::invTexPath [setInvPath $invNo tex]
  set Latex::tmpDir $tmpDir
  set Latex::spoolDir $spoolDir
  
  #A. do DVI > tmpDir
  if {$type == "dvi"} {
    namespace eval Latex {
      eval exec -- latex -draftmode -interaction nonstopmode -output-directory $tmpDir $invTexPath
    }
    return 0
  }
  
  #B. do PS > tmpDir - TODO test namespacing for all 3 functions
  if {$type == "ps"} {
    set Latex::invPsPath [setInvPath $invNo ps]
    set Latex::invDviPath $invDviPath
    namespace eval Latex {
      eval exec dvips -o $invPsPath $invDviPath
    }
    return 0
  }
    
  #C. do PDF > spoolDir
  if {$type == "pdf"} {
  
    namespace eval Latex {
    #TODO can pdf be done in draftmode?!
      eval exec -- pdflatex -draftmode -interaction nonstopmode -output-directory $spoolDir $invTexPath
    }  
    set invPdfPath [setInvPath $invNo pdf]
    NewsHandler::QueryNews "Das PDF-Dokument '[file tail $invPdfPath]' befindet sich in $spoolDir zur weiteren Bearbeitung." lightblue
    return 0
  }

  return 1
} ;#END latexInvoice


###############################################################################################
#### O L D   I N V O I C E   P R O C S  #######################################################
###############################################################################################

# fillAdrInvWin
##called by .adrSB 
##Note: ts=customerOID in 'address', now identical with objectid,needed for identification with 'invoice'
proc fillAdrInvWin {adrId} {
  global invF db

  #Delete previous frames
  set slaveList [pack slaves $invF]
  foreach  w $slaveList {
    foreach w [pack slaves $w] {
      pack forget $w
    }
  }
  #Clear old window+namespace
  if [namespace exists verbucht] {
    namespace delete verbucht
  }

  #Show Kundenguthaben
  set token [pg_exec $db "SELECT credit FROM address WHERE objectid=$adrId"]
  set credit [pg_result $token -list]
  if ![string is double $credit] {
    set credit 0.00
    .creditM conf -bg silver
  } elseif {$credit >0} {
    .creditM conf -bg lightgreen
    #set credit +${credit}
  } elseif {$credit <0} { 
    .creditM conf -bg red
  }
  set ::credit $credit
  
  #Add new namespace no.
  namespace eval verbucht {

    createPrintBitmap
    ##set ::verbucht vars to manipulate header visibility
    set eingabe 0
    set anzeige 0

    set adrId [.adrSB get]
    set idToken [pg_exec $db "SELECT ts FROM address WHERE objectid = $adrId"]
    set custId [pg_result $idToken -list]
    set invNoT [pg_exec $db "SELECT f_number FROM invoice WHERE customeroid = $custId"]
    set nTuples [pg_result $invNoT -numTuples]

  	if {$nTuples == -1} {return 1}

    set invDatT   [pg_exec $db "SELECT f_date FROM invoice WHERE customeroid = $custId"]
	  set beschrT   [pg_exec $db "SELECT shortdescription FROM invoice WHERE customeroid = $custId"]
	  set sumtotalT [pg_exec $db "SELECT finalsum FROM invoice WHERE customeroid = $custId"]
	  set payedsumT [pg_exec $db "SELECT payedsum FROM invoice WHERE customeroid = $custId"]
	  set statusT   [pg_exec $db "SELECT ts FROM invoice WHERE customeroid = $custId"]	
    set itemsT    [pg_exec $db "SELECT items FROM invoice WHERE items IS NOT NULL AND customeroid = $custId"]
    set commT     [pg_exec $db "SELECT f_comment FROM invoice WHERE customeroid = $custId"]
    set auslageT  [pg_exec $db "SELECT auslage FROM invoice WHERE customeroid = $custId"]
    
    for {set n 0; set ::umsatz 0} {$n<$nTuples} {incr n} {
    
      namespace eval $n {

        set n [namespace tail [namespace current]]
        set invF $::invF
        
        #compute Rechnungsbetrag from sumtotal+auslage
			  set sumtotal [pg_result $::verbucht::sumtotalT -getTuple $n]
			  set auslage [pg_result $::verbucht::auslageT -getTuple $n]
			  if {[string is double $auslage] && $auslage >0} {
  			  set invTotal [expr $sumtotal + $auslage]
			  } else {
			    set invTotal $sumtotal
			  } 
			  set ::umsatz [expr $::umsatz + $invTotal]
			  
			  set ts [pg_result $::verbucht::statusT -getTuple $n]
			  set invno [pg_result $::verbucht::invNoT -getTuple $n]
        set invdat [pg_result $::verbucht::invDatT -getTuple $n]
			  set beschr [pg_result $::verbucht::beschrT -getTuple $n]
        set comment [pg_result $::verbucht::commT -getTuple $n]

			  #increase but don't overwrite frames per line	
			  catch {frame $invF.$n}
			  pack $invF.$n -anchor nw -side top -fill x

    		#create entries per line, or refill present entries
			  catch {label $invF.$n.invNoL -width 10 -anchor w}
			  $invF.$n.invNoL conf -text $invno
        catch {label $invF.$n.invDatL -width 15 -anchor w -justify left}
        $invF.$n.invDatL conf -text $invdat
			  catch {label $invF.$n.beschr -width 50 -justify left -anchor w}
			  $invF.$n.beschr conf -text $beschr
			  catch {label $invF.$n.sumL -width 10 -justify right -anchor e}
			  $invF.$n.sumL conf -text $invTotal

        #create label/entry for Bezahlt, packed later
        set bezahlt [pg_result $::verbucht::payedsumT -getTuple $n]
        catch {label $invF.$n.payedL -width 13 -justify right -anchor e}
        $invF.$n.payedL conf -text $bezahlt

        ##create showInvoice button, to show up only if inv not empty
        catch {button $invF.$n.invshowB}
			  catch {label $invF.$n.commM -width 50 -justify left -anchor w -padx 35}

			  if {$ts==3} {
			  
			    $invF.$n.payedL conf -fg green
				  $invF.$n.commM conf -fg grey -text $comment -textvar {}
          pack $invF.$n.invNoL $invF.$n.invDatL $invF.$n.beschr $invF.$n.sumL $invF.$n.payedL $invF.$n.commM -side left
			  
        #If 1 or 2 make entry
			  } else {
			  
          $invF.$n.payedL conf -fg red			    
          catch {entry $invF.$n.zahlenE -bg beige -fg black -width 7 -justify left}
          $invF.$n.zahlenE conf -validate focusout -vcmd "saveInvEntry %P %W $n"

			    set ::verbucht::eingabe 1
          set restbetrag "Restbetrag eingeben und mit Tab-Taste quittieren"
          set gesamtbetrag "Zahlbetrag eingeben und mit Tab-Taste quittieren"
          $invF.$n.commM conf -fg red -textvar gesamtbetrag
				  pack $invF.$n.invNoL $invF.$n.invDatL $invF.$n.beschr $invF.$n.sumL $invF.$n.payedL $invF.$n.zahlenE $invF.$n.commM -side left
		  
        #if 2 (Teilzahlung) include payed amount
				  if {$ts==2} {

					  $invF.$n.commM conf -fg maroon -textvar restbetrag
					  $invF.$n.payedL conf -fg maroon
				  }

			  }

        #Create Show button if items not empty
        set itemsT $::verbucht::itemsT
        catch {set itemlist [pg_result $itemsT -getTuple $n] }
        if {[pg_result $itemsT -error] == "" && [info exists itemlist]} {
          set ::verbucht::anzeige 1
          $invF.$n.invshowB conf -width 40 -padx 40 -image $::verbucht::printBM -command "doPrintOldInv $invno"
          pack $invF.$n.invshowB -anchor e -side right
        }

  		} ;#end for loop
    } ;#END namspace $rowNo
    
#    if {$eingabe} {.invEntryH conf -state normal -bg lightblue} {.invEntryH conf -state disabled -bg #d9d9d9}
    if {$anzeige} {.invShowH conf -state normal} {.invShowH conf -state disabled -bg #d9d9d9}
    
  } ;#END namespace verbucht

} ;#END fillAdrInvWin

# fetchInvData
##1.retrieves invoice data from DB
##2.gets some vars from Config
##3.saves dataFile & itemFile for Latex processing
##called by invLatex & showInvoice
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
    NewsHandler::QueryNews "Konnte Rechnungsdaten Nr. $invNo nicht wiederherstellen.\n[pg_result $invToken -error]" red
    return 1
  }
  
  set ref       [lindex [pg_result $invToken -list] 0]
  set cond      [lindex [pg_result $invToken -list] 1]
  set auftrDat  [lindex [pg_result $invToken -list] 2]
  
  #make sure below signs are escaped since they interfere with LaTex commands
  set itemsHex  [lindex [pg_result $invToken -list] 3]
  regsub -all {%} $itemsHex {\%} itemsHex
  regsub -all {&} $itemsHex {\&} itemsHex
  regsub -all {$} $itemsHex {\$} itemsHex
  regsub -all {#} $itemsHex {\#} itemsHex
  regsub -all {_} $itemsHex {\_} itemsHex
  
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
  set chan [open $itemFile w]
  puts $chan $itemList
  close $chan

  #Cleanup
  pg_result $invToken -clear
  pg_result $adrToken -clear

  return 0
  
} ;#END fetchInvData


#Invoice view/print wrappers
proc doPrintOldInv {invNo} {

  #1. Get invoice data from DB
  if [catch "fetchInvData $invNo"] {
    NewsHandler::QueryNews "Rechnungsdaten $invNo konnten nicht wiederhergestellt werden. Ansicht/Ausdruck nicht möglich." red
    return 1
  }
  NewsHandler::QueryNews "Rechnung Nr. $invNo wird nun angezeigt.\nEine weitere Bearbeitung (Ausdruck/Versand) ist  aus dem Anzeigeprogramm möglich." lightblue

  after 5000 "latexInvoice $invNo dvi"
  after 9000 "viewInvoice $invNo"
  return 0
}

proc doPrintNewInv {invNo} {
  
  #1.convert DVI to PostScript
  latexInvoice $invNo ps
  
  #2. try printing to lpr
  NewsHandler::QueryNews "Sende Rechnung $invNo zum Drucker..." lightblue
printInvoice $invNo
return



 #TODO test this thoroughly, there may be no output at all!!!
  if [catch {printInvoice $invNo} res] {
    NewsHandler::QueryNews "$res\nDruck fehlgeschlagen!" red 
  }
  
  #3. viewInvoice anyway
  set invPsPath [setInvPath ps]
  after 5000 "NewsHandler::QueryNews 'Die Rechnung wird nun angezeigt. Sie können sie aus dem Anzeigeprogramm erneut ausdrucken bzw. nach PDF umwandeln.' orange"
  after 8000 "viewInvoice $invPsPath"
}

# setInvPath
##composes invoice name from company short name & invoice number
##returns invoice path with required ending: TEX / DVI / PS / PDF
##called by doPrintOldInv & doPrintNewInv
proc setInvPath {invNo type} {
  global spoolDir myComp vorlageTex tmpDir
  
  set compShortname [lindex $myComp 0]
  append invName invoice _ $compShortname - $invNo

  #Copy vorlageTex to $tmpDir/invName.tex for all types
  if {$type == "tex"} {
    append invTexName $invName . tex
    set invPath [file join $tmpDir $invTexName]
    file copy -force $vorlageTex $invPath
    
  } elseif {$type == "dvi"} {
    append invDviName $invName . dvi
    set invPath [file join $tmpDir $invDviName]
    
  } elseif {$type == "ps"} {  
    append invPsName $invName . ps
    set invPath [file join $tmpDir $invPsName]
    
  } elseif {$type == "pdf"} {  
    append invPdfName $invName . pdf
    set invPath [file join $spoolDir $invPdfName]
  }

  return $invPath
  
} ;#END setInvPath

# viewInvoice
##checks out DVI/PS capable viewer
##sends rechnung.dvi / rechnung.ps to prog for viewing
##called by "Ansicht" & "Rechnung drucken" buttons
proc viewInvoice {invNo} {
  global db itemFile vorlageTex texDir spoolDir

  set invDviPath [setInvPath $invNo dvi]

  #A) Show DVI
  if {[auto_execok XXevince] != ""} {
    set dviViewer "evince"
  } elseif {[auto_execok okular] != ""} {
    set dviViewer "okular"
  }
  
  if [info exists dviViewer] {
    if [catch {exec $dviViewer $invDviPath}] {
      viewInvOnCanvas $invNo
      return
    }
  }

proc meyutar! {} {
  #B) Convert to PS & show
  ##zathura can show & convert PS>PDf
  if {[auto_execok XXzathura] != ""} {
    set psViewer "zathura"
  ##gv can show PS + PDF, not convert
  } elseif {[auto_execok XXgv] != ""} {
    set psViewer "gv"
  }
  if [info exists psViewer] {
    set invPsPath [setInvPath $invNo ps]
    catch {latexInvoice $invNo ps} ;#catch wegen garbage output!
    
#TODO if catch funktioniert nicht, da immer grabage output! - but test if just with gv, if so throw out!!!!
    if [catch {exec $psViewer $invPsPath}] {
      viewInvOnCanvas $invNo
    }
    return 0
  }
}

  #B) Last resort: Try showing PS on canvas OR convert to PDF
  viewInvOnCanvas $invNo
  
  if [catch {XXviewInvOnCanvas $invNo}] {
   # set invPdfPath [setInvPath $invNo pdf]
   # catch {latexInvoice $invNo pdf}
   # return 1
  }
  
} ;#END viewInvoice


# printInvoice
##prints to printer or shows in view prog
##called after latex - TODO: what inv.name to print?
##called by "Rechnung drucken" button (neue Rechnung)
proc printInvoice {invNo} {

  #1. try direct printing to lpr  
  set invPsPath [setInvPath $invNo ps]
  NewsHandler::QueryNews "Die Rechnung $invNo wird zum Drucker geschickt." orange

#TODO Hängt wenn lpr auf Drucker wartet!
  if {[auto_execok lpr] != ""} {
    
    set textChan [open $invPsPath]
    set t [read $textChan]
    close $textChan

    set printChan [open |/usr/bin/lpr w]    
    puts $printChan $t
    close $rintChan
#    catch {close $printChan}
  NewsHandler::QueryNews "Die Rechnung $invNo wurde zum Drucker geschickt." orange
#    return 0
    #after 5000 {return 1}
 #   catch {exec lpr $invPsPath}
        
  } 
return 



  #2. try direct printing vie GhostScript
#TODO: zis not working yet!
  if {[auto_execok gs] != ""} {
    
    set invPsPath [setInvPath $invNo ps]
    set device "ps2write"
    set printer "/dev/usb/lp0" 
    catch {
      eval exec gs -dSAFER -dNOPAUSE -sDEVICE=$device -sOutputFile=\|$printer $invPsPath 
    }
  return 0
  }

  NewsHandler::QueryNews "Die Rechnung $invNo kann nicht gedruckt werden." red
  NewsHandler::QueryNews "Installieren Sie ein Betrachtungsprogramm wie 'evince' oder 'okular' für besseres Druck-Handling." orange
  
  latexInvoice pdf
  
  return 1
} ;#END printInvoice


# saveInvEntry
###called by fillAdrInvWin by $invF.$n.zahlenE entry widget
proc saveInvEntry {curVal curEName ns} {
  global db invF
  set curNS "verbucht::${ns}"
  set rowNo [namespace tail $curNS]

	#1)get invoice details
  set invNo [$invF.$rowNo.invNoL cget -text]
  set newPayedsum [$curEName get]  

  #avoid non-digit amounts
  if ![string is double $newPayedsum] {
    $curEName delete 0 end
    $curEName conf -validate focusout -vcmd "saveInvEntry %P %W $ns"
    NewsHandler::QueryNews "Fehler: Konnte Zahlbetrag nicht speichern." red
    return 1
  }
  
  set invT [pg_exec $db "SELECT payedsum,finalsum,auslage,customeroid FROM invoice WHERE f_number=$invNo"]
  set oldPayedsum [lindex [pg_result $invT -list] 0]
  set buchungssumme [lindex [pg_result $invT -list] 1]
  set auslage [lindex [pg_result $invT -list] 2]
  set adrNo [lindex [pg_result $invT -list] 3]
  
  if {[string is double $auslage] && $auslage >0} {
    set finalsum [expr $buchungssumme + $auslage]
  } else {
    set finalsum $buchungssumme
  }
  

  #Determine credit avoiding non-digit values
  #TODO: which????
  
  set oldCredit $::credit
#  set oldCredit [pg_result [pg_exec $db "SELECT credit from address where objectid=$adrNo"] -list]
  
  if ![string is double $oldCredit] {
    set oldCredit 0
  }
    
  #Compute total payedsum:
  set totalPayedsum [expr $oldPayedsum + $newPayedsum]
  
  ##is identical - don't touch credit
  if {$totalPayedsum == $finalsum} {
    set status 3
    set diff 0

  #diff is +
  } elseif {$totalPayedsum > $finalsum} {
   # set status 3
    set totalPayedsum $finalsum
    set diff [expr $finalsum - $totalPayedsum]

  #diff is -
  } elseif {$totalPayedsum < $finalsum} {
   # set status 2
    set diff [expr $totalPayedsum - $finalsum]
    
  }
  
  #compute remaining credit + set status
  set newCredit [expr $oldCredit + $diff]
  if {$newCredit >0} {
    set status 3
    set totalPayedsum $finalsum
  } else {
    set status 2
  }

puts "OldCredit $oldCredit"
puts "NewCredit $newCredit"
puts "OldPS $oldPayedsum"
puts "NewPS $newPayedsum"
puts "status $status"
puts "diff $diff"

	# S a v e  totalPayedsum  to 'invoice' 
  set token1 [pg_exec $db "UPDATE invoice 
    SET payedsum = $totalPayedsum, 
    ts = $status 
    WHERE f_number=$invNo"]
    
  # S a v e  credit to 'address'
  set token2 [pg_exec $db "UPDATE address
    SET credit = $newCredit
    WHERE objectid = $adrNo"]

  #Update GUI
  reportResult $token1 "Betrag CHF $newPayedsum verbucht"
  reportResult $token2 "Das aktuelle Kundenguthaben beträgt $::credit"

  ##delete OR reset zahlen entry
  if {$status == 3} {
    pack forget $curEName
 		$invF.$rowNo.payedL conf -text $totalPayedsum -fg green
    pack forget $invF.$rowNo.commM
    
  } else {
  
    $curEName delete 0 end
    $curEName conf -validate focusout -vcmd "saveInvEntry %P %W $ns"
 		$invF.$rowNo.payedL conf -text $totalPayedsum -fg maroon
  }

  set ::credit $newCredit    
  return 0
} ;#END saveInvEntry


### A R C H I V ################################################################################

# doInvoicePdf  - obsolete!!! 
##creates invoice PDF if so desired by user
##called by showInvoice
proc doInvoicPdf {invNo} {
  global invDviName invDviPath invPdfName invPdfPath 
  global psViewer invPsPath

  set reply [tk_messageBox -type yesno -message "Möchten Sie von der Rechnung Nr. $invNo ein PDF zum Versand/Ausdruck erstellen?"]
  if {$reply == "yes"} {

    if [catch {exec dvipdf $invDviPath} res] {
      NewsHandler::QueryNews "Es konnte kein PDF der Rechnung Nr. $invNo erstellt werden: \n$res" red
      exec dvips $invDviPath
      exec psViewer $invPsPath
      NewsHandler::QueryNews "Die Rechnung Nr. $invNo liegt im PostScript-Format vor. Druck/Versand über $psViewer" lightblue

    } else {
      NewsHandler::QueryNews "Das PDF der Rechnung finden Sie in $invPdfPath" lightgreen
    }

  }
}

# viewInvOnCanvas
##shows invoice in toplevel window
##called by viewInvoice if no viewer found
proc viewInvOnCanvas {invNo} {
  global adrSpin
 
  NewsHandler::QueryNews "Kein externes Betrachtungsprogramm gefunden." orange
  NewsHandler::QueryNews "Installieren Sie zur bequemen Anzeige/Bearbeitung von Rechnungen eines der Programme 'evince' oder 'okular'." orange  

  set invPsPath [setInvPath $invNo ps]
  catch {latexInvoice $invNo ps}
  
  #Create toplevel window with canvas & buttons
  catch {toplevel .topW -borderwidth 7 -relief sunken}
  catch {button .topW.showinvexitB -text "Schliessen"}
  catch {button .topW.showinvpdfB -text "PDF erzeugen"}
  catch {button .topW.showinvprintB -text "Drucken"}
  catch {canvas .topW.invC -yscrollc ".topW.yScroll set"}
  catch {scrollbar .topW.yScroll -ori vert -command ".topW.invC yview"}
  #Create PostScript image (height/width nicht beeinflussbar!)
  image create photo psIm -file $invPsPath
  .topW.invC create image 0 0 -image psIm -anchor nw
  .topW.invC configure -scrollregion [.topW.invC bbox all]
  .topW.invC conf -width [image width psIm] -height [image height psIm]
    
  pack .topW.invC
  pack .topW.yScroll -side left
  pack .topW.showinvexitB .topW.showinvpdfB .topW.showinvprintB -side right

  .topW.showinvexitB conf -command "wm forget .topW"
  
#TODO export to function - what about ps2pdf in latexPdf???
  .topW.showinvpdfB conf -command "doPdf $invNo"
  
  proc doPdf {invNo} {
    set invPsPath [setInvPath $invNo ps]
    set invPdfPath [setInvPath $invNo pdf]  
    exec ps2pdf $invPsPath $invPdfPath
    NewsHandler::QueryNews "Das PDF finden Sie unter $invPdfPath." lightgreen
    return 0
  }
  
  .topW.showinvprintB conf -command "printInvoice $invNo"  

  return 0
}

