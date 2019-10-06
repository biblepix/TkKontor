# called by auftrag.tcl
# Aktualisiert: 1nov17
# Restored: 3oct19

##################################################################################################
###  A D D R E S S  P R O C S  
##################################################################################################

proc createTkOfficeLogo {} {
  canvas .logoC -width 1000 -height 130 -borderwidth 7 -bg steelblue2
  pack .logoC -in .titelF -side left -anchor nw

set blau lightblue2
set dunkelblau steelblue3

  set kreis [.logoC create oval 7 7 50 50]
  .logoC itemconf $kreis -fill orange -outline red

  set schrift0 [.logoC create text 23 28]
  .logoC itemconf $schrift0 -font "TkHeadingFont 18 bold" -fill $dunkelblau -text "T"
  set schrift1 [.logoC create text 32 32]
  .logoC itemconf $schrift1 -font "TkCaptionFont 18 bold" -fill $dunkelblau -text "k"

  set schrift2 [.logoC create text 95 30]
  .logoC itemconf $schrift2 -font "TkHeadingFont 20 bold" -fill orange -text "f f i c e"

  set schrift3 [.logoC create text 8 65 -anchor w]
  .logoC itemconf $schrift3 -font "TkCaptionFont 18 bold" -fill $blau -text "Business Software"
  
  set schrift4 [.logoC create text 0 110 -anchor w]
  .logoC itemconf $schrift4 -font "TkHeadingFont 80 bold" -fill $dunkelblau -text "Auftragsverwaltung" -angle 4.
  .logoC lower $schrift4

  set schrift5 [.logoC create text 900 128 -justify right -text TkOffice.vollmar.ch]
  .logoC itemconf $schrift5 -fill $blau -font "TkCaptionFont 14 bold"

}

proc setAdrList {} {
  global db adrSpin
  $adrSpin config -bg lightblue
	set IDlist [pg_exec $db "SELECT objectid FROM address ORDER BY objectid DESC"]
	$adrSpin configure -values [pg_result $IDlist -list] 
	$adrSpin configure -command {
		fillAdrWin %s
		fillAdrInvWin %s
	}
	#set last entry at start
  fillAdrWin [$adrSpin get]
  catch {pack forget .adrClearSelB} 
}

proc fillAdrWin {adrOID} {
global db adrWin1 adrWin2 adrWin3 adrWin4 adrWin5
  #set variables
	set name1 [pg_exec $db "SELECT name1 FROM address WHERE objectid=$adrOID"]
	set name2 [pg_exec $db "SELECT name2 FROM address WHERE objectid=$adrOID"]
	set street [pg_exec $db "SELECT street FROM address WHERE objectid=$adrOID"]
	set zip [pg_exec $db "SELECT zip FROM address WHERE objectid=$adrOID"]
	set city [pg_exec $db "SELECT city FROM address WHERE objectid=$adrOID"]
  set tel1 [pg_exec $db "SELECT phone FROM address WHERE objectid=$adrOID"]
  set tel2 [pg_exec $db "SELECT mobile FROM address WHERE objectid=$adrOID"]
  set mail [pg_exec $db "SELECT mail FROM address WHERE objectid=$adrOID"]
  set www  [pg_exec $db "SELECT www FROM address WHERE objectid=$adrOID"]

	#insert into adrWin
  regsub {({)(.*)(})} [pg_result $name1 -list] {\2} ::name1
  regsub {({)(.*)(})} [pg_result $name2 -list] {\2} ::name2
  regsub {({)(.*)(})} [pg_result $street -list] {\2} ::street
  regsub {({)(.*)(})} [pg_result $city -list] {\2} ::city
  set ::zip [pg_result $zip -list]
  set ::tel1 [pg_result $tel1 -list]
  set ::tel2 [pg_result $tel2 -list]
  set ::www [pg_result $www -list]
  set ::mail [pg_result $mail -list]

  return 0
}

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

    set adrId [.adrSB get]
    set token [pg_exec $::db "SELECT ts FROM address WHERE objectid = $adrId"]
    set custId [pg_result $token -list]
    set invNo [pg_exec $::db "SELECT f_number FROM invoice WHERE customeroid = $custId"]
    set nTuples [pg_result $invNo -numTuples]
  	if {$nTuples == -1} {return 1}

    set invDat [pg_exec $db "SELECT f_date FROM invoice WHERE customeroid = $custId"]
	  set beschr [pg_exec $db "SELECT shortdescription FROM invoice WHERE customeroid = $custId"]
	  set sumtotal [pg_exec $db "SELECT finalsum FROM invoice WHERE customeroid = $custId"]
	  set payedsum [pg_exec $db "SELECT payedsum FROM invoice WHERE customeroid = $custId"]
	  set status [pg_exec $db "SELECT ts FROM invoice WHERE customeroid = $custId"]	

    for {set n 0} {$n<$nTuples} {incr n} {
    
      namespace eval $n {

        set n [namespace tail [namespace current]]
        puts $n
        set invF $::invF
        set invNo $::verbucht::invNo

			  set total [pg_result $::verbucht::sumtotal -getTuple $n] 
			  set ts [pg_result $::verbucht::status -getTuple $n]
			  set invno [pg_result $::verbucht::invNo -getTuple $n]
        set invdat [pg_result $::verbucht::invDat -getTuple $n]
			  set desc [pg_result $::verbucht::beschr -getTuple $n]

			  #increase but don't overwrite frames per line	
			  catch {frame $invF.$n}
			  pack $invF.$n -anchor nw -side top -fill x

    		#create entries per line, or refill present entries
			  catch {label $invF.$n.invNoL -width 10 -anchor w}
			  $invF.$n.invNoL configure -text $invno
        catch {label $invF.$n.invDatL -width 10 -anchor w}
        $invF.$n.invDatL configure -text $invdat
			  catch {label $invF.$n.beschr -width 20 -justify left -anchor w}
			  $invF.$n.beschr configure -text $desc
			  catch {label $invF.$n.sumtotal -width 10 -justify right -anchor e}
			  $invF.$n.sumtotal configure -text $total
			  catch {label $invF.$n.statusL -width 10 -justify right -anchor e}
			  $invF.$n.statusL configure -text $ts
        #create label/entry for Bezahlt, packed later
        set bezahlt [pg_result $::verbucht::payedsum -getTuple $n]
        catch {label $invF.$n.payedsumL -width 10 -justify right -anchor e}
        $invF.$n.payedsumL conf -text $bezahlt
        catch {entry $invF.$n.payedsumE -text Eingabe -bg beige -fg grey -width 7 -justify right}

        ##create PrintInvoice button (works only if invoice present in spoolDir)
        catch {button $invF.$n.invPrintB}
        $invF.$n.invPrintB configure -text "Rechnung nachdrucken" -command "printInvoice $invno"

			#PAYEDSUM label/entry
			#If 3 (payed) make label
			if {$ts==3} {
				set zahlen ""
				#catch {label $invF.$n.payedsumL -width 10}
        $invF.$n.payedsumL conf -fg green
        $invF.$n.statusL conf -fg green
        pack $invF.$n.invNoL $invF.$n.invDatL $invF.$n.beschr $invF.$n.sumtotal $invF.$n.payedsumL $invF.$n.statusL -side left
        pack $invF.$n.invPrintB -side right
			
      #If 1 or 2 make entry
			} else {

				catch {label $invF.$n.zahlenL -textvariable zahlen -fg red -width 50}
				set zahlen "Zahlbetrag eingeben und mit Tab-Taste quittieren"
        #create entry widget providing amount, entry name & NS to calling prog
        $invF.$n.payedsumE delete 0 end
        $invF.$n.payedsumE conf -validate focusout -validatecommand "saveEntry %P %W $n" 
        $invF.$n.statusL conf -fg red
				pack $invF.$n.invNoL $invF.$n.invDatL $invF.$n.beschr $invF.$n.sumtotal $invF.$n.payedsumL $invF.$n.statusL -side left
        pack $invF.$n.invPrintB $invF.$n.zahlenL $invF.$n.payedsumE  -side right
			
      #if 2 (Teilzahlung) include payed amount
			#WARUM IST payedsum LEER - can't use -textvariable with -validatecommand!
				if {$ts==2} {
					$invF.$n.payedsumE configure -bg orange
					$invF.$n.zahlenL conf -bg orange -fg white -width 50 -textvariable zahlen
          $invF.$n.statusL conf -fg orange
					set zahlen "Restbetrag eingeben und mit Tab-Taste quittieren"
				}
			}

  		pack $invF.$n.invPrintB -side right 
	
  		} ;#end for loop
    } ;#END namspace $rowNo
  } ;#END namespace verbucht

} ;#END fillAdrInvWin

proc searchAddress {s} {
  global db adrSpin adrSearch
  set s [$adrSearch get]

  if {$s == ""} {return 0}

  #Search names/city/zip
  set token [pg_exec $db "SELECT objectid FROM address WHERE 
	  name1 ~ '$s' OR 
	  name2 ~ '$s' OR
    zip ~ '$s' OR
	  city ~ '$s'
  "]

  #Get list of number(s)
	set adrList [pg_result $token -list]
  set numTuples [pg_result $token -numTuples]

  #A: open address if only 1 found
  if {$numTuples == 1} {
	  fillAdrWin $adrList
	  fillAdrInvWin $adrList

  #B: fill adrSB spinbox to choose from selection
  } else {

	$adrSpin config -bg beige -values "$adrList"
  catch {button .adrClearSelB -width 13 -text "^ Auswahl löschen" -command {setAdrList}}
  pack .adrClearSelB -in .adrF1
  }

  set ::suche "Adressuche"

  #Reset adrSearch widget & address list (called by .adrClearSelB)
  $adrSearch conf -fg grey -validate focusin -validatecommand {
    set ::suche ""
    %W config -fg black -validate focusout -validatecommand {
      searchAddress %s
      return 0
    }
  return 0
  }

  return 0
} ;# END searchAddress

# clearAdrWin
##called by "Neue Anschrift" & "Anschrift ändern" buttons
proc clearAdrWin {} {
  global adrSpin adrSearch
  foreach e [pack slaves .adrF2] {
    $e conf -bg beige -fg silver -state normal -validate focusin -validatecommand {
    %W delete 0 end
    %W conf -fg black
    return 0
    }
  }
  catch {pack forget .adrClearSelB}
  $adrSearch conf -state disabled
  .adrF2 conf -bg #d9d9d9
  return 0
}

# resetAdrWin
##called by GUI (first fill) + Abbruch btn + aveAddress
proc resetAdrWin {} {
  global adrSpin adrSearch
  pack .name1E .name2E .streetE -in .adrF2 -anchor nw
  pack .zipE .cityE -anchor nw -in .adrF2 -side left
  pack .tel1E .tel2E .mailE .wwwE -in .adrF2 -side right
  foreach e [pack slaves .adrF2] {
    $e conf -bg lightblue -validate none -fg black -state readonly -readonlybackground lightblue -relief flat -bd 0
  } 
  .b1 configure -text "Anschrift ändern" -command {changeAddress $adrNo}
  .b2 configure -text "Anschrift löschen" -command {deleteAddress $adrNo}
  pack .b0 -in .adrF3  
  $adrSpin conf -bg lightblue
  $adrSearch conf -state normal
  .adrF2 conf -bg lightblue
  catch {pack forget .adrClearSelB}

  setAdrList
  fillAdrInvWin [$adrSpin get]
}

proc newAddress {} {
  global adrSpin

  set ::name1 "Anrede"
  set ::name2 "Name"
  set ::street "Strasse"
  set ::zip "PLZ"
  set ::city "Ortschaft"
  set ::tel1 "Telefon"
  set ::tel2 "Telefon"
  set ::www "Internet"
  set ::mail "E-Mail"

  clearAdrWin
  $adrSpin delete 0 end
  $adrSpin configure -bg #d9d9d9  

  .b1 configure -text "Anschrift speichern" -command {saveAddress}
  .b2 configure -text "Abbruch" -activebackground red -command {resetAdrWin}
  pack forget .b0
  return 0
}

proc changeAddress {adrNo} {
  clearAdrWin
  .b1 configure -text "Anschrift speichern" -command {saveAddress}
  .b2 configure -text "Abbruch" -activebackground red -command {resetAdrWin}
  pack forget .b0
  return 0
}

# saveAddress
##saves existing or new address
##called by "Anschrift speichern" button
proc saveAddress {} {
  global db adrSpin

  #get new values from entery widgets
	set adrno [$adrSpin get]		
	set name1 [.name1E get]
	set name2 [.name2E get]
	set street [.streetE get]
	set zip [.zipE get]
	set city [.cityE get]
	set tel1 [.tel1E get]
  set tel2 [.tel2E get]
  set mail [.mailE get]
  set www [.wwwE get]

	#A: save new
	if {$adrno == ""} {
		set newNo [createNewNumber address]
		set token [pg_exec $db "INSERT INTO address (
      objectid, 
      ts, 
      name1, 
      name2, 
      street, 
      zip, 
      city, 
      telephone, 
      mobile, 
      email, 
      www
      ) 	
		VALUES (
      $newNo, 
      $newNo, 
      '$name1', 
      '$name2', 
      '$street', 
      '$zip', 
      '$city', 
      '$tel1', 
      '$tel2', 
      '$mail', 
      '$www'
      )"
    ]
    set adrno $newNo

	#B: change old
	} else {
				
	set token [pg_exec $db "UPDATE address SET 
		name1='$name1',
		name2='$name2',
		street='$street',
		zip='$zip',
		city='$city',
    telephone='$tel1',
    mobile='$tel2',
    email='$mail',
    www='$www'
  WHERE objectid=$adrno"
    ]
	}

  if {[pg_result $token -error] != ""} {
  	NewsHandler::QueryNews "[pg_result $token -error ]" red
  } else {
   	NewsHandler::QueryNews "Anschrift Nr. $adrno gespeichert" green
	  #Update Address list
	  catch setAdrList
  } 

  resetAdrWin
}

proc deleteAddress {adrNo} {
  global db
  #Check if any invoice is attached
  set token [pg_exec $db "SELECT f_number from invoice where customeroid=$adrNo"]

  if {[pg_result $token -list] == ""} {

    set res [tk_messageBox -message "Wollen Sie die Adresse $adrNo wirklich löschen?" -type yesno]
    if {!$res} {return 1}
  	
    set token [pg_exec $db "DELETE FROM address WHERE objectid=$adrNo"]
    reportResult $token "Adresse $adrNo gelöscht."
    resetAdrWin

  } else {
    reportResult $token "Adresse $adrNo nicht gelöscht, da mit Rechnung(en) [pg_result $token -list] verknüpft." 
  }
}




################################################################################################################
################# I N V O I C E   P R O C S ####################################################################
################################################################################################################

# resetNewInvDialog
##called by Main + "Abbruch Rechnung"
proc resetNewInvDialog {} {
  pack forget [pack slaves .invoiceFrame]
  set invNo 0

  #create Addrow button
  catch {button .addrowB -text "Hinzufügen" -command {addInvRow}}
  catch {message .einheit -textvariable unit}
  catch {message .einzel -textvariable einzel}

  #Create Menge entry
  catch {entry .mengeE -width 7 -bg yellow -fg grey}
  set menge "Menge"
  
.mengeE configure -validate focusin -validatecommand {
    #set ::menge ""
    %W conf -fg black
    %W delete 0 end
    return 0
  }

  set ::subtot 0

  pack .invcondL .invcondSB .invauftrdatL .invauftrdatE .invrefL .invrefE .invcomL .invcomE -in .n.t2.f1 -side left -fill x 
  pack .invArtlistL -in .n.t2.f1 -before .n.t2.f2 -anchor w 
  pack .invArtNumSB .invArtNameL .invArtPriceL .mengeE .invArtUnitL -in .n.t2.f2 -side left -fill x
  pack .addrowB -in .n.t2.f2 -side right -fill x
  
  #Reset .saveInvB to "Rechnung speichern"
  .saveInvB conf -text "Rechung speichern" -command "
    saveInv2DB
    saveInv2Tex $invNo
    "
} ;#END resetNewInvDialog

# setArticleLine
##sets Artikel line in New Invoice window
##set $args for Artikelverwaltung window
proc setArticleLine tab {
  global db artPrice
  #set ::menge "Menge"
.mengeE delete 0 end
.mengeE insert 0 "Menge"

  if {$tab == "TAB4"} {
    set artNum [.confArtNumSB get]

  #Invoice Tab
  } elseif {$tab == "TAB2"} {
    set artNum [.invArtNumSB get]
  }

  #Get data per line
  set token [pg_exec $db "SELECT artname,artprice,artunit,arttype FROM artikel WHERE artnum=$artNum"]
  set ::artName [lindex [pg_result $token -list] 0]
  set ::artPrice [lindex [pg_result $token -list] 1]
  set ::artUnit [lindex [pg_result $token -list] 2]
  set ::artType [lindex [pg_result $token -list] 3]

  if {$tab == "TAB4"} {
    return 0
  }

  .mengeE conf -state normal -bg beige -fg silver

    if {$::artType == "R"} { 
.mengeE delete 0 end
.mengeE insert 0 1
     .mengeE conf -bg grey -fg silver -state readonly
      set ::menge 1

    }

    if {$::artPrice == 0} {
      set ::artPrice [.invArtPriceE get]
      pack forget .invArtPriceL
      pack .invArtNameL .invArtPriceE .invArtUnitL .invArtPriceL .invArtTypeL -in .n.t2.f2 -side left   

    } else {
      pack .invArtNameL .invArtPriceL .invArtUnitL .invArtTypeL -in .n.t2.f2 -side left
    }
  
  return 0

} ;#END setArticleLine

# addInvRow
##called by setupNewInvDialog
proc addInvRow {} {
  #Create Row Frame
  namespace eval rows {}
  
  #Create Abbruch button
  catch {button .abbruchInvB}
  pack .abbruchInvB -in .n.t2.bottomF -side right
  .abbruchInvB conf -text "Abbruch" -activebackground red -command {
    pack forget .abbruchInvB
    namespace delete rows
    foreach w [pack slaves .invoiceFrame] {
      pack forget $w
    }
    resetNewInvDialog
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
      set subtot [expr $::subtot + $rowtot]

      #Create row frame
      catch {frame .invF${rowNo}}
      pack .invF${rowNo} -in .invoiceFrame -fill x -anchor w    

      #Create labels per row
      catch {label .mengeL${rowNo} -text $menge -bg lightblue -width 20 -justify left -anchor w}
      catch {label .artnameL${rowNo} -text $artName -bg lightblue -width 53 -justify left -anchor w}
      catch {label .artpriceL${rowNo} -text $artPrice -bg lightblue -width 10 -justify right -anchor w}
      catch {label .artunitL${rowNo} -text $artUnit -bg lightblue -width 5 -justify left -anchor w}
      catch {label .arttypeL${rowNo} -text $artType -bg lightblue -width 20 -justify right -anchor e}

      #Handle "A" and "R" types:
      set type [.arttypeL${rowNo} cget -text] 
      
      ##deduce Rabatt from subtot (for GUI + DB, Invoice makes its own calculation)
      if {$type == "R"} {
        set rabatt [expr ($subtot * $artPrice / 100)]
        .arttypeL${rowNo} conf -bg orange    
        .artpriceL${rowNo} conf -text "-${rabatt}" 

        #Export for saveInv2Tex
        set subtot [expr $subtot - $rabatt]        
        set ::rabatt $rabatt
      }


      catch {label .rowtotL${rowNo} -text $rowtot -bg lightblue  -width 50 -justify left -anchor w}
      pack .artnameL${rowNo} .artpriceL${rowNo} .mengeL${rowNo} -in .invF${rowNo} -anchor w -fill x -side left
      pack .artunitL${rowNo} .rowtotL${rowNo} .arttypeL${rowNo} -in .invF${rowNo} -anchor w -fill x -side left

      #Export subtot with 2 decimal points
      set ::subtot [expr {double(round(100*$subtot))/100}]    
    }
  }

} ;#END addInvRow

#TODO: save f_date with other data when printing invoice!!!
#incorporate in printInvoice

# saveInvoiceToDB
##called by "Rechnung speichern" button
proc saveInv2DB {} {
  global db adrSpin ref comm auftrdat env msg
  global artName artPrice menge cond artUnit rowtot

  #1. Get current vars - TODO: incorporate in DB as 'SERIAL', starting with %YY
	set invNo [createNewNumber invoice]
	
	#Get current address from GUI
  set shortAdr "$::name1 $::name2, $::city"

  #	set custOID [$adrSpin get]
  set custObjID [$adrSpin get]
  set custID [pg_exec $db "SELECT ts FROM address WHERE objectid=$custObjID"]
  set custOID [pg_result $custID -list]
  set cond $::cond
  set auftrDat $::auftrDat

  #2. Set payedsum=finalsum and ts=3 if cond="bar"
	if {$cond=="bar"} {
    set ts 3
    set payedsum $finalsum
  } else {
    set ts 1
    set payedsum 0
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
    payedsum
    f_number, 
    f_date, 
    f_comment
    ) 
  VALUES 
    (
    $invNo, 
    $ts, 
    $custOID, 
    '$shortAdr', 
    '$menge $artName', 
    $::subtot,
    $payedsum, 
    $invNo, 
    to_date('$auftrDat','DD MM YYYY'), 
    '$comm'
    )
  RETURNING objectid"	]

  if {[pg_result $token -error] != ""} {
    	NewsHandler::QueryNews "Rechnung $invNo nicht gespeichert:\n [pg_result $token -error ]" red

    } else {

     	NewsHandler::QueryNews "Rechnung $invNo gespeichert" green
      saveInv2Rtf

      #Reconfigure Button for Printing
      .saveInvB conf -text "Rechnung ausdrucken" -command {printInvoice $invNo}
    } 

} ;#END saveInv2DB


# saveInv2Tex 
##called by saveInv2DB
proc saveInv2Tex {invNo} {
  global spoolDir texVorlage texDir confFile env

  set itemFile [file join $texDir invitems.tex]
  set dataFile [file join $texDir invdata.tex]

  #vars from top win
  set comm [.invcomE get]
  set cond [.invcondSB get]
  set auftrDat [.invauftrdatE get]
  set subtot [.subtotalL cget -text]

  source $confFile
  if {![string is digit $vat]} {set vat 0.0}

  if {$currency=="$"} {set currency \\textdollar}
  if {$currency=="£"} {set currency \\textsterling}
  if {$currency=="€"} {set currency \\texteuro}
  if {$currency=="CHF"} {set currency {Fr.}}
  
  #1.set itemList for itemFile
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

#TODO: get Prozentsatz !
      append itemList \\Discount\{ $artName \} \{ $::rabatt \} \n
    #Check if Auslage - TODO change save2DB 
    } elseif {$artType=="A"} {
      append itemList \\EBC\{ $artName \} \{ $artPrice \} \n
    }
  } ;#END foreach w

  #2.set dataList for usepackage letter
  lappend custAdr $::name1 {\\} $::name2 {\\} $::street {\\} $::zip { } $::city

  append dataList \\newcommand\{\\comm\} \{ $comm \} \n
  append dataList \\newcommand\{\\cond\} \{ $cond \} \n
  append dataList \\newcommand\{\\dat\} \{ $auftrDat \} \n
  append dataList \\newcommand\{\\invNo\} \{ $invNo \} \n
  append dataList \\newcommand\{\\custAdr\} \{ $custAdr \} \n
  append dataList \\newcommand\{\\bank\} \{ $myBank \} \n
  append dataList \\newcommand\{\\myName\} \{ $myComp \} \n
  append dataList \\newcommand\{\\myAddress\} \{ $myAdr \} \n
  append dataList \\newcommand\{\\myPhone\} \{ $myPhone \} \n
  append dataList \\newcommand\{\\vat\} \{ $vat \} \n
  append dataList \\newcommand\{\\currency\} \{ $currency \} \n
 
  #3.Overwrite any old data file
  set chan [open $dataFile w] 
  puts $chan $dataList
  close $chan

  #4. Overwrite any old items file
  set chan [open $itemFile w]
  puts $chan $itemList
  close $chan

  #3. LaTex $vorlage & save invoice to $spool

  ##1. overwrite $vorlage.dvi
  eval exec latex -output-directory=$spoolDir -draftmode $texVorlage
return

  ##2. Create $invName DVI
  append vorlageDvi [file root $texVorlage] . dvi
  set compShortname [lindex ${myComp} 0]
  append invName invoice _ $compShortname - $invNo
  append invDviPath [file join $texDir] / $invName . dvi
  append invPdfPath [file join $spoolDir] / $invName . pdf

  ##3. Create $invName PDF  
  file copy $vorlageDvi $invDviPath
  eval exec dvipdf $invDviPath $invPdfPath
return
 
  ##4. save $invDvi to DB
  set chan [open $invDviPath]
  set invDviText [read $chan]
  close $chan
  ##convert to hex to avoid encoding probs
  set hexText [binary encode hex $invDviTex]

#TODO: gehtnicht ,keine negativ-Suchen möglich!!!  
#regsub -all {![[:xdigit:]]} $hexText {} hexText

  set token [pg_exec $db "UPDATE invoice SET dok = '$hexText' WHERE objectid = $invNo"]
  #file delete $invDviPath

  reportResult $token "Rechnung $invNo in $invPdfPath gespeichert." lightblue

  #Change "Rechnung speichern" button to "Rechnung drucken" button
  .saveInv configure -text "Rechnung drucken" -command {printInvoice}

} ;#END saveInv2Tex


# printInvoice ??TODO
##prints existing RTF
##called by "Rechnung drucken" button
##manuell mit Num.Eingabe
proc printInvoice {invNo} {
  global spoolDir printCmd
  set invName $spoolDir/invoiceVollmar-${invNo}.rtf
  if [file exists $invName] {
    NewsHandler::QueryNews "$invName wird ausgedruckt." lightblue
    exec $printCmd $invName
  } else {
    NewsHandler::QueryNews "$invName nicht gefunden." red
  }
}

# saveEntry
###called by fillAdrInvWin by $invF.$n.payedsumE entry widget
proc saveEntry {curVal curEName ns} {
  
  global db invF
  
set curNS "verbucht::${ns}"
set rowNo [namespace tail $curNS]
puts "$curNS"

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
} ;#END saveEntry



################################################################################################
### A B S C H L Ü S S E 
################################################################################################

proc abschlussErstellen {} {
  global db myComp

  set jahr [.abschlussJahrSB get]
	#put Jahr's abschluss in array
#get date from 'invoice'
	set res [pg_exec $db "SELECT f_number,f_date,addressheader,finalsum,payedsum FROM invoice WHERE EXTRACT(YEAR from f_date) = $jahr ORDER BY f_number ASC"]
	pg_result $res -assign j
	set maxTuples [pg_result $res -numTuples]

	#make text widget - TODO: try canvas instead and convert to postscript!!!
	set t .n.t3.abschlussT
	catch {text $t -width 700 -height [expr $maxTuples + 30]}
  $t delete 1.0 end
	$t configure -tabs {2c 4c 18c numeric 20c numeric}
	pack $t -anchor nw

	#compute sum total & insert text lines
	for {set no 0;set sumtotal 0} {$no <$maxTuples} {incr no} {
		set total $j($no,payedsum)
		catch {set sumtotal [expr $sumtotal + $total]}  
		$t insert end "\n $j($no,f_number) \t $j($no,f_date) \t $j($no,addressheader) \t $j($no,finalsum) \t $j($no,payedsum)"		
	}
#TODO : add Tags for font size!
	$t insert 1.0 "$myComp"
  $t insert end "Erfolgsrechnung $jahr"
  $t insert end "======================================================="
  $t insert end "\nE i n n a h m e n\n\nRch.Nr. \tDatum\tAdresse\tBetrag\tBezahlt\n\n"
	$t insert end "\n\n Einnahmen Total \t\t\t\t $sumtotal"
	$t insert end "\n\nA u s l a g e n

Büromiete
Abschr. Büroeinrichtung\t\t\t
Providergebühr\t\t\t
Web-Hosting-Jahresgebühr\t\t\t
Telefongebühren Grundtaxe & Gespräche\t\t\t
Postwertzeichen\t\t\t
Bahn-Berufsfahrten\t\t\t
Bürobedarf\t\t\t
Beglaubigungen\t\t\t
Varia
Varia

 Auslagen Total\t\t\t

R e i n g e w i n n \t\t\t\t
"
}

proc abschlussDrucken {} {
  global kontorDir

  set abschlusstext [.n.t3.abschlussT get 1.0 end]
  set jahr [.abschlussJahrSB get]
  set datei $kontorDir/reports/abschluss${jahr}.txt
  
  set chan [open $datei w]
  puts $chan $abschlusstext
  close $chan

  NewsHandler::QueryNews "Abschluss in $datei gespeichert. Wird jetzt gedruckt..." lightblue
  exec ~/bin/bas $datei
}

##################################################################################
# A R T I K E L V E R W A L T U N G
##################################################################################

proc createArticle {} {
  global db

 #clear previous entries
  .confArtNumSB set ""
  .confArtNumSB conf -bg lightgrey
#TODO:move to GUI?
  catch {entry .confartnameE -bg beige}
  catch {entry .confartunitE -bg beige -textvar rabatt}
  catch {entry .confartpriceE -bg beige}
  catch {ttk::checkbutton .confarttypeACB -text "Auslage"}
  catch {ttk::checkbutton .confarttypeRCB -text "Rabatt"}
  .confarttypeRCB conf -variable rabattselected -command {
    if [.confarttypeRCB instate selected] {
      set rabatt %
      .confartunitE conf -state readonly
      set ::artPrice "Abzug in %"
    } else {
      set rabatt ""
      .confartunitE conf -state normal
      set ::artPrice "Preis"
    }
  }

  .confartnameE delete 0 end
  .confartunitE delete 0 end
  .confartpriceE delete 0 end
  .confartpriceE conf -validate key -vcmd {%W conf -bg beige ; string is double %P} -invcmd {%W conf -bg red}
  #Rename list entries to headers  
  set ::artName "Bezeichnung"
  set ::artPrice "Preis"
  set ::artUnit "Einheit"
  pack .confArtNameL .confartnameE .confArtUnitL .confartunitE .confArtPriceL .confartpriceE .confarttypeACB .confarttypeRCB -in .n.t4.f1 -side left
  pack forget .confArtDeleteB

  #Rename Button
  .confArtCreateB conf -text "Abbruch" -activebackground red -command {
    pack forget .confartnameE .confartunitE .confartpriceE
    .confArtCreateB conf -text "Artikel erfassen" -activebackground #ececec -command {createArticle}
    .confArtNumSB conf -bg white
    pack .confArtDeleteB .confArtSaveB .confArtCreateB -in .n.t4.f1 -side right
  }
} ;#END createArticle

proc saveArticle {} {
  global db

  set artName [.confartnameE get]
  set artUnit [.confartunitE get]

  #check if type "Auslage"
  if [.confarttypeACB instate selected] {
    set artType A
  #check if type "Rabatt"
  } elseif [.confarttypeRCB instate selected] {
      set artType R
  } else {
    set artType ""
  }

  #Allow for empty article price
  set artPrice [.confartpriceE get]
  if {$artPrice == ""} {set artPrice 0}

  set token [pg_exec $db "INSERT INTO artikel (
    artname,
    artunit,
    artprice,
    arttype
    ) 
    VALUES (
      '$artName',
      '$artUnit',
      $artPrice,
      '$artType'
    )"]

  #Reset original mask
  foreach w [pack slaves .n.t4.f1] {
    pack forget $w
  }

pack .confArtL .confArtNumSB .confArtUnitL .confArtPriceL .confArtNameL .confArtTypeL -in .n.t4.f1 -side left
#pack .confArtSaveB .confArtDeleteB .confArtCreateB -in .n.t4.f1 -side right
#  pack .confArtNameL .confArtPriceL .confArtUnitL .confArtTypeL -in .n.t4.f1 -side left
  
  #Recreate article list
  updateArticleList
  reportResult $token "Artikel $artName gespeichert"

} ;#END saveArticle

# deleteArticle
proc deleteArticle {} {
  global db
  set artNo [.confArtNumSB get]
  set token [pg_exec $db "DELETE FROM artikel WHERE artnum=$artNo"]
  reportResult $token "Artikel $artNo gelöscht."
  updateArticleList
}

# updateArticleList
##gets articles from DB + updates spinboxes
proc updateArticleList {} {
  global db

  #set spinbox article no. lists
  set token [pg_exec $db "SELECT artnum FROM artikel"] 
  .invArtNumSB configure -values [pg_result $token -list]
  .confArtNumSB configure -values [pg_result $token -list]
}


#####################################################################################
# G E N E R A L : NewsHandler etc. ##################################################
#####################################################################################

namespace eval NewsHandler {
	namespace export QueryNews
  source $::progDir/JList.tcl
	
	variable queryTextJList ""
	variable queryColorJList ""
	variable counter 0
	variable isShowing 0	
	
	proc QueryNews {text color} {
		variable queryTextJList
		variable queryColorJList
		variable counter
		
		set queryTextJList [jappend $queryTextJList $text]
		set queryColorJList [jappend $queryColorJList $color]
		
		incr counter
		
		ShowNews
	}
	
	proc ShowNews {} {
		variable queryTextJList
		variable queryColorJList
		variable counter
		variable isShowing
	
		if {$counter > 0} {
			if {!$isShowing} {
				set isShowing 1
				
				set text [jlfirst $queryTextJList]
				set queryTextJList [jlremovefirst $queryTextJList]
				
				set color [jlfirst $queryColorJList]
				set queryColorJList [jlremovefirst $queryColorJList]
				
				incr counter -1
				
				.news configure -bg $color
				set ::news $text
				
				after 7000 {
					NewsHandler::FinishShowing
				}
			}
		}
	}
	
	proc FinishShowing {} {	
		variable isShowing
		
		.news configure -bg silver
		set ::news "TkOffice $::version"
		set isShowing 0
		
		ShowNews
	}
} ;#END NewsHandler

#2.Create new f_number
#TODO: let Postgres take care of it !!!!!!!!!!!!!!!!!!!!!!

proc createNewNumber {objectKind} {
#one for all!
global db	
#use new no. for all "integer not null" DB fields! (ref. saveAdress + saveInvoice)	
	if {$objectKind=="address"} {
		set object "objectid"
	} elseif {$objectKind=="invoice"} {
		set object "f_number"
	}
	set lastNo [pg_exec $db "SELECT $object FROM $objectKind ORDER BY $object DESC LIMIT 1"]
	set objectNo [pg_result $lastNo -list]
	incr objectNo
	return $objectNo
}

proc reportResult {token text} {
  #if error
  if {[pg_result $token -error] != ""} {
  	NewsHandler::QueryNews "[pg_result $token -error]" red

  #if empty - TODO: falsches ERgebnis bei Zahlungseingang!
#FOR deletions? insertions? 
  } elseif {[pg_result $token -oid] != ""} {

    NewsHandler::QueryNews "$text [pg_result $token -oid]" green
  } 
}

proc initialiseDB {dbname} {

  #1. Create DB

  #2. Create tables

    ##1. Article table
    set token [pg_exec $db "CREATE TABLE artikel (
      artnum SERIAL,
      artname text NOT NULL,
      artunit text NOT NULL,
      artprice NUMERIC
    )"
    ]
}

# dumpDB
##called by 'Datenbank sichern' button
proc dumpDB {} {
  global dbname dbuser dumpDir
  file mkdir $dumpDir

  set date [clock format [clock seconds] -format %d-%m-%Y]
  set dumpfile $dbname-${date}.sql
  set dumppath [file join $dumpDir $dumpfile]
  catch {exec pg_dump -U $dbuser $dbname > $dumppath} err
  
  if {$err != ""} {
    NewsHandler::QueryNews "Datenbank konnte nicht gesichert werden;\n$err" red
  } else {
    NewsHandler::QueryNews "Datenbank erfolgreich gesichert in $dumppath" green
  }
}

