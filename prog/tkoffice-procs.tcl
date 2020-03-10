# ~/TkOffice/prog/tkoffice-procs.tcl
# called by tkoffice-gui.tcl
# Salvaged: 1nov17
# Restored: 10mch20

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
## args = invNo OR jahr

##called by ?printInvoice? & ?printReport?

proc latex2pdf {num type} {
  global tmpDir spoolDir reportDir texDir
  

  #Copy PDF to correct location
  
  #A. Abschluss
  if {$type == "rep"} {
    
    set jahr $num
    set texName "Abschluss.tex"
    set texPath [file join $texDir $texName]
    append pdfName [file root $texName] . pdf  
    set targetDir $reportDir
    
  #B. Invoice
  } elseif {$type == "inv"} {

    set invNo $num
    set texPath [setInvPath $invNo tex]
    set pdfPath [setInvPath $invNo pdf]
    set pdfName [file tail $pdfPath]
    set targetDir $spoolDir
  }

  #Latex > PDF
  namespace eval Latex {}
  set Latex::texPath $texPath
  set Latex::tmpDir $tmpDir
  set Latex::targetDir $targetDir
    
  namespace eval Latex {
    eval exec -- pdflatex -interaction nonstopmode -output-directory $targetDir $texPath
  }
  
  #Rename Report to include year
  if {$type == "rep"} {
    cd $reportDir
    set pdfNewName [file root $pdfName]${jahr}.pdf
    set pdfName [file rename $pdfName $pdfNewName]
  }
  
  NewsHandler::QueryNews "Die Datei $pdfName befindet sich in $targetDir zur weiteren Bearbeitung." lightgreen
  return 0
  
} ;#END latex2pdf

# viewDocument
##runs detectViewer & opens file with appropriate app
##works with DVI & PDF
##called by ...
proc viewDocument {file type} {
  set viewer [detectViewer $type]
  #open in $viewer if found, else use xdg-open
  if {$viewer==1} {
    exec xdg-open $file
  } else {
    catch {exec $viewer $file}
  }
  return
}

# detectViewer
##looks for DVI/PDF viewer
##returns 1 if none found
##called by showInvoice (DVI) +  ? ?
proc detectViewer {type} {
  
  #Viewers for DVI+PDF
  lappend viewerList evince okular

  #Extra PDF viewers
  if {$type == "pdf" } {
    lappend viewerList xpdf qpdf mupdf acroread zathura qpdfview pqiv gspdf pdf-reader
  }
  
  #Detect 1st installed viewer
  foreach p $viewerList {
    if {[auto_execok $p] != ""} {
      set viewer $p
      break
    }
  }
    
  if [info exists viewer] {
    return $viewer
  } else {
    return 1
  }

} ;#END detectViewer

# printPdf
##sends PDF to printer / viewer
##called by ?printInvoice? & latexReport
proc printPdf {pdfPath} {

  namespace eval Latex {}
  set Latex::pdfPath $pdfPath
  set Latex::pdfFile [file tail $pdfPath]
  
  #1. View if no lpr found
  if {[auto_execok lpr] == ""} {
    NewsHandler::QueryNews "Kein Drucker gefunden!\nDas Dokument $pdfFile wird zur Weiterverarbeitung angezeigt..." orange
    viewDocument $pdfPath pdf
    return 1
  }
    
  #2. Try printing
  after 500 {
  NewsHandler::QueryNews "Das Dokument $Latex::pdfFile wird zum Drucker geschickt..." orange
     }
    if ![catch {exec lpr $pdfPath}] {
      return 0
    }
  
  
  after 2000  {
    NewsHandler::QueryNews "Das Dokument $Latex::pdfFile wurde möglicherweise nicht gedruckt.\nIst der Drucker eingeschaltet?" red  
  }
  
  #3. Retry printing OR view
  after 5000  {
    NewsHandler::QueryNews "Das Dokument $Latex::pdfFile wird noch einmal zum Drucker geschickt..." lightblue
    if [catch {exec lpr $Latex::pdfPath}] {
      NewsHandler::QueryNews "Das Dokument $Latex::pdfFile wurde möglicherweise nicht gedruckt.\nEs wird nun zur Weiterverarbeitung angezeigt..." orange
      viewDocument $Latex::pdfPath pdf
    }
    
  return 1
  }
  
} ;#END printPdf


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
  pack .confartT .confartM -in .n.t4.f1 -anchor w
  pack .confartL .confartnumSB .confartunitL .confartpriceL .confartnameL .confarttypeL -in .n.t4.f1 -side left
  pack .confartdeleteB .confartcreateB -in .n.t4.f1 -side right
  pack forget .confartsaveB .confarttypeACB .confarttypeRCB
  pack forget .confartnameE .confartunitE .confartpriceE
  .confartdeleteB conf -text "Artikel löschen" -command {deleteArticle}
  .confartcreateB conf -text "Artikel erfassen" -command {createArticle}
}

# setArticleLine
##sets Artikel line in New Invoice window + Artikelverwaltung
##needs TAB2 / TAB4 args
##called by GUI + spinboxes .confartnumSB/.invartnumSB
proc setArticleLine {tab} {
  global db
  .confarttypeL conf -bg #c3c3c3
  
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
      .confarttypeL conf -bg yellow
    } elseif {$artType == "A"} {
      .confarttypeL conf -bg orange
    }
  }
  
  if {$tab == "TAB4"} {
    return 0
  }

#TODO get order right! 
  namespace eval artikel {
    if {$artPrice == 0} {
      set artPrice [.invartpriceE get]
      pack forget .invartpriceL
      pack .invartunitL .invartnameL .invartpriceE .invarttypeL -in .n.t2.f2 -side left   
    } else {
      pack forget .invartpriceE
      pack .invartunitL .invartnameL .invartpriceL .invarttypeL -in .n.t2.f2 -side left
    }
  }
  
  return 0

} ;#END setArticleLine

proc createArticle {} {
  global db

 #clear previous entries & add .confArtSaveB
  .confartnumSB set ""
  .confartnumSB conf -bg lightgrey
  pack .confartsaveB -in .n.t4.f1 -side right
   
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
  pack .confartnameL .confartnameE .confartunitL .confartunitE .confartpriceL .confartpriceE .confarttypeACB .confarttypeRCB -in .n.t4.f1 -side left
  pack forget .confartdeleteB

  #Rename Button
  .confartcreateB conf -text "Abbruch" -activebackground red -command {resetArticleWin}
  
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

pack .confartL .confartnumSB .confartunitL .confartpriceL .confartnameL .confarttypeL -in .n.t4.f1 -side left
  
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

# printDocument
##latexes Abschluss.tex + Invoice[NR].tex & sends to Printer/Viewer
##with type "report" num=jahr / with type "Invoice" num=invNo
##called by .newinvprintB & .abschlussPrintB
proc printDocument {num type} {

  global texDir reportDir tmpDir spoolDir
 
  #A.  A b s c h l u s s
  if {$type == "rep"} {
 
  #  set jahr [.abschlussJahrSB get]
    set jahr $num
    set texName Abschluss.tex
    set texPath [file join $texDir $texName]
    append pdfName [file root $texName] $jahr . pdf 
    set pdfPath [file join $reportDir $pdfName]
    
    #1. run latexReport
    if [catch latexReport] {
      NewsHandler::QueryNews "Es ist ein Fehler aufgetreten..." red
      return 1
    }
    
  # B. I n v o i c e 
  } elseif {$type == "inv"} { 

    set invNo $num
    set texPath [setInvPath $invNo tex]
    set pdfPath [setInvPath $invNo pdf]
     
    #2. Run latex2pdf (not needed for Report!)
    latex2pdf $invNo $type
  }

  #3. Try printing OR view
  printPdf $pdfPath

} ;# END printDocument
