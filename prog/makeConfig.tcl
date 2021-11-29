# makeConfig
##saves confFile, overwriting old
##called by .saveConfigB "Einstellungen speichern" button 
proc makeConfig {} {
  global confFile adrpos

  #Get DB name & User
  set dbname [.confdbnameE get]
  set dbuser [.confdbUserE get]
  append setDbName set { } dbname { } \" $dbname \"
  append setDbUser set { } dbuser { } \" $dbuser \"

  #Get currency (default set to CHF)
  append setCurrency set { } currency { } \" [.billcurrencySB get] \"

  #Get Vat: if 0, invoice ignores it, from 0.0 upwards invoice displays it
  set vat [.billvatE get]
  ##rejec non-digit values
  if {![string is double -strict $vat]} {
    set vat 0.0
  }
  append setVat set { } vat { } $vat
  
  #Get desired tex usepackage: letter / chletter from radiobutton var
  if {$adrpos == "Rechts"} {
    set letterclass "chletter"
  } elseif {$adrpos == "Links"} {
    set letterclass "letter"
  }
  append setLetterclass set { } letterclass { } $letterclass

  append setMyName set { } myName { } \" [.billownerE get] \"
  append setMyComp set { } myComp { } \" [.billcompE get] \"
  append setMyAdr set { } myAdr { } \" [.billstreetE get] \"
  append setMyCity set { } myCity { } \" [.billcityE get] \" 
  append setMyPhone set { } myPhone { } \" [.billphoneE get] \"
  append setMyBank set { } myBank { } \" [.billbankE get] \"

  #Get condition(s) & check if any have been altered, else set to ""
  set testphrase "Zahlungskondition"
  set cond1 [.billcond1E get]
  set cond2 [.billcond2E get]
  set cond3 [.billcond3E get]

#TODO: Bedingung stimmt nicht!!!
  if {![string compare -length 17 $testphrase $cond1]} {
    set cond1 ""
  }
  if {![string compare -length 17 $testphrase $cond2]} {
    set cond2 ""
  }
  if {![string compare -length 17 $testphrase $cond3]} {
    set cond3 ""
  }

  append setCond1 set { } cond1 { } \" $cond1 \"
  append setCond2 set { } cond2 { } \" $cond2 \"
  append setCond3 set { } cond3 { } \" $cond3 \"

  #Check company logo (TODO: not for letter yet!)
  ##check if newly set by button
  if [info exists ::logoPath] {
    set myLogo $::logoPath
  ##else check if already in Config
  } elseif {![info exists myLogo]} {
    set myLogo ""
  }
  append setMyLogo set { } myLogo { } \" $myLogo \"
  
  #Overwrite config file with new entries, deleting old
  set chan [open $confFile w]
    puts $chan $setDbName
    puts $chan $setDbUser
    puts $chan $setLetterclass
    puts $chan $setCurrency
    puts $chan $setVat
    puts $chan $setMyName
    puts $chan $setMyComp
    puts $chan $setMyAdr
    puts $chan $setMyCity
    puts $chan $setMyPhone
    puts $chan $setMyBank
    puts $chan $setCond1
    puts $chan $setCond2
    puts $chan $setCond3
    puts $chan $setMyLogo
  close $chan

  unset setCurrency setVat setMyName setMyComp setMyAdr setMyPhone setMyBank setCond1 setCond2 setCond3

  NewsHandler::QueryNews "Einstellungen in $confFile gespeichert." lightgreen

  source $confFile
  catch setMyLogo

  makeTexVorlage
  return 0
}

# makeTexVorlage
##creates general invoice vars 
##called by makeConfig
proc makeTexVorlage {} {
  global confFile spoolDir texVorlage
  source $confFile

  #1. first line add documentclass (letter OR chletter, from config)
  append tex \\documentclass\{ $letterclass \}

  #2. add fixed text (document & letter specific) 
  append tex {
  \usepackage[utf8]{inputenc}
  \usepackage[T1]{fontenc}
  \usepackage{textcomp}
  \usepackage[a4paper]{geometry}
  \usepackage[german]{babel}
  \usepackage[german]{invoice}
  \renewcommand*{\Fees}{Leistungen}
  \renewcommand*{\UnitRate}{Einzelpeis}
  \renewcommand*{\Count}{Menge}
  \renewcommand*{\Activity}{Produkt}
  \title{}
  \author{}
  }

  #3. add letter variables
  append tex \\name\{ $myComp \} \n
  append tex \\address\{ $myAdr \} \n
  append tex \\telephone\{ $myPhone \} \n
  append tex \\location\{ $myCity \}
 
  #4. add more fix with inv specific data commands
  append tex {
  \input{newInvData.tex}
  \begin{document}
  \begin{letter}{\custAdr}
  \date{\location, \today}
  \opening{Rechnung Nr. \quad \invNo \\ Ihre Referenz: \quad \comm \\ Auftragsdatum: \quad \dat \\ \bf{Zahlungsfrist: \quad \cond}}
  \begin{invoice}{\currency}{\vat}
  \ProjectTitle{Rechnung}
  \input{newInvItems.tex}
  \end{invoice}
  \closing{Besten Dank für den geschätzten Auftrag! \\\\ Zahlung an: \bank}
  \end{letter}
  \end{document}
  }

  #Save new vorlage 
  set chan [open $texVorlage w]
  puts $chan $tex
  close $chan

  NewsHandler::QueryNews "Personalisierte Rechnungsvorlage in $texVorlage gespeichert." lightgreen

  return 0
} ;#END makeTexVorlage

#TODO add set lang & set compName

#TODO scrap?
#Setzt Firmenlogo rechts oben, falls existent
proc setMyLogo {} {
  global myLogo
  if {[info exists myLogo] && [file exists $myLogo]} {
    image create photo logo -file $myLogo
    canvas .mylogoC -width [image width logo] -height [image height logo]
    .mylogoC create image 0 0 -image logo -anchor nw
    pack .mylogoC -in .titelF -side right
  }
}
