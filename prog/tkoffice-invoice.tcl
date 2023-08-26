# ~/TkOffice/prog/tkoffice-invoice.tcl
# called by tkoffice-gui.tcl
# Salvaged: 2nov17
# Updated for use with SQLite: 9sep22
# Updated 25aug23

catch {source $confFile}
################################################################################################################
################# N E W   I N V O I C E   P R O C S ############################################################
################################################################################################################

set dataFile [file join $texDir invdata.tex]
set itemFile [file join $texDir invitems.tex]
 
# resetNewInvDialog
##called by Main + "Abbruch Rechnung"
proc resetNewInvDialog {} {
  global heute cond1
  
  #Cleanup
  catch {namespace delete rows}
  foreach w [winfo children .newInvoiceF] {
    destroy $w
  }

  #Set vars to 0
  namespace eval rows {
    set bill 0
    set buch 0
    set auslage 0
  }
  
  updateArticleList
  #TODO anpassen
#  .invartnumSB invoke buttondown
  
  #Configure message labels & pack
  .subtotalM conf -textvar rows::bill
  .abzugM conf -textvar rows::auslage
  .totalM conf -textvar rows::buch
  pack .subtotalL .subtotalM .abzugL .abzugM .totalL .totalM -side left -in .n.t2.bottomF

  #create Addrow button w/dynamic width - funzt mit '-expand 1' bestens!
  catch {button .addrowB}
  .addrowB conf -text "Posten hinzufügen" -command {addInvRow}
  catch {message .einheit -textvariable unit}
  catch {message .einzel -textvariable einzel}

  pack .invcondL .invcondSB .invauftrdatL .invauftrdatE .invrefL .invrefE .invcomL .invcomE -in .n.t2.f1 -side left -fill x 
  #Empty entry widgets
  .invrefE delete 0 end
  .invcomE delete 0 end
  .invcomE delete 0 end
  
  #Set back global vars
  set ::cond $cond1
  set ::auftrDat $heute
 
  pack .invartlistMB -in .n.t2.f1 -before .n.t2.f2 -anchor w -padx 20 -pady 5 
 
 #TODO anpassen
 # pack .invartnumSB .mengeE .invartunitL .invartnameL .invartpriceL -in .n.t2.f2 -side left -fill x
pack .mengeE .invartunitL .invartnameL .invartpriceL -in .n.t2.f2 -side left -fill x
  pack .addrowB -in .n.t2.f2 -side right -expand 1 -fill x
  
  
  #Reset Buttons
##TODO testing
#  .abbruchinvB conf -state disabled
 # .abbruchinvB conf -activebackground red -state normal
  .invSaveBtn conf -state disabled -command "
    .invSaveBtn conf -activebackground #ececec -state normal
    doSaveInv
  "
} ;#END resetNewInvDialog

# addInvRow
## creates 1 new row 
## called by setupNewInvDialog
proc addInvRow {} {
  
  #Exit if menge empty
  set menge [.mengeE get]
  if {$menge == ""} {
    NewsHandler::QueryNews "Bitte Menge eingeben!" red
    .mengeE conf -bg red
    focus .mengeE
    after 7000 {.mengeE conf -bg beige}
    return 1
  }

  #Configure Abbruch button
  pack .invCancelBtn .invSaveBtn -in .n.t2.bottomF -side right
  .invSaveBtn conf -activebackground skyblue -state normal
  .invCancelBtn conf -activebackground red -state normal -command {resetNewInvDialog}


  ##get last namespace no.
  if [catch {namespace children rows}] {
    set lastrow 0
  }  else {
    set lastrow [namespace tail [lindex [namespace children rows] end]]
  }

  ##add new namespace no.
  namespace eval rows {
    variable rowtot
    variable rabatt
    set rowNo [incr lastrow 1]

    # new row namespace
    namespace eval $rowNo  {

     #Get current values from GUI
      set bill $rows::bill
      set buch $rows::buch
      set auslage $rows::auslage 

      set artName [.invartnameL cget -text]
      set menge [.mengeE get]
      set artPrice [.invartpriceL cget -text]
      set artUnit [.invartunitL cget -text]
      set artType [.invarttypeL cget -text]
      
      set rowNo $::rows::rowNo
      set rowtot [expr $menge * $artPrice]

      #Create row frame
      set F [frame .newInvoiceF.invF${rowNo}]
      pack $F -fill x -anchor w    

      #Create labels per row
      catch {label $F.mengeL -text $menge -bg lightblue -justify left -anchor w}
      catch {label $F.artnameL -text $artName -bg lightblue -justify left -anchor w}
      catch {label $F.artpriceL -text $artPrice -bg lightblue -justify right -anchor w}
      catch {label $F.artunitL -text $artUnit -bg lightblue -justify left -anchor w}
      catch {label $F.arttypeL -text $artType -bg lightblue -justify right -anchor e}
      catch {label $F.rowtotL -text $rowtot -bg lightblue -justify left -anchor w}

      #Create "deleteRow" label & set bindings                  
      label $F.deleterowL -text "< Posten löschen" -bg beige -fg grey -borderwidth 1 -relief raised -width 15 
      pack $F.deleterowL -anchor w -fill x -padx 7 -side right 
			bind $F.deleterowL <Enter> "%W conf -bg red -fg black"
			bind $F.deleterowL <Leave> "%W conf -bg beige -fg grey"
			bind $F.deleterowL <Double-1> "deleteInvRow $F $rowtot $artType"
     

      # H a n d l e   t y p e s
              
      #Exit if rebate doubled
      if {$artType == "R" && ( [info exists ::rows::rabatt] && $rows::rabatt >0 ) } {
        NewsHandler::QueryNews "Nur 1 Rabatt zulässig" red
        namespace delete [namespace current]
        return 1
      }
       
      ##a) Type normal     
      if {$artType == ""} {
      
        ##deduce any existing rabattProzent from rowtot
        if [info exists ::rows::rabattProzent] {
          
          set rabattProzent $::rows::rabattProzent

          #compute this row's rebate
          set bill [expr $bill + $rowtot]
          set newrabatt [expr ($rabattProzent * $rowtot) / 100]
          set oldrabatt $::rows::rabatt

          #update global rebate
          #TODO zis isnt working yet!
          set ::rows::rabatt [expr $oldrabatt + $newrabatt]
          set ::rows::bill [expr $bill + $rowtot - $newrabatt]
          set ::rows::buch [expr $bill + $rowtot - $newrabatt]
         
        } else {
        
          set ::rows::bill [expr $bill + $rowtot]
          set ::rows::buch [expr $buch + $rowtot]
        }
        
      ##b) Type is "Rabatt" - compute from $buch (abzgl. Spesen)
      } elseif {$artType == "R"} {
        
        $F.artnameL conf -text "abzüglich $artName"
        $F.artpriceL conf -bg yellow -textvar ::rows::rabatt

        set ::rows::rabattProzent $artPrice
      
        set rabatt [expr ($buch * $artPrice / 100)]
        set ::rows::buch [expr $buch - $rabatt]
        set ::rows::bill [expr $bill - $rabatt]

        set ::rows::rabatt $rabatt

        $F.arttypeL conf -bg yellow
        .mengeE conf -state disabled
        set menge 1
      
                  
      ##c) "Auslage" types - add to $bill, not to $buch     
      } elseif {$artType == "A"} {
        
          set ::rows::auslage [expr $auslage + $rowtot]
          set ::rows::bill [expr $bill + $rowtot]
          set ::rows::buch [expr $bill - $auslage]
          $F.arttypeL conf -bg orange
          $F.rowtotL conf -bg orange
      }

     
      pack $F.artnameL $F.artpriceL $F.mengeL -anchor w -fill x -side left
      pack $F.artunitL $F.rowtotL $F.arttypeL -anchor w -fill x -side left


      #Reduce amounts to 2 decimal points -TODO better use
      set ::rows::bill [expr {double(round(100*$rows::bill))/100}]
      set ::rows::buch [expr {double(round(100*$rows::buch))/100}]
      if [info exists ::rows::rabatt] {
        set ::rows::rabatt [expr {double(round(100*$rows::rabatt))/100}]
      }
  
      #Export article cumulatively for use in saveInv2DB & fillAdrInvWin
      set separator {}
      if [info exists ::rows::article] {
        set separator { /}
      }
      append ::rows::article $separator ${menge} { } $artName

    } ;#END rowno ns
  } ;#END rows ns
          
} ;#END addInvRow

# deleteInvRow
## removes 1 row & recalculates total sums
## args = artType (can be empty)
## called by "delete row" label in new invoice dialog
proc deleteInvRow {F rowtot args} {

#TODO jesh balagan with rows:: vars !!!!!!!!!!!
# info vars rows::* gives much more info to be considered.
# Sonuç: silinen diziler hesaplanmasa da, hesapta gösteriyor.

  global rows::bill
  global rows::buch
  global rows::rabatt
  global rows::auslage

  pack forget $F

  if {$args == "R"} {
   
    set rows::bill [expr $bill + $rabatt]
    set rows::buch [expr $buch + $rabatt]
    set rows::rabatt 0
    
  } elseif {$args == "A"} {

    #don't touch rows::buch!
    set rows::bill [expr $bill - $rowtot] 
    set rows::auslage [expr $auslage - $rowtot]
     
  } else {

    set rows::bill [expr $bill - $rowtot]
    set rows::buch [expr $buch - $rowtot]
   
  }
} ;#END deleteInvRow

 
# doSaveInv
##coordinates invoice saving + printing progs
##evaluates exit codes
##called by .saveinvB button
proc doSaveInv {} {
  
  #1.Save to DB
  if [catch saveInv2DB res] {
    NewsHandler::QueryNews $res red
    return 1
  } 
  
  #2. LatexInvoice -NOTE: invNo put into ::Latex by saveInv2DB
	catch {latexInvoice $::Latex::invNo}
  
  return 0

} ;#END doSaveInv

# saveInv2DB
##saves new invoice to DB
##called by doSaveInv
proc saveInv2DB {} {
  global db env msg texDir itemFile name1 name2 city
  global cond ref comm auftrDat vat
  
  set adrNo [.adrSB get]

  #1. Get invNo & export to ::Latex 
	set invNo [createNewNumber invoice]
	namespace eval Latex {}
	set ::Latex::invNo $invNo
	
	
	#Get current vars from GUI
  set shortAdr "$name1 $name2, $city"
  set shortDesc $rows::article
  
  # set subtot $rows::buch
  set invTotal $rows::bill
  set auslage $rows::auslage
    
  #Create itemList for itemFile (needed for LaTeX)
  foreach rowNo [namespace children rows] {
    set rowNo [namespace tail $rowNo]
    set F .newInvoiceF.invF${rowNo}
    
    set artUnit [$F.artunitL cget -text]
    set artPrice [$F.artpriceL cget -text]
    set artType [$F.arttypeL cget -text]
    set artName [$F.artnameL cget -text]
    set menge [$F.mengeL cget -text]
    #Check if Discount
    if {$artType==""} {
      append itemList \\Fee\{ $artName { } \( pro { } $artUnit \) \} \{ $artPrice \} \{ $menge \} \n
    } elseif {$artType=="R"} {
      append itemList \\Discount\{ $artName \} \{ $rows::rabatt \} \n
    #Check if Auslage
    } elseif {$artType=="A"} {
      append itemList \\EBC\{ $artName \} \{ $artPrice \} \n
    }
    
  } ;#END foreach w

  #1. Save itemList to ItemFile & convert to Hex for DB
  set chan [open $itemFile w]
  puts $chan $itemList
  close $chan
  set itemListHex [binary encode hex $itemList]

  #2. Set payedsum=finalsum and ts=3 if cond="bar"
	if {$cond=="bar"} {
    set ts 3
    set payedsum $invTotal
  } else {
    set ts 1
    set payedsum 0
  }	

  #3. Make entry for vatlesssum if different from finalsum
  set vatlesssum $invTotal
  if {$vat > 0} {
    set vatlesssum [expr ($vat * $finalsum)/100]
  }

	#3. reformat auftrDat for DB date function
	set rawdate [clock scan "$auftrDat" -format "%d.%m.%Y"]
	set dbdate  [clock format $rawdate  -format "%Y-%m-%d"]
	
  #4. Save new invoice to DB
  set token [db eval "INSERT INTO invoice 
    (
    objectid,
    ts,
    customeroid, 
    addressheader, 
    shortdescription, 
    finalsum, 
    payedsum,
    vatlesssum,
    auslage,
    f_number,
    f_date,
    f_comment,
    ref,
    cond,
    items
    ) 
  VALUES 
    (
    $invNo,
    $ts,
    $adrNo,
    '$shortAdr',
    '$shortDesc',
    $invTotal,
    $payedsum,
    $vatlesssum,
    $auslage,
    $invNo,
    date('$dbdate'),
    '$comm',
    '$ref',
    '$cond',
    '$itemListHex'
    )"]
  
#TODO does this belong here?
  if [db errorcode] {
  
  #TODO how to get error message from SQLite?????????????????
    #NewsHandler::QueryNews "[mc invNotsaved $invNo]:\n[pg_result $token -error ]" red
     NewsHandler::QueryNews "[mc invNotsaved $invNo]:\n $token ]" red
     
    return 1
  
  } else {
   	NewsHandler::QueryNews "[mc invSaved $invNo]" green
    fillAdrInvWin $adrNo
    .invSaveBtn conf -text [mc printInv] -command "printInvoice $invNo" -bg orange

    return 0
  } 

} ;#END saveInv2DB



# clearAdrInvWin
##called by fillAdrInvWin & newAddress
proc clearAdrInvWin {} {
	global invF c1 c2 c3 c4 c5 c6 c7 c8

#catch {namespace delete invpages}
catch {namespace delete verbucht}
	
	#Empty columns except Headers
	lappend columnL $c1 $c2 $c3 $c4 $c5 $c6 $c7 $c8
  
  foreach col $columnL {
    
    set itemL [pack slaves $col]
    
      foreach i $itemL {
      if { [string index $i end] != "H"} {
        pack forget $i
      }
    }
  
  }
}

# fillAdrInvWin
##refills address invoice window with max 30 entries, paging through up+down btns
##Note: ts=customerOID in 'address', now identical with objectid,needed for identification with 'invoice'
##called by invPager & up+down btns
#TODO ?  set invL [lsort -decreasing [db eval "SELECT f_number FROM invoice WHERE customeroid = $custId"]]
#TODO: change name of column from ts to ...?
proc fillAdrInvWin {adrId args} {
  
  global invF db
  global c1 c2 c3 c4 c5 c6 c7 c8

  
  #Delete previous frames
  clearAdrInvWin

puts "running fillAdrInvWin..."

if {$args == "select"} {
  variable invpages::select 1
}  
  
  #Clear old window+namespace
  if [namespace exists verbucht] {
    namespace delete verbucht
  }

  #Add new namespace no.
  namespace eval verbucht {

    set adrId [.adrSB get]
    set custId [db eval "SELECT ts FROM address WHERE objectid = $adrId"]
    set invL [db eval "SELECT f_number FROM invoice WHERE customeroid = $custId"] 

    #run Pager unless invSelect is calling with argument "select"
    if {![info exists invpages::select]} { 
      invPager $invL
    }

    #redefine invL after Pager run
    global invpages::curPage
    set cur $invpages::curPage
    set invL [set invpages::$cur]
    set nTuples [llength $invL]

		#NOTE: T stands for "token", yet these are no more tokens, but single items or lists! 
    set invDatT   [db eval "SELECT f_date FROM invoice WHERE customeroid = $custId"]
	  set articleT   [db eval "SELECT shortdescription FROM invoice WHERE customeroid = $custId"]
	  set sumtotalT [db eval "SELECT finalsum FROM invoice WHERE customeroid = $custId"]
	  set payedsumT [db eval "SELECT payedsum FROM invoice WHERE customeroid = $custId"]

	  set payeddate [db eval "SELECT payeddate FROM invoice WHERE customeroid = $custId"]

	  set statusT   [db eval "SELECT ts FROM invoice WHERE customeroid = $custId"]	
    set itemsT    [db eval "SELECT items FROM invoice WHERE items IS NOT NULL AND customeroid = $custId"]
    set commT     [db eval "SELECT f_comment FROM invoice WHERE customeroid = $custId"]
    set auslageT  [db eval "SELECT auslage FROM invoice WHERE customeroid = $custId"]

    #Show client turnover, including 'auslagen'
    set umsatzL [db eval "SELECT sum(finalsum),sum(auslage) AS total from invoice WHERE customeroid = $custId"]
    set verbucht [lindex $umsatzL 0]
    set auslage [lindex $umsatzL 1]
    if {![string is double $auslage] || $auslage == ""} {
      set auslage 0.00
    }
    
    #TODO look below!
    set ::umsatz [roundDecimal [expr $verbucht + $auslage]]
        
    #set modulo initial vars
    set wechselfarbe #d9d9d9
    set normal $wechselfarbe
        
    #Create row per invoice
    for {set row 0} {$row<$nTuples} {incr row} {
    
      namespace eval $row {

        set n [namespace tail [namespace current]]
        set invF $::invF
        set row $n
        
        #compute Rechnungsbetrag from sumtotal+auslage
			  set sumtotal [lindex $::verbucht::sumtotalT $row]
			  set auslage [lindex $::verbucht::auslageT $row]

			  if {[string is double $auslage] && $auslage >0} {
  			  set invTotal [expr $sumtotal + $auslage]
			  } else {
			    set invTotal $sumtotal
			  } 
			  
			  set ts [lindex $::verbucht::statusT $row]
			  set invNo [lindex $::verbucht::invL $row]
        set invdat [lindex $::verbucht::invDatT $row]
			  set article [lindex $::verbucht::articleT $row]
        set comment [lindex $::verbucht::commT $row]
        set payeddate [lindex $::verbucht::payeddate $row] 
        set bezahlt [lindex $::verbucht::payedsumT $row]
        
			  #increase but don't overwrite frames per line	
			  catch {frame $invF.$row}
			  pack $invF.$row -anchor nw -side top -fill x -expand 0

    		#create entries per line, or refill present entries
    		## with fixed widths corresponding to GUI
			  
			  catch {label .invNoL-$row -anchor w -width 11}
			  .invNoL-$row conf -text $invNo
        
        catch {label .invDatL-$row -anchor w -justify left -width 11}
        .invDatL-$row conf -text $invdat
        
        ##letter width of TkDefaultFont is 1.2 bigger than TkHeaderFont!
			  catch {label .invArtL-$row -justify left -anchor w -width 34}
			  .invArtL-$row conf -text $article

			  catch {label .invSumL-$row -justify right -anchor e -width 12}
			  .invSumL-$row conf -text $invTotal

        #create label/entry for Bezahlt, packed later
        catch {label .payedSumL-$row -justify right -anchor e -width 12}
        .payedSumL-$row conf -text $bezahlt
        
        catch {label .payedDatL-$row -text $payeddate -justify right -anchor w -width 10}
        
        catch {entry .zahlenE-$row -bg beige -fg black -justify left -state disabled -width 10}
        #.zahlenE conf -fg grey
        
        catch {label .commentL-$row}

        #Pack all in corresponding columns
        pack .invNoL-$row -in $c1 -anchor w 
        pack .invDatL-$row -in $c2 -anchor w
        pack .invArtL-$row -padx 0 -in $c3 -anchor w
        pack .invSumL-$row -padx 30 -in $c4 -anchor e
        pack .payedSumL-$row -padx 26 -in $c5 -anchor e
        pack .payedDatL-$row -in $c6 -anchor w
        pack .zahlenE-$row -in $c7 -anchor w
        pack .commentL-$row -in $c8 -anchor w

			  if {$ts==3} {
			  
			    .payedSumL-$row conf -fg green
				  .commentL-$row conf -fg grey -text $comment -textvar {}
          
			    			    
        #If 1 or 2 activate entry widget
			  } else {
			  
		      .zahlenE-$row conf -fg black 
          .payedSumL-$row conf -fg red
          
 #  TODO lindex stimmt nicht mit Zeilennummer überein!!!!!!!!!!!!!! - Farbe ändert nicht, warum?
          .zahlenE-$row conf -state normal
          .zahlenE-$row conf -background beige
          .zahlenE-$row conf -validate focusout -vcmd "savePaymentEntry %P %W $n"

	#		    set ::verbucht::eingabe 1
          set restbetrag "Restbetrag eingeben und mit Tab-Taste quittieren"
          set gesamtbetrag "Zahlbetrag eingeben und mit Tab-Taste quittieren"
          .commentL-$row conf -fg red -textvar gesamtbetrag
          
				  
        #if 2 (Teilzahlung) include payed amount
				  if {$ts==2} {
                
					  .commentL-$row conf -fg maroon -textvar restbetrag
					  .payedSumL-$row conf -fg maroon
				  }
			  }

        #create comment btn
			  #catch {label $invF.$n.commentL -width 50 -justify left -anchor w -padx 35}
			  
        #Modulo: colour lines alternately if more than 5 lines
        set normal #d9d9d9
        if [expr $n % 2] {set wechselfarbe silver} {set wechselfarbe $normal}
        foreach w [winfo children $invF.$n] {$w conf -bg $wechselfarbe}
        
        #Bind invNo labels to highlighting on hover & command on double-click
			  bind .invNoL-$row <Enter> "%W conf -bg orange"
			  bind .invNoL-$row <Leave> "%W conf -bg $wechselfarbe"
			  bind .invNoL-$row <Double-1> "printInvoice $invNo"
 		
  		} ;#END ns $n

    } ;#END for loop

    #Recolour lines to normal if only few
    if {$row < 5} {
      foreach f [winfo children $invF] {
        foreach w [winfo children $f] {
          $w conf -bg $normal
        }
        
      }
    }
  } ;#END ns verbucht

  set ::credit [updateCredit $adrId]
  
  #TODO watch umsatzL, which must comprise ALL turnover from customer
  #s.o. set umsatz...
  
} ;#END fillAdrInvWin

# invPager
## checks if invL has more than 25 entries & writes 1 or several $chunk item vars into ::invpages
## for filladrInvWin & up+down buttons to retrieve
## called by .adrSB 
proc invPager {invL} {
  
  puts "running invPager.."
  
  set chunk 25
  
  #Clear any invpages info for new run & create mandatory invL-1
  namespace eval invpages {
    variable 1
    variable curPage
    variable lsize 0
  }

  global invpages::curPage
  global invpages::lsize

  #exit if no invoices found
	set nTuples [llength $invL]
	if {$nTuples == -1} {
	  return 1
  }

  # 1. if 1 page set invL-1 & return
  if {$nTuples <= $chunk} {
    set invpages::1 $invL
    .invupBtn conf -state disabled
    .invdownBtn conf -state disabled
  .invSB conf -state disabled
    set curPage 1
    
  
  # 2. if several pages set pageL for invSelectPage to evaluate
  } else {

    #Enable up+down btns for several pages
    .invupBtn conf -state normal
    .invdownBtn conf -state normal

    
    #split invL into item chunks & save into vars
    set beg 0
    set end $chunk
    set no 1
      
    while {[lrange $invL $beg $end] != ""} {

puts "run $no"

      catch {variable invpages::$no}
      
      set invpages::$no [lrange $invL $beg $end]
puts [lrange $invL $beg $end]

      #TODO do we need this?      
#      set invpages::$no $invL-$no
      #lappend invpages::pageL $no
      lappend numPages "page $no"
            
      incr beg $chunk
      incr end $chunk
      incr no 1
      incr lsize
 

    }
  
  .invSB conf -state normal
  .invSB conf -values [lsort -decreasing $numPages]
  .invSB set "page 1"
  
  } ;#END main clause
  
    
} ;#END invPager

# invSelectPage
## checks how many pages exist & moves 1 up or down from $curPage
## resets $::invpages::curPage
## called by .invupBtn & .invdownBtn when activated
proc invSelectPage {args} {

  global invpages::curPage
  global invpages::lsize
  
  set max $lsize
  
  if {$curPage <= $max} {
    set cur $curPage
  } else {
    return 1
  }
  
  if {$args == "up"} {
    if {[incr cur -1] <= 0} {
      return 1
    } 
       
  } elseif {$args == "down"} {
  
    if {[incr cur] > $max} {
      return 1
    }

  } ;#END main if

#puts $cur
puts $invpages::curPage

    fillAdrInvWin $cur select
    set invpages::curPage $cur

} ;#END invSelectPage
  	


# setInvPath
##composes invoice name from company short name & invoice number
##returns invoice path with required ending: TEX + PDF
##required types: tex / pdf / pdftmp
##called by printInvoice
proc setInvPath {invNo type} {
  global spoolDir myComp vorlageTex tmpDir
  
  set compShortname [lindex $myComp 0]
  append invName invoice _ $compShortname - $invNo

  if {$type == "tex"} {
    append invTexName $invName . tex
    set invPath [file join $tmpDir $invTexName]
  
    file copy -force $vorlageTex $invPath
  
  } elseif {$type == "pdf" || $type == "pdftmp"} {
    
    append invPdfName $invName . pdf
    
    if {$type == "pdftmp"} {
	    set invPath [file join $tmpDir $invPdfName]
  	} elseif {$type == "pdf"} {  
    	set invPath [file join $spoolDir $invPdfName]
  	}
  
  }
  
  return $invPath

} ;#END setInvPath


# savePaymentEntry
##called by fillAdrInvWin by $invF.$n.zahlenE entry widget
proc savePaymentEntry {newPayedsum curEName ns} {
  global db invF
  set curNS "verbucht::${ns}"
  set rowNo [namespace tail $curNS]

	#1)get invoice details
  set invNo [$invF.$rowNo.invNoL cget -text]
  set newPayedsum [$curEName get]

  #avoid non-digit amounts
  if [string is false $newPayedsum] {
    $curEName delete 0 end
    $curEName conf -validate focusout -vcmd "savePaymentEntry %P %W $ns"
    NewsHandler::QueryNews "Fehler: Konnte Zahlbetrag nicht speichern." red
    return 1
  }

#puts $newPayedsum
#return

  set invT [db eval "SELECT payedsum,finalsum,auslage,customeroid FROM invoice WHERE f_number=$invNo"]
  set oldPayedsum [lindex $invT 0]
  set buchungssumme [lindex $invT 1]
  set auslage [lindex $invT 2]
  set adrNo [lindex $invT 3]
  
  if {[string is double $auslage] && $auslage > 0} {
    set finalsum [expr $buchungssumme + $auslage]
  } else {
    set finalsum $buchungssumme
  }
  
    
  #Compute total payedsum:
  set totalPayedsum [expr $oldPayedsum + $newPayedsum] 
  set newCredit [expr $totalPayedsum - $finalsum]
  
  #compute remaining credit + set status
  if {$newCredit >= 0} {
    set status 3
    
  } else {
    set status 2
#    set totalPayedsum ?
  }

#puts "OldCredit $oldCredit"
#puts "NewCredit $newCredit"
#puts "OldPS $oldPayedsum"
#puts "NewPS $newPayedsum"
#puts "status $status"
#puts "diff $diff"

	# S a v e  totalPayedsum  to 'invoice' 
  set token1 [db eval "UPDATE invoice 
    SET payedsum = $totalPayedsum, 
    ts = $status,
    payeddate = (SELECT date())
    WHERE f_number=$invNo
    "]

  #Update GUI    
  NewsHandler::QueryNews "Betrag CHF $newPayedsum verbucht" green

  ##delete OR reset zahlen entry
  if {$status == 3} {
    pack forget $curEName
 		.payedSumL conf -text $totalPayedsum -fg green
    pack forget .commentL
    
  } else {
  
    $curEName delete 0 end
    $curEName conf -validate focusout -vcmd "savePaymentEntry %P %W $ns"
 		.payedSumL conf -text $totalPayedsum -fg maroon
  }
    
  set ::credit [updateCredit $adrNo]
  NewsHandler::QueryNews "Das aktuelle Kundenguthaben beträgt $newCredit" green
  return 0
  
} ;#END savePaymentEntry

# updateCredit
##calculates total credit per customer
##called by fillAdrInvWin + ?savePaymentEntry
proc updateCredit {adrNo} {
  global db
  
  set invoicesT [db eval "SELECT 
    sum(finalsum),
    sum(payedsum),
    sum(auslage) AS total from invoice WHERE customeroid = $adrNo"
    ]
  
  set verbuchtTotal [lindex $invoicesT 0]
  set gezahltTotal  [lindex $invoicesT 1]
  set auslagenTotal [lindex $invoicesT 2]
  
  if {![string is double $verbuchtTotal]  || $auslagenTotal == ""} {
    set verbuchtTotal 0.00
  }
  if {![string is double $gezahltTotal]  || $auslagenTotal == ""} {
    set gezahltTotal 0.00
  }
  if {![string is double $auslagenTotal] || $auslagenTotal == ""} {
    set auslagenTotal 0.00
  }
  
  set billedTotal [expr $verbuchtTotal + $auslagenTotal]
  set totalCredit [expr $gezahltTotal - $billedTotal]

  #Configure .creditM widget
  if {$totalCredit >0} {
    .creditM conf -bg lightgreen
  } elseif {$totalCredit <0} {
    .creditM conf -bg red
  } else { 
    .creditM conf -bg silver
  }
  
  return [roundDecimal $totalCredit]
}
   
# storno
##removes given item from database if confirmed in messageBox
##called by .stornoE   
proc storno {id} {
	global db

	#Switch back to main page & create pop-up window to verify deletion
	.n select 0
	set res [tk_messageBox -title "Buchung stornieren" -message "Wollen Sie Buchung $id wirklich dauerhaft entfernen?" -icon warning -type yesno]	

	#Exit if "No"
	if {$res == "no"} {
		NewsHandler::QueryNews "Buchung Nr. $id wurde nicht storniert." red
		return 1
	}
	
	#Avoid error of empty item (wrong number - sqlite has no proper error handling!!!)
	set code "FROM invoice WHERE objectid=$id"
	set res [db eval "SELECT * $code"]
	if {$res == ""} {
		NewsHandler::QueryNews "Kein Auftrag mit Nr. $id vorhanden. Abbruch." red
		return 1
	}
	
	#Proecess deletion & update GUI
	db eval "DELETE $code"
	NewsHandler::QueryNews "Buchung Nr. $id erfolgreich storniert." green
	fillAdrInvWin $id

} ;#END storno

# fetchInvData
##1.retrieves invoice data from DB
##2.gets some vars from Config
##3.saves dataFile & itemFile to $texDir for Latex processing
##called by printDocument if invoice not found in spooldir
proc fetchInvData {invNo} {
  global db texDir confFile itemFile dataFile tkoDir
  
  #1.get some vars from config
  source $confFile
  if {![string is digit $vat]} {set vat 0.0}
  if {$currency=="$"} {set currency \\textdollar}
  if {$currency=="£"} {set currency \\textsterling}
  if {$currency=="€"} {set currency \\texteuro}
  
#TODO what's the deal with Swiss Francs?!
  if {$currency=="CHF"} {set currency {CHF}}

  #2.Get invoice data from DB - TODO add f_comment, rename ref
  set invToken [db eval "SELECT 
    ref,
    cond,
    f_date,
    items,
    customeroid
  FROM invoice WHERE f_number = $invNo"
  ]

  if [db errorcode] {
    NewsHandler::QueryNews "[mc invRecovErr $invNo]\n$invToken" red
    return 1
  }
  
  set ref       [lindex $invToken 0]
  set cond      [lindex $invToken 1]
  set auftrDat  [lindex $invToken 2]
  set itemsHex  [lindex $invToken 3]
  set adrNo     [lindex $invToken 4]

  #3.Get address data from DB & format for Latex
  set adrToken [db eval "SELECT 
    name1,
    name2,
    street,
    zip,
    city 
  FROM address WHERE ts=$adrNo"
  ]
  
  #make sure below signs are escaped since they interfere with LaTex commands
  lappend custAdr [lindex $adrToken 0] {\\}
  lappend custAdr [lindex $adrToken 1] {\\}
  lappend custAdr [lindex $adrToken 2] {\\}
  lappend custAdr [lindex $adrToken 3] { }
  lappend custAdr [lindex $adrToken 4]
    
  #4.set dataList for usepackage letter
  append dataList \\newcommand\{\\referenz\} \{ $ref \} \n
  append dataList \\newcommand\{\\cond\} \{ $cond \} \n
  append dataList \\newcommand\{\\dat\} \{ $auftrDat \} \n
  append dataList \\newcommand\{\\invNo\} \{ $invNo \} \n
  append dataList \\newcommand\{\\custAdr\} \{ $custAdr \} \n
  append dataList \\newcommand\{\\myBank\} \{ $myBank \} \n
  append dataList \\newcommand\{\\myName\} \{ $myComp \} \n
  append dataList \\newcommand\{\\myAddress\} \{ $myAdr \} \n
  append dataList \\newcommand\{\\myPhone\} \{ $myPhone \} \n
  append dataList \\newcommand\{\\vat\} \{ $vat \} \n
  append dataList \\newcommand\{\\currency\} \{ $currency \} \n

  ##save dataList to dataFile
  set chan [open $dataFile w] 
  puts $chan $dataList
  close $chan

  #save itemList to itemFile  
  set itemList [binary decode hex $itemsHex]
  if {$itemList == ""} {
    NewsHandler::QueryNews "Keine Posten für Rechnung $invNo gefunden. Kann Rechnung nicht anzeigen oder ausdrucken." red 
    return 1
  }
  #get rid of Latex code signs
  regsub -all {%} $itemList {\%} itemList
  regsub -all {&} $itemList {\&} itemList
  regsub -all {$} $itemList {\$} itemList
  regsub -all {#} $itemList {\#} itemList
  regsub -all {_} $itemList {\_} itemList
  
  set chan [open $itemFile w]
  puts $chan $itemList
  close $chan

  #Cleanup
  unset invToken adrToken
	
  return 0
  
} ;#END fetchInvData
