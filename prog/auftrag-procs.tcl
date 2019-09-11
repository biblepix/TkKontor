# ~/bin/kontor/auftrag-procs.tcl
# called by auftrag.tcl
# Aktualisiert: 1nov17
# Restored: 11sep19

##################################################################################################
###  A D D R E S S  P R O C S  
##################################################################################################

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
	#insert into adrWin
	set ::name1 [pg_result $name1 -list]
	set ::name2 [pg_result $name2 -list]
	set ::street [pg_result $street -list]
	set ::zip [pg_result $zip -list]
	set ::city [pg_result $city -list]
  
  return 0
}

# fillAdrInvWin
##called by .adrSB 
##Note: ts=customerOID in 'address', now identical with objectid,needed for identification with 'invoice'
proc fillAdrInvWin {adrId} {
  global invF db
  puts "filling $adrId"

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
puts "Search string: $s"
set s [.searchE get]
puts $s

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
  .searchE conf -fg grey -validate focusin -validatecommand {
    set ::suche ""
    %W config -fg black -validate focusout -validatecommand {
      searchAddress %s
      return 0
    }
  return 0
  }

  return 0
} ;# END searchAddress

proc clearAdrWin {} {
  global adrSpin  
  foreach s [pack slaves .adrF2] {pack forget $s}  
  $adrSpin delete 0 end
  $adrSpin configure -bg gray
  .name1E configure -bg beige -fg silver -validate focusin -validatecommand {%W delete 0 end;%W conf -fg black;return 0}
  .name2E configure -bg beige -fg silver -validate focusin -validatecommand {%W delete 0 end;%W conf -fg black;return 0}
  .streetE configure -bg beige -fg silver -validate focusin -validatecommand {%W delete 0 end;%W conf -fg black;return 0}
  .zipE configure -bg beige -fg silver -validate focusin -validatecommand {%W delete 0 end;%W conf -fg black;return 0}
  .cityE configure -bg beige -fg silver -validate focusin -validatecommand {%W delete 0 end;%W conf -fg black;return 0}
  catch {pack forget .adrClearSelB}
}

proc resetAdrWin {} {
  foreach s [pack slaves .adrF2] {pack forget $s}
  pack .name1L .name2L .streetL -in .adrF2 -anchor nw
  pack .zipL .cityL -anchor nw -in .adrF2 -side left
  .b1 configure -text "Anschrift ändern" -command {changeAddress $adrNo}
  .b2 configure -text "Anschrift löschen" -command {deleteAdress $adrNo}
  catch {pack forget .adrClearSelB}
  return 0
}

proc newAddress {} {
  clearAdrWin
  set ::name1 "Anrede"
  set ::name2 "Name"
  set ::street "Strasse"
  set ::zip "PLZ"
  set ::city "Ortschaft"
  pack .name1E .name2E .streetE -in .adrF2 -anchor nw
  pack .zipE .cityE -anchor nw -in .adrF2 -side left
  .b1 configure -text "Anschrift speichern" -command {saveAddress $adrNo}
  .b2 configure -text "Abbruch" -activebackground red -command {resetAdrWin}
  return 0
}

proc changeAddress {adrNo} {
  clearAdrWin
  pack .name1E .name2E .streetE -in .adrF2 -anchor nw
  pack .zipE .cityE -anchor nw -in .adrF2 -side left
  .b1 configure -text "Anschrift speichern" -command {saveAddress $adrNo}
  .b2 configure -text "Abbruch" -activebackground red -command {resetAdrWin}
  return 0
}

proc saveAddress {} {
  global db adrSpin

	set adrno [$adrSpin get]		
	set name1 ::name1
	set name2 ::name2
	set street ::street
	set zip ::zip
	set city ::city
	
	#A: save new
	if {$adrno == ""} {
		set newNo [createNewNumber address]
		set token [pg_exec $db "INSERT INTO address (objectid, ts, name1, name2, street, zip, city) 	
		VALUES ($newNo, $newNo, '$name1', '$name2', '$street', '$zip', '$city') RETURNING objectid"]
    set adrno $newNo

	#B: change old
	} else {
				
	set token [pg_exec $db "UPDATE address SET 
		name1='$name1',
		name2='$name2',
		street='$street',
		zip='$zip',
		city='$city' 
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
  	pg_exec $db "DELETE FROM address WHERE objectid=$adrNo"
    reportResult $token "Adresse $adrNo gelöscht."
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
  catch {entry .mengeE -width 7 -textvariable ::menge -bg yellow -fg grey}
  set ::menge "Menge"
  proc unsetMenge {menge} {set ::menge ""; .mengeE conf -fg black; return 0}
  .mengeE configure -validate focusin -validatecommand {
    unsetMenge $menge
  }

  set ::subtot 0

  pack .condL .condSB .auftrDatL .auftrDatE .refL .refE .komL .komE -in .n.t2.f1 -side left -fill x 
  pack .invArtlistL -in .n.t2.f1 -before .n.t2.f2 -anchor w 
  pack .invArtNumSB .invArtNameL .invArtPriceL .mengeE .invArtUnitL -in .n.t2.f2 -side left -fill x
pack .addrowB -in .n.t2.f2 -side right -fill x
  
  #Reset .saveInvB to "Rechnung speichern"
  .saveInvB conf -text "Rechung speichern" -command "
    saveInv2DB
    saveInv2Rtf $invNo
    "
} ;#END resetNewInvDialog

# setArticleLine
##sets Artikel line in New Invoice window
##set $args for Artikelverwaltung window
proc setArticleLine tab {
global db artPrice
puts $artPrice
  #Configuration tab
  if {$tab == "TAB4"} {
    set artNum [.confArtNumSB get]
#    set artPrice [.confArtPriceL cget -text]

  #Invoice Tab
  } elseif {$tab == "TAB2"} {
    set artNum [.invArtNumSB get]
#   set artPrice [.invArtPriceL cget -text]
      if {$artPrice == 0} {
        set artPrice [.invArtPriceE get]
        pack forget .invArtPriceL
        pack .invArtPriceE .invArtUnitL .invArtPriceL -in .n.t2.f2 -side left   
    } else {
       pack .invArtNameL .invArtPriceL .invArtUnitL -in .n.t2.f2 -side left
    }
  }
  
  set token [pg_exec $db "SELECT artname,artprice,artunit FROM artikel WHERE artnum=$artNum"]
  set ::artName [lindex [pg_result $token -list] 0]
  set ::artPrice [lindex [pg_result $token -list] 1]
  set ::artUnit [lindex [pg_result $token -list] 2]
  return 0
}

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
      #Set vars
      set article $::artName
      set menge $::menge
      set einzel $::artPrice
      set unit $::artUnit
      set beschr $::artName
      set rowNo $::rows::rowNo
      set rowtot [expr $menge * $artPrice]
      #Export subtot
      set ::subtot [expr $rowtot + $::subtot]

      #Create row frame
      catch {frame .invF${rowNo}}
      catch {label .rowL${rowNo}}
      pack .invF${rowNo} -in .invoiceFrame -fill x -expand 1
 
      .rowL${rowNo} conf -text "$article \t$menge \t  Fr. $artPrice \t Fr. $rowtot" -justify left -bg lightblue
      set ::ROWS [.rowL${rowNo} conf -text]
      pack .rowL${rowNo} -in .invF${rowNo} -anchor nw -fill x
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

};#END saveInv2DB

# printInvoice
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

# saveInv2Rtf 
##called by saveInv2DB
proc saveInv2Rtf {invNo} {
  global db
  global vorlage spoolDir

  set chan [open $vorlage] 
  set invtext [read $chan]
  close $chan

#TODO: eleganter wär statt Entries mit Labels/Textvariablen!
set adr "$::name1
$::name2
$::street
$::zip $::city"
regsub -all {[{}]} $adr {} adr

set rdatkurz [.auftrDatE get]
set auftrdat $rdatkurz
#set rdatkurz $::auftrDat
set token [pg_exec $db "SELECT to_date('[.auftrDatE get]','DD MM YYYY')"]
set rdatlang [pg_result $token -list]
set ref $::ref
set cond $::cond
set finalsum $::subtot

  regsub {ADDRESS} $invtext $adr invtext
  regsub {O_DATE} $invtext $auftrdat invtext
  regsub {INV_NO} $invtext $invNo invtext
  regsub {RDATUM} $invtext $rdatlang invtext
  regsub {COMMENT} $invtext $ref	 invtext
  regsub {ROWS} $invtext $::ROWS invtext
  regsub {CONDITION} $invtext $cond invtext
  regsub {FINAL_SUME} $invtext $finalsum invtext
  regsub {HEUTE} $invtext $rdatkurz invtext 
  #what does this do?		
  regsub -all {[\s]} $invNo {} INV_NO
  	
  #Save invoice to ~spool
  append invName $spoolDir / invoiceVollmar - $invNo . rtf
	set chan [open $invName w]
	puts $chan $invtext
	close $chan
	
  #Change "Rechnung speichern" button to "Rechnung drucken" button

  .saveInvB configure -text "Rechnung drucken" -command {printInvoice}

	NewsHandler::QueryNews "Rechnung $invNo als RTF gespeichert" green

} ;#END saveInvoiceToRTF


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
  global db 
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
	$t insert 1.0 "V O L L M A R   Ü B E R S E T Z U N G S - S E R V I C E\nE r f o l g s r e c h n u n g   $jahr
=======================================================
\nE i n n a h m e n\n\nRch.Nr. \tDatum\tAdresse\tBetrag\tBezahlt\n\n"
	$t insert end "\n\n Einnahmen Total \t\t\t\t $sumtotal"
	$t insert end "\n\nA u s l a g e n

Büromiete
Abschr. Büroeinrichtung\t\t\t
Providergebühr Hoststar\t\t\t
Jahresgebühr Web-Hosting\t\t\t
Sunrise Grundtaxe & Gespräche 12x70.-\t\t\t
Postwertzeichen\t\t\t
SBB-Berufsfahrten\t\t\t
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
  catch {entry .confArtNameE -bg beige}
  catch {entry .confArtUnitE -bg beige}
  catch {entry .confArtPriceE -bg beige}

  .confArtNameE delete 0 end
  .confArtUnitE delete 0 end
  .confArtPriceE delete 0 end

  #Rename list entries to headers  
  set ::artName "Bezeichnung"
  set ::artPrice "Preis"
  set ::artUnit "Einheit"
  pack .confArtNameL .confArtNameE .confArtUnitL .confArtUnitE .confArtPriceL .confArtPriceE -in .n.t4.f1 -side left
  pack forget .confArtDeleteB

  #Rename Button
  .confArtCreateB conf -text "Abbruch" -activebackground red -command {
    pack forget .confArtNameE .confArtUnitE .confArtPriceE
    .confArtCreateB conf -text "Artikel erfassen" -activebackground #ececec -command {createArticle}
    .confArtNumSB conf -bg white
    pack .confArtDeleteB .confArtSaveB .confArtCreateB -in .n.t4.f1 -side right
  }
} ;#END createArticle

proc saveArticle {} {
  global db

  set artName [.confArtNameE get]
  set artUnit [.confArtUnitE get]

  #Allow for empty article price
  set artPrice [.confArtPriceE get]
  if {$artPrice == ""} {set artPrice 0}

  set token [pg_exec $db "INSERT INTO artikel (
    artname,
    artunit,
    artprice
    ) 
    VALUES (
      '$artName',
      '$artUnit',
      $artPrice
    )"]

  #Reset original mask
  pack forget .confArtNameE .confArtUnitE .confArtPriceE
  pack .confArtNameL .confArtPriceL .confArtUnitL -in .n.t4.f1 -side left
  
  #Recreate article list
  updateArticleList
  reportResult $token "Artikel $artName gespeichert"
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
source ~/Biblepix/prog/src/share/JList.tcl
	
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
		
		.news configure -bg grey
		set ::news "            "
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
  } elseif {[pg_result $token -numTuples] == 0} {
    NewsHandler::QueryNews "Suchergebnis leer" orange

  } else {
   	NewsHandler::QueryNews "$text" green
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

