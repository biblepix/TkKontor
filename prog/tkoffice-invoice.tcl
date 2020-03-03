# ~/TkOffice/prog/tkoffice-invoice.tcl
# called by tkoffice-gui.tcl
# Salvaged: 2nov17
# Updated: 3mch20

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

  #Cleanup
  catch {namespace delete rows}
  foreach w [winfo children .newInvoiceF] {
    destroy $w
  }

  #Set vars to 0
  namespace eval rows {
    set bill 0
    set buch 0
    set auslage 0
  }
  
  updateArticleList
  .invartnumSB invoke buttondown
  
  #Configure message labels & pack
  .subtotalM conf -textvar rows::bill
  .abzugM conf -textvar rows::auslage
  .totalM conf -textvar rows::buch
  pack .subtotalL .subtotalM .abzugL .abzugM .totalL .totalM -side left -in .n.t2.bottomF

  #create Addrow button w/dynamic width - funzt mit '-expand 1' bestens!
  catch {button .addrowB}
    
  .addrowB conf -text "Posten hinzufügen" -command {addInvRow}
  catch {message .einheit -textvariable unit}
  catch {message .einzel -textvariable einzel}

  pack .invcondL .invcondSB .invauftrdatL .invauftrdatE .invrefL .invrefE .invcomL .invcomE -in .n.t2.f1 -side left -fill x 
  pack .invartlistL -in .n.t2.f1 -before .n.t2.f2 -anchor w 
  pack .invartnumSB .mengeE .invartunitL .invartnameL .invartpriceL -in .n.t2.f2 -side left -fill x
  pack .addrowB -in .n.t2.f2 -side right -expand 1 -fill x
  
  #Reset Buttons
  .abbruchinvB conf -state disabled
  .saveinvB conf -state disabled -command "
    .saveinvB conf -activebackground #ececec -state normal
    doSaveInv
  "
} ;#END resetNewInvDialog

# addInvRow
##called by setupNewInvDialog
proc addInvRow {} {
  
  #Exit if menge empty
  set menge [.mengeE get]
  if {$menge == ""} {
    NewsHandler::QueryNews "Bitte Menge eingeben!" red
    .mengeE conf -bg red
    focus .mengeE
    after 7000 {.mengeE conf -bg beige}
    return 1
  }

  #Configure Abbruch button
  pack .abbruchinvB .saveinvB -in .n.t2.bottomF -side right
  .saveinvB conf -activebackground skyblue -state normal
  .abbruchinvB conf -activebackground red -state normal -command {resetNewInvDialog}


  ##get last namespace no.
  if [catch {namespace children rows}] {
    set lastrow 0
  }  else {
    set lastrow [namespace tail [lindex [namespace children rows] end]]
  }

  ##add new namespace no.
  namespace eval rows {
    variable rowtot
    variable rabatt
    set rowNo [incr lastrow 1]

    #Create new row namespace
    namespace eval $rowNo  {

      set artName [.invartnameL cget -text]
      set menge [.mengeE get]
      set artPrice [.invartpriceL cget -text]
      set artUnit [.invartunitL cget -text]
      set artType [.invarttypeL cget -text]
      
      set rowNo $::rows::rowNo
      set rowtot [expr $menge * $artPrice]

      #Create row frame
#      catch {frame .newInvoiceF}
      set F [frame .newInvoiceF.invF${rowNo}]
      pack $F -fill x -anchor w    

      #Create labels per row
      catch {label $F.mengeL${rowNo} -text $menge -bg lightblue -width 20 -justify left -anchor w}
      catch {label $F.artnameL${rowNo} -text $artName -bg lightblue -width 53 -justify left -anchor w}
      catch {label $F.artpriceL${rowNo} -text $artPrice -bg lightblue -width 10 -justify right -anchor w}
      catch {label $F.artunitL${rowNo} -text $artUnit -bg lightblue -width 5 -justify left -anchor w}
      catch {label $F.arttypeL${rowNo} -text $artType -bg lightblue -width 20 -justify right -anchor e}
      catch {label $F.rowtotL${rowNo} -text $rowtot -bg lightblue  -width 50 -justify left -anchor w}

      #Get current values from GUI
      set bill $rows::bill
      set buch $rows::buch
      set auslage $rows::auslage

      # H a n d l e   t y p e s
              
      #Exit if rebate doubled
      if {$artType == "R" && [info exists ::rows::rabatt]} {
        NewsHandler::QueryNews "Nur 1 Rabatt zulässig" red
        namespace delete [namespace current]
        return 1
      }
       
      ##a) Type normal     
      if {$artType == ""} {
      
        ##deduce any existing rabattProzent from rowtot
        if [info exists ::rows::rabattProzent] {
          
          set rabattProzent $::rows::rabattProzent

          #compute this row's rebate
          set bill [expr $bill + $rowtot]
          set newrabatt [expr ($rabattProzent * $rowtot) / 100]
          set oldrabatt $::rows::rabatt

          #update global rebate
          #TODO zis isnt working yet!
          set ::rows::rabatt [expr $oldrabatt + $newrabatt]
          set ::rows::bill [expr $bill + $rowtot - $newrabatt]
          set ::rows::buch [expr $bill + $rowtot - $newrabatt]
         
        } else {
        
          set ::rows::bill [expr $bill + $rowtot]
          set ::rows::buch [expr $buch + $rowtot]
        }
        
      ##b) Type is "Rabatt" - compute from $buch (abzgl. Spesen)
      } elseif {$artType == "R"} {
        
        $F.artnameL${rowNo} conf -text "abzüglich $artName"
        $F.artpriceL${rowNo} conf -bg yellow -textvar ::rows::rabatt

        set ::rows::rabattProzent $artPrice
      
        set rabatt [expr ($buch * $artPrice / 100)]
        set ::rows::buch [expr $buch - $rabatt]
        set ::rows::bill [expr $bill - $rabatt]

        set ::rows::rabatt $rabatt

        .arttypeL${rowNo} conf -bg yellow
        .mengeE conf -state disabled
        set menge 1
      
                  
      ##c) "Auslage" types - add to $bill, not to $buch     
      } elseif {$artType == "A"} {
        
          set ::rows::auslage [expr $auslage + $rowtot]
          set ::rows::bill [expr $bill + $rowtot]
          set ::rows::buch [expr $bill - $auslage]
          $F.arttypeL${rowNo} conf -bg orange
          $F.rowtotL${rowNo} conf -bg orange
      }

      pack $F.artnameL${rowNo} $F.artpriceL${rowNo} $F.mengeL${rowNo} -anchor w -fill x -side left
      pack $F.artunitL${rowNo} $F.rowtotL${rowNo} $F.arttypeL${rowNo} -anchor w -fill x -side left

      #Reduce amounts to 2 decimal points -TODO better use
      set ::rows::bill [expr {double(round(100*$rows::bill))/100}]
      set ::rows::buch [expr {double(round(100*$rows::buch))/100}]
      if [info exists ::rows::rabatt] {
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
  global db env msg texDir itemFile
  global cond ref comm auftrDat vat

  set adrNo [.adrSB get]

  #1. Get invNo & export to ::Latex 
  #TODO: incorporate in DB as 'SERIAL', starting with %YY
	set invNo [createNewNumber invoice]
	namespace eval Latex {}
	set ::Latex::invNo $invNo
	
	#Get current vars from GUI
  set shortAdr "$::name1 $::name2, $::city"
  set shortDesc $rows::beschr
 # set subtot $rows::buch
  set invTotal $rows::bill
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
    set payedsum $invTotal
  } else {
    set ts 1
    set payedsum 0
  }	

  #3. Make entry for vatlesssum if different from finalsum
  set vatlesssum $invTotal
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
    $invTotal,
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

    #Show client turnover, including 'auslagen'
    set umsatzT [pg_exec $db "SELECT sum(finalsum),sum(auslage) AS total from invoice WHERE customeroid = $custId"]
    set verbucht [lindex [pg_result $umsatzT -list] 0]
    set auslagen [lindex [pg_result $umsatzT -list] 1]
    
    if {![string is double $auslagen] || $auslagen == ""} {
      set auslagen 0.00
    }
    set ::umsatz [roundDecimal [expr $verbucht + $auslagen]]
        
    #Create row per invoice
    for {set n 0} {$n<$nTuples} {incr n} {
    
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
			  
			  set ts [pg_result $::verbucht::statusT -getTuple $n]
			  set invNo [pg_result $::verbucht::invNoT -getTuple $n]
        set invdat [pg_result $::verbucht::invDatT -getTuple $n]
			  set beschr [pg_result $::verbucht::beschrT -getTuple $n]
        set comment [pg_result $::verbucht::commT -getTuple $n]

			  #increase but don't overwrite frames per line	
			  catch {frame $invF.$n}
			  pack $invF.$n -anchor nw -side top -fill x -expand 0

    		#create entries per line, or refill present entries
			  catch {label $invF.$n.invNoL -width 10 -anchor w}
			  $invF.$n.invNoL conf -text $invNo
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
          $invF.$n.zahlenE conf -validate focusout -vcmd "savePaymentEntry %P %W $n"

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
          $invF.$n.invshowB conf -width 40 -padx 40 -image $::verbucht::printBM -command "doPrintOldInv $invNo"
          pack $invF.$n.invshowB -anchor e -side right
        }

  		} ;#end for loop
    } ;#END namspace $rowNo
    
    if {$anzeige} {.invShowH conf -state normal} {.invShowH conf -state disabled -bg #d9d9d9}
    
  } ;#END namespace verbucht

  set ::credit [updateCredit $adrId]
  
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


#TODO extend to be used by abschluss too >tkoffice-procs.tcl
# viewInvoice >>>>> viewDocument !!!
##checks out DVI/PS capable viewer
##sends rechnung.dvi / rechnung.ps to prog for viewing
##called by "Ansicht" & "Rechnung drucken" buttons
proc viewInvoice {invNo} {
  global db itemFile vorlageTex texDir spoolDir

  set invDviPath [setInvPath $invNo dvi]

  #A) Show DVI
  if {[auto_execok evince] != ""} {
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
      return 0  
  } 


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

  #3. Print to PS or PDF 
  NewsHandler::QueryNews "Die Rechnung $invNo kann nicht gedruckt werden." red
  NewsHandler::QueryNews "Installieren Sie ein Betrachtungsprogramm wie 'evince' oder 'okular' für besseres Druck-Handling." orange
  
  set invPdfPath [setInvPath $invNo pdf]
  if ![catch {exec ps2pdf $invPsPath $invPdfPath}] {
    set path $invPdfPath
  } else {
    set path $invPsPath
  }
  NewsHandler::QueryNews "Sie finden Rechnung $invNo unter $path zur weiteren Bearbeitung." orange
  return 1

} ;#END printInvoice


# savePaymentEntry
##called by fillAdrInvWin by $invF.$n.zahlenE entry widget
proc savePaymentEntry {newPayedsum curEName ns} {
  global db invF
  set curNS "verbucht::${ns}"
  set rowNo [namespace tail $curNS]

	#1)get invoice details
  set invNo [$invF.$rowNo.invNoL cget -text]
  #set newPayedsum [$curEName get]

  #avoid non-digit amounts
  if ![string is double $newPayedsum] {
    $curEName delete 0 end
    $curEName conf -validate focusout -vcmd "savePaymentEntry %P %W $ns"
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
  
    
  #Compute total payedsum:
  set totalPayedsum [expr $oldPayedsum + $newPayedsum] 
  set newCredit [expr $totalPayedsum - $finalsum]
  
  #compute remaining credit + set status
  if {$newCredit >= 0} {
    set status 3
    
  } else {
    set status 2
#    set totalPayedsum ?
  }

#puts "OldCredit $oldCredit"
puts "NewCredit $newCredit"
puts "OldPS $oldPayedsum"
puts "NewPS $newPayedsum"
puts "status $status"
#puts "diff $diff"

	# S a v e  totalPayedsum  to 'invoice' 
  set token1 [pg_exec $db "UPDATE invoice 
    SET payedsum = $totalPayedsum, 
    ts = $status,
    payeddate = (SELECT current_timestamp::timestamp::date)
    WHERE f_number=$invNo
    "]

  #Update GUI    
  reportResult $token1 "Betrag CHF $newPayedsum verbucht"

  ##delete OR reset zahlen entry
  if {$status == 3} {
    pack forget $curEName
 		$invF.$rowNo.payedL conf -text $totalPayedsum -fg green
    pack forget $invF.$rowNo.commM
    
  } else {
  
    $curEName delete 0 end
    $curEName conf -validate focusout -vcmd "savePaymentEntry %P %W $ns"
 		$invF.$rowNo.payedL conf -text $totalPayedsum -fg maroon
  }
    
  set ::credit [updateCredit $adrNo]
  #reportResult $token2 "Das aktuelle Kundenguthaben beträgt $newCredit"
  return 0
} ;#END savePaymentEntry

# updateCredit
##calculates total credit per customer
##called by fillAdrInvWin + ?savePaymentEntry
proc updateCredit {adrNo} {
  global db
  
  set invoicesT [pg_exec $db "SELECT 
    sum(finalsum),
    sum(payedsum),
    sum(auslage) AS total from invoice WHERE customeroid = $adrNo"
    ]
  
  set verbuchtTotal [lindex [pg_result $invoicesT -list] 0]
  set gezahltTotal  [lindex [pg_result $invoicesT -list] 1]
  set auslagenTotal [lindex [pg_result $invoicesT -list] 2]
  
  if {![string is double $verbuchtTotal]  || $auslagenTotal == ""} {
    set verbuchtTotal 0.00
  }
  if {![string is double $gezahltTotal]  || $auslagenTotal == ""} {
    set gezahltTotal 0.00
  }
  if {![string is double $auslagenTotal] || $auslagenTotal == ""} {
    set auslagenTotal 0.00
  }
  
  set billedTotal [expr $verbuchtTotal + $auslagenTotal]
  set totalCredit [expr $gezahltTotal - $billedTotal]

  #Configure .creditM widget
  if {$totalCredit >0} {
    .creditM conf -bg lightgreen
  } elseif {$totalCredit <0} {
    .creditM conf -bg red
  } else { 
    .creditM conf -bg silver
  }
  
  return [roundDecimal $totalCredit]
}
    
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
  destroy .topW
  toplevel .topW -borderwidth 7 -relief sunken
  button .topW.showinvexitB -text "Schliessen"
  button .topW.showinvpdfB -text "PDF erzeugen"
  button .topW.showinvprintB -text "Drucken"
  canvas .topW.invC -yscrollc ".topW.yScroll set"
  scrollbar .topW.yScroll -ori vert -command ".topW.invC yview"

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

