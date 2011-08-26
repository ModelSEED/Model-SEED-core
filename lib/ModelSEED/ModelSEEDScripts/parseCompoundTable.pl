use strict;
use warnings;
use FIGMODEL;
use FIG_Config;

my $figmodel = FIGMODEL->new();

my $db_dir = $figmodel->directory();
my $cpd_file = "ReactionDB/masterfiles/CompoundDatabase.txt";

my $map_data = $figmodel->database()->GetDBTable('Map data');

unless (-e $db_dir.$cpd_file) {
    die "Cannot open: $db_dir$cpd_file\n";
}

my $row = 0;

open(COMPOUNDS, $db_dir.$cpd_file) or die $!;
open(COMPOUNDSOUT, ">common/CGI/Html/compounds.tbl") or die $!;
while(<COMPOUNDS>) {
    chomp;
    my @items = split(";");
    my @new_items;

    # 0:DATABASE
    push (@new_items, $items[0]);
    # 1:NAME
    push (@new_items, $items[1]);
    # 2:FORMULA
    push (@new_items, $items[2]);
    # 6:MASS
    push (@new_items, $items[6]);
    # 9:KEGGID
    push (@new_items, $items[9]);
    # 11:MODELID
    push (@new_items, $items[11]);

    my @map_rows = $map_data->get_rows_by_key( $items[0], "COMPOUNDS" );
    my @map_ids;
    map {push(@map_ids, $_->{'ID'}->[0])} @map_rows;

    # KEGGMAPS
    if ($row == 0) {
	push(@new_items, 'KEGG MAPS');
    } else {
	push(@new_items, join("|", @map_ids));
    }

    print COMPOUNDSOUT join (";", @new_items), "\n";
    $row++;
}

close COMPOUNDS;
close COMPOUNDSOUT;

exit;
