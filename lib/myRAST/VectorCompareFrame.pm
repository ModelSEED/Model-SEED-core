package VectorCompareFrame;

use SeedV;
use SeedUtils;
use SampleAnalysisPanel;

use Data::Dumper;

use Moose;
use MooseX::NonMoose;

use wxPerl::Constructors;
use Wx qw(:sizer :everything);
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX EVT_COMBOBOX EVT_TIMER EVT_LIST_ITEM_ACTIVATED);

extends 'Wx::Frame';

has 'vector_data' => (is => 'rw',
		      isa => 'ArrayRef');

has 'result_list' => (is => 'rw',
		      isa => 'Wx::ListCtrl');

has 'panel' => (is => 'rw',
		isa => 'Object');

sub FOREIGNBUILDARGS
{
    my($self, %args) = @_;

    my $title = $args{title};

    return (undef, -1, $title, wxDefaultPosition,
	    (exists($args{size}) ? $args{size} : Wx::Size->new(600,300)));
};

sub BUILD
{
    my($self) = @_;

    my $panel = wxPerl::Panel->new($self);
    $self->panel($panel);

    my $top_sz = Wx::BoxSizer->new(wxVERTICAL);

    $panel->SetSizer($top_sz);
    # $top_sz->SetSizeHints($self);

    my $list = wxPerl::ListCtrl->new($panel,
				     style => wxLC_REPORT);
    $self->result_list($list);
    $top_sz->Add($list, 1, wxEXPAND | wxALL, 5);

    EVT_LIST_ITEM_ACTIVATED($self, $list, sub { $self->open_sample(); } );
    
    $self->load_data();
}

#
# Open the selected sample.
sub open_sample
{
    my($self) = @_;

    my $sel = -1;

    while (1)
    {
	$sel = $self->result_list->GetNextItem($sel, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED);
	last if $sel == -1;

	my $idx = $self->result_list->GetItemData($sel);
	my $dat = $self->vector_data->[$idx];

	$self->view_sample($dat);
    }
}
    

sub view_sample
{
    my($self, $data) = @_;

    my $frame = wxPerl::Frame->new(undef, "View sample $data->{name}",
				  size => Wx::Size->new(600,600));
#				  size => Wx::Size->new(800, 1000));

    my $sample = SampleDir->new($data->{dir});

    my $panel = SampleAnalysisPanel->new(parent => $frame,
					 sample => $sample,
					 analysis_dataset => $data->{dataset},
					 analysis_index => $data->{dataset_index},
					);
    $frame->Show();
}

sub load_data
{
    my($self) = @_;

    my $list = $self->result_list();
    my $data = $self->vector_data;

    #
    # What to show, and what the key is.
    #
    my $hsize = 100;
    $hsize = wxLIST_AUTOSIZE_USEHEADER;
    my @cols = (["Score", "score", "Comparison score", $hsize],
		["Name", "name", "Sample data name", wxLIST_AUTOSIZE],
		["Size", "total_size", "Size of uploaded sample DNA", wxLIST_AUTOSIZE],
		["Dataset", "dataset", "Kmer dataset used to process sample", wxLIST_AUTOSIZE],
		["Kmer size", "kmer", "Kmer size used to process sample", $hsize],
		["Max gap", "max_gap", "Maximum gap parameter used to process sample", $hsize],
		["Min hits", "min_hits", "Minimum hits parameter used to process sample", $hsize],
		["Num func hits", "hits_with_function", "Number of samples that were assigned a function", $hsize],
		["Num OTU hits", "hits_with_otu", "Number of samples that were assigned an OTU", $hsize],
		["Data dir", "dir", "", wxLIST_AUTOSIZE],
		);

    for my $i (0..$#cols)
    {
	$list->InsertColumn($i, $cols[$i]->[0]);
    }

    my $row = 0;
    for my $ent (@$data)
    {
	$ent->{score} = sprintf("%.3f", $ent->{score});
	$list->InsertStringItem($row, $ent->{$cols[0]->[1]});
	for my $col (1..$#cols)
	{
	    my $val = $ent->{$cols[$col]->[1]};
	    $val = "" unless defined($val);
	    $list->SetItem($row, $col, $val);
	}
	$list->SetItemData($row, $row);
	$row++;
    }

    my $item = $list->GetItem(0);
    my $font = $item->GetFont();
    print "font=$font\n";
    my $dc = Wx::MemoryDC->new();
    my $bitmap = Wx::Bitmap->new(100,100);
    $dc->SelectObject($bitmap);

    for my $i (0..$#cols)
    {
	my $w = $cols[$i]->[3];
	if ($w == wxLIST_AUTOSIZE_USEHEADER)
	{
	    my($tw, $th, $desc, $lead) = $dc->GetTextExtent($cols[$i]->[0]);
	    $w = $tw + 20;
	}
	$list->SetColumnWidth($i, $w);
    }
}

1;
