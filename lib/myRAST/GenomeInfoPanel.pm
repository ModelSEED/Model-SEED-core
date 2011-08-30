package GenomeInfoPanel;

use SeedUtils;
use Data::Dumper;
use SeedV;

use Moose;
use MooseX::NonMoose;

use wxPerl::Constructors;
use Wx::Grid;
use Wx qw(:sizer :everything);
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX EVT_COMBOBOX EVT_TIMER EVT_GRID_COL_SIZE EVT_GRID_ROW_SIZE
		 EVT_IDLE EVT_SIZE EVT_GRID_CELL_LEFT_DCLICK);

extends 'Wx::Panel';

=head1 NAME

GenomeInfoPanel - general info about a genome

=cut

has 'org_dir' => (is => 'rw',
		  isa => 'Str',
		  required => 1);

has 'fig' => (is => 'rw',
	      isa => 'SeedV',
	      required => 1,
	      lazy => 1,
	      builder => '_make_fig');

has 'panel' => (is => 'rw',
		isa => 'Object');

sub FOREIGNBUILDARGS
{
    my($self, %args) = @_;

    return ($args{parent}, -1);
};

sub BUILD
{
    my($self) = @_;

    my $top_sz = Wx::BoxSizer->new(wxVERTICAL);

    $self->SetSizer($top_sz);
    $top_sz->SetSizeHints($self);

    my $fig = $self->fig;

    my $bold_font = Wx::Font->new(24, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_BOLD);
    my $gs = $fig->genus_species();
    my $id = $fig->genome_id();
    print "$gs $id\n";

    my $title = wxPerl::StaticText->new($self, join(" ", $gs, $id),
					style => wxALIGN_CENTRE);
    $title->SetFont($bold_font);
    $top_sz->Add($title, 0, wxEXPAND);

    my $stats = $fig->get_basic_statistics();

    $top_sz->Add(wxPerl::StaticText->new($self, "$stats->{genome_pegs} pegs"));
    $top_sz->Add(wxPerl::StaticText->new($self, "$stats->{genome_rnas} rnas"));
    $top_sz->Add(wxPerl::StaticText->new($self, "$stats->{num_contigs} contigs"));
    $top_sz->Add(wxPerl::StaticText->new($self, "$stats->{num_basepairs} bp"));
    $top_sz->Add(wxPerl::StaticText->new($self, "Located $stats->{num_subsystems} subsystems"));

#    my $peg_list = wxPerl::ListCtrl->new($self,
#					 style => wxLC_REPORT);
#    $top_sz->Add($peg_list, 1, wxEXPAND);

    my $peg_grid = Wx::Grid->new($self, -1);
    $top_sz->Add($peg_grid, 1, wxEXPAND);
    
    my $features = $fig->all_features_detailed_fast();
    $#$features = 10;

    $peg_grid->CreateGrid(scalar @$features, 5);

    push(@$_, SeedUtils::parse_location($_->[1])) for @$features;

    my $col = 0;
    $peg_grid->SetColLabelValue($col++, "Feature ID");
    $peg_grid->SetColLabelValue($col++, "Function");
    $peg_grid->SetColLabelValue($col++, "Contig");
    $peg_grid->SetColLabelValue($col++, "Start");
    $peg_grid->SetColLabelValue($col++, "Stop");

    my $wrapper = Wx::GridCellAutoWrapStringRenderer->new;

    my $font = Wx::Font->new($peg_grid->GetCellFont(0, 0));
    $font->SetUnderlined(1);

    my $row = 0;
    for my $fent (sort { $a->[9] cmp $b->[9] or $a->[4] <=> $b->[4] } @$features)
    {
	my($id, $loc, undef, $type, $beg, $end, $func, $who, $conf, $contig, $xbegin, $xend, $strand) = @$fent;

	my $col = 0;

	$peg_grid->SetCellRenderer($row, $col, Wx::GridCellAutoWrapStringRenderer->new);
	$peg_grid->SetCellValue($row, $col, $id);
	$peg_grid->SetCellFont($row, $col, $font);
	$peg_grid->SetCellTextColour($row, $col, wxBLUE);
	$col++;


	$peg_grid->SetCellRenderer($row, $col, Wx::GridCellAutoWrapStringRenderer->new);
	$peg_grid->SetCellValue($row, $col++, $func ? $func : "");
	
	$peg_grid->SetCellValue($row, $col++, $contig);
	$peg_grid->SetCellValue($row, $col++, $xbegin);
	$peg_grid->SetCellValue($row, $col++, $xend);

	$peg_grid->SetReadOnly($row, $_) for 0..$col-1;
	$row++;
    }

    EVT_GRID_CELL_LEFT_DCLICK($peg_grid, sub {
	my($x, $evt) = @_;
	my $r = $evt->GetRow();
	my $c = $evt->GetCol();
	my $txt = $peg_grid->GetCellValue($r, $c);
	print "dclick $r $c $txt\n";
    });


    EVT_GRID_COL_SIZE($peg_grid, sub {
	print "Column resized\n";
	$peg_grid->AutoSizeRows();
    });

    $peg_grid->AutoSizeRows();

#    $peg_grid->SetColSize(0, 400);
    $peg_grid->AutoSizeColumn(0);
    $peg_grid->AutoSizeColumn(1);

    my $x = EVT_IDLE($self, sub {
	print "On idle\n";
	$peg_grid->AutoSizeRows();
	EVT_IDLE($self, undef);
    });
    print Dumper($x);
    

#     $peg_list->InsertColumn(0, "PEG");
#     $peg_list->InsertColumn(1, "Function");
#     $peg_list->InsertColumn(2, "Contig");
    
#     print Dumper($features->[0]);
#     my $row = 0;
#     for my $fent (sort { $a->[9] cmp $b->[9] or $a->[4] <=> $b->[4] } @$features)
#     {
# 	my($id, $loc, undef, $type, $beg, $end, $func, $who, $conf, $contig, $xbegin, $xend, $strand) = @$fent;
# 	$peg_list->InsertStringItem($row, $id);
# 	$peg_list->SetItem($row, 1, $func ? $func : "");
# 	$peg_list->SetItem($row, 2, $contig);
# 	$row++;
#     }

#     $peg_list->SetColumnWidth(1, wxLIST_AUTOSIZE);
#     $peg_list->SetColumnWidth(2, wxLIST_AUTOSIZE);
    
}

sub _make_fig
{
    my($self) = @_;
    return SeedV->new($self->org_dir);
}

1;
