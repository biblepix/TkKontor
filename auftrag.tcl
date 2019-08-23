# ~/Kontor/auftrag.tcl
# Updated: 1nov17 
# Restored: 21aug19

set kontorDir $env(HOME)/Kontor
cd $kontorDir
set db kontordb
set dbuser postgres
set spoolDir $kontorDir/spool
set vorlage [file join $spoolDir rechnung-vorlage.rtf]

package require Tk
package require Img
#package require pgintcl


set path [file dirname [info script]]
set pgintclDir [glob -type d $path/pgintcl*]
source $path/auftrag-procs.tcl
source $pgintclDir/pgin.tcl

set px 5
set py 5

#Haupttitel & Frames
image create photo vollmar -file ~/www/bilder/logo_rot.gif -format GIF
label .titel -text "\tAuftrags-  \n\tverwaltung" -image vollmar -pady $py -padx -$px -compound left -font "TkHeadingFont 40 bold" -fg steelblue -justify right

#Create Notebook
ttk::notebook .n -width 1400
.n add [frame .n.t1] -text "Adressen + Aufträge"
.n add [frame .n.t2] -text "Neue Rechnung"
.n add [frame .n.t3] -text "Abschlüsse"
.n add [frame .n.t4] -text "Einstellungen"

#frame .n.t1.f2 -borderwidth 5 -relief ridge -pady $py -padx $px
#frame .n.t1.f3 -borderwidth 5 -relief ridge -pady $py -padx $px
#frame .n.t1.f4 -pady $py -padx $px

#Pack all frames
pack .titel -anchor ne
pack .n -fill y -expand 1

#Tab 1
pack [frame .n.t1.f2 -borderwidth 5 -relief ridge -pady $py -padx $px] -anchor nw -padx 20 -pady 20 -fill x
pack [frame .n.t1.f3 -borderwidth 5 -relief ridge -pady $py -padx $px] -anchor nw -padx 20 -pady 20 -fill x
pack [frame .n.t1.f4] -anchor nw -padx 20 -pady 20 -fill x
#Tab 2
pack [frame .n.t2.f1] -anchor nw -padx 20 -pady 20 -fill x
pack [frame .n.t2.f2] -anchor nw -padx 20 -pady 20 -fill x
pack [frame .n.t2.bottomF] -anchor nw -padx 20 -pady 20 -fill x
#Tab 3
pack [frame .n.t3.f1] -anchor nw -padx 20 -pady 20 -fill x
pack [frame .n.t3.bottomF] -anchor nw -padx 20 -pady 20 -fill x
#Tab 4
pack [frame .n.t4.f1] -anchor nw -padx 20 -pady 20 -fill both
pack [frame .n.t4.f2] -anchor nw -padx 20 -pady 20 -fill both



###############################################
# T A B 1. : A D R E S S F E N S T E R
###############################################

#create Address number Spinbox
set adrSpin [spinbox .adrSB -takefocus 1 -width 20]
focus $adrSpin
#create address search spinbox (packed later if needed by searchAddress)
set adrSearchResults [spinbox .adrSearchSB -bg beige -width 20]

#Create Address Window
##set search Text
label .sucheL -text "Adresssuche"

##set search field
set adrSearch [entry .searchE -width 20 -bg beige -textvariable suche]
.searchE configure -validate focusout -validatecommand {
	searchAddress %s
	after idle {%W config -validate %v}
  .searchE delete 0 end
	return 0
}

##set address fields
entry .name1 -width 20 -textvariable name1
entry .name2 -width 50 -textvariable name2
entry .street -width 50 -textvariable street
entry .zip -width 10 -textvariable zip
entry .city -width 40 -textvariable city
set name1 Anrede
set name2 Name
set street Strasse
set zip PLZ
set city Stadt

#create New Address button
button .b0 -text "Neue Anschrift" -width 20 -command {clearAdrWin}
#create OK button for address change
button .b1 -text "Anschrift speichern" -width 20 -command {saveAddress}
#create DELETE button (deletes whole address!)
button .b2 -text "Anschrift löschen" -width 20 -command {deleteAddress} -activebackground red

#TODO: decent packing (s.o.)
pack $adrSpin -in .n.t1.f2 -anchor nw -side left
pack .searchE .sucheL -in .n.t1.f2 -anchor ne -side right
pack .name1 .name2 .street -in .n.t1.f2 -anchor nw
pack .zip .city -side left -anchor nw -in .n.t1.f2
pack .b0 -in .n.t1.f2 -side right
pack .b1 .b2 -in .n.t1.f2 -side right

##################################################
# T A B 1 :  I N V O I C E   L I S T
##################################################
# Inv. no. | Beschr. | Datum | Betrag  | Status (1-3)     #    Bezahlt (Text)   # Zahlen (Button)   #
##########################################################

#Titel
#label .titel2 -text "Rechnungen" -font "TkCaptionFont"

#Create Rechnungen Kopfdaten

label .invNo -text "Nr."  -font TkCaptionFont -justify left -width 10
label .invDatL -text "Datum"  -font TkCaptionFont -justify left -width 10
label .invBesch -text "Artikel" -font TkCaptionFont -justify left -width 20
label .invSum -text "Betrag" -font TkCaptionFont -justify right -width 10
label .invPayed -text "Bezahlt" -font TkCaptionFont -justify right -width 10
label .invStatus -text "Status" -font TkCaptionFont -justify right -width 10

#Create Zahlungseingang entry & button
#entry .zahlungseingang -textvariable payedsum
#button .zahlen  -text "Zahlungseingang verbuchen" -command {zahlungsEingang}

#pack .titel2 -in .n.f0 -anchor nw
pack [frame .n.t1.headF] -anchor nw
pack [frame .n.t1.invF] -anchor nw -fill x
set invF .n.t1.invF
pack .invNo .invDatL .invBesch .invSum .invPayed .invStatus -in .n.t1.headF -side left


########################################################################################
# T A B  2 :   N E W   I N V O I C E
########################################################################################

# Art.Nr.		Beschr. 		Einzelpreis			Menge
#----------------------------------------------
# ART.LB	| BESCHR.LB	| EINZEL.T | MENGE.T 	| OK.B
# ----------------------------------------------
# NEWROW{1}.L .........
# NEWROW{2}.L .........

#Main Title
#label .titel3 -text "Neue Rechnung" -font "TkCaptionFont"

#Zahlungsbedingung - TODO : move to config
label .condL -text Zahlungsbedingung
spinbox .condSB -width 7 -values {"10 Tage" "vor Kursbeginn" "bar"}

#Auftragsdatum: set to heute
label .auftrDatL -text "Auftragsdatum"
entry .auftrDatE -width 9 -textvariable ::auftrdat
set ::auftrdat [clock format [clock seconds] -format %d.%m.%Y]

#Referenz
label .refL -text "Ihre Referenz"
entry .refE -width 10 -textvariable ::ref

#Int. Kommentar - TODO: needed?
label .komL -text "Bemerkung"
entry .komE -width 20 -textvariable ::comm

#Set up Artikelliste, fill later when connected to DB
label .artlistL -text "Artikelliste" -font TkCaptionFont
label .artL -text "Artikel Nr."
spinbox .artNumSB -width 2 -command {setArticleLine TAB2}

#Make invoiceFrame
  catch {frame .invoiceFrame}
  pack .invoiceFrame -in .n.t2.f2 -side bottom -fill both

#Set KundenName in Invoice window
label .clientL -text "Kunde:" -font "TkCaptionFont" -bg orange
label .clientNameL -textvariable name2 -font "bold"
pack .clientNameL .clientL -in .n.t2.f1 -side right

label .subtotal -textvariable ::subtot -bg orange
pack .subtotal -in .n.t2.f2
button .saveInvB -text "Rechnung speichern" -command {
  saveInv2DB
#TODO: reactivate after testing
#  saveInv2Rtf $invNo
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
# T A B 4 :  A R T I K E L  V E R W A L T E N
######################################################################################
label .artikelT -text "Artikel verwalten" -font "TkHeadingFont 20"
label .artikelL -text "Artikel Nr."
spinbox .artikelNumSB -width 5 -command {setArticleLine TAB4}
label .artikelNameL -padx 10 -textvariable artName
label .artikelPriceL -padx 10 -textvariable artPrice
label .artikelUnitL -padx 10 -textvariable artUnit
button .artikelSaveB -text "Artikel speichern" -command {saveArticle}
button .artikelDeleteB -text "Artikel löschen" -command {deleteArticle} -activebackground red
button .artikelCreateB -text "Artikel erfassen" -command {createArticle}
pack .artikelT -in .n.t4.f1
pack .artikelL .artikelNumSB -in .n.t4.f1 -side left
pack .artikelNameL .artikelPriceL .artikelUnitL -in .n.t4.f1 -side left
pack .artikelDeleteB .artikelSaveB .artikelCreateB -in .n.t4.f2 -side right -anchor se


#######################################################################
## F i n a l   a c t i o n s :    detect Fehlermeldung bzw. socket no.
#######################################################################
if {[string length $res] >20} {
  NewsHandler::QueryNews $res red 
  } else {
  NewsHandler::QueryNews "Mit Datenbank verbunden" green
  set db $res
  setAdrList
  set curAdrNo [$adrSpin get]
  fillAdrInvWin $curAdrNo
}

#Artikelverwaltung: Fill Artikelliste - TODO: only if tab opened!
##createArticleList
resetNewInvDialog

#Fill "Artikel erfassen" - TODO: find better widget names!
.artNumSB configure -values [pg_result [pg_exec $db "SELECT artnum FROM artikel"] -list]
.artikelNumSB configure -values [pg_result [pg_exec $db "SELECT artnum FROM artikel"] -list]
##updateArticleList
