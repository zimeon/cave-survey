#!/usr/bin/perl
#
# Convert cave survey data from the format used by Art Palmer's
# DOS program SURVEY.EXE to the svx format of survex.
# Simeon Warner
#
# $Id: palmer-to-survex.pl,v 1.2 2007/02/25 20:30:33 simeon Exp $x
use strict;

use Getopt::Std;

use vars qw($opt_h $opt_q $opt_v $opt_V $opt_f);

my ($myname)=__FILE__=~/([^\/]+)$/;

(getopts('hqvVf') && !$opt_h) || &usage();

my $debug_level=1;
$debug_level=0 if ($opt_q);
$debug_level=2 if ($opt_v);
$debug_level=3 if ($opt_V);

my $infile=undef;
my $outfile=undef;
if (scalar(@ARGV)==0) {
  &mywarn("No input file specified");
  &usage();
} elsif (scalar(@ARGV)==1) {
  $infile=shift;
  $outfile=$infile; $outfile=~s/\.[^\.]+$//; $outfile.=".svx";
  $outfile.='~' if ($infile eq $outfile);
  &mynote(1,"Reading from '$infile', writing to '$outfile'");
} elsif (scalar(@ARGV)==2) {
  $infile=shift;
  $outfile=shift;
  &mydie("Can't have same in and out file! '$infile'") if ($infile eq $outfile);
} else {
  &mywarn("Too many command line arguments");
  &usage();
}

### Open in an out files
open(IN,"<$infile") || &mydie("Can't open input file '$infile': $!");
&mydie("Output file '$outfile' already exists, use -f to overwrite") if (-e $outfile and !$opt_f);

my $survey=&read_palmer(\*IN);
close(IN);

open(OUT,">$outfile") || &mydie("Can't open output file '$outfile': $!"); 
&write_survex(\*OUT,$survey);
close(OUT);

&mynote(1,"Done, exiting.");
exit(0);
###END###

my $linenum;

sub read_palmer {
  my ($infh)=@_;
  my $survey={};
  $linenum=0;

  $survey->{title}=&readline($infh);
  &mynote(2,"Title: ".$survey->{title});

  my $block=&read_palmer_block($infh);
  unless ($block->{to} eq 'code') {
    mydie("First block must be a calibration block!");
  } 
  $survey->{sets}=[];
  my $set={};
  push(@{$survey->{sets}},$set);
  $set->{calibration}=$block;
  $set->{legs}=[];

  my $numlegs=0;
  while (not eof($infh)) {
    my $block=&read_palmer_block($infh);
    if ($block->{to} eq 'code') {
      #new set
      $set={};
      push(@{$survey->{sets}},$set);
      $set->{calibration}=$block;
      $set->{legs}=[];
    } else {
      push(@{$set->{legs}},$block);
      $numlegs++;
    }
  }
  &mynote(1,"Read $linenum lines; $numlegs legs.");
  return($survey);
}


sub readline {
  my ($infh)=@_;
  my $c=<$infh> || &mydie("Unexpected end of file at line $linenum");
  $c=~s/[\r\n\s]+$//;
  $linenum++;
  return($c);
}


sub readnum {
  my ($infh)=@_;
  my $n=<$infh> || &mydie("Unexpected end of file at line $linenum, expected number");
  $n=~s/[\r\n\s]+$//;
  $linenum++;
  return($n);
}
  

sub read_palmer_block {
  my ($infh)=@_;
  my %b;
  $b{to}=&readline($infh);
  $b{from}=&readline($infh);
  $b{dir}=&readline($infh);
  $b{dst}=&readnum($infh);
  $b{az}=&readnum($infh);
  $b{inc}=&readnum($infh);
  $b{q1}=&readnum($infh);
  $b{q2}=&readnum($infh);
  my $numextra=&readnum($infh);
  $b{x}=&readnum($infh);
  $b{y}=&readnum($infh);
  $b{z}=&readnum($infh);
  foreach (my $j=1; $j<=$numextra; $j++) {
    $b{extra}={} unless (defined $b{extra});
    my $type=&readline($infh);
    my $val=&readline($infh);
    if (defined $b{extra}{$type}) {
	&mynote(1,"Line $linenum: duplicate extra parameter '$type', taking last");
        &mynote(2,"  => discarded ".$b{extra}{$type});
        &mynote(2,"  => kept      ".$val);
    }
    $b{extra}{$type}=$val;
  }
  return(\%b);
}


sub write_survex {
  my ($outfh,$survey)=@_;
  
  #Write title information
  print $outfh "; ".$survey->{title}."\n";
  print $outfh "; Converted from Art Palmer's format by $myname on ".localtime()."\n\n";
  
  #Write overall information
  print $outfh "*units tape meters\n";
  print $outfh "*units compass degrees\n";
  print $outfh "*units clino degrees\n";
  print $outfh "\n";

  foreach my $set (@{$survey->{sets}}) {
    #Write calibration information
    print $outfh "; Calibration\n";
    printf $outfh "*calibrate declination %g\n",-$set->{calibration}->{az};

    #Write legs
    print $outfh "; Survey legs\n";
    #standard form: from-station to-station tape compass clino
    foreach my $leg (@{$set->{legs}}) {
      my $from=$leg->{from};
      my $to=$leg->{to};
      my $dst=$leg->{dst};
      my $az=$leg->{az};
      my $inc=$leg->{inc};
      if ($from eq '---') {
        #this is a fix on the from station
      } else {
        #normal leg
        if (lc($leg->{dir}) eq 'f') {
          #forward, no action required
        } elsif (lc($leg->{dir}) eq 'b') {
          #backsight
          my $j=$to; $to=$from; $from=$j;
        } else {
          &mywarn("Bad direction flag '".$leg->{dir}."' for $from to $to leg, assuming foresight");
        }
        printf $outfh "%s\t%s\t%g\t%g\t%g\n",$from,$to,$dst,$az,$inc;
      }
    }
  }
}

sub mynote {
  my ($level,$msg)=@_;
  if ($debug_level>=$level) {
    warn "$myname: $msg\n";
  }
}

sub mywarn {
  print "$myname: ".join('',@_)."\n";
}

sub mydie {
  &mywarn(@_);
  exit(1);
}

sub usage {
  die "usage: $myname [-h] infile [outfile]
  -f   overwrite existing outfile

  -q   quiet
  -v   verbose
  -V   more verbose

  -h   help.\n";
}
