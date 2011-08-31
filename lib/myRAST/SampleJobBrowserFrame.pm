package SampleJobBrowserFrame;

use SeedV;
use SeedUtils;
use Data::Dumper;
use File::HomeDir;
use File::Basename;
use File::Path;

use myRAST;
use SampleDir;
use SampleAnalysisPanel;
use AnalyzeMGPanel;
use NewSampleFrame;

use Moose;
use MooseX::NonMoose;

use wxPerl::Constructors;
use Wx qw(:sizer :everything);
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX EVT_COMBOBOX EVT_TIMER EVT_LIST_ITEM_ACTIVATED);

extends 'Wx::Frame';

has 'panel' => (is => 'rw',
		isa => 'Object');

has 'sample_list' => (isa => 'Wx::ListCtrl',
		      is  => 'rw');
has 'sample_data' => (isa => 'ArrayRef',
		      is => 'rw');

sub FOREIGNBUILDARGS
{
    my($self, %args) = @_;

    my $title = $args{title};

    return (undef, -1, $title, wxDefaultPosition,
	    (exists($args{size}) ? $args{size} : Wx::Size->new(900,300)));
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
    $self->sample_list($list);
    $top_sz->Add($list, 1, wxEXPAND | wxALL, 5);

    my $bsizer = Wx::BoxSizer->new(wxHORIZONTAL);
    $top_sz->Add($bsizer, 0, wxEXPAND | wxALL, 5);

    my $b = wxPerl::Button->new($panel, "Process new sample");
    $bsizer->Add($b, 0, wxALIGN_LEFT | wxALL, 5);
    EVT_BUTTON($self, $b, sub { $self->process_new_sample(); });

    $b = wxPerl::Button->new($panel, "Open sample");
    $bsizer->Add($b, 0, wxALIGN_RIGHT | wxALL, 5);
    EVT_BUTTON($self, $b, sub { $self->open_sample(); });

    $b = wxPerl::Button->new($panel, "Delete analysis");
    $bsizer->Add($b, 0, wxALIGN_RIGHT | wxALL, 5);
    EVT_BUTTON($self, $b, sub { $self->delete_analysis(); });

    $b = wxPerl::Button->new($panel, "Add analysis");
    $bsizer->Add($b, 0, wxALIGN_RIGHT | wxALL, 5);
    EVT_BUTTON($self, $b, sub { $self->add_analysis(); });

    $b = wxPerl::Button->new($panel, "Cancel");
    $bsizer->Add($b, 0, wxALIGN_RIGHT | wxALL, 5);
    EVT_BUTTON($self, $b, sub { $self->cancel(); });

    #
    # another line of buttons
    #

    $bsizer = Wx::BoxSizer->new(wxHORIZONTAL);
    $top_sz->Add($bsizer, 0, wxEXPAND | wxALL, 5);

    $b = wxPerl::Button->new($panel, "Compute and export all-to-all comparison");
    $bsizer->Add($b, 0, wxALIGN_LEFT | wxALL, 5);
    EVT_BUTTON($self, $b, sub { 
	my @samples = $self->get_selected_samples();
	Wx::App::GetInstance()->export_all_to_all(\@samples);
    });
    
    $b = wxPerl::Button->new($panel, "Display tree of all-to-all comparison");
    $bsizer->Add($b, 0, wxALIGN_LEFT | wxALL, 5);
    EVT_BUTTON($self, $b,
	       sub {
		   my @samples = $self->get_selected_samples();
		   Wx::App::GetInstance()->all_to_all_to_tree(\@samples);
	       });

    $self->load_samples();
    EVT_LIST_ITEM_ACTIVATED($self, $list, sub { $self->open_sample(); } );
    
}

sub load_samples
{
    my($self) = @_;

    my $list = $self->sample_list();
    my @items = myRAST->instance->enumerate_samples();

    $list->ClearAll();

    #
    # What to show, and what the key is.
    #
    my $hsize = 100;
    $hsize = wxLIST_AUTOSIZE_USEHEADER;
    my @cols = (["Name", "name", "Sample data name", wxLIST_AUTOSIZE],
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

    return if @items == 0;

    my $row = 0;
    for my $ent (@items)
    {
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

    $self->sample_data(\@items);
}

#
# Open the selected sample.
sub open_sample
{
    my($self) = @_;

    my $sel = -1;

    while (1)
    {
	$sel = $self->sample_list->GetNextItem($sel, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED);
	last if $sel == -1;

	my $idx = $self->sample_list->GetItemData($sel);
	my $dat = $self->sample_data->[$idx];

	print "Found $sel $idx ", Dumper($dat);

	$self->view_sample($dat);
    }
}
    

sub view_sample
{
    my($self, $data) = @_;

    my $frame = wxPerl::Frame->new(undef, "View sample $data->{name}",
				  size => Wx::Size->new(600,600));
#				  size => Wx::Size->new(800, 1000));

    my $menubar = Wx::App::GetInstance()->default_menubar();
    $frame->SetMenuBar($menubar);

    my $sample = SampleDir->new($data->{dir});

    my $panel = SampleAnalysisPanel->new(parent => $frame,
					 sample => $sample,
					 analysis_dataset => $data->{dataset},
					 analysis_index => $data->{dataset_index},
					);
    $frame->Show();
}

sub add_analysis
{
    my($self) = @_;

    my $sel = -1;

    my @samples;
    while (1)
    {
	$sel = $self->sample_list->GetNextItem($sel, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED);
	last if $sel == -1;

	my $idx = $self->sample_list->GetItemData($sel);
	my $dat = $self->sample_data->[$idx];

	print "Found $sel $idx ", Dumper($dat);

	push(@samples, $dat);
    }

    return if (@samples == 0);

    for my $x (@samples)
    {
	my $fr = wxPerl::Frame->new(undef, "Analyze Sample",
				    size => Wx::Size->new(400,400));
	my $sample = SampleDir->new($x->{dir});
	my $panel = AnalyzeMGPanel->new(parent => $fr,
					sample => $sample);
	
	my $menubar = Wx::App::GetInstance()->default_menubar();
	$fr->SetMenuBar($menubar);
	
	$fr->Show();
    }
}

sub delete_analysis
{
    my($self) = @_;

    my $sel = -1;

    my @samples;
    while (1)
    {
	$sel = $self->sample_list->GetNextItem($sel, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED);
	last if $sel == -1;

	my $idx = $self->sample_list->GetItemData($sel);
	my $dat = $self->sample_data->[$idx];

	print "Found $sel $idx ", Dumper($dat);

	push(@samples, $dat);
    }

    return if (@samples == 0);
    my $msg;
    if (@samples == 1)
    {
	my $x = $samples[0];
	$msg = "Delete analysis $x->{name} $x->{dataset}/$x->{dataset_index}? (This action cannot be undone)";
    }
    else
    {
	my $n = @samples;
	$msg = "Delete $n analyses? (This action cannot be undone)";
    }
    my $dlg = Wx::MessageDialog->new($self, $msg,
				     "Delete sample",
				     wxYES_NO | wxNO_DEFAULT | wxICON_EXCLAMATION);
    my $rc = $dlg->ShowModal();
    
    if ($rc == wxID_YES)
    {
	for my $sample(@samples)
	{
	    my $dir = $sample->{andir};
	    print "Delete sample $sample in $dir\n";
	    if (-d $dir)
	    {
		File::Path::remove_tree($dir);
	    }
	}
	$self->load_samples();
    }
}

sub process_new_sample()
{
    my($self) = @_;

    my $fr = NewSampleFrame->new(title => "myRAST", 
				 size => Wx::Size->new(700,700),
				 job_browser => $self);

    my $menubar = Wx::App::GetInstance()->default_menubar();
    $fr->SetMenuBar($menubar);
    $fr->Show(1);
    
}

sub get_selected_samples
{
    my($self) = @_;

    my $sel = -1;

    my @samples;
    while (1)
    {
	$sel = $self->sample_list->GetNextItem($sel, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED);
	last if $sel == -1;

	my $idx = $self->sample_list->GetItemData($sel);
	my $dat = $self->sample_data->[$idx];

#	print "Found $sel $idx ", Dumper($dat);

	push(@samples, $dat);
    }

    return @samples;
}



1;
