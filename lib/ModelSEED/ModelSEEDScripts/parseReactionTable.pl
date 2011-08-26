use strict;
use warnings;
use FIGMODEL;
use FIG_Config;

my $figmodel = FIGMODEL->new();

my $db_dir = $figmodel->directory();
my $rxn_file = "ReactionDB/masterfiles/ReactionDatabase.txt";

unless (-e $db_dir.$rxn_file) {
    die "Cannot open: $db_dir$rxn_file\n";
}

open(REACTIONS, $db_dir.$rxn_file) or die $!;

open(REACTIONSOUT, ">common/CGI/Html/reactions.tbl") or die $!;
<REACTIONS>; # throw out headers
while(<REACTIONS>) {
    chomp;
    my @items = split(";");
    my @new_items;

    # 0:DATABASE
    push (@new_items, $items[0]);
    # 1:NAME
    push (@new_items, $items[1]);
    # 2:EQUATION
    push (@new_items, $items[2]);
    # 5:ENZYME
    push (@new_items, $items[5]);
    # 6:PATHWAY
    # push (@new_items, $items[6]);
    # 7:KEGG MAPS
    push (@new_items, $items[7]);
    # 8:REVERSIBILITY
    push (@new_items, $items[8]);
    # 11:KEGGID
    push (@new_items, $items[11]);

    print REACTIONSOUT join (";", @new_items), "\n";
}

close REACTIONS;
close REACTIONSOUT;

exit;
