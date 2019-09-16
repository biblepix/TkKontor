# ~/Kontor/auftrag-gui.tcl
# Updated: 1nov17 
# Restored: 16sep19


#Source Tk/Pgintcl packages
#package require pgintcl
package require Tk
package require Img
source [file join $progDir tkoffice-procs.tcl]
source [file join $progDir pgin.tcl]

#Haupttitel & Frames
set px 5
set py 5
pack [frame .titelF -padx 10 -pady 10] -fill x
label .titelL -text "TkOffice\nAuftragsverwaltung" -pady $py -padx 50 -font "TkHeadingFont 40 bold" -fg steelblue -justify left
image create photo vollmar -file ~/www/bilder/logo_rot.gif -format GIF
canvas .titelC -width 250 -height 150
.titelC create image 0 0 -image vollmar -anchor nw

#Create Notebook
ttk::notebook .n -width 1400
.n add [frame .n.t1] -text "Adressen + Aufträge"
.n add [frame .n.t2] -text "Neue Rechnung"
.n add [frame .n.t3] -text "Jahresabschlüsse"
.n add [frame .n.t4] -text "Einstellungen"

#Pack all frames
pack .titelL -anchor nw -in .titelF -side left
pack .titelC -in .titelF -side right
pack .n -fill y -expand 1

#Tab 1
pack [frame .n.t1.f2 -borderwidth 5 -relief ridge -pady 10 -padx 10] -anchor nw -fill x
pack [frame .n.t1.f3 -borderwidth 0 -pady 10] -anchor nw -fill x
pack [frame .n.t1.f4] -anchor nw -padx 20 -pady 20 -fill x
#Tab 2
pack [frame .n.t2.f1 -relief ridge -pady $py -padx $px -borderwidth 5] -anchor nw -fill x
pack [frame .n.t2.f2 -relief ridge -pady $py -padx $px -borderwidth 5] -anchor nw -fill x
pack [frame .n.t2.bottomF] -anchor nw -padx 20 -pady 20 -fill x
#Tab 3
pack [frame .n.t3.f1 -relief ridge -pady $py -padx $px -borderwidth 5] -fill x
pack [frame .n.t3.bottomF] -anchor nw -padx 20 -pady 20 -fill x
#Tab 4
pack [frame .n.t4.f3 -relief ridge -pady $py -padx $px -borderwidth 5] -anchor nw -fill x
pack [frame .n.t4.f2 -relief ridge -pady $py -padx $px -borderwidth 5] -anchor nw -fill x
pack [frame .n.t4.f1 -relief ridge -pady $py -padx $px -borderwidth 5] -anchor nw -fill x


###############################################
# T A B 1. : A D R E S S F E N S T E R
###############################################

#Pack 3 top frames seitwärts
#Create "Adressen" title
label .adrTitel -text "Adressverwaltung" -font TkCaptionFont -pady 5
pack .adrTitel -in .n.t1.f2 -side top -fill x

pack [frame .adrF2 -bd 3 -relief sunken -bg lightblue -pady $py -padx $px] -anchor nw -side left -in .n.t1.f2
#ack [frame .adrF4 -bg lightblue] -anchor e -in .adrF2 -side right
pack [frame .adrF1] -anchor nw -side left -in .n.t1.f2
pack [frame .adrF3] -anchor se -side left -in .n.t1.f2 -expand 1

#create Address number Spinbox
set adrSpin [spinbox .adrSB -takefocus 1 -width 15 -textvariable adrNo -bg lightblue]
focus $adrSpin

#Create search field
set suche "Adresssuche"
set adrSearch [entry .searchE]
  .searchE config -width 25 -borderwidth 3 -bg beige -fg grey -textvariable suche
  .searchE config -validate focusin -validatecommand {
    set ::suche ""
    %W config -fg black -validate focusout -validatecommand {
      searchAddress %s
      return 0
    }
  return 0
  }

#Create address entries, to be packed only when 'changeAddress' or 'newAddress' are invoked
entry .name1E -width 50 -textvariable name1 -justify left
entry .name2E -width 50 -textvariable name2 -justify left
entry .streetE -width 50 -textvariable street -justify left
entry .zipE -width 7 -textvariable zip -justify left
entry .cityE -width 43 -textvariable city -justify left
entry .tel1E -width 15 -textvariable tel1 -justify right
entry .tel2E -width 15 -textvariable tel2 -justify right
entry .mailE -width 15 -textvariable mail -justify right
entry .wwwE -width 15 -textvariable www -justify right

#create Address buttons
button .b0 -text "Neue Anschrift" -width 20 -command {newAddress}
button .b1 -text "Anschrift ändern" -width 20 -command {changeAddress $adrNo}
button .b2 -text "Anschrift löschen" -width 20 -command {deleteAddress $adrNo} -activebackground red

#Pack adrF1 spinbox
pack $adrSpin -in .adrF1 -anchor nw

#Pack adrF2 entries later

#Pack adrF3 buttons
pack $adrSearch .b0 .b1 .b2 -in .adrF3 -anchor se


##################################################
# T A B 1 :  I N V O I C E   L I S T
##################################################
# Inv. no. | Beschr. | Datum | Betrag  | Status (1-3)     #    Bezahlt (Text)   # Zahlen (Button)   #
##########################################################

#Create "Rechnungen" Titel
label .adrInvTitel -text "Verbuchte Rechnungen" -font "TkCaptionFont"
pack .adrInvTitel -in .n.t1.f3

#Create Rechnungen Kopfdaten
label .invNoH -text "Nr."  -font TkCaptionFont -justify left -anchor w -width 10
label .invDatH -text "Datum"  -font TkCaptionFont -justify left -anchor w -width 10
label .invArtH -text "Artikel" -font TkCaptionFont -justify left -anchor w -width 20
label .invSumH -text "Betrag" -font TkCaptionFont -justify right -anchor w -width 10
label .invPayedH -text "Bezahlt" -font TkCaptionFont -justify right -anchor w -width 10
label .invStatusH -text "Status" -font TkCaptionFont -justify right -anchor w -width 10

#pack .titel2 -in .n.f0 -anchor nw
pack [frame .n.t1.headF -padx $px] -anchor nw
pack [frame .n.t1.invF -padx $px] -anchor nw -fill x
set invF .n.t1.invF
pack .invNoH .invDatH .invArtH .invSumH .invPayedH .invStatusH -in .n.t1.headF -side left


########################################################################################
# T A B  2 :   N E W   I N V O I C E
########################################################################################

#Main Title
#label .titel3 -text "Neue Rechnung" -font "TkCaptionFont"

#Zahlungsbedingung - TODO : move to config/DB?
label .condL -text Zahlungsbedingung
spinbox .condSB -width 7 -values {"10 Tage" "vor Kursbeginn" "bar"} -textvariable cond

#Auftragsdatum: set to heute
label .auftrDatL -text "Auftragsdatum"
entry .auftrDatE -width 9 -textvariable auftrDat
set ::auftrdat [clock format [clock seconds] -format %d.%m.%Y]

#Referenz
label .refL -text "Ihre Referenz"
entry .refE -width 10 -textvariable ::ref

#Int. Kommentar - TODO: needed?
label .komL -text "Bemerkung"
entry .komE -width 20 -textvariable ::comm

#Set up Artikelliste, fill later when connected to DB
label .invArtlistL -text "Artikelliste" -font TkCaptionFont
label .artL -text "Artikel Nr."
spinbox .invArtNumSB -width 2 -command {setArticleLine TAB2}

#Make invoiceFrame
catch {frame .invoiceFrame}
pack .invoiceFrame -in .n.t2.f2 -side bottom -fill both

#Set KundenName in Invoice window
label .clientL -text "Kunde:" -font "TkCaptionFont" -bg orange
label .clientNameL -textvariable name2 -font "bold"
pack .clientNameL .clientL -in .n.t2.f1 -side right

label .invArtPriceL -textvariable artPrice
entry .invArtPriceE -textvariable artPrice
label .invArtNameL -textvariable artName
label .invArtUnitL -textvariable artUnit

label .subtotalL -width 7 -textvariable ::subtot -bg lightblue
message .subtotalM -width 200 -text "Zwischensumme: "
pack .subtotalM .subtotalL -side left -in .n.t2.bottomF

button .saveInvB -text "Rechnung speichern" -command {
  saveInv2DB
  }

pack .saveInvB -in .n.t2.bottomF -side right

####################################################################################
# P a c k   b o t t o m 
###################################################################################
pack [frame .bottomF] -side bottom -fill x
button .abbruch -text "Programm beenden" -activebackground red -command {
	catch {pg_disconnect $db}
	exit
	}

pack .abbruch -in .bottomF -side right


######################################################################################
# T A B  3 :  A B S C H L Ü S S E
######################################################################################

button .abschlussErstellenB -text "Abschluss erstellen" -command {abschlussErstellen}
button .abschlussDruckenB -text "Abschluss drucken" -command {abschlussDrucken}
spinbox .abschlussJahrSB -values {2018 2019 2020 2021 2022 2023 2024 2025} -width 4

message .news -textvariable news -width 800 -relief sunken -pady 5 -padx 10
pack [frame .n.t3.bottomF.f2] -side bottom -fill x
pack [frame .n.t3.bottomF.f1] -side bottom -fill x
pack .abschlussJahrSB .abschlussErstellenB .abschlussDruckenB -in .n.t3.bottomF.f1 -side right -fill x

#Execute initial commands if connected to DB
catch {pg_connect -conninfo [list host = localhost user = $dbuser dbname = $db]} res
pack .news -in .bottomF -side left -anchor nw -fill x

######################################################################################
# T A B 4 :  C O N F I G U R A T I O N
######################################################################################

#1. ARTIKEL VERWALTEN
label .confArtT -text "Artikel verwalten" -font "TkHeadingFont"
label .confArtL -text "Artikel Nr."
spinbox .confArtNumSB -width 5 -command {setArticleLine TAB4}
label .confArtNameL -padx 10 -textvariable artName
#allow for entry if article list price is 0, pack entry later if necessary
label .confArtPriceL -padx 10 -textvariable artPrice
label .confArtUnitL -padx 10 -textvariable artUnit
button .confArtSaveB -text "Artikel speichern" -command {saveArticle}
button .confArtDeleteB -text "Artikel löschen" -command {deleteArticle} -activebackground red
button .confArtCreateB -text "Artikel erfassen" -command {createArticle}

pack .confArtT -in .n.t4.f1 -anchor w
pack .confArtL .confArtNumSB .confArtUnitL .confArtPriceL .confArtNameL -in .n.t4.f1 -side left
pack .confArtSaveB .confArtDeleteB .confArtCreateB -in .n.t4.f1 -side right

label .dumpDBT -text "Datenbank sichern" -font "TkHeadingFont"
message .dumpDBM -width 800 -text "Es ist ratsam, die Datenbank regelmässig zu sichern. Durch Betätigen des Knopfs 'Datenbank sichern' wird jeweils eine Tagessicherung der gesamten Datenbank im Ordner [file join $auftragDir dumps] abgelegt. Bei Problemen kann später der jeweilige Stand der Datenbank mit dem Kommando 'psql $db < $dbname-\[DATUM\].sql' wieder eingelesen werden. Das Kommando 'psql' (Linux) muss durch den Datenbank-Nutzer in einer Konsole erfolgen."
button .dumpDBB -text "Datenbank sichern" -command {dumpDB}

label .confDBT -text "Datenbank einrichten" -font "TkHeadingFont"
message .confDBM -width 800 -text "Fürs Einrichten der PostgresQL-Datenbank sind folgende Schritte nötig:..............."
label .confDBNameL -text "Name der Datenbank" -font "TKSmallCaptionFont"
label .confDBUserL -text "Benutzer" -font "TKSmallCaptionFont"
entry .confDBNameE -textvariable Datenbankname -validate focusin -validatecommand {set Datenbankname "";return 0}
entry .confDBUserE -textvariable Benutzername -validate focusin -validatecommand {set Datenbanknutzer "";return 0}
button .initDBB -text "Datenbank erstellen" -command {initDB}

pack .dumpDBT .dumpDBM -in .n.t4.f2 -anchor w -side left
pack .dumpDBB -in .n.t4.f2 -anchor e -side right

pack .confDBT -in .n.t4.f3 -anchor w 

pack .confDBM .confDBNameE .confDBUserE -in .n.t4.f3 -side left
pack .initDBB -in .n.t4.f3 -side right


#######################################################################
## F i n a l   a c t i o n s :    detect Fehlermeldung bzw. socket no.
#######################################################################
if {[string length $res] >20} {
  NewsHandler::QueryNews $res red 
  return 1
} 

NewsHandler::QueryNews "Mit Datenbank verbunden" green
set db $res
setAdrList
resetAdrWin
fillAdrInvWin [$adrSpin get]
.confDBNameE conf -state disabled
.confDBUserE conf -state disabled
set Datenbankname "Datenbankname: $dbname"
set Datenbanknutzer "Nutzername: $dbuser"
.initDBB conf -state disabled
resetNewInvDialog
updateArticleList
setArticleLine TAB2
setArticleLine TAB4

