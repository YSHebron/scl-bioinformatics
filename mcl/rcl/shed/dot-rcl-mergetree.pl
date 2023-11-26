#!/usr/bin/perl

# - reads the .joindot file that can optionally be made rcl-res.pl
# -- this describes the full tree, so only usable for small examples.
# It kind of works on the Falkner graph.
#
# - can optionally read levels, and will merge all non-sink nodes in the bands
# between the levels; these levels are read from RCL_DOT_TREE_LEVELS
# if it is defined. (TODO ensure/check that first level exceeds highest v)
#
# If RCL_DOT_TREE_HEADER is defined it is taken to be the name of
# a file to include as header.
# If RCL_DOT_TREE_ANNOT is defined it is taken to be the name of
# a file with annotation for tree nodes.

# TODO: might this script just as well read .join-order ?
# It builds enough of a tree internally.
#

use strict;
use warnings;

my %levels = ();
my @input  = ();

while (<>) {
  chomp;
  my ($p, $c, $v, $Nc) = split "\t";
  $levels{$v}++;
  push @input, [ $p, $c, $v ];
}

my @levels = map { $_ + 0.01 } sort { $b <=> $a } keys %levels;
if (defined($ENV{RCL_DOT_TREE_LEVELS})) {
	@levels = split /\s+/, $ENV{RCL_DOT_TREE_LEVELS};
}
push @levels, 0 unless $levels[-1] == 0;

# rcl fa2: @levels = qw(990 950 940 925 920 895 875 850 825 805 750 715 685 635 600 570 530 480 435 380 350 300 260 190 130 95 50 23 0);
# ucl fa2: @levels = qw(970 950 920 870 850 800  780 750 700 680 640 600 570 530  450  400 330 250  0);


my $curlevel = 0;
my %joins = ();			# join certain nodes together, based on level.

for my $it (sort { $b->[2] <=> $a->[2] } @input) {
  my ($p, $c, $v) = @$it;
  $curlevel++ while ($v < $levels[$curlevel]);
  push @{$joins{$levels[$curlevel]}}, [ $p, $c ];
}

my @dotprintlevels = map { "lev$_" } 0..(@levels-1);
push @dotprintlevels, map
  { my $i=$_;my $j=$i+1; my $d=sprintf("%.2f",(($levels[$i]-$levels[$j])/50));
    $d = 1 if $d < 1;
    "lev$j -> lev$i [minlen=$d]"
  } 0..(@levels-2);

print "digraph g {\n";


if (defined($ENV{RCL_DOT_TREE_HEADER})) {
  print STDERR "including header file $ENV{RCL_DOT_TREE_HEADER}\n";
  system "cat $ENV{RCL_DOT_TREE_HEADER}";
}
else {
print <<EOH;
  node [shape="circle", width=0.20, fixedsize=true, label="" ];
    edge [arrowhead=none]
    ranksep = 0.2;
    nodesep = 0.1;
EOH
}

{ local $" = ";\n";
print <<EOT;
    subgraph levels {
      label="levels";
      node [style="invis", shape=point, width=0.01];
      edge [style="invis"];
@dotprintlevels
    }
    subgraph tree {
EOT
}


if (defined($ENV{RCL_DOT_TREE_ANNOT})) {
  print STDERR "including annotation file $ENV{RCL_DOT_TREE_ANNOT}\n";
  system "cat $ENV{RCL_DOT_TREE_ANNOT}";
}
else {
  print qq{node [ style=filled, color="#999999" ];\n};
}



for my $v (sort {$b <=> $a} keys %joins) {

  my @edges = @{$joins{$v}};
  my $ne = @edges;
print STDERR "HAVE $ne edges at level $v\n";
  my %c2p = ();
  my %isparent = ();

  my $level = 0;
  $level++ while $levels[$level] > $v;

  for my $e (@edges) {
    $c2p{$e->[1]} = $e->[0];
    $isparent{$e->[0]} = 1;
  }

  my @sinks = ();
  my @leafnodes = grep { !defined($isparent{$_}) } keys %c2p;

  for my $c (@leafnodes) {
    my $p = $c2p{$c};
    $p = $c2p{$p} while defined($c2p{$p});
    print "$p -> $c;\n";
    push @sinks, $p;
  }
  local $" = ' ';
  print "{ rank = same; lev$level @sinks; }\n";
}

print "}}\n";


__DATA__

make connected components
  find the top of each (grandparent); this will be the representative.
    link all leaves in the component to the representative, remove the intermediates.
    everything keeps its name.

