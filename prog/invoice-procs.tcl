# ~/TkOffice/prog/invoice-procs.tcl
# called by tkoffice-gui.tcl
# Aktualisiert: 1nov17
# Restored: 24oct19


################################################################################################################
################# I N V O I C E   P R O C S ####################################################################
################################################################################################################

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
    set invNo [pg_exec $db "SELECT f_number FROM invoice WHERE customeroid = $custId"]
    set nTuples [pg_result $invNo -numTuples]

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
        set invNo $::verbucht::invNo
			  set total [pg_result $::verbucht::sumtotalT -getTuple $n] 
			  set ts [pg_result $::verbucht::statusT -getTuple $n]
			  set invno [pg_result $::verbucht::invNo -getTuple $n]
        set invdat [pg_result $::verbucht::invDatT -getTuple $n]
			  set beschr [pg_result $::verbucht::beschrT -getTuple $n]

			  #increase but don't overwrite frames per line	
			  catch {frame $invF.$n}
			  pack $invF.$n -anchor nw -side top -fill x

    		#create entries per line, or refill present entries
			  catch {label $invF.$n.invNoL -width 10 -anchor w}
			  $invF.$n.invNoL configure -text $invno
        catch {label $invF.$n.invDatL -width 10 -anchor w}
        $invF.$n.invDatL configure -text $invdat
			  catch {label $invF.$n.beschr -width 20 -justify left -anchor w}
			  $invF.$n.beschr configure -text $beschr
			  catch {label $invF.$n.sumtotal -width 10 -justify right -anchor e}
			  $invF.$n.sumtotal configure -text $total
			  catch {label $invF.$n.statusL -width 10 -justify right -anchor e}
			  $invF.$n.statusL configure -text $ts
        #create label/entry for Bezahlt, packed later
        set bezahlt [pg_result $::verbucht::payedsumT -getTuple $n]
        catch {label $invF.$n.payedsumL -width 10 -justify right -anchor e}
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
          $invF.$n.statusL conf -fg green
          pack $invF.$n.invNoL $invF.$n.invDatL $invF.$n.beschr $invF.$n.sumtotal $invF.$n.payedsumL $invF.$n.statusL -side left
			  
        #If 1 or 2 make entry
			  } else {

				  catch {label $invF.$n.zahlenL -textvar zahlen -fg red -width 50}
				  set zahlen "Zahlbetrag eingeben und mit Tab-Taste quittieren"
          #create entry widget providing amount, entry name & NS to calling prog
          $invF.$n.payedsumE delete 0 end
          $invF.$n.payedsumE conf -validate focusout -validatecommand "saveInvEntry %P %W $n" 
          $invF.$n.statusL conf -fg red
				  pack $invF.$n.invNoL $invF.$n.invDatL $invF.$n.beschr $invF.$n.sumtotal $invF.$n.payedsumL $invF.$n.statusL -side left
          pack $invF.$n.zahlenL $invF.$n.payedsumE -side right
		  
        #if 2 (Teilzahlung) include payed amount
			  #WARUM IST payedsum LEER - can't use -textvariable with -validatecommand!
				  if {$ts==2} {
					  $invF.$n.payedsumE configure -bg orange
					  $invF.$n.zahlenL conf -bg orange -fg white -width 50 -textvar zahlen
            $invF.$n.statusL conf -fg orange
					  set zahlen "Restbetrag eingeben und mit Tab-Taste quittieren"
				  }

			  }

        #Create Show button if items not empty
        set itemsT $::verbucht::itemsT
        catch {set itemlist [pg_result $itemsT -getTuple $n] }
        if {[pg_result $itemsT -error] == "" && [info exists itemlist]} {

#Bitmap should work, but donno why it doesn't
#          $invF.$n.invshowB conf -bitmap $::verbucht::bmdata -command "showInvoice $invno"
           $invF.$n.invshowB conf -image $::verbucht::printBM -command "showInvoice $invno"  
          pack $invF.$n.invshowB -side right
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

#  doViewInv
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
   	NewsHandler::QueryNews "Rechnung $invNo gespeichert" green
    fillAdrInvWin $adrNo
    .saveInvB conf -text "Rechnung drucken" -command {printInvoice $invNo}
    return 0
  } 

} ;#END saveInv2DB

# fetchInvData
##retrieves dataList from DB + some config vars for Latex
##saves dataFile for Latex
##called by invLatex
proc fetchInvData {invNo} {
  global db texDir confFile

  #1.get some vars from config
  source $confFile
  if {![string is digit $vat]} {set vat 0.0}
  if {$currency=="$"} {set currency \\textdollar}
  if {$currency=="£"} {set currency \\textsterling}
  if {$currency=="€"} {set currency \\texteuro}
  if {$currency=="CHF"} {set currency {Fr.}}

  #2.Get invoice data from DB
  set dataFile [file join $texDir invdata.tex]
  set invToken [pg_exec $db "SELECT ref,cond,f_date,f_number,items FROM invoice WHERE f_number=$invNo"]
  if {[pg_result $invToken -error] != ""} {
    NewsHandler::QueryNews "Konnte Rechnungsdaten Nr. $invNo nicht wiederherstellen.\n[pg_result $invToken -error]" red
    return 1
  }
  set ref [lindex [pg_result $invToken -list] 1]
  set cond [lindex [pg_result $invToken -list] 2]
  set auftrDat [lindex [pg_result $invToken -list] 3]
  set invNo [lindex [pg_result $invToken -list] 4]
  set itemList [lindex [pg_result $invToken -list] 5]

  #3.Get address data from DB & format for Latex
  set adrToken [pg_exec $db "SELECT name1,name2,street,zip,city FROM address WHERE objectid=$adrNo"]
  lappend custAdr [lindex [pg_result $adrToken] 1] {\\}
  lappend custAdr [lindex [pg_result $adrToken] 2] {\\}
  lappend custAdr [lindex [pg_result $adrToken] 3] {\\}
  lappend custAdr [lindex [pg_result $adrToken] 4] { }
  lappend custAdr [lindex [pg_result $adrToken] 5]
    
  #4.set dataList for usepackage letter
  append dataList \\newcommand\{\\ref\} \{ $ref \} \n
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

  ##overwrite any old data file
  set chan [open $dataFile w] 
  puts $chan $dataList
  close $chan

  pg_result $invToken -clear
  pg_result $adrToken -clear

  return 0
} ;#END fetchInvData

# fetchInvItems
##gets item list from DB & saves to itemFile
##called by invLatex
proc fetchInvItems {invNo} {
  global db texDir
  set itemFile [file join $texDir invitems.tex]

 #1.Get invitems from DB
  set token [pg_result $db "SELECT items FROM invoice WHERE f_number=$invNo"]
  set tHex [pg_list $token -list]
  set itemList [binary decode hex $thex]
  if {$itemList == ""} {
    return 1
  }

  #save to itemFile  
  set chan [open $itemFile w]
  puts $chan $itemList
  close $chan

  return 0
}

# invLatex
##called by saveInv2DB (new) & showInvoice (old)
##with args(=invNo): retrieve data from DB
##witout args: get data from new invoice dialogue
proc invLatex {} {
  global db adrSpin spoolDir texVorlage texDir confFile env

  fetchInvData
  fetchInvItems

  eval exec pdflatex -no-file-line-error $texVorlage

  append invOrigPdfName [file root $texVorlage] . pdf
  append invOrigPdfPath [file join $texDir $invOrigPdfName]
  set invNewPdfPath [setInvPdfPath $invNo]

  ## Rechnung.pdf > spoolDir
  file copy $invOrigPdfPath $invNewPdfPath

  #Change "Rechnung speichern" button to "Rechnung drucken" button
  .saveInvB conf -text "Rechnung drucken" -command {printInvoice}

  return 0

} ;#END invLatex


# setInvPdfPath
##called by latexInv
proc setInvPdfPath {invNo} {
  global spoolDir myComp

  set compShortname [lindex $myComp 0]
  append invPdfName invoice _ $compShortname - $invNo .pdf
  set invPdfPath [file join $spoolDir $invPdfName]

  return $invPdfPath
}


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
      NewsHandler::QueryNews "Das PDF der Rechnung finden Sie in $invPdfPath" green
    }

  }
}

#TODO: Is this to replace below??!!!
proc doViewInv {} {

puts "Noch nicht so weit..."


}

# showInvoice
##(meant to display existing DVI or PS,but..)
##gets invoice data from DB & recreates TeX (??>DIV>PS) > PDF
## TODO: thought: if we just get a PDF this can be viewed by any old prog - but still must find installed PDF viewer :-
##called by "Ansicht" button
proc showInvoice {invNo} {
  global db itemFile vorlageTex

  fetchInvData
  fetchInvItems

  #1. latex invNo in texDir
  eval exec latex $vorlageTex 

  #2. dvips $invNo in texDir
  append vorlageDvi [file root $vorlageTex] . dvi
  eval exec dvips $vorlageDvi


  #3. create canvas + load PS
 canvas .c -xscrollc ".x set" -yscrollc ".y set" -height 1000 -width 1000
 scrollbar .x -ori hori -command ".c xview"
 scrollbar .y -ori vert -command ".c yview"
 set im [image create photo -file $invPs]
 .c create image 0 0 -image $im -anchor nw
 .c configure -scrollregion [.c bbox all]
  
  #Clear main Window from all content
  foreach w [pack slaves .n.t1.mainF] {pack forget $w}

  pack .c -in .n.t1.mainF
  pack .x -in .n.t1.mainF -side right
  pack .y -in .n.t1.mainF -side bottom

  button .showinvexit -text "Schliessen" -command {resetAdrInvWin}
  button .showinvpdf "PDF erzeugen" -command {doPdf}
  button .showinvprint "Drucken" -command {printInvoice}
  pack .showinvexit .showinvpdf .showinvprint -side right -in .n.t1.mainF

  return

#TODO: incorporate this in fetchInvItems!
  #1.get itemList from DB & create itemFile
  set token [pg_exec $db "SELECT items FROM invoice WHERE f_number=$invNo"]
  if { [pg_result $token -error] != "" || [pg_result $token -list == ""] } {
    set itemList ""  
  } else {
    set thex [pg_result $token -list]
}

  #2.get dataFile details from $config + DB (VAT, cond, ref) & create dataFile

  #3.execute latex on $vorlage




  global spoolDir myComp
  set compShortname [lindex $myComp 0]
  append invName invoice _ $compShortname $invNo
  append invDviName $invName . dvi
  append invPsName $invName . ps
  append invPdfName $invName . pdf
  set invDviPath [file join $spoolDir $invDviName]
  set invPsPath [file join $spoolDir $invPsName]
  set invPdfPath [file join $spoolDir $invPdfName]

  #1. Exit if DVI doesn't exist
  if {![file exists $invDviPath]} {
    NewsHandler::QueryNews "$invDviName kann nicht gefunden werden." red
    return 1
  }

  #2. Determine DVI capable display program
  if {[autoexec_ok evince] != ""} {
    set dviViewer "evince"
  } elseif {[autoexec_ok okular] != ""} {
    set dviViewer "okular"
  }

  #3.Determine PS capable display program
  if {[autoexec_ok gv] != ""} {
    set psViewer "gv"
  } elseif {[autoexec_ok qpdfview] != ""} {
    set psViewer "qpdfview"
  }

  #4. Make PDF & exit if no viewer found
  if {! [info exists dviViewer] && ! [info exists psViewer]} {

    NewsHandler::QueryNews "Die Rechnung Nr. $invNo kann nicht angezeigt werden. Bitte installieren Sie ein Anzeigeprogramm wie 'evince', 'okular', 'gv' oder 'qpdfview'.\nDas entsprechende PDF finden Sie in $spoolDir" red
    after 3000 {doInvoicePdf $invNo}
    return 1
  }

  ##MAIN CLAUSE

  #A: execute DVi viewer
  if [info exists dviViewer] {
    
    if [catch {exec $dviViewer $invDviPath} res] {
      NewsHandler::QueryNews "Die Rechnung Nr. $invNo kann nicht angezeigt werden. \n$res" red
    } else {
      NewsHandler::QueryNews "Benutzen Sie den Druckdialog von $dviViewer, um die Rechnung auszudrucken." green 
    }

  #B: Execute PS viewer
  } elseif [info exists psViewer] {
    
    exec dvips $invDviPath 
    
    if [catch {exec $psViewer $invPsPath} res] {
      NewsHandler::QueryNews "Die Rechnung Nr. $invNo kann nicht angezeigt werden: \n$res" red
    } else {
      NewsHandler::QueryNews "Benutzen Sie den Druckdialog von $psViewer, um die Rechnung auszudrucken." green
    }

  } ;#End main clause

  #Offer PDF anyway
  after 3000 {doInvoicePdf $invNo}

} ;#END showInvoice


# printInvoice
##prints to printer or shows in view prog
##called by "Rechnung drucken" button (neue Rechnung)
proc printInvoice {invNo} {

  #1. get inv from spoolDir
#TODO: make invName global - used already in 2 previous progs!
#TODO: make proc for viewer selection (<showInvoice) if printing not possible
set invName ...
set invDviPath ...(needed?)
set invPsPath ...(PS needed for gs!)

#2. try direct printing PS - achtung: dvi könnte schon da sein
  catch {eval exec dvips $invDviPath} 
  
  ##1. Try lpr
  if {[autoexec_ok lpr] != ""} {
    if [catch {eval exec lpr $invPsPath}] {
    
    ##2. Try gs
    set device "ps2write"
    set printer "/dev/usb/lp0" 

#is there a better way to check?
#Better Test lpinfo / lpstat (only works if CUPS installed) 
    catch {
      eval exec gs -dSAFER -dNOPAUSE -sDEVICE=$device -sOutputFile=\|$printer $invPsPath
    } res

#TODO: evaluate $res and exit here if print successful
#Maybe like this: set res [eval exec ...]
# if {$res == ""} { gleich fail??? }

  }
}

#3. Try viewing PS
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


