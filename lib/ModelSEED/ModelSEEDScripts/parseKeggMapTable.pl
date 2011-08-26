use strict;
use warnings;
use FIGMODEL;
use FIG_Config;

my $figmodel = FIGMODEL->new();

my $db_dir = $figmodel->directory();
my $map_file = "ReactionDB/masterfiles/MapDataTable.txt";

unless (-e $db_dir.$map_file) {
    die "Cannot open: $db_dir$map_file\n";
}

open(MAPS, $db_dir.$map_file) or die $!;

open(MAPSOUT, ">common/CGI/Html/keggmap.tbl") or die $!;
<MAPS>; # throw out headers
while(<MAPS>) {
    chomp;
    my @items = split(";");
    my @new_items;

    # skip maps with no compounds and no reactions
    next if (($items[2] eq '') && ($items[3] eq ''));

    # 0:ID
    push (@new_items, $items[0]);
    # 1:NAME
    push (@new_items, $items[1]);
    # 2:REACTIONS
    push (@new_items, $items[2]);
    # 3:COMPOUNDS
    push (@new_items, $items[3]);
    # 4:ECS
    push (@new_items, $items[4]);

    print MAPSOUT join (";", @new_items), "\n";
}

close MAPS;
close MAPSOUT;

exit;
