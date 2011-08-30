package GenbankComparisonFrame;

use POSIX;
use SeedUtils;
use Data::Dumper;
use YAML::Any 'LoadFile';

use Moose;
use MooseX::NonMoose;
use List::Util 'first';
use WebBrowser;

use wxPerl::Constructors;
use Wx qw(:sizer :everything);
use Wx::Grid;
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX EVT_COMBOBOX EVT_TIMER EVT_GRID_COL_SIZE EVT_GRID_ROW_SIZE
		 EVT_IDLE EVT_SIZE EVT_GRID_CELL_LEFT_CLICK);

extends 'Wx::Frame';

has "table_file" => (isa => 'Str',
		     is => 'ro',
		     required => 1);

has "summary_file" => (isa => 'Str',
		       is => 'ro',
		       required => 1);

has 'browser' => (isa => 'Browser',
		  is => 'ro');

has 'panel' => (isa => 'Wx::Panel',
		is => 'rw');

has 'genome_id' => (isa => 'Str',
		    is => 'ro');

sub FOREIGNBUILDARGS
{
    my($self, %args) = @_;

    my $title = $args{title};

    return (undef, -1, $title, wxDefaultPosition,
	    (exists($args{size}) ? $args{size} : Wx::Size->new(700, 700)));
};

sub BUILD
{
    my($self) = @_;

    my $panel = wxPerl::Panel->new($self);
    $self->panel($panel);

    my $top_sz = Wx::BoxSizer->new(wxVERTICAL);
    $panel->SetSizer($top_sz);

    my $flex = Wx::FlexGridSizer->new(0, 2, 5, 5);
    $top_sz->Add($flex, 0, wxEXPAND | wxALL, 5);

    my $data = LoadFile($self->summary_file);

    my $tbl_fh;
    if (!open($tbl_fh, "<", $self->table_file))
    {
	Wx::MessageBox("Could not open data table " . $self->table_file . ": $!",
		       "Error");
	return;
    }

    my @to_show = (['Number of pegs in genbank file', 'old_num'],
		   ['Number of pegs in RAST data', 'new_num'],
		   ['Number of pegs with same stop', 'same_stop'],
		   ['Number of new pegs in RAST data', 'added'],
		   ['Number of pegs in Genbank but not RAST', 'lost'],
		   ['Number of pegs with identical size', 'identical'],
		   ['Number of pegs called shorter by RAST', 'short'],
		   ['Number of pegs called longer by RAST', 'long']);
    for my $ent (@to_show)
    {
	my($caption, $key) = @$ent;
	$flex->Add(wxPerl::StaticText->new($panel, $caption));
	$flex->Add(wxPerl::StaticText->new($panel, $data->{$key}));
    }

    #
    # And the grid of detailed data.
    #
    #
    # Scan the input file once to count lines.
    my $n = 0;
    while (<$tbl_fh>)
    {
	$n++;
    }
    seek($tbl_fh, SEEK_SET, 0);
    $n--;
    
    my $grid = Wx::Grid->new($panel, -1);

    my @col_hdrs = ("Comparison", "Feature ID", "Function", "Genbank Function", "Gene ID", "Genbank ID");


    $top_sz->Add($grid, 1, wxEXPAND | wxALL, 5);
    $grid->CreateGrid($n, scalar @col_hdrs);
    my $col = 0;
    for my $lbl (@col_hdrs)
    {
	$grid->SetColLabelValue($col++, $lbl);
    }

    my $font = Wx::Font->new($grid->GetCellFont(0, 0));
    $font->SetUnderlined(1);

    my $key_data = <$tbl_fh>;
    $key_data =~ s/^#//;
    chomp $key_data;
    my(@keys) = split(/\t/, $key_data);
    my %col_idx;
    for my $i (0..$#keys)
    {
	$col_idx{$keys[$i]} = $i;
    }
    my @col_data = map { $col_idx{$_} } qw(Comparison New_ID New_Function Old_Function Old_ID Old_Alt_IDs);
    my %wrap_cols = map { $_ => 1 } (2, 3);

    my $row = 0;

    my $peg_col = $col_idx{New_ID};
    my $gi_col = $col_idx{Old_Alt_IDs};
    my %link_cols = (1 => 1, 5 => 1);

    my $my_genome = $self->genome_id;
    while (<$tbl_fh>)
    {
	chomp;
	my @dat = split(/\t/);

	if (defined($my_genome))
	{
	    $dat[$peg_col] =~ s/^fig\|$my_genome\.//;
	}

	if (defined($dat[$gi_col]) && $dat[$gi_col] ne '')
	{
	    my @alts = split(/,/, $dat[$gi_col]);
	    my $gi = first { /^GI:/ } @alts;
	    if (defined($gi) && $gi =~ /^GI:(\d+)/)
	    {
		$dat[$gi_col] = $1;
	    }
	}

	my $col = 0;
	for my $colnum (@col_data)
	{
	    my $val = $dat[$colnum];

	    $grid->SetCellValue($row, $col, $val);
	    $grid->SetReadOnly($row, $col);

	    if ($wrap_cols{$col})
	    {
		$grid->SetCellRenderer($row, $col, Wx::GridCellAutoWrapStringRenderer->new);
	    }

	    if ($link_cols{$col})
	    {
		$grid->SetCellFont($row, $col, $font);
		$grid->SetCellTextColour($row, $col, wxBLUE);
	    }

	    $col++;
	}
	$row++;
    }
    close($tbl_fh);

    $grid->AutoSizeColumn(2);
    $grid->AutoSizeColumn(3);
    $grid->AutoSizeColumn(4);
    $grid->AutoSizeColumn(5);

    $grid->SetRowLabelSize(0);

    EVT_GRID_COL_SIZE($grid, sub {
	print "Column resized\n";
	$grid->AutoSizeRows();
    });

    $grid->AutoSizeRows();

    EVT_GRID_CELL_LEFT_CLICK($grid, sub {
	my($x, $evt) = @_;
	my $r = $evt->GetRow();
	my $c = $evt->GetCol();
	my $txt = $grid->GetCellValue($r, $c);

	print "dclick $r $c $txt\n";

	#
	# Hardcoded column numbers here.
	#


	if ($c == 1) # RAST id
	{
	    $self->show_local_id($txt);
	}
	elsif ($c == 5) # Genbank ID
	{
	    $self->show_genbank_id($txt);
	}
	       
    });
}

sub show_local_id
{
    my($self, $txt) = @_;
    if ($txt !~ /^fig\|/)
    {
	$txt = "fig|" . $self->genome_id . "." . $txt;
    }
    print "Setting peg to '$txt'\n";
    $self->browser->set_peg($txt);
}

sub show_genbank_id
{
    my($self, $id) = @_;

    my $url = "http://www.ncbi.nlm.nih.gov/protein/$id";
    WebBrowser::open($url);
}


1;
