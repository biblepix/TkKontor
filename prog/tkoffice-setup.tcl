# tkoffice/prog/tkoffice-setup.tcl
##contains procs sourced by tkoffice-gui.tcl

# setupConfig
proc setupConfig {} {
  global dumpDir dbname spoolDir

#MANAGE DATENBANK
label .managedbL -text "[mc manageDb]" -font "TkHeadingFont"
message .managedbM -width 800 -text "[mc manageDbTxt]"
button .dumpdbBtn -text "[mc dumpDb]" -command {dumpDB}
button .restoredbBtn -text "[mc restoreDb]" -command {
  tk_messageBox -icon info -type ok -message "Wählen Sie eine Sicherungsdatei zum Wiederherstellen"
  restoreDB
}
pack .managedbL -in .n.t4.f2 -anchor nw
pack .managedbM -in .n.t4.f2 -anchor nw -side left
pack .restoredbBtn .dumpdbBtn -in .n.t4.f2 -anchor se -side right

#DATENBANK EINRICHTEN
#label .confdbT -text "[mc manageDb]" -font "TkHeadingFont"
#message .confdbM -width 800 -text "[mc manageDbTxt]"
#label .confdbnameL -text "Name der Datenbank" -font "TKSmallCaptionFont"
#label .confdbUserL -text "Benutzer" -font "TkSmallCaptionFont"
#entry .confdbnameE -textvar dbname
#entry .confdbUserE -textvar dbuser -validate focusin -validatecommand {%W conf -bg beige -fg grey ; return 0}


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
pack .billformatlinksRB .billformatrechtsRB -in .n.t4.f5 -anchor nw
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

button .billingSaveB -text [mc saveConf] -command {source $makeConfig ; makeConfig}
pack .billingSaveB -in .billing2F -side bottom -anchor se -padx 10 -pady 10

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

} ;#END setupConfig
