#!/usr/bin/perl
#
use strict;

use Compass qw(&compassReadPage);
use Survex qw(&survexWritePage);

my $lineNum=0;
my $pageNum=0;
my $status;
while (1) {
  my $pageptr;
  ($status,$lineNum,$pageNum,$pageptr)=&compassReadPage($lineNum,$pageNum);
  last if ($status);
  warn "Read page $pageNum (line $lineNum)\n"; 
  &dumpPage($pageNum,$pageptr);
  &survexWritePage($pageNum,$pageptr);
}
print "Status = $status\n";



sub dumpPage {
  my ($pageNum,$pageptr)=@_;
  my ($globalsptr,$linesptr)=@$pageptr;
  print "-------------------------------------------\nPage $pageNum\n";
  print "Globals:\n";
  foreach my $key (sort keys %$globalsptr) {
    print "      $key\t".$globalsptr->{$key}."\n";
  }
  print "Lines:\n";
  foreach my $lptr (@$linesptr) {
    my ($lineNum,$cmd,$argsptr)=@$lptr;
    my @args=();
    foreach my $a (sort keys %$argsptr) {
      push(@args,"$a=".$argsptr->{$a});
    }
    print sprintf("%5d",$lineNum)." $cmd\t".join(' ',@args)."\n";
  }
  print "\n";
}
