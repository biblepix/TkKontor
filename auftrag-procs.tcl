# ~/bin/kontor/auftrag-procs.tcl
# called by auftrag.tcl
# Aktualisiert: 1nov17
# Restored: 20aug19

##################################################################################################
###  A D D R E S S  P R O C S  
##################################################################################################

proc setAdrList {} {
  global db adrSpin
	set IDlist [pg_exec $db "SELECT objectid FROM address ORDER BY objectid DESC"]
	$adrSpin configure -values [pg_result $IDlist -list] 
	$adrSpin configure -command {
		fillAdrWin %s
		fillAdrInvWin %s
	}
	#set last entry at start
  fillAdrWin [$adrSpin get]
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
  #set adrWin background
  .name1 conf -bg white
  .name2 conf -bg white
  .street conf -bg white
  .zip conf -bg white
  .city conf -bg white

  return 0
}

proc searchAddress {s} {
  global db adrSpin adrSearch adrSearchResults

  if {$s == ""} {return 0}

  #Search names/city/zip
  set adrOID [pg_exec $db "SELECT objectid FROM address WHERE 
	  name1 ~ '$s' OR 
	  name2 ~ '$s' OR
    zip ~ '$s' OR
	  city ~ '$s'
  "]

	set adrNo [pg_result $adrOID -list]
  set numTuples [pg_result $adrOID -numTuples]

  #A: open address if only 1 found
  if {$numTuples == 1} {
	  fillAdrWin $adrNo
	  fillAdrInvWin $adrNo

  #B: create spinbox to choose from
  } else {
    
    pack $adrSearchResults -in .n.t1.f2 -side right
    $adrSearchResults configure -values $adrNo -command {
      fillAdrWin %s
      fillAdrInvWin %s
  }

  $adrSpin delete 0 end
	$adrSpin set $adrNo
  .sucheL configure -text [$adrSearch get]
  }

#  .searchE delete 0 end
	return 0
}

proc clearAdrWin {} {
  global adrSpin
  set ::name1 "Anrede"
  set ::name2 "Name"
  set ::street "Strasse"
  set ::zip "PLZ"
  set ::city "Ortschaft"
  $adrSpin delete 0 end
  $adrSpin configure -bg gray
  .name1 configure -bg beige -fg silver -validate focusin -validatecommand {%W delete 0 end;%W conf -fg black;return 0}
  .name2 configure -bg beige -fg silver -validate focusin -validatecommand {%W delete 0 end;%W conf -fg black;return 0}
  .street configure -bg beige -fg silver -validate focusin -validatecommand {%W delete 0 end;%W conf -fg black;return 0}
  .zip configure -bg beige -fg silver -validate focusin -validatecommand {%W delete 0 end;%W conf -fg black;return 0}
  .city configure -bg beige -fg silver -validate focusin -validatecommand {%W delete 0 end;%W conf -fg black;return 0}
  #focus .name1
}

proc saveAddress {} {
  global db adrSpin

	set adrno [$adrSpin get]		
	set name1 [.name1 get]
	set name2 [.name2 get]
	set street	[.street get]
	set zip [.zip get]
	set city [.city get]
	
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
}

proc deleteAddress {} {
	pg_exec $::db "DELETE FROM address WHERE objectid=[$adrSpin get]"
}

# fillAdrInvWin
##shows all invoices of current customer
proc fillAdrInvWin {adrOID} {
global db invF

	#Delete previous frames
	foreach i [winfo children $invF] {pack forget $i} 

	#ts=customerOID in 'address', now identical with objectid,needed for identification with 'invoice'
	set customerOID [pg_exec $db "SELECT ts FROM address WHERE objectid = $adrOID"]
	set invNo [pg_exec $db "SELECT f_number FROM invoice WHERE customeroid=[pg_result $customerOID -list] "]
  set invDat [pg_exec $db "SELECT f_date FROM invoice WHERE customeroid=[pg_result $customerOID -list] "]
	set beschr [pg_exec $db "SELECT shortdescription FROM invoice WHERE customeroid=[pg_result $customerOID -list]"]
	set sumtotal [pg_exec $db "SELECT finalsum FROM invoice WHERE customeroid = [pg_result $customerOID -list]"]
	set payedsum [pg_exec $db "SELECT payedsum FROM invoice WHERE customeroid = [pg_result $customerOID -list]"]
	set status [pg_exec $db "SELECT ts FROM invoice WHERE customeroid = [pg_result $customerOID -list]"]	

	set nTuples [pg_result $invNo -numTuples]

	if {$nTuples!=-1} {

		for {set n 0} {$n<$nTuples} {incr n} {

			#-getTuple must have 0-9
			set bezahlt [pg_result $payedsum -getTuple $n] 
			set total [pg_result $sumtotal -getTuple $n] 
			set ts [pg_result $status -getTuple $n]
			set invno [pg_result $invNo -getTuple $n]
      set invDat [pg_result $invDat -getTuple $n]
			set desc [pg_result $beschr -getTuple $n]

			#increase but don't overwrite frames per line	
			catch {frame $invF.$n}
			pack $invF.$n -anchor nw -side top -fill x

#TODO: replace labels with 'text' lines and bind to scrollbar! (list tends to get too long!)

			#create entries per line, or refill present entries
			catch {label $invF.$n.invNo -width 10}
			$invF.$n.invNo configure -text $invno
      catch {label $invF.$n.invDatL -width 10}
			$invF.$n.invDatL configure -text $invDat
			catch {	label $invF.$n.beschr -width 30 -justify left}
			$invF.$n.beschr configure -text $desc
			catch {	label $invF.$n.sumtotal -width 10}
			$invF.$n.sumtotal configure -text $total
			catch {label $invF.$n.status -width 10}
			$invF.$n.status configure -text $ts

			#PAYEDSUM label/entry
			#If 3 (payed) make label
			if {$ts==3} {
				set ::zahlen ""
				destroy $invF.$n.payedsum
				label $invF.$n.payedsum -width 10 -text $bezahlt
        $invF.$n.payedsum configure -fg green

			#If 1 or 2 make entry
			} else {
				catch {label $invF.$n.zahlen -textvariable ::zahlen -fg red -width 50}
				pack $invF.$n.zahlen -side right
				set ::zahlen  "Zahlbetrag eingeben und mit Tab-Taste quittieren"

				destroy $invF.$n.payedsum
				entry $invF.$n.payedsum -width 10 \
				-validate focusout -validatecommand "saveZahlungseingang %P %W $nTuples" 

			#if 2 (Teilzahlung) include payed amount
			#WARUM IST payedsum LEER - can't use -textvariable with -validatecommand!
				if {$ts==2} {
					$invF.$n.payedsum configure -bg orange
					$invF.$n.zahlen configure -bg orange -fg white -width 75
					set ::zahlen "Bezahlt: $bezahlt - Restbetrag hinzuzählen und Gesamtbetrag mit Tab-Taste quittieren"
				}
			}
	
#Print button - NEIN, Ausdruck nur ab RTF(TeX) möglich, RTF(TeX) wird nun immer gemacht
#    catch {button $invF.$n.invPrintB -text "Drucken" -padx 10 -command {printInvoiceFromRow}}

#pack forget [winfo children $invF]		
    pack $invF.$n.invNo $invF.$n.invDatL $invF.$n.beschr $invF.$n.sumtotal $invF.$n.payedsum $invF.$n.status -side left
#		pack $invF.$n.invPrintB -side left 
	
		} ;#end for loop
	} ;#END if not empty
} ;#end fillAdrInvWin



################################################################################################################
################# I N V O I C E   P R O C S ####################################################################
################################################################################################################

# resetNewInvDialog
##called by Main + "Abbruch Rechnung"
proc resetNewInvDialog {} {
  pack forget [pack slaves .invoiceFrame]

  catch {entry .artPriceE -width 10}
  catch {label .artNameL -textvariable ::artName -padx 10}
  catch {label .artPriceL -textvariable ::artPrice -padx 10}
  catch {label .artUnitL -textvariable ::artUnit -padx 30}

  #create Addrow button
  catch {button .addrowB -text "Hinzufügen" -command {addInvRow}}
  catch {message .einheit -textvariable unit}
  catch {message .einzel -textvariable einzel}

  #Create Menge entry
  catch {entry .mengeE -width 5 -textvariable menge -bg yellow -fg grey}
  set menge "Menge"
  proc unsetMenge {menge} {set ::menge ""; .mengeE conf -fg black; return 0}
  .mengeE configure -validate focusin -validatecommand {unsetMenge $menge}

  set ::subtot 0

  pack .condL .condSB .auftrDatL .auftrDatE .refL .refE .komL .komE -in .n.t2.f1 -side left -fill x 
  pack .artlistL -in .n.t2.f1 -before .n.t2.f2 -anchor w 
  pack .artNumSB .artNameL .artPriceL .mengeE .artUnitL .addrowB -in .n.t2.f2 -side left -fill x
  
  #Reset .saveInvB to "Rechnung speichern"
  .saveInvB conf -text "Rechung speichern" -command {
    saveInv2DB
#TODO: reactivate after testing!
#    saveInv2Rtf $invNo
    }

} ;#END resetNewInvDialog

# setArticleLine
##sets Artikel line in New Invoice window
##set $args for Artikelverwaltung window
proc setArticleLine tab {
global db
  if {$tab == "TAB4"} {
    set artNum [.artikelNumSB get]
  } elseif {$tab == "TAB2"} {
    set artNum [.artNumSB get]
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

  #Repack main frame
  #pack .invoiceFrame -in .n.t2.f2 -side bottom -fill both

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
#	set adr "[.name1 get]\n[.name2 get]\n[.street get]\n[.zip get] [.city get]"
  set shortAdr "[.name1 get] [.name2 get], [.city get]"

	#get rid of {} & format for RTF
#	regsub -all {[{}]} $adr {} adr
#	regsub -all {[[:cntrl:]]} $adr {\\par&} adr
	
  #	set custOID [$adrSpin get]
  set custObjID [$adrSpin get]
  set custID [pg_exec $db "SELECT ts FROM address WHERE objectid=$custObjID"]
  set custOID [pg_result $custID -list]

  #Get Auftragsdatum & convert to Postgres 'date' format
#  set token [pg_exec $db "SELECT to_date('[.auftrDatE get]','DD MM YYYY')"]
#  set auftrDat [pg_result $token -list]
#	set beschr "$auftrDat | $artName"
  set cond [.condSB get ]
#	set MENGE $menge
#	set EINZEL $artPrice
#	set UNIT $artUnit
	#set SUME $rowtot[expr {$MENGE * $EINZEL}]  ;#extra 0 added in template
	#set finalsum $::subtot

set auftrDat [.auftrDatE get]

  #2. Save new invoice to DB
	if {$cond=="bar"} {set ts 3} {set ts 1}	

  set token [pg_exec $db "INSERT INTO invoice 
    (
    objectid,
    ts, 
    customeroid, 
    addressheader, 
    shortdescription, 
    finalsum, 
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
    $invNo, 
    to_date('$auftrDat','DD MM YYYY'), 
    '$comm'
    )
  RETURNING objectid"	]

  if {[pg_result $token -error] != ""} {
    	NewsHandler::QueryNews "Rechnung $invNo nicht gespeichert:\n [pg_result $token -error ]" red

    } else {

     	NewsHandler::QueryNews "Rechnung $invNo gespeichert" green

      #Reconfigure Button for Printing
      .saveInvB conf -text "Rechnung ausdrucken" -command {printInvoice}
    } 
};#END saveInv2DB

# printInvoice
##prints existing RTF
##called by "Rechnung drucken" button
##manuell mit Num.Eingabe
proc printInvoice {invNo} {
  global spoolDir
  set invName $spooldir/rechnung-vollmar-${invNo}.rtf
  if [file exists $invName] {
    NewsHandler::QueryNews "$invName wird ausgedruckt." lightblue
    exec bas $invNo
  } else {
    NewsHandler::QueryNews "$invName nicht gefunden." red
  }
}

# saveInv2Rtf 
##called by saveInv2DB
proc saveInv2Rtf {invNo} {
  global vorlage
  global adr auftrdat rdatlang ref cond finalsum rdatkurz
	NewsHandler::QueryNews "Speichere Rechnung $invNo als RTF..." lightblue

  set chan [open $vorlage] 
  set invtext [read $chan]
  close $chan

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
  .saveInv configure -text "Rechnung drucken" -command {printInvoice}

} ;#END writeInvoiceToRTF


proc saveZahlungseingang {P activePayedEntry nTuples} {
  #called by entry widget "validatecommand", needs 'return 0'
  global db invF
  set oldpayedsum ""
  set payedsum ""

  puts "%P : $P"
  puts "Active: $activePayedEntry Tuples: $nTuples"


  #TODO:

  #1.determine active entry row - GEHT NICHT
  #set entryName 
  #invalid command name "$invF..invNo"
  #    while executing
  #"$invF.$rowNo.invNo cget -text"
   #   (procedure "saveZahlungseingang" line 16)
  #GEHT NICHT WENN MEHRERE entries VORHANDEN!!!
	  
  #Trick7: set some unimportant attr. to 1
		  #$activePayedEntry configure -takefocus 1

  #Get row no. from activePayedEntry
  regexp -start 7 -indices {[0-9]} $activePayedEntry loc
  set rowNo [string index $activePayedEntry [lindex $loc 0] ]

  #Search each tuple 
  #	for {set n 0} {$n<$nTuples} {incr n} {
	  #define row number from last digit 
		  
  #	set digitIndex [string last $n $activePayedEntry]
  #		set rowNo [string index $activePayedEntry $digitIndex]

   #puts "digitindex: $digitIndex"
  puts "loc: $loc"
  puts "Row: $rowNo"
  #}


	
	#2. get invNo
	set invNo [$invF.$rowNo.invNo cget -text]

	#2. Betrag lesen & in DB einfügen überschreiben! / status ändern
	set payedsum [$invF.$rowNo.payedsum get]
	set finalsum [pg_exec $db "SELECT finalsum FROM invoice WHERE f_number=$invNo"]

puts "payedsum: $payedsum"
puts "finalsum: [pg_result $finalsum -list]"

	#Insert payedsum if digit, avoiding errors
	if {[regexp {[[:digit:]]} $payedsum]} {
puts digit
		
	
		if {$payedsum==[pg_result $finalsum -list]} {
			set status 3
		} else {
			set status 2
		}

		#add to DB
		pg_exec $db "UPDATE invoice SET payedsum='$payedsum' WHERE f_number=$invNo"
		pg_exec $db "UPDATE invoice SET ts='$status' WHERE f_number=$invNo"

		#update GUI
		set ::zahlen  "Betrag CHF $payedsum verbucht"
		$invF.$rowNo.zahlen configure -fg green -textvariable ::zahlen
		set status [pg_exec $db "SELECT ts FROM invoice WHERE f_number=$invNo;"]
		$invF.$rowNo.status configure -text	[pg_result $status -list]
		set payedsum [pg_exec $db "SELECT payedsum FROM invoice WHERE f_number=$invNo;"]
		$invF.$rowNo.payedsum configure -text [pg_result $payedsum -list] -state readonly 
	} 

return 0
} ;#END saveZahlungseingang



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

  #check if 'artikel' exists, else create TABLE
  set err [pg_exec $db "SELECT 1 from artikel"]
  if {[pg_result $err -error] != ""} {
    set token [pg_exec $db "CREATE TABLE artikel (
      artnum SERIAL,
      artname text NOT NULL,
      artunit text NOT NULL,
      artprice NUMERIC
    )"
    ]
  reportResult $token "Tabelle 'Artikel' in Datenbank erstellt"
  }

 #clear article entries
  .artikelNumSB set ""
  .artikelNumSB conf -bg lightgrey
  catch {entry .artikelNameE -bg beige}
  catch {entry .artikelUnitE -bg beige}
  catch {entry .artikelPriceE -bg beige}
  
  #Rename list entries to headers  
  set ::artName "Bezeichnung"
  set ::artPrice "Preis"
  set ::artUnit "Einheit"
  pack .artikelNameL .artikelNameE .artikelUnitL .artikelUnitE .artikelPriceL .artikelPriceE -in .n.t4.f1 -side left
  pack forget .artikelDeleteB

  #Rename Button
  .artikelCreateB conf -text "Abbruch" -activebackground red -command {
    pack forget .artikelNameE .artikelUnitE .artikelPriceE
    .artikelCreateB conf -text "Artikel erfassen" -activebackground #ececec -command {createArticle}
    .artikelNumSB conf -bg white
    pack .artikelDeleteB .artikelSaveB .artikelCreateB -in .n.t4.f1 -side right
  }
}

proc saveArticle {} {
  global db

  set artName [.artikelNameE get]
  set artUnit [.artikelUnitE get]
  set artPrice [.artikelPriceE get]
  set token [pg_exec $db "INSERT INTO artikel (artname,artunit,artprice) VALUES ('$artName','$artUnit',$artPrice)"]

  #Reset original mask
  pack forget .artikelNameE .artikelUnitE .artikelPriceE
  pack .artikelNameL .artikelPriceL .artikelUnitL -in .n.t4.f1 -side left
  
  #Recreate article list
  createArticleList
  
  reportResult $token "Artikel $artName gespeichert"
}





#TODO: bu ne?
proc updateArticleList {} {
  global db
  #set ::artnum [pg_result [pg_exec $db "SELECT artnum WHERE art"] -list]
  set artNum [.artNumSB get]
  set token [pg_exec $db "SELECT artunit,artname,artprice from artikel WHERE artnum=$artNum"]
  .artNameE delete 0 end
  .artUnitE delete 0 end
  .artPriceE delete 0 end
  .artUnitE insert 0 [lindex [pg_result $token -list] 0]
  .artNameE insert 0 [lindex [pg_result $token -list] 1]
  .artPriceE insert 0 [lindex [pg_result $token -list] 2]
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

  if {[pg_result $token -error] != ""} {
      	NewsHandler::QueryNews "[pg_result $token -error ]" red

  } else {
     	NewsHandler::QueryNews "$text" green
		  #Update Address list
#		  catch setAdrList
  } 
}
