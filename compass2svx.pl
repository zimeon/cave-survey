#!/usr/bin/perl
#
# Qucik and dirty attempt at converter for COMPASS data so that I
# can look at it using Survex.
# Simeon Warner - 14Mar2001
#
# [CVS: $Id: compass2svx.pl,v 1.1 2001/03/14 07:03:53 simeon Exp $]
#
use strict;

my @months=('','Jan','Feb','Mar','Apr','May','Jun',
               'Jul','Aug','Sep','Oct','Nov','Dec');
my %possibleColumns=(
 'FROM'=>1, 'TO'=>1, 'LENGTH'=>1, 'BEARING'=>1, 'AZM'=>1, 
 'INC'=>1, 'DIP'=>1, 'LEFT'=>1, 'UP'=>1, 'DOWN'=>1, 'RIGHT'=>1, 
 'AZM2'=>1, 'INC2'=>1, 'FLAGS'=>1, 'COMMENTS'=>1, 'COMMENT'=>1
);

my $lineNum=0;
my $pageNum=1;
my $lineInPage=0;
my ($name, $surveyName, $surveyors, $date, $comment, $declination, $format, $corrections );
my @columns;
while (<STDIN>) {
  chomp;
  my $line=$_;
  $lineNum++;
  if ($line=~m%^\s*/(.*)%) { 
    # Comment
    print ";$1\n";
  } elsif ($line=~m/^\f/) {
    if (defined $surveyName) { &writePageFoot(); }
    $lineInPage=0;
    $pageNum++;
    $name=undef, $surveyName=undef, $surveyors=undef, 
    $date=undef, $comment=undef;
    $declination=undef; $format=undef; $corrections=undef;
    @columns=();
  } elsif ($line=~m/^\cZ/) {
    warn "Found end (^Z) at line $lineNum\n";
  } else {
    $lineInPage++;
    if ($lineInPage==1) {
      #warn "Page $pageNum starts at line $lineNum\n";
      $name=$line;
    } elsif ($lineInPage==2) {
      if ($line=~/^SURVEY NAME:\s+(\S+)\s*$/) {
        $surveyName=&encode($1);
      } else {
        warn "Can't parse line 2 = $line\n";
      }
    } elsif ($lineInPage==3) {
      #SURVEY DATE: 12 8 1992  COMMENT:
      if ($line=~/^SURVEY DATE:\s+(\d+)\s+(\d+)\s+(\d+)\s+(.*)/) {
        $date="$2".$months[$1]."$3";
        $comment=$4; 
      } else {
        &mydie("Can't parse line $lineNum (3) = $line\n");
      }
    } elsif ($lineInPage==4) {
      if ($line=~/^SURVEY TEAM:/) {
      } else {
        warn "Can't parse line $lineNum (4) = $line\n";
      }
    } elsif ($lineInPage==5) {
      $surveyors=$line; 
    } elsif ($lineInPage==6) {
      #DECLINATION:    0.00  FORMAT: DDDDLRUDLAD  CORRECTIONS:  0.00 0.00 0.00
      if ($line=~/^DECLINATION:\s+(-?\d+.\d+)(\s+FORMAT:\s+([A-Z]+))?(\s+CORRECTIONS:.*)?\s*$/) {
	$declination=$1;
        $format=$3;
        $corrections=$4;
        if ($corrections) {
          if ($corrections=~s/^\s+CORRECTIONS:\s*//) {
            #nothing
          } else {
            warn "Bad corrections on line $lineNum: $corrections\n";
          } 
        }
      } else {
        warn "Can't parse line $lineNum (6) = $line\n";
      }
    } elsif ($lineInPage==7) {
      unless ($line=~/^\s*$/) {
        warn "Can't parse line $lineNum (7) = $line\n";
      } 
    } elsif ($lineInPage==8) {
      #Column headings
      $line=~s/^\s+//;
      $line=~s/\s+$//;
      foreach my $col (split(/\s+/,$line)) {
        if (defined $possibleColumns{$col}) {
	  push(@columns,$col);
	} else {
          warn "Can't parse column heading '$col' in line $lineNum\n $line\n";
	}
      }
    } elsif ($lineInPage==9) {
      unless ($line=~/^\s*$/) {
        warn "Can't parse line $lineNum (9) = $line\n";
      } 
      &writePageHead();
    } elsif ($lineInPage>9) {
      #Column data
      $line=~s/^\s+//;
      $line=~s/\s+$//;
      my @columnData=split(/\s+/,$line,scalar(@columns));
      my %data=();
      if ( (scalar(@columnData)!=scalar(@columns)) and
          ((scalar(@columnData)!=scalar(@columns)-1) and ($columns[$#columns] eq 'COMMENTS')) and
	  ((scalar(@columnData)!=scalar(@columns)-2) and ($columns[$#columns] eq 'COMMENTS') and ($columns[$#columns-1] eq 'FLAGS'))) {
         warn "Bad number of columns in line $lineNum\n $line\n";
      }
      foreach my $colNum (0..$#columnData) {
        if ($columns[$colNum]=~/(FROM|TO)/) {
          $data{$columns[$colNum]}=&encode($columnData[$colNum]);
	} else {
          $data{$columns[$colNum]}=$columnData[$colNum];
	}
      }
      &writeLine(%data);
    }       
  }
}


sub writePageHead {
 print "*begin $surveyName\n";
 print ";cave: $name\n";
 print ";date: $date\n";
 print ";comment: $comment\n";
 print ";surveyors: $surveyors\n";
 print "\n";
}

sub writePageFoot {
 print "*end $surveyName\n\n";
}

sub writeLine {
  my %data=@_;
  my ($from,$to,$length,$bearing,$gradient);
  $from=$data{FROM} || warn "No FROM on line $lineNum\n";
  $to=$data{TO} || warn "No TO on line $lineNum\n";
  $length=$data{LENGTH} || warn "No Length on line $lineNum\n";
  if (defined $data{BEARING}) {
    $bearing=$data{BEARING};
  } elsif (defined $data{AZM}) {
    $bearing=$data{AZM};
  } else { 
    warn "No bearing on line $lineNum\n";
  }
  if (defined $data{INC}) {
    $gradient=$data{INC};
  } elsif (defined $data{DIP}) {
    $gradient=-$data{DIP};
  } else { 
    warn "No INC/DIP on line $lineNum\n";
  }
  print "*equate $from \\$from\n";
  print "*equate $to \\$to\n";
  print "$from\t$to\t$length\t$bearing\t$gradient\n";
}

sub encode {
  my ($txt)=@_;
  my $stxt=$txt;
  $txt=~s/\'/prime/g; $txt=~s/\+/plus/g; $txt=~s/\-/dash/g;
  $txt=~s/\$/dollar/g; $txt=~s/!/pling/g; $txt=~s/\*/star/g;
  $txt=~s/\?/quest/g;
  if ($txt ne $stxt) { warn "Rename $stxt -> $txt\n"; }
  return($txt);
}

sub mydie {
  print "---DEATH DUMP---\n";
  &writePageHead();
  die join(" ",@_);
}






