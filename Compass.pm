package Compass;
#
# Routines to read and write files in COMPASS format
# Simeon Warner - 15Apr2001
#
# [CVS: $Id: Compass.pm,v 1.2 2001/04/17 07:38:51 simeon Exp $]
#
use strict;

use Exporter;

use vars qw(@EXPORT_OK @ISA $AUTOLOAD);

@EXPORT_OK = qw(&compassReadPage);
@ISA = qw(Exporter);


my @months=('','Jan','Feb','Mar','Apr','May','Jun',
               'Jul','Aug','Sep','Oct','Nov','Dec');
my %possibleColumns=(
 'FROM'=>1, 'TO'=>1, 'LENGTH'=>1, 'BEARING'=>1, 'AZM'=>1, 
 'INC'=>1, 'DIP'=>1, 'LEFT'=>1, 'UP'=>1, 'DOWN'=>1, 'RIGHT'=>1, 
 'AZM2'=>1, 'INC2'=>1, 'FLAGS'=>1, 'COMMENTS'=>1, 'COMMENT'=>1
);


sub compassReadPage {
  my ($lineNum,$pageNum)=@_;

  $pageNum++;
  my $lineInPage=0;
  my @lines=();        #individual lines of survey data in page
  my %globals=();       #global properties of the page 
 
  my ($name, $surveyName, $surveyors, $date, $comment, $declination, $format, $corrections );
  my @columns;

  my $format=undef;
  my $corrections=undef;

  while (<STDIN>) {
    chomp;
    my $line=$_;
    $lineNum++;
    if ($line=~m%^\s*/(.*)%) { 
      # Comment
      push(@lines,['comment',$1]);
    } elsif ($line=~m/^\f/) {
      return('',$lineNum,$pageNum,[\%globals,\@lines]);
    } elsif ($line=~m/^\cZ/) {
      warn "Found end (^Z) at line $lineNum\n";
      return('eof',$lineNum,$pageNum,[\%globals,\@lines]);
    } else {
      $lineInPage++;
      if ($lineInPage==1) {
        #warn "Page $pageNum starts at line $lineNum\n";
        $globals{'page name'}=$line;
      } elsif ($lineInPage==2) {
        if ($line=~/^SURVEY NAME:\s+(\S+)\s*$/) {
          $globals{'survey name'}=$1;
        } else {
          warn "Can't parse line 2 = $line\n";
        }
      } elsif ($lineInPage==3) {
        #SURVEY DATE: 12 8 1992  COMMENT:
        if ($line=~/^SURVEY DATE:\s+(\d+)\s+(\d+)\s+(\d+)(\s+.+)?/) {
          $globals{'date'}="$2".$months[$1]."$3";
	  my $comment=$4;
	  if ($comment!~m/^\s*$/) {
	    if ($comment=~m/^\s+COMMENT:\s*(.*)/) {
	      $globals{'comment'}=$1;
	    } else {
	      &mydie("Can't parse COMMENT: on line $lineNum (3) `$comment'");
	    }
	  }
        } else {
          &mydie("Can't parse line $lineNum (3) = $line\n");
        }
      } elsif ($lineInPage==4) {
        if ($line=~/^SURVEY\s+TEAM:\s*(.*)/) {
	  $globals{'survey team'}=$1;
        } else {
          &mydie("Can't parse line $lineNum (4) = $line\n");
        }
      } elsif ($lineInPage==5) {
        #no checking, no extra fomatting  -- just whole line
        $globals{'surveyors'}=$line; 
      } elsif ($lineInPage==6) {
        #DECLINATION:    0.00  FORMAT: DDDDLRUDLAD  CORRECTIONS:  0.00 0.00 0.00
        if ($line=~/^DECLINATION:\s+(-?\d+.\d+)(\s+FORMAT:\s+([A-Z]+))?(\s+CORRECTIONS:.*)?\s*$/) {
	  $globals{'declination'}=$1;
          $format=$3;
          $corrections=$4;
          if ($corrections) {
            if ($corrections=~s/^\s+CORRECTIONS:\s*([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)//) {
	      $globals{'correction_azm_plus'}=$1;
 	      $globals{'correction_inc_plus'}=$2;
 	      $globals{'correction_len_plus'}=$3;
           } else {
              &mydie("Bad corrections on line $lineNum: $corrections\n");
            } 
          }
        } else {
          &mydie("Can't parse line $lineNum (6) = $line\n");
        }
      } elsif ($lineInPage==7) {
        unless ($line=~/^\s*$/) {
          &mydie("Can't parse line $lineNum (7) = $line\n");
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
          $data{$columns[$colNum]}=$columnData[$colNum];
        }
        push(@lines,[$lineNum,'data',\%data]);
      }       
    }
  }
  return('Unexpected end of file',$lineNum,$pageNum);
}


sub mydie {
  print "---DEATH DUMP---\n";
  die join(" ",@_,"\n");
}



