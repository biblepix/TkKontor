# ~/TkOffice/prog/invoice-procs.tcl
# called by tkoffice-gui.tcl
# Aktualisiert: 1nov17
# Restored: 30oct19

source $confFile
################################################################################################################
################# N E W   I N V O I C E   P R O C S ############################################################
################################################################################################################

set vorlageTex [file join $texDir rechnung-vorlage.tex]
 
# resetNewInvDialog
##called by Main + "Abbruch Rechnung"
proc resetNewInvDialog {} {
  pack forget [pack slaves .invoiceFrame]
  set invNo 0
  set ::subtot 0

  catch {namespace delete rows}
  catch {unset ::beschr}

  #create Addrow button
  catch {button .addrowB -text "Hinzufügen" -command addInvRow}
  catch {message .einheit -textvariable unit}
  catch {message .einzel -textvariable einzel}

  #Create Menge entry
  catch {entry .mengeE -width 7 -bg yellow -fg grey -textvar menge}
  set menge "Menge"
  .mengeE configure -validate focusin -validatecommand {
    %W conf -fg black
    set menge ""
    return 0
    }

  pack .invcondL .invcondSB .invauftrdatL .invauftrdatE .invrefL .invrefE .invcomL .invcomE -in .n.t2.f1 -side left -fill x 
  pack .invArtlistL -in .n.t2.f1 -before .n.t2.f2 -anchor w 
  pack .invArtNumSB .invArtNameL .invArtPriceL .mengeE .invArtUnitL -in .n.t2.f2 -side left -fill x
  pack .addrowB -in .n.t2.f2 -side right -fill x
  
  #Reset Buttons
  .abbruchInvB conf -state disabled
  .saveInvB conf -state disabled -command "
    .saveInvB conf -activebackground #ececec -state normal
    doSaveInv $invNo
    "
} ;#END resetNewInvDialog


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
    
    for {set n 0} {$n<$nTuples} {incr n} {
    
      namespace eval $n {

        set n [namespace tail [namespace current]]
        set invF $::invF
			  set total [pg_result $::verbucht::sumtotalT -getTuple $n] 
			  set ts [pg_result $::verbucht::statusT -getTuple $n]
			  set invno [pg_result $::verbucht::invNoT -getTuple $n]
        set invdat [pg_result $::verbucht::invDatT -getTuple $n]
			  set beschr [pg_result $::verbucht::beschrT -getTuple $n]

			  #increase but don't overwrite frames per line	
			  catch {frame $invF.$n}
			  pack $invF.$n -anchor nw -side top -fill x

    		#create entries per line, or refill present entries
			  catch {label $invF.$n.invNoL -width 10 -anchor w}
			  $invF.$n.invNoL configure -text $invno
        catch {label $invF.$n.invDatL -width 15 -anchor w -justify left}
        $invF.$n.invDatL configure -text $invdat
			  catch {label $invF.$n.beschr -width 50 -justify left -anchor w}
			  $invF.$n.beschr configure -text $beschr
			  catch {label $invF.$n.sumtotal -width 10 -justify right -anchor e}
			  $invF.$n.sumtotal configure -text $total
#			  catch {label $invF.$n.statusL -width 10 -justify right -anchor e}
#			  $invF.$n.statusL configure -text $ts
        #create label/entry for Bezahlt, packed later
        set bezahlt [pg_result $::verbucht::payedsumT -getTuple $n]
        catch {label $invF.$n.payedsumL -width 13 -justify right -anchor e}
        $invF.$n.payedsumL conf -text $bezahlt
        catch {entry $invF.$n.payedsumE -text Eingabe -bg beige -fg grey -width 7 -justify right}

        ##create showInvoice button, to show up only if inv not empty
        catch {button $invF.$n.invshowB}

			  #PAYEDSUM label/entry
			  #If 3 (payed) make label
			  if {$ts==3} {
				  set zahlen ""
				  #catch {label $invF.$n.payedsumL -width 10}
          $invF.$n.payedsumL conf -fg green
#         $invF.$n.statusL conf -fg green
          pack $invF.$n.invNoL $invF.$n.invDatL $invF.$n.beschr $invF.$n.sumtotal $invF.$n.payedsumL  -side left
			  
        #If 1 or 2 make entry
			  } else {

				  catch {label $invF.$n.zahlenL -textvar zahlen -fg red -width 50}
				  set zahlen "Zahlbetrag eingeben und mit Tab-Taste quittieren"
          #create entry widget providing amount, entry name & NS to calling prog
          $invF.$n.payedsumE delete 0 end
          $invF.$n.payedsumE conf -validate focusout -validatecommand "saveInvEntry %P %W $n" 
#          $invF.$n.statusL conf -fg red
				  pack $invF.$n.invNoL $invF.$n.invDatL $invF.$n.beschr $invF.$n.sumtotal $invF.$n.payedsumL -side left
          pack $invF.$n.zahlenL $invF.$n.payedsumE -side right
		  
        #if 2 (Teilzahlung) include payed amount
			  #WARUM IST payedsum LEER - can't use -textvariable with -validatecommand!
				  if {$ts==2} {
					  $invF.$n.payedsumE configure -bg orange
					  $invF.$n.zahlenL conf -bg orange -fg white -width 50 -textvar zahlen
#            $invF.$n.statusL conf -fg orange
					  set zahlen "Restbetrag eingeben und mit Tab-Taste quittieren"
				  }

			  }

        #Create Show button if items not empty
        set itemsT $::verbucht::itemsT
        catch {set itemlist [pg_result $itemsT -getTuple $n] }
        if {[pg_result $itemsT -error] == "" && [info exists itemlist]} {

#Bitmap should work, but donno why it doesn't
#          $invF.$n.invshowB conf -bitmap $::verbucht::bmdata -command "showInvoice $invno"
#puts "InvNo: $invno"

          $invF.$n.invshowB conf -width 40 -padx 40 -image $::verbucht::printBM -command "doPrintOldInv $invno"
#pack [frame .invshowbuttonF -width 40] -anchor e -in $invF.$n -fill x -side left
pack $invF.$n.invshowB -anchor e -side left
        }

  		} ;#end for loop
    } ;#END namspace $rowNo
  } ;#END namespace verbucht

} ;#END fillAdrInvWin

# addInvRow
##called by setupNewInvDialog
proc addInvRow {} {
  #Create Row Frame
  namespace eval rows {}
  
  #Configure Abbruch button
  pack .abbruchInvB .saveInvB -in .n.t2.bottomF -side right
  .saveInvB conf -activebackground skyblue -state normal
  .abbruchInvB conf -activebackground red -state normal -command {
    .abbruchInvB conf -state disabled
    namespace delete rows
    foreach w [pack slaves .invoiceFrame] {
      pack forget $w
    }
    resetNewInvDialog
    .saveInvB conf -activebackground #cecece
    }

  if {[namespace children rows] == ""} {
    set lastrow 0
    set rowtot 0
  }  else {
    #get last namespace no.
    set lastrow [namespace tail [lindex [namespace children rows] end]]
  }

  #add new namespace no.
  namespace eval rows {
    
    set rowNo [incr lastrow 1]

    namespace eval $rowNo  {

      #get global vars
      set artName [.invArtNameL cget -text]
      set menge [.mengeE get]
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

      #Handle "R" types
      set type [.arttypeL${rowNo} cget -text] 
      
      ##deduce Rabatt from subtot (for GUI + DB, Invoice makes its own calculation)
      if {$type == "R"} {
        set rabatt [expr ($subtot * $artPrice / 100)]
        .arttypeL${rowNo} conf -bg orange    
        .artpriceL${rowNo} conf -text "-${rabatt}" 

        #Export for saveInv2TeX
        set subtot [expr $subtot - $rabatt]        
        set ::rabatt $rabatt

      } else {
        set subtot [expr $::subtot + $rowtot]
      }


      catch {label .rowtotL${rowNo} -text $rowtot -bg lightblue  -width 50 -justify left -anchor w}
      pack .artnameL${rowNo} .artpriceL${rowNo} .mengeL${rowNo} -in .invF${rowNo} -anchor w -fill x -side left
      pack .artunitL${rowNo} .rowtotL${rowNo} .arttypeL${rowNo} -in .invF${rowNo} -anchor w -fill x -side left

      #Export subtot with 2 decimal points
      set ::subtot [expr {double(round(100*$subtot))/100}]

      #Export beschr cumulatively for use in saveInv2DB & fillAdrInvWin
      set separator {}
      if [info exists ::beschr] {
        set separator { /}
      }
      append ::beschr $separator $menge $artName

    }
  }

} ;#END addInvRow

# doSaveInv
##coordinates invoice saving + printing progs
##evaluates exit codes
##called by .saveInvB button
proc doSaveInv {invNo} {
  catch saveInv2DB res1
  if {$res1 != 0} {
    return 1
  } 
  catch {invLatex $invNo} res2
  if {$res2 != 0} {
    return 1
  }

#  doPrintInv
  return 0
}

# saveInv2DB
##called by doSaveInv
proc saveInv2DB {} {
  global db adrNo env msg texDir
  global cond ref subtot beschr ref comm auftrDat vat

  #1. Get current vars - TODO: incorporate in DB as 'SERIAL', starting with %YY
	set invNo [createNewNumber invoice]
	
	#Get current address from GUI
  set shortAdr "$::name1 $::name2, $::city"

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
      append itemList \\Discount\{ $artName \} \{ $::rabatt \} \n
    #Check if Auslage
    } elseif {$artType=="A"} {
      append itemList \\EBC\{ $artName \} \{ $artPrice \} \n
    }
  } ;#END foreach w

  #1. Save itemList to ItemFile for Latex
  set chan [open $itemFile w]
  puts $chan $itemList
  close $chan
  ##convert to Hex for DB
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
    '$beschr',
    $subtot,
    $payedsum,
    $vatlesssum,
    $invNo,
    to_date('$auftrDat','DD MM YYYY'),
    '$comm',
    '$ref',
    '$cond',
    '$itemListHex'
    )"]

  if {[pg_result $token -error] != ""} {
    NewsHandler::QueryNews "Rechnung $invNo nicht gespeichert:\n[pg_result $token -error ]" red
    return 1

  } else {

   	NewsHandler::QueryNews "Rechnung $invNo gespeichert" lightgreen
    fillAdrInvWin $adrNo
    .saveInvB conf -text "Rechnung drucken" -command {printInvoice $invNo}
    return 0
  } 

} ;#END saveInv2DB



###############################################################################################
#### O L D   I N V O I C E   P R O C S  #######################################################
###############################################################################################

# fetchInvData
##1.retrieves invoice data from DB
##2.gets some vars from Config
##3.saves dataFile & itemFile for Latex processing
##called by invLatex & showInvoice
proc fetchInvData {invNo} {
  global db texDir confFile
  
  set dataFile [file join $texDir invdata.tex]
  set itemFile [file join $texDir invitems.tex]

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
  set chan [open $itemFile w]
  puts $chan $itemList
  close $chan

  #Cleanup
  pg_result $invToken -clear
  pg_result $adrToken -clear

  return 0
  
} ;#END fetchInvData

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
  
  #A. do DVI > tmpDir
  if {$type == "dvi"} {
    namespace eval Latex {
      eval exec -- latex -draftmode -interaction nonstopmode -output-directory $tmpDir $invTexPath
    }
    return 0
  }
  
  #B. do PS > tmpDir
  if {$type == "ps"} {
    set invPsPath [setInvPath $invNo ps]
    eval exec dvips -o $invPsPath $invDviPath
    return 0
  }
    
  #C. do PDF > spoolDir
  if {$type == "pdf"} {
    set invPdfPath [setInvPath $invNo pdf]
    eval exec dvipdf $invDviPath $invPdfPath
    return 0
  }

  return 1
} ;#END latexInvoice


#Invoice view/print wrappers
proc doPrintOldInv {invNo} {

  #1. Get invoice data from DB
  if [catch "fetchInvData $invNo"] {
    NewsHandler::QueryNews "Rechnungsdaten $invNo konnten nicht wiederhergestellt werden. Ansicht/Ausdruck nicht möglich." red
    return 1
  }
  NewsHandler::QueryNews "Wir versuchen nun, Rechnung Nr. $invNo anzuzeigen.\nEine weitere Bearbeitung (Ausdruck / E-Mail-Versand) ist  aus dem Anzeigeprogramm möglich." lightblue

  after 6000 "latexInvoice $invNo dvi"
  after 12000 "viewInvoice $invNo"
  return 0
}

proc doPrintNewInv {invNo} {
?  set invPath [setInvPath $invNo pdf]
  set invoicePs ...
  latexInvoice $invNo ps
  printInvoice $invoicePs
  after 3000 {
    viewInvoice $invoiceDvi / $invoicePs ?
    NewsHandler::QueryNews "Sie können über das Anzeigeprogramm die Rechnung nochmals ausdrucken bzw. zum Versand per E-Mail nach PDF umwandeln." orange
  }
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
  global db itemFile vorlageTex texDir

    set invDviPath [setInvPath $invNo dvi]

    #A) Show DVI
    if {[auto_execok evince] != ""} {
      set dviViewer "evince"
    } elseif {[auto_execok okular] != ""} {
      set dviViewer "okular"
    }
    if [info exists dviViewer] {
      catch {exec $dviViewer $invDviPath} ;#catch wegen garbage output!
      return 0
    }

#TODO: THESE ARE  B O T H  CRAP -FIND PROGS THAT CAN PRINT TO PDF!!!!!
    #B) Convert to PS & show
    if {[auto_execok qpdfview] != ""} {
      set psViewer "qpdfview"
    } elseif {[auto_execok gv] != ""} {
      set psViewer "gv"
    }

    if [info exists psViewer] {
      set invPsPath [setInvPath $invNo ps]
      catch {latexInvoice $invNo ps} ;#catch wegen garbage output!
      catch {exec $psViewer $invPsPath}
      return 0
    }
    
    #C) Convert to PDF and exit
    set invPdfPath [setInvPath $invNo pdf]
    catch {latexInvoice $invNo pdf}
 NewsHandler::QueryNews "Kein Anzeigeprogramm für Rechnung $invNo gefunden.\nDas Dokument [file tail $invPdfPath] befindet sich in $spoolDir zur weiteren Bearbeitung (Ausdruck/Versand).\nInstallieren Sie 'evince' oder 'okular' zur bequemen Anzeige." orange
    return 1

} ;#END viewInvoice


# printInvoice
##prints to printer or shows in view prog
##called after latex - TODO: what inv.name to print?
##called by "Rechnung drucken" button (neue Rechnung)
proc printInvoice {invNo} {

  #1. dvips
  exec dvips ...

  #2. try direct printing vie lpr
  if {[autoexec_ok lpr] != ""} {
    if [catch {exec lpr $invPsPath}] {
    
    ## or Try gs
    set device "ps2write"
    set printer "/dev/usb/lp0" 

#is there a better way to check?
#Better Test lpinfo / lpstat (only works if CUPS installed) 
    catch {
      eval exec gs -dSAFER -dNOPAUSE -sDEVICE=$device -sOutputFile=\|$printer $invPsPath
    } res

#TODO: evaluate $res and exit here if print successful
#Maybe like this: set res [eval exec ...]
   if {$res == ""} { 
      NewsHandler::QueryNews "Die Rechnung $invNo wurde zum Drucker geschickt." orange
   }
  }
 }

#3. View PS anyway
showInvoice $invNo
NewsHandler::QueryNews "Sie können nun die Rechnung $invNo über das Anzeigeprogramm nochmals ausdrucken oder zwecks Versand nach PDF umwandeln." lightblue

  set invName $spoolDir/invoice_$compName -${invNo}.ps

#Make 1 command for direct PS printing, else show file in evince/okular
#TODO: for direct PS printing
#TODO: use pipe instaed of file?
set dviFile /tmp/$invName.dvi

exec $viewer $dviFile


  if [file exists $invName] {
    NewsHandler::QueryNews "$invName wird ausgedruckt." lightblue
    exec $printCmd $invName
  } else {

    NewsHandler::QueryNews "$invName kann weder angezeigt noch gedruckt werden.... $invPdf ..." red
  }

} ;#END printInvoice


# saveInvEntry
###called by fillAdrInvWin by $invF.$n.payedsumE entry widget
proc saveInvEntry {curVal curEName ns} {
  global db invF
  set curNS "verbucht::${ns}"
  set rowNo [namespace tail $curNS]

	#2. get invNo
  set invNo [$invF.$rowNo.invNoL cget -text]
	
  #2. Betrag lesen & in DB einfügen überschreiben! / status ändern set newPayedsum [$rowNo::payedsumE get]
  set newPayedsum [$curEName get]  
  set finalsum [pg_result [pg_exec $db "SELECT finalsum FROM invoice WHERE f_number=$invNo"] -list]
  set oldPayedsum [pg_result [pg_exec $db "SELECT payedsum FROM invoice WHERE f_number=$invNo"] -list]
  set totalPayedsum [expr $oldPayedsum + $newPayedsum]

	#Insert payedsum if digit, avoiding errors
	if {[regexp {[[:digit:]]} $newPayedsum]} {
	
		if {$totalPayedsum == $finalsum} {
			set status 3
		} else {
			set status 2
		}

		#Save to DB
    set totalPayedsum 
    set token [pg_exec $db "UPDATE invoice 
      SET payedsum = $totalPayedsum, 
          ts = $status 
      WHERE f_number=$invNo"]

    reportResult $token "Betrag CHF $newPayedsum verbucht"

		#update GUI
    set zahlen [set curNS]::zahlen
    set payedsum [set curNS]::payedsum

#TODO: brauchen wir dieses Label?
		set $zahlen "Betrag CHF $newPayedsum verbucht"
    set $payedsum $totalPayedsum		
		set status [pg_exec $db "SELECT ts FROM invoice WHERE f_number=$invNo"]

    $invF.$rowNo.zahlenL conf -fg green -textvariable $zahlen
		$invF.$rowNo.statusL conf -text [pg_result $status -list]
		$invF.$rowNo.payedsumL conf -text $totalPayedsum
    pack forget $curEName
    set $payedsum ""
	} 
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

#create canvas + load PS - only if no viewer found!!!
proc lastresort {} {
 canvas .c -xscrollc ".x set" -yscrollc ".y set" -height 1000 -width 1000
 scrollbar .x -ori hori -command ".c xview"
 scrollbar .y -ori vert -command ".c yview"
 set im [image create photo -file $vorlagePs]
 .c create image 0 0 -image $im -anchor nw
 .c configure -scrollregion [.c bbox all]
  
  #Clear main Window from all content
  foreach w [pack slaves .n.t1.mainF] {pack forget $w}

  pack .c -in .n.t1.mainF
  pack .x -in .n.t1.mainF -side right
  pack .y -in .n.t1.mainF -side bottom

  button .showinvexitB -text "Schliessen" -command {resetAdrInvWin}
  button .showinvpdfB -text "PDF erzeugen" -command {doPdf}
  button .showinvprintB -text "Drucken" -command {printInvoice}
  pack .showinvexitB .showinvpdfB .showinvprintB -side bottom -in .n.t1.mainF

  return geschafft
}

