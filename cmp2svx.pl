#!/usr/bin/perl
#
# Take compass makefile (.mak) and processes this and all
# referenced data (.dat) files.
#
# Simeon Warner - 7Apr2001
#
# [CVS: $Id: cmp2svx.pl,v 1.1 2001/04/17 05:39:26 simeon Exp $]

use strict;

use Getopt::Std;
use vars qw($opt_h);

my ($myname)=__FILE__=~/([^\/]+)$/;

(&getopts('') and !$opt_h) || &usage();

foreach my $file (@ARGV) {
  # decide what type of file it is based on the extension
  # (compass uses strict extension typing)
  if ($file=~/^(.*)\.dat$/) {
    # single survey data file
    my $svxfile=$1.".svx";
    &convertDatafile($file,$svxfile);
  } elsif ($file=~/^(.*)\.mak$/) {
    my $svxfile=$1.".svx";
    &convertMakefile($file,$svxfile);
  } else {
    warn "$myname: Extension of file $file not recognized, ignoring.\n";
  }
}

sub convertDatafile { 
  my ($cmpfile,$svxfile)=@_;
  system("cat $cmpfile | compass2svx > $svxfile");
}

sub convertMakefile { 
  my ($makfile,$svxfile)=@_;
  unless (open(MAK,"<$makfile")) {
    warn "$myname: Can't read $makfile, skipping\n";
    return();
  }
  unless (open(SVX,">$svxfile")) {
    warn "$myname: Can't write $svxfile, skipping\n";
    return();
  }
  my $line;
  my $linenum=0;
  my $inline=0;
  my %includes=();
  while (<MAK>) {
    s/^\s+//; #zap any leading spaces
    s/\s+$//; #zap any trailing spaces including CR
    $line.=$_; 
    $linenum++;
    if ($line=~/^\s*$/) {
      #discard blank line
    } elsif ($line=~/^#/) {
      $line=~s/\s+\/(.*)$//;
      my $comment=$1;
      warn "$myname: Comment $comment\n" if ($comment);
      if ($line=~/;$/) {
        # Now have complete `line'
	$line=~s/^#//; $line=~s/;$//;
	my ($datfile,@stations)=split(/,/,$line);
	if (defined $includes{$datfile}) {
	  warn "$myname: Second include of `$datfile' ignored.\n";
	} else {
	  if (scalar(@stations)>0) {
	    warn "$myname: $datfile => stations ".join(',',@stations)."\n";
	  } else {
	    warn "$myname: $datfile => no stations\n";
	  }
	  # now take current station list and add to exports for
	  # already read datafiles
	  foreach my $df (keys %includes) {
	    push(@{$includes{$df}[1]},@stations);
	  }
	  $includes{$datfile}=(\@stations,[]);
	}
      }
      $line='';
    } else {
      #discard
      warn "$myname: Discarded line: '$line'\n";
      $line='';
    }
  }
}



sub usage {
  die "usgae:  $myname filename\n";
}
     
