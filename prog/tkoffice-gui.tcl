# ~/Kontor/auftrag-gui.tcl
# Updated: 1nov17 
# Restored: 25oct19

set version 1.0

package require Tk
package require Img
source [file join $progDir tkoffice-procs.tcl]
source [file join $progDir invoice-procs.tcl]
source [file join $progDir pgin.tcl]
source $confFile

#Haupttitel & Frames
set px 5
set py 5
pack [frame .titelF -padx 10 -pady 10] -fill x
label .titelL -text "Auftragsverwaltung" -pady $py -padx $px -font "TkHeadingFont 80 bold" -fg silver -anchor w

#Eigenes Firmenlogo falls vorhanden
catch setMyLogo

#Create Notebook
ttk::notebook .n -width 1400
.n add [frame .n.t1] -text "Adressen + Aufträge"
.n add [frame .n.t2] -text "Neue Rechnung"
.n add [frame .n.t3] -text "Jahresabschlüsse"
.n add [frame .n.t4] -text "Einstellungen"

#Pack all frames
createTkOfficeLogo
#pack .titelL -anchor nw -in .titelF -side left
pack .n -fill y -expand 1

#Tab 1
pack [frame .n.t1.mainF] -fill both
pack [frame .n.t1.mainF.f2 -borderwidth 5 -relief ridge -pady 10 -padx 10] -anchor nw -fill x
pack [frame .n.t1.mainF.f3 -borderwidth 0 -pady 10] -anchor nw -fill x
pack [frame .n.t1.mainF.f4] -anchor nw -padx 20 -pady 20 -fill x
#Tab 2
pack [frame .n.t2.f1 -pady $py -padx $px -borderwidth 5] -anchor nw -fill x
pack [frame .n.t2.f2 -relief ridge -pady $py -padx $px -borderwidth 5] -anchor nw -fill x
pack [frame .n.t2.f3 -pady $py -padx $px -borderwidth 5] -anchor nw -fill x
pack [frame .n.t2.bottomF] -anchor nw -padx 20 -pady 20 -fill both -expand 1

#Tab 3
pack [frame .n.t3.f1 -relief ridge -pady $py -padx $px -borderwidth 5] -fill x
pack [frame .n.t3.bottomF] -anchor nw -padx 20 -pady 20 -fill x
#Tab 4
pack [frame .n.t4.f3 -pady $py -padx $px -borderwidth 5 -highlightbackground silver -highlightthickness 5] -anchor nw -fill x
pack [frame .n.t4.f2 -pady $py -padx $px -borderwidth 5 -highlightbackground silver -highlightthickness 5] -anchor nw -fill x
pack [frame .n.t4.f1 -pady $py -padx $px -borderwidth 5 -highlightbackground silver -highlightthickness 5] -anchor nw -fill x
pack [frame .n.t4.f5 -pady $py -padx $px -borderwidth 5 -highlightbackground silver -highlightthickness 5] -anchor nw -fill x -side left -expand 1


###############################################
# T A B 1. : A D R E S S F E N S T E R
###############################################

#Pack 3 top frames seitwärts
#Create "Adressen" title
label .adrTitel -text "Adressverwaltung" -font TkCaptionFont -pady 5
pack .adrTitel -in .n.t1.mainF.f2 -side top -fill x
##obere Frames in .n.t1.f2
pack [frame .adrF2 -bd 3 -relief flat -bg lightblue -pady $py -padx $px] -anchor nw -in .n.t1.mainF.f2 -side left
pack [frame .adrF4 -bd 3 -relief flat -bg lightblue -pady $py -padx $px] -anchor nw -in .n.t1.mainF.f2 -side left
pack [frame .adrF1] -anchor nw -in .n.t1.mainF.f2 -side left
pack [frame .adrF3] -anchor se -in .n.t1.mainF.f2 -expand 1 -side left
##create Address number Spinbox
set adrSpin [spinbox .adrSB -takefocus 1 -width 15 -textvariable adrNo -bg lightblue]
focus $adrSpin
##Create search field
set suche "Adresssuche (+Tab)"
set adrSearch [entry .adrSearchE]
  $adrSearch config -width 25 -borderwidth 3 -bg beige -fg grey -textvariable suche
  $adrSearch config -validate focusin -validatecommand {
    set ::suche ""
    %W config -fg black -validate focusout -validatecommand {
      searchAddress %s
      return 0
    }
  return 0
  }

#Create address entries, to be packed only when 'changeAddress' or 'newAddress' are invoked
entry .name1E -width 50 -textvar name1 -justify left
entry .name2E -width 50 -textvar name2 -justify left
entry .streetE -width 50 -textvar street -justify left
entry .zipE -width 7 -textvar zip -justify left
entry .cityE -width 43 -textvar city -justify left
entry .tel1E -width 25 -textvar tel1 -justify right
entry .tel2E -width 25 -textvar tel2 -justify right
entry .faxE -width 25 -textvar fax -justify right
entry .mailE -width 25 -textvar mail -justify right
entry .wwwE -width 25 -textvar www -justify right

#create Address buttons
button .b0 -text "Neue Anschrift" -width 20 -command {newAddress}
button .b1 -text "Anschrift ändern" -width 20 -command {changeAddress $adrNo}
button .b2 -text "Anschrift löschen" -width 20 -command {deleteAddress $adrNo} -activebackground red

#Pack adrF1 spinbox
pack $adrSpin -in .adrF1 -anchor nw
#Pack adrF3 buttons
pack $adrSearch .b0 .b1 .b2 -in .adrF3 -anchor se


#########################################################################################
# T A B 1 :  I N V O I C E   L I S T
#########################################################################################

#Create "Rechnungen" Titel
label .adrInvTitel -text "Verbuchte Rechnungen" -font "TkCaptionFont"
pack .adrInvTitel -in .n.t1.mainF.f3

#Create Rechnungen Kopfdaten
label .invNoH -text "Nr."  -font TkCaptionFont -justify left -anchor w -width 9
label .invDatH -text "Datum"  -font TkCaptionFont -justify left -anchor w -width 13
label .invArtH -text "Artikel" -font TkCaptionFont -justify left -anchor w -width 47
label .invSumH -text "Betrag" -font TkCaptionFont -justify right -anchor w -width 11
label .invPayedH -text "Bezahlt" -font TkCaptionFont -justify right -anchor w -width 10
#label .invStatusH -text "Status" -font TkCaptionFont -justify right -anchor w -width 10
label .invShowH -text "Ansicht" -font TkCaptionFont -justify right -anchor w -justify right -width 10

pack [frame .n.t1.mainF.headF -padx $px] -anchor nw -fill x
pack [frame .n.t1.mainF.invF -padx $px] -anchor nw -fill x
set invF .n.t1.mainF.invF
set headF .n.t1.mainF.headF
pack .invNoH .invDatH .invArtH .invSumH .invPayedH -in $headF -side left
pack .invShowH -in $headF -side right


########################################################################################
# T A B  2 :   N E W   I N V O I C E
########################################################################################

#Main Title
label .titel3 -text "Neue Rechnung erfassen" -font "TkCaptionFont" -pady 15
pack .titel3 -in .n.t2.f1

#Get Zahlungsbedingungen from config
set condList ""
label .invcondL -text "Zahlungsbedingung:"
if [info exists cond1] {
lappend condList $cond1
}
if [info exists cond2] {
lappend condList $cond2
}
if [info exists cond3] {
lappend condList $cond3
}
#Insert into spinbox
spinbox .invcondSB -width 20 -values $condList -textvar cond -bg beige

#Auftragsdatum: set to heute
label .invauftrdatL -text "Auftragsdatum:"
entry .invauftrdatE -width 9 -textvar auftrDat -bg beige
set auftrDat [clock format [clock seconds] -format %d.%m.%Y]

#Referenz
label .invrefL -text "Ihre Referenz:"
entry .invrefE -width 20 -bg beige -textvar ref

#Int. Kommentar
label .invcomL -text "Interne Bemerkung:"
entry .invcomE -width 30 -bg beige -textvar comm

#Set up Artikelliste, fill later when connected to DB
label .invArtlistL -text "Artikelliste" -font "TkHeadingFont"
label .artL -text "Artikel Nr."
spinbox .invArtNumSB -width 2 -command {setArticleLine TAB2}

#Make invoiceFrame
catch {frame .invoiceFrame}
pack .invoiceFrame -in .n.t2.f3 -side bottom -fill both

#Set KundenName in Invoice window
label .clientL -text "Kunde:" -font "TkCaptionFont" -bg lightblue
label .clientNameL -textvariable name2 -font "TkCaptionFont"
pack .clientNameL .clientL -in .n.t2.f1 -side right

label .invArtPriceL -textvar artPrice -padx 20
entry .invArtPriceE -textvar artPrice
label .invArtNameL -textvar artName -padx 50
label .invArtUnitL -textvar artUnit -padx 20
label .invArtTypeL -textvar artType -padx 20

label .subtotalL -width 7 -textvar subtot -bg lightblue
message .subtotalM -width 200 -text "Zwischensumme: "
pack .subtotalM .subtotalL -side left -in .n.t2.bottomF
##configured later by resetNewInvDialog:
button .saveInvB -text "Rechnung verbuchen"
button .abbruchInvB -text "Abbruch"
pack .abbruchInvB .saveInvB -in .n.t2.bottomF -side right


####################################################################################
# P a c k   b o t t o m 
###################################################################################
pack [frame .bottomF] -side bottom -fill x
button .abbruchB -text "Programm beenden" -activebackground red -command {
	catch {pg_disconnect $dbname}
	exit
	}
pack .abbruchB -in .bottomF -side right


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
catch {pg_connect -conninfo [list host = localhost user = $dbuser dbname = $dbname]} res
pack .news -in .bottomF -side left -anchor nw -fill x

######################################################################################
# T A B 4 :  C O N F I G U R A T I O N
######################################################################################

#1. A R T I K E L   V E R W A L T E N
label .confArtT -text "Artikel erfassen" -font "TkHeadingFont"
message .confArtM -width 800 -text "Die Felder 'Bezeichnung' und 'Einheit' (z.B. Std.) dürfen nicht leer sein.\nDie Kontrollkästchen 'Auslage' und 'Rabatt' für den Artikeltyp können leer sein. Wenn 'Rabatt' ein Häkchen bekommt, gilt der Artikel als Abzugswert in Prozent (im Feld 'Preis' Prozentzahl ohne %-Zeichen eingeben, z.B. 5.5). Der Rabatt wird in der Rechnung vom Gesamtbetrag abgezogen.\nFalls das Feld 'Auslage' angehakt wird (z.B. für Artikel 'Zugfahrt'), wird der Artikel in der Rechnung separat als Auslage aufgeführt, unterliegt nicht der Mehrwertsteuerpflicht und wird nicht als Einnahme verbucht."

#TODO: move?
proc rebuildArticleWin {} {
label .confArtL -text "Artikel Nr."
spinbox .confArtNumSB -width 5 -command {setArticleLine TAB4}
label .confArtNameL -padx 10 -textvar artName
label .confArtPriceL -padx 10 -textvar artPrice
label .confArtUnitL -padx 10 -textvar artUnit
label .confArtTypeL -padx 10 -textvar artType
button .confArtSaveB -text "Artikel speichern" -command {saveArticle}
button .confArtDeleteB -text "Artikel löschen" -command {deleteArticle} -activebackground red
button .confArtCreateB -text "Artikel erfassen" -command {createArticle}
pack .confArtT .confArtM -in .n.t4.f1 -anchor w
pack .confArtL .confArtNumSB .confArtUnitL .confArtPriceL .confArtNameL .confArtTypeL -in .n.t4.f1 -side left
pack .confArtSaveB .confArtDeleteB .confArtCreateB -in .n.t4.f1 -side right
}
rebuildArticleWin

#DATENBANK SICHERN
label .dumpDBT -text "Datenbank sichern" -font "TkHeadingFont"
message .dumpDBM -width 800 -text "Es ist ratsam, die Datenbank regelmässig zu sichern. Durch Betätigen des Knopfs 'Datenbank sichern' wird jeweils eine Tagessicherung der gesamten Datenbank im Ordner [file join $tkofficeDir dumps] abgelegt. Bei Problemen kann später der jeweilige Stand der Datenbank mit dem Kommando \n\tsu postgres -c 'psql $dbname < $dbname-\[DATUM\].sql' \n wieder eingelesen werden. Das Kommando 'psql' (Linux) muss durch den Datenbank-Nutzer in einer Konsole erfolgen."
button .dumpDBB -text "Datenbank sichern" -command {dumpDB}
pack .dumpDBT -in .n.t4.f2 -anchor nw
pack .dumpDBM -in .n.t4.f2 -anchor nw -side left
pack .dumpDBB -in .n.t4.f2 -anchor se -side right

#DATENBANK EINRICHTEN
label .confDBT -text "Datenbank einrichten" -font "TkHeadingFont"
message .confDBM -width 800 -text "Fürs Einrichten der PostgreSQL-Datenbank sind folgende Schritte nötig:\n1. Das Programm PostgreSQL über die Systemsteuerung installieren.\n2. (optional) Einen Nutzernamen für PostgreSQL einrichten, welcher von TkOffice auf die Datenbank zugreifen darf. Normalerweise wird der privilegierte Nutzer 'postgres' automatisch erstellt. Sonst in einer Konsole als root (su oder sudo) folgendes Kommando eingeben: \n\t sudo useradd postgres \n3. Den Nutzernamen und einen beliebigen Namen für die TkOffice-Datenbank hier eingeben (z.B. tkofficedb).\n4. Den Knopf 'Datenbank erstellen' betätigen, um die Datenbank und die von TkOffice benötigten Tabellen einzurichten.\n5. TkOffice neu starten und hier weitermachen (Artikel erfassen, Angaben für die Rechnungsstellung)."
label .confDBNameL -text "Name der Datenbank" -font "TKSmallCaptionFont"
label .confDBUserL -text "Benutzer" -font "TkSmallCaptionFont"
entry .confDBNameE -textvar dbname
entry .confDBUserE -textvar dbuser -validate focusin -validatecommand {%W conf -bg beige -fg grey ; return 0}
button .initDBB -text "Datenbank erstellen" -command {initDB}
pack .confDBT -in .n.t4.f3 -anchor nw 
pack .confDBM -in .n.t4.f3 -anchor ne -side left
pack .initDBB  .confDBNameE .confDBUserE -in .n.t4.f3 -anchor se -side right

#RECHNUNGSSTELLUNG
pack [frame .billing2F] -in .n.t4.f5 -side right -anchor ne -fill x -expand 1
label .billingT -text "Rechnungsstellung" -font "TkHeadingFont"
message .billingM -width 800 -text "Nachdem unter 'Neue Rechnung' neue Posten für den Kunden erfasst sind, wird der Auftrag in der Datenbank gespeichert (Button 'Rechnung speichern'). Danach kann eine Rechnung ausgedruckt werden (Button 'Rechnung drucken'). Dazu ist eine Vorinstallation von TeX/LaTeX erforderlich. Die neue Rechnung wird im Ordner $spoolDir als PDF gespeichert und wird (falls PostScript vorhanden?) an den Drucker geschickt. Das PDF kann per E-Mail versandt werden. Gleichzeitig wird eine Kopie im DVI-Format in der Datenbank gespeichert. Die Rechnung kann somit später (z.B. als Mahnung) nochmals ausgedruckt werden (Button: 'Rechnung nachdrucken').\n\nDie Felder rechts betreffen die Absenderinformationen in der Rechnung.\nDer Mehrwertsteuersatz ist obligatorisch (z.B. 0 (erscheint nicht) / 0.0 (erscheint)) / 7.5 usw.).\nIn den Feldern 'Zahlungskondition 1-3' können verschiedene Zahlungsbedingungen erfasst werden, welche bei der Rechnungserstellung jeweils zur Auswahl stehen (z.B. 10 Tage / 30 Tage / bar). Ein Eintrag 'bar' steht für Barzahlung und markiert die Rechnung als bezahlt. Ohne Voreinträge muss die Kondition von Hand eingegeben werden.\n\nDie in $spoolDir befindlichen PDFs können nach dem Ausdruck/Versand gelöscht werden."

radiobutton .billformatlinksRB -text "Adressfenster links (International)" -value Links -variable adrpos
radiobutton .billformatrechtsRB -text "Adressfenster rechts (Schweiz)" -value Rechts -variable adrpos
.billformatrechtsRB select

spinbox .billcurrencySB -width 5 -text Währung -values {€ £ $ CHF}

entry .billvatE
entry .billownerE
entry .billcompE
entry .billstreetE
entry .billcityE
entry .billphoneE
entry .billbankE -width 50
entry .billcond1E
entry .billcond2E
entry .billcond3E
button .billcomplogoB -text "Firmenlogo hinzufügen" -command {
  set ::logoPath [tk_getOpenFile]
  return 0
}
pack .billingT .billingM -in .n.t4.f5 -anchor nw
pack .billformatlinksRB .billformatrechtsRB -in .n.t4.f5 -anchor se -side bottom
pack .billcomplogoB .billcurrencySB .billvatE .billownerE .billcompE .billstreetE .billcityE .billphoneE .billbankE .billcond1E .billcond2E .billcond3E -in .billing2F

#Configure all entries to change colour & be emptied when focused
foreach e [pack slaves .billing2F] {
  catch {$e config -fg grey -bg beige -width 30 -validate focusin -validatecommand "
    %W delete 0 end
    $e config -bg beige -fg black -state normal
    return 0
    "
  }
}

#Configure vat entry to accept only numbers like 0 / 1.0 / 7.5
#.billvatE conf -validate key -vcmd {%W conf -bg beige ; string is double %P} -invcmd {%W conf -bg red}

button .billingSaveB -text "Einstellungen speichern" -command {source $makeConfig ; makeConfig}
pack .billingSaveB -in .billing2F -side bottom -anchor se

#Check if vars in config
if {[info exists vat] && $vat != ""} {.billvatE insert 0 $vat; .billvatE conf -bg "#d9d9d9"} {.billvatE conf -bg beige ; .billvatE insert 0 "Mehrwertsteuersatz %"}
if {[info exists myName] && $myName != ""} {.billownerE insert 0 $myName; .billownerE conf -bg "#d9d9d9"} {.billownerE insert 0 "Name"}
if {[info exists myComp] && $myComp != ""} {.billcompE insert 0 $myComp; .billcompE conf -bg "#d9d9d9"} {.billcompE insert 0 "Firmenname"}
if {[info exists myAdr] && $myAdr != ""} {.billstreetE insert 0 $myAdr; .billstreetE conf -bg "#d9d9d9"} {.billstreetE insert 0 "Strasse"}
if {[info exists myCity] && $myCity != ""} {.billcityE insert 0 $myCity; .billcityE conf -bg "#d9d9d9"} {.billcityE insert 0 "PLZ & Ortschaft"}
if {[info exists myPhone] && $myPhone != ""} {.billphoneE insert 0 $myPhone; .billphoneE conf -bg "#d9d9d9"} {.billphoneE insert 0 "Telefon"}
if {[info exists myBank] && $myBank != ""} {.billbankE insert 0 $myBank; .billbankE conf -bg "#d9d9d9"} {.billphoneE insert 0 "Bankverbindung"}

if {[info exists cond1] && $cond1!=""} {.billcond1E insert 0 $cond1; .billcond1E conf -bg "#d9d9d9"} {.billcond1E insert 0 "Zahlungskondition 1"}
if {[info exists cond2] && $cond2!=""} {.billcond2E insert 0 $cond2; .billcond2E conf -bg "#d9d9d9"} {.billcond2E insert 0 "Zahlungskondition 2"}
if {[info exists cond3] && $cond3!=""} {.billcond3E insert 0 $cond3; .billcond3E conf -bg "#d9d9d9"} {.billcond3E insert 0 "Zahlungskondition 3"}
if [info exists currency] {.billcurrencySB conf -bg "#d9d9d9" -width 5; .billcurrencySB set $currency}



#######################################################################
## F i n a l   a c t i o n s :    detect Fehlermeldung bzw. socket no.
#######################################################################
if {[string length $res] >20} {
  NewsHandler::QueryNews $res red 
  .confDBNameE conf -text "Datenbankname eingeben" -validate focusin -validatecommand {%W conf -bg beige -fg grey ; return 0}
  .confDBUserE conf -text "Datenbanknutzer eingeben" -validate focusin -validatecommand {%W conf -text "Name eingeben" -bg beige -fg grey ; return 0}
  return 1
}

NewsHandler::QueryNews "Mit Datenbank verbunden" green
set db $res
setAdrList
resetAdrWin
fillAdrInvWin [$adrSpin get]
.confDBNameE conf -state disabled
.confDBUserE conf -state disabled
.initDBB conf -state disabled
resetNewInvDialog
updateArticleList
setArticleLine TAB2
setArticleLine TAB4
#createPrintBitmap
