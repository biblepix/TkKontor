# ~/TkOffice/prog/tkoffice-procs.tcl
# called by tkoffice-gui.tcl
# Salvaged: 1nov17
# Restored:10feb20

##################################################################################################
### G E N E R A L   &&   A D D R E S S  P R O C S  
##################################################################################################

# roundDecimal
##rounds any sum to $sum.$dp
##called by various output progs 
proc roundDecimal {sum} {
  set dp 2 ;#no. of decimal places
  set rounded [format "%.${dp}f" $sum]
  return $rounded
}

# latex2pdf
##produces PDF of any TeX file
##called by ?printInvoice? & ?printReport?
proc latex2pdf {texPath} {
  global tmpDir spoolDir reportDir
  
  #Latex > PDF
  namespace eval Latex {}
  set Latex::texPath $texPath
  set Latex::tmpDir $tmpDir
  namespace eval Latex {
    eval exec -- pdflatex -interaction nonstopmode -output-directory $tmpDir $texPath
  }

  #Copy PDF to correct location
  set fileName [file tail $texPath]
  if [regexp Abschluss $texPath] {
    set targetDir $reportDir
  } else {
    set targetDir $spoolDir
  }
  set pdfName [file root $fileName].pdf
  file copy -force [file join $tmpDir $pdfName] $targetDir
  
  NewsHandler::QueryNews "Die Datei $pdfName befindet sich in $targetDir zur weiteren Bearbeitung." lightgreen
  return 0
}

# printPdf
##sends PDF to printer / viewer
##called by ?printInvoice? & ?printReport?
proc printPdf {pdfPath} {
  
}



# createTkOfficeLogo
##called by tkoffice-gui.tcl 
proc createTkOfficeLogo {} {
#Bitmap should work, but donno why it doesn't
#$invF.$n.invshowB conf -bitmap $::verbucht::bmdata -command "showInvoice $invno"

  set bildschirmbreite [winfo screenwidth .]
  set fensterbreite [winfo width .]
  set blau lightblue2
  set dunkelblau steelblue3

  canvas .logoC -width $bildschirmbreite -height 30 -borderwidth 7 -bg $dunkelblau
  pack .logoC -in .titelF -side left -anchor nw

  set kreis [.logoC create oval 7 7 50 50]
  .logoC itemconf $kreis -fill orange -outline red

  set schrift0 [.logoC create text 23 28]
  .logoC itemconf $schrift0 -font "TkHeadingFont 18 bold" -fill $dunkelblau -text "T"
  set schrift1 [.logoC create text 32 32]
  .logoC itemconf $schrift1 -font "TkCaptionFont 18 bold" -fill $dunkelblau -text "k"

  set schrift2 [.logoC create text 95 30]
  .logoC itemconf $schrift2 -font "TkHeadingFont 20 bold" -fill orange -text "f f i c e"

  set schrift3 [.logoC create text 8 65 -anchor w]
  .logoC itemconf $schrift3 -font "TkCaptionFont 18 bold" -fill $blau -text "TkOffice Business Software"
  
  set schrift4 [.logoC create text 0 110 -anchor w]
  .logoC itemconf $schrift4 -font "TkHeadingFont 50 bold" -fill red -text "Auftragsverwaltung" -angle 4.
  .logoC lower $schrift4

  set schrift5 [.logoC create text 900 128 -justify right -text TkOffice.vollmar.ch]
  .logoC itemconf $schrift5 -fill $blau -font "TkCaptionFont 14 bold"
}

#Create small bitmap ::verbucht::im 
##called by fillAdrInvWin
#for printInvButton
#Bitmap should work, but donno why it doesn't:
# $invF.$n.invshowB conf -bitmap $::verbucht::bmdata -command "showInvoice $invno"
proc createPrintBitmap {} {
    set bmdata {
      #define printInvB_width 7
      #define printInvB_height 7
      static unsigned char printInvB_bits[] = {
      0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f};
    }
    set ::verbucht::printBM [image create bitmap -data $bmdata]
    $::verbucht::printBM conf -foreground red -background red
}

#############################################################################################
###  A D D R E S S  P R O C S  
#############################################################################################

proc setAdrList {} {
  global db adrSpin
  $adrSpin config -bg lightblue
	set IDlist [pg_exec $db "SELECT objectid FROM address ORDER BY objectid DESC"]
	$adrSpin conf -values [pg_result $IDlist -list] 
	
	$adrSpin conf -command {
		fillAdrWin %s
		fillAdrInvWin %s
	} -validate key -vcmd {
  	fillAdrWin %s
  	after idle {%W config -validate %v}
  	return 1
	} -invcmd {}
	
	#set last entry at start
  fillAdrWin [$adrSpin get]
  catch {pack forget .adrClearSelB} 
}

proc fillAdrWin {adrId} {
global db adrWin1 adrWin2 adrWin3 adrWin4 adrWin5
  #set variables
	set name1 [pg_result [pg_exec $db "SELECT name1 FROM address WHERE objectid=$adrId"] -list]
	set name2 [pg_result [pg_exec $db "SELECT name2 FROM address WHERE objectid=$adrId"] -list]
	set street [pg_result [pg_exec $db "SELECT street FROM address WHERE objectid=$adrId"] -list]
	set city [pg_result [pg_exec $db "SELECT city FROM address WHERE objectid=$adrId"] -list]
	set ::zip  [pg_result [pg_exec $db "SELECT zip FROM address WHERE objectid=$adrId"] -list]

  #Export if not empty
  set tel1 [pg_result [pg_exec $db "SELECT telephone FROM address WHERE objectid=$adrId"] -list]
  set tel2 [pg_result [pg_exec $db "SELECT mobile FROM address WHERE objectid=$adrId"] -list]
  set fax  [pg_result [pg_exec $db "SELECT telefax FROM address WHERE objectid=$adrId"] -list]
  set mail [pg_result [pg_exec $db "SELECT email FROM address WHERE objectid=$adrId"] -list]
  set www  [pg_result [pg_exec $db "SELECT www FROM address WHERE objectid=$adrId"] -list]

  regsub {({)(.*)(})} $name1 {\2} ::name1
  regsub {({)(.*)(})} $name2 {\2} ::name2
  regsub {({)(.*)(})} $street {\2} ::street
  regsub {({)(.*)(})} $city {\2} ::city
  regsub {({)(.*)(})} $tel1 {\2} ::tel1
  regsub {({)(.*)(})} $tel2 {\2} ::tel2

  if {[string is punct $tel1] || $tel1==""} {set ::tel1 "Telefon1" ; .tel1E conf -fg silver} {set ::tel1 $tel1}
  if {[string is punct $tel2] || $tel2==""} {set ::tel2 "Telefon2" ; .tel2E conf -fg silver} {set ::tel2 $tel2}
  if {[string is punct $mail] || $mail==""} {set ::mail "Mail" ; .mailE conf -fg silver} {set ::mail $mail}
  if {[string is punct $www] || $www==""} {set ::www "Internet" ; .wwwE conf -fg silver} {set ::www $www}
  if {[string is punct $fax] || $fax==""} {set ::fax "Telefax" ; .faxE conf -fg silver} {set ::fax $fax}
  
  return 0
} ;#END fillAdrWin

proc searchAddress {} {
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
	set adrNumList [pg_result $token -list]
  set numTuples [pg_result $token -numTuples]
puts $adrNumList
puts $numTuples

  if {$numTuples == 0} {
    NewsHandler::QueryNews "Suchergebnis leer!" red
    after 5000 {resetAdrSearch}
    return 1
  }
  
  #A: open address if only 1 found
  if {$numTuples == 1} {
    $adrSpin set $adrNumList
	  fillAdrWin $adrNumList
	  fillAdrInvWin $adrNumList

  #B: fill adrSB spinbox to choose from selection
  } elseif {$numTuples > 1} {

    $adrSpin config -bg beige -values "$adrNumList"
    fillAdrWin [$adrSpin get]
    fillAdrInvWin [$adrSpin get]
    catch {button .adrClearSelB -width 13 -text "^ Auswahl löschen" -command setAdrList}
    pack .adrClearSelB -in .adrF1
  }

  #Reset adrSearch widget & address list (called by .adrClearSelB)
  after 5000 {resetAdrSearch}
  return 0
} ;# END searchAddress

# clearAdrWin
##called by "Neue Anschrift" & "Anschrift ändern" buttons
proc clearAdrWin {} {
  global adrSpin adrSearch
  foreach e "[pack slaves .adrF2] [pack slaves .adrF4]" {
    $e conf -bg beige -fg silver -state normal -validate focusin -validatecommand {
    %W delete 0 end
  catch {  %W conf -fg black}
    return 0
    }
  }
  catch {pack forget .adrClearSelB}
  $adrSearch conf -state disabled
  .adrF2 conf -bg #d9d9d9
  return 0
}

# resetAdrSearch
##called by GUI + searchAddress
proc resetAdrSearch {} {
  global adrSearch
  $adrSearch delete 0 end
  $adrSearch insert 0 "Adresssuche (+Tab)"
  $adrSearch config -fg grey -validate focusin -vcmd {
    %W delete 0 end
    %W conf -fg black
    after idle {
      %W conf -validate focusout -vcmd searchAddress
    }
    return 0
  }
}

# resetAdrWin
##called by GUI (first fill) + Abbruch btn + aveAddress
proc resetAdrWin {} {
  global adrSpin adrSearch
  
  pack .name1E .name2E .streetE -in .adrF2 -anchor nw
  pack .zipE .cityE -anchor nw -in .adrF2 -side left
  pack .tel1E .tel2E .faxE .mailE .wwwE -in .adrF4

  foreach e "[pack slaves .adrF2] [pack slaves .adrF4]" {
    $e conf -bg lightblue -validate none -fg black -state readonly -readonlybackground lightblue -relief flat -bd 0
  }

  .b1 config -text "Anschrift ändern" -command {changeAddress $adrNo}
  .b2 config -text "Anschrift löschen" -command {deleteAddress $adrNo}
  pack .b1 .b2 .b0 -in .adrF3 -anchor se  

  $adrSpin conf -bg lightblue
  $adrSearch conf -state normal
  .adrF2 conf -bg lightblue
  catch {pack forget .adrClearSelB}

  setAdrList
  fillAdrInvWin [$adrSpin get]
}

proc newAddress {} {
  global adrSpin

  set ::name1 "Anrede/Firma"
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
  $adrSpin conf -bg #d9d9d9  

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
  #set tel2 [.tel2E get]
 # set mail [.mailE get]
  set www [.wwwE get]
set mail $::mail
set tel2 $::tel2

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
   	NewsHandler::QueryNews "Anschrift Nr. $adrno gespeichert" lightgreen
	  #Update Address list
	  catch setAdrList
  } 

  resetAdrWin
} ;#END saveAddress

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
} ;#END deleteAddress



##################################################################################
#### A R T I K E L V E R W A L T U N G
##################################################################################

# resetArticleWin
##called by ... in Artikel verwalten
proc resetArticleWin {} {

  pack .confArtT .confArtM -in .n.t4.f1 -anchor w
  pack .confArtL .confartnumSB .confArtUnitL .confArtPriceL .confartnameL .confArtTypeL -in .n.t4.f1 -side left
  pack .confArtDeleteB .confArtCreateB -in .n.t4.f1 -side right
  pack forget .confArtSaveB .confarttypeACB .confarttypeRCB
  pack forget .confartnameE .confartunitE .confartpriceE
  .confArtDeleteB conf -text "Artikel löschen" -command {deleteArticle}
  .confArtCreateB conf -text "Artikel erfassen" -command {createArticle}
}

# setArticleLine
##sets Artikel line in New Invoice window + Artikelverwaltung
##needs TAB2 / TAB4 args
##called by GUI + spinboxes .confartnumSB/.invartnumSB
proc setArticleLine {tab} {
  global db
  .confArtTypeL conf -bg #c3c3c3
  
  if {$tab == "TAB4"} {
    set artNum [.confartnumSB get]
    
  } elseif {$tab == "TAB2"} {
    .mengeE delete 0 end
    .mengeE conf -bg beige
    .mengeE conf -insertbackground orange -insertwidth 10 -insertborderwidth 5 -insertofftime 500 -insertontime 1000  
    .mengeE conf -state normal -validate key -vcmd {string is double %P} -invcmd {%W conf -bg red; after 2000 {%W conf -bg beige}}
    set artNum [.invartnumSB get]
    focus .invartnumSB
  }
  
  #Read spinboxes
  if {$tab == "TAB2"} {
    namespace eval artikel {
      set artNum [.invartnumSB get]
    }
  } else {
    namespace eval artikel {
      set artNum [.confartnumSB get]
    }
  }

  #Get DB data per line
  namespace eval artikel {
    set token [pg_exec $db "SELECT artname,artprice,artunit,arttype FROM artikel WHERE artnum=$artNum"]
    set artName [lindex [pg_result $token -list] 0]
    set artPrice [lindex [pg_result $token -list] 1]
    set artUnit [lindex [pg_result $token -list] 2]
    set artType [lindex [pg_result $token -list] 3]
  
    if {$artType == "R"} {
      .mengeE delete 0 end
      .mengeE insert 0 "1"
      .mengeE conf -bg grey -fg silver -state readonly
      .confArtTypeL conf -bg yellow
    } elseif {$artType == "A"} {
      .confArtTypeL conf -bg orange
    }
  }
  
  if {$tab == "TAB4"} {
    return 0
  }

#TODO get order right! 
  namespace eval artikel {
    if {$artPrice == 0} {
      set artPrice [.invArtPriceE get]
      pack forget .invArtPriceL
      pack .invArtUnitL .invArtNameL .invArtPriceE .invArtTypeL -in .n.t2.f2 -side left   
    } else {
      pack forget .invArtPriceE
      pack .invArtUnitL .invArtNameL .invArtPriceL .invArtTypeL -in .n.t2.f2 -side left
    }
  }
  
  return 0

} ;#END setArticleLine

proc createArticle {} {
  global db

 #clear previous entries & add .confArtSaveB
  .confartnumSB set ""
  .confartnumSB conf -bg lightgrey
  pack .confArtSaveB -in .n.t4.f1 -side right
   
#TODO:move to GUI?
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
  pack .confartnameL .confartnameE .confArtUnitL .confartunitE .confArtPriceL .confartpriceE .confarttypeACB .confarttypeRCB -in .n.t4.f1 -side left
  pack forget .confArtDeleteB

  #Rename Button
  .confArtCreateB conf -text "Abbruch" -activebackground red -command {resetArticleWin}
  
#TODO: articleWin is not reset after saving!!!
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

pack .confArtL .confartnumSB .confArtUnitL .confArtPriceL .confartnameL .confArtTypeL -in .n.t4.f1 -side left
#pack .confArtSaveB .confArtDeleteB .confArtCreateB -in .n.t4.f1 -side right
#  pack .confArtNameL .confArtPriceL .confArtUnitL .confArtTypeL -in .n.t4.f1 -side left
  
  #Recreate article list
  updateArticleList
  resetArticleWin
  setArticleLine TAB4
  reportResult $token "Artikel $artName gespeichert"

} ;#END saveArticle

# deleteArticle
proc deleteArticle {} {
  global db
  set artNo [.confartnumSB get]
  set res [tk_messageBox -message "Wollen Sie Artikel $artNo wirklich löschen?" -type yesno]
  if {$res == "yes"} {
    set token [pg_exec $db "DELETE FROM artikel WHERE artnum=$artNo"]
    reportResult $token "Artikel $artNo gelöscht."
    updateArticleList
    setArticleLine TAB4
  }
}

# updateArticleList
##gets articles from DB + updates spinboxes
##called by saveArticle / ...
proc updateArticleList {} {
  global db

  #set spinbox article no. lists
  set token [pg_exec $db "SELECT artnum FROM artikel"] 
  .invartnumSB conf -values [pg_result $token -list]
  .confartnumSB conf -values [pg_result $token -list]
}


################################################################################
### G E N E R A L   P R O C S
################################################################################

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

    NewsHandler::QueryNews "$text [pg_result $token -oid]" lightgreen
  } 
}

proc initialiseDB {dbname} {
  global db
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
    
  set token [pg_exec $db "CREATE TABLE spesen (
    num SERIAL,
    name text NOT NULL,
    value NUMERIC NOT NULL
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
    NewsHandler::QueryNews "Datenbank erfolgreich gesichert in $dumppath" lightgreen
  }
}

# T  E  S  T  I  N   G

#
 # Capture a window into an image
 # Author: David Easton
 #
proc canv2ps {canv} {
  global reportDir tmpDir
  set win .abschlussT

  set origCanvHeight [winfo height $canv]
    
  #1. move win to top position + make first PS page
  raise $win
  update
  $win yview moveto 0.0 
  raise $win
  update

  set pageNo 1
  $canv postscript -colormode gray -file [file join $tmpDir abschluss_$pageNo.ps]
  
  #move 1 page
  set visFraction [$win yview]
  set begVisible [lindex $visFraction 0] 
  set endVisible [lindex $visFraction 1]
  $win yview moveto $endVisible

  while {$endVisible < 1.0} {

    incr pageNo
        
    set lastVisible $endVisible
    raise $win
    update
    $canv postscript -colormode gray -file [file join $tmpDir abschluss_$pageNo.ps]

    #move 1 page
    set visFraction [$win yview]
    set begVisible $endVisible
    set endVisible [lindex $visFraction 1]
    $win yview moveto $endVisible      
    
	}

puts $endVisible
puts $lastVisible	

	#3. Compute remaining page height & adapt window dimension
    if {$begVisible < $lastVisible} {
        set cutoutPercent [expr $begVisible - $lastVisisble]
        set hiddenHeight [expr round($cutoutPercent * $origCanvHeight)]
        set visHeight [expr $origCanvHeight - $hiddenHeight]
        $canv itemconf textwin -height $visHeight
        $canv conf -height $visHeight 
    }



  incr pageNo
  
  #4. Make last page
  raise $win
  update
  $canv postscript -colormode gray -file [file join $tmpDir abschluss_$pageNo.ps]
  
  #5. Restore original dimensions
  $canv itemconf textwin -height $origCanvHeight
  $canv conf -height $origCanvHeight 
}

proc captureWindow {win} {
  global tmpDir reportDir
  
  set ppmDir $tmpDir/tkoffice_ppm
  file mkdir $ppmDir
  set ppmFile [file join $ppmDir abschluss.ppm]
  
  #create base image with defined height and width

  
  set winX [winfo width $win]
  set winY [winfo height $win]
  
  $win yview moveto 0.0 
  image create photo abschlussPpm -format window -data $win -width $winX -height $winY
  
  set y2 [image height abschlussPpm]
  set x2 [image width abschlussPpm]
 
  ##move win to top & get visible window coords

  set visibleFraction [$win yview]
  set begVisible [lindex $visibleFraction 0] 
  set endVisible [lindex $visibleFraction 1]

  ##count lines for hiding
#  set totalLines [$win count -lines 1.0 end]
  
  while {$endVisible < 1.0} {

    $win yview moveto $endVisible
    
    image create photo abschlussPart -format window -data $win -width $winX -height $winY
	  abschlussPpm copy -shrink abschlussPart -to $y2 $x2 

    set begVisible $endVisible
    set endVisible [lindex [$win yview] 1]
    
    set x2 [image width abschlussPpm]
    set y2 [image height abschlussPpm]
	}
	
  ##compute lines to hide for last fraction
#  set visFraction [lindex [$win yview ] 0]
#  set invisible [expr round($visFraction * $totalLines)] 
#  $win tag configure hide -elide
#  $win tag add hide 0.0 $invisible.end

  image create photo abschlussEnd -format window -data $win -width $winX -height $winY
  #compute any top whiteArea
  ##TODO take from BiblePix !
  
	abschlussPpm copy -shrink abschlussEnd -to $y2 $x2 

  abschlussPpm write -format PPM $ppmFile
#  abschlussPpm write -format PNG $abschlussPng

} ;#END captureWindow

proc window2ppm {win} {
  global tmpDir reportDir
  
  set ppmDir $tmpDir/tkoffice_ppm
  file mkdir $ppmDir
  
  #first page pic
  $win yview moveto 0.0 
  set picNo 1
  image create photo abschlussPpm -format window -data $win 
	abschlussPpm write -format PPM [file join $ppmDir abschluss${picNo}.ppm]  
  
  set visibleFraction [$win yview]
  set begVisible [lindex $visibleFraction 0] 
  set endVisible [lindex $visibleFraction 1]

  #any following pages pics
  while {$endVisible < 1.0} {

    incr picNo
    $win yview moveto $endVisible
    
    #recreate abschlussPpm, save to new name
    image create photo abschlussPpm -format window -data $win
	  abschlussPpm write -format PPM [file join $ppmDir abschluss${picNo}.ppm]

    set begVisible $endVisible
    set endVisible [lindex [$win yview] 1]
  }
}

proc ppm2pdf {jahr} {
  global reportDir
  set ppmDir $tmpDir/tkoffice_ppm
  set ppmList [glob -directory $ppmDir *.ppm]
  
  if {[auto_execok img2pdf] == ""} {
    NewsHandler::QueryNews "PDF konnte nicht generiert werden. Sie müssen das Programm 'img2pdf' installieren." red
    foreach file $ppmList {
      set psNo 1
      exec pnmtops $file > [file join $reportDir abschluss${psNo}.ps]
      incr psNo
    }
    NewsHandler::QueryNews "Der Abschluss liegt als seitengetrennte Postscript-Dateien in $reportDir zum Ausdruck vor." lightblue
    return 1
  }
  
  #TODO make global var
  set abschlussPdf [file join $reportDir abschluss${jahr}.pdf]   
  exec img2pdf --output $abschlussPdf $ppmList
  NewsHandler::QueryNews "Der Abschluss liegt als PDF in $reportDir bereit." lightgreen
}
