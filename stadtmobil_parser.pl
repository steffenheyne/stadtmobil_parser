#!/usr/bin/perl

## data exractor for Stadtmobil invoices 

use strict;
use Time::Piece;
my $inv_dir = $ARGV[0];

my $bidx=0;

open(OUT,">","alle_buchungen.tsv");
print OUT join("\t",("idx","Teilnehmer","Stadt","Station","Auto","Jahr","Monat","von","TagA","Anfang","bis","TagE","Ende","Stunden","Km","Grundpreis","Zeitpreis","Km-Preis","Gesamtpreis","Rechnungsdatum","Datei"))."\n";

foreach my $file (<$inv_dir/*tadtmobil*.pdf>){
	my $inv_text = readpipe("pdftotext -layout $file -");
	$inv_text =~ s/\n/§/g;
	
	$inv_text =~ /Teilnehmer-Nr\.\s+(\d+)/g;
	my $tnr= $1;
	$inv_text =~ /\G.*?Rechnungsdatum\s+(\S+)\s*§/g;
	my $date= $1;
	print "\n\n".$file," TNr. ",$tnr," Datum ",$date,"\n";

	while ($inv_text =~ /([^§]+\s\S+\s+USt\s+Netto)/g){
		my $start = $-[1];
		my $end = -1;
		if ($inv_text =~ /(\G.*?Fahrtgutschrift.Schnupperangebot.*?)§/){
			print "Schnupperangebot Rabatt";
			next;		
		}
		elsif ($inv_text =~ /(\G.*?Fahrtkosten.*?)§/g){
			$end = $+[1];}
		elsif ($inv_text =~ /(\G.*?Tankkostenerstattung.*?)§/g){
			$end = $+[1];
			print "Nur Tankkostenbuchung! - Skip!";
			next;
		}
		my $buchung = substr($inv_text,$start,$end-$start+1);
		$buchung =~ s/§/\n/g;
		$bidx++;
		print "\n--> Buchung: $bidx\n";
		print "### Erkannter Buchungstext - Orginal: >>>\n",$buchung,"\n >>> Ende Original ####################\n\n";
		
		$buchung =~ /^(.*?),/;
		my $car = $1;
		print "Auto        : ",$car,"\n";
		$buchung =~ /,.([^,]+),.([^,]+\S)\s+USt/;
		my $city = $1;
		print "Stadt       : ",$city,":\n";
		
		my $station = $2;
		print "Station     : ",$station,"\n";
		
		$buchung =~ /von ([\d.]+), ([\d:]+)/;
		my $date_start = $1."-".$2;
		print "Zeitraum von: ".$date_start,"\n";
		
		my $gp=0;
		if ($buchung =~ /Grundgebühr.*?\%.*?€\s+([\d,]+) €/){
			$gp=$1; $gp=~s/,/./;
		}
		print "Grundpreis  : ",$gp," Euro\n";
		$buchung =~ /bis ([\d.]+), ([\d:]+)/;
		my $date_end = $1."-".$2;
		print "Zeitraum bis: ".$date_end,"\n";
		my $kmt = 0;
		my $km = 0;
		if ($buchung =~ /Km-Tarif(.*)\s+[\d,]+\%.*?€\s+([\d,]+) €/){
			my $tmp = $1;
			print "case1: ",$tmp,"\n";
			$kmt=$2; 
			$kmt=~s/,/./;
			
			while ($tmp=~/([\d]+) km/g){
				$km+=$1;
			}
		} elsif ($buchung =~ /Km-Tarif.*\n\s+(.*)\s+[\d,]+\%.*?€\s+([\d,]+) €/){
			my $tmp = $1;
			print "case2: ",$tmp,"\n";
			$kmt=$2; 
			$kmt=~s/,/./;
			
			while ($tmp=~/([\d]+) km/g){
				$km+=$1;
			}
		}
		
		print "km         : ",$km,"\n";
		print "Km Preis   : ",$kmt," Euro\n";
		my $zt=0;
		my $gutschrift=0;
		if ($buchung =~ /Zeit-Tarif.*?\%\s+[\d,]+.€\s+([\d,]+) €/){
			$zt=$1; $zt=~s/,/./;
		} elsif ($buchung =~ /Zeit-Tarif.*\n\s+.*\s+[\d,]+\%.*?€\s+([\d,]+) €/){
			$zt=$1;$zt=~s/,/./;
		}
		
		if ($buchung =~ /Zeit-Tarif.*Gutschrift.*?\%\s+[-\d,]+.€\s+([-\d,]+) €/){
			$gutschrift = $1; $gutschrift =~s/,/./;
		}
		my $gesamtpreis = $gp+$kmt+$zt+$gutschrift;
		print "Zeitpreis  : ",$zt," Euro\n";
		print "Gutschrift : ",$gutschrift," Euro \n";
		print "Gesamtpreis: ",$gesamtpreis," Euro\n";
		
		my $t1 = Time::Piece->strptime($date_start,"%d.%m.%Y-%H:%M");
		print "time ",$t1,"\n";
		my $t2 = Time::Piece->strptime($date_end,"%d.%m.%Y-%H:%M");
		print "time ",$t2,"\n";
		my $zeitraum = sprintf("%.1f",($t2-$t1)/3600);
		print "duration ",$zeitraum," hours\n";
		
		if ($buchung =~ /^Fahrtunabhängige Kosten.*Quernutzung/s){
			print "Quernuzung!"."\n";
			$buchung =~ /Quernutzung\s+(.*Kilometer)/s;
			my $tmp = $1;
			print $1,"\n";
			
			$tmp =~ /(.*)\s+[\d,]+%\s+[\d,]+ €\s+([\d,]+) €\n(.*)$/;
			#print $1,$2,$3,"\n";
			my $t1 = $1.$3;
			$gp = 0;
			my $preis = $2;
			$preis=~s/,/./;
			$kmt=$preis/2;
			$zt=$preis/2;
			$gesamtpreis=$kmt+$zt;
			$t1 =~ /^([^\,]+?), (\S+).*?(\S+)\, ([\d\.]+).*?([\d:]+).*?([\d\.]+).*?([\d:]+) Uhr\,\s+([\d]+)/;
			$city = $1;
			$station = $2;
			$car = $3;
			$km = $8;
			print "time ",$4."-".$5,"\n";
			my $ti1 = Time::Piece->strptime($4."-".$5,"%d.%m.%y-%H:%M");
			print "time ",$ti1,"\n";
			my $ti2 = Time::Piece->strptime($6."-".$7,"%d.%m.%y-%H:%M");
			print "time ",$ti2,"\n";
			$zeitraum = sprintf("%.1f",($ti2-$ti1)/3600);
		
			print "stadt :".$city.": ",$station," ",$car," ",$ti1," ",$ti2," ",$zeitraum," ",$km,"\n";
		}
		
		print OUT join("\t",($bidx,$tnr,$city,$station,$car,$t1->year,$t1->fullmonth,$t1->dmy("."),$t1->wdayname,$t1->hms,$t2->dmy("."),$t2->wdayname,$t2->hms,$zeitraum,$km,$gp,$zt,$kmt,$gesamtpreis,$date,$file))."\n";
	}
}

close(OUT);
