package Survex;
#
# Routines to read and write files in Survex format
# Simeon Warner - 16Apr2001
#
# [CVS: $Id: Survex.pm,v 1.1 2001/04/17 07:38:51 simeon Exp $]
#
use strict;

use Exporter;

use vars qw(@EXPORT_OK @ISA $AUTOLOAD);

@EXPORT_OK = qw(&survexWritePage);
@ISA = qw(Exporter);


sub survexWritePage {
  my ($OUT,$pageptr)=@_;

  my ($globalsptr,$linesptr)=@$pageptr;

  &initGlobalsUsed($globalsptr);
  
  my $surveyName=&getGlobal('survey name');
  print "*begin $surveyName\n";
  #
  ##### Use comment tags proposed by Paul De Bie
  #
  my $pageName=&getGlobal('page name');
  print ";#SVYNAM $pageName\n";
  my $date=&getGlobal('date',1);
  print ";#SVYDAT $date\n";
  my $comment=&getGlobal('comment',1);
  print ";#SVYCOM $comment\n";
  my $surveyTeam=&getGlobal('survey team');
  print ";#SVYTEA $surveyTeam\n";
  my $surveyors=&getGlobal('surveyors');
  print ";surveyors $surveyors\n";
  #
  # MUST ADD UNITS for corrections!
  #
  # In surex first number is offset (default 0.0) and the second number
  # is the scale factor (if specified, defaults to 1.0) .
  #   trueValue = ( reading - offset ) * scaleFactor
  #
  my $d;
  $d=&getGlobalWithUnits('correction_azm_plus',1);
  print "*calibrate compass ".-$d."\n" if ($d != 0.0);
  $d=&getGlobalWithUnits('correction_inc_plus',1);
  print "*calibrate clino ".-$d."\n" if ($d != 0.0);
  $d=&getGlobalWithUnits('correction_len_plus',1);
  print "*calibrate tape ".-$d."\n" if ($d != 0.0);
  $d=&getGlobalWithUnits('declination',1);
  print "*calibrate declination ".$d."\n" if ($d != 0.0);
  print "\n";
  
  my %stationsEquated=();
  foreach my $lptr (@$linesptr) {
    my ($lineNum,$cmd,$dptr)=@$lptr;
    my $from=$dptr->{FROM} || warn "No FROM on line $lineNum\n";
    my $to=$dptr->{TO} || warn "No TO on line $lineNum\n";
    my $length=$dptr->{LENGTH} || warn "No Length on line $lineNum\n";
    my $bearing;
    if (defined $dptr->{BEARING}) {
      $bearing=$dptr->{BEARING};
    } elsif (defined $dptr->{AZM}) {
      $bearing=$dptr->{AZM};
    } else { 
      warn "No bearing on line $lineNum\n";
    }
    my $gradient;
    if (defined $dptr->{INC}) {
      $gradient=$dptr->{INC};
    } elsif (defined $dptr->{DIP}) {
      $gradient=-$dptr->{DIP};
    } else { 
      warn "No INC/DIP on line $lineNum\n";
    }
    #
    ##### Do any data conversions
    #
    $from=&encode($from);
    $to=&encode($to);
    #
    ##### Write out data
    #
    if (not defined($stationsEquated{$from})) {
      print "*equate $from \\$from\n";
      $stationsEquated{$from}=1;
    }
    if (not defined($stationsEquated{$to})) {
      print "*equate $to \\$to\n";
      $stationsEquated{$to}=1;
    }
    print "$from\t$to\t$length\t$bearing\t$gradient\n";
  }

  print "*end $surveyName\n\n";

  &warnAboutUnusedGlobals();

}

my $allowedSurvexChars="#\'+-\$!*?,";

sub encode {
  my ($txt)=@_;
  my $stxt=$txt;
  # Don't want some characters as first characters 
  $txt=~s/^\'/prime/g; $txt=~s/^\+/plus/g; $txt=~s/^\-/dash/g;
  $txt=~s/^\$/dollar/g; $txt=~s/^!/pling/g; $txt=~s/^\*/star/g;
  $txt=~s/^\?/quest/g; $txt=~s/^,/comma/g;
  # Now check for anything not in allowed list   
  ### should use variable here!! 
  while ($txt=~s/([^a-zA-Z0-9_#'\+\-\$!*\?,])/&survexEncodeChar($1)/e) { 
    # nothing 
  }  
  # Print message if changed
  if ($txt ne $stxt) { warn "Rename $stxt -> $txt\n"; }
  return($txt);
}


sub survexEncodeChar {
  my ($ch)=@_;
  my $hex='a'.unpack('c',$ch);
  return($hex);
}


sub survexAllowedChars {
  return($allowedSurvexChars);
}


#############################################################################

my %globalsUsed;
my $globalsPtr;
 
sub initGlobalsUsed {
  ($globalsPtr)=@_;
  %globalsUsed=();
}

sub getGlobal {
  my ($key,$ignoreIfNotSet)=@_;
  if (defined($globalsPtr->{$key})) {
    $globalsUsed{$key}=1;
    return($globalsPtr->{$key});
  } elsif ($ignoreIfNotSet) {
    return(undef);
  } else {
    die "Global '$key' not set";
  }
}

sub getGlobalWithUnits {
  my ($key,$ignoreIfNotSet)=@_;
  if (defined($globalsPtr->{$key})) {
    $globalsUsed{$key}=1;
    return($globalsPtr->{$key});
  } elsif ($ignoreIfNotSet) {
    return(undef);
  } else {
    die "Global '$key' not set";
  }
}

sub warnAboutUnusedGlobals {
  foreach my $key (sort keys %$globalsPtr) {
    unless (defined($globalsUsed{$key})) {
      print "Warning - Unused global $key=".$globalsPtr->{$key}."\n";
    }
  }
}
    
1; 
