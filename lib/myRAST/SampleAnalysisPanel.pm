package SampleAnalysisPanel;

use Moose;

extends 'ParamPanel';

use File::Copy;

use VectorCompareFrame;
use AnalyzeMGPanel;

use Data::Dumper;
use POSIX;
use wxPerl::Constructors;
use Wx qw(:sizer :everything);
use Wx::Grid;
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX EVT_COMBOBOX EVT_TIMER EVT_GRID_COL_SIZE EVT_GRID_ROW_SIZE
		 EVT_IDLE EVT_SIZE EVT_GRID_CELL_LEFT_CLICK EVT_GRID_CELL_CHANGE);

has 'sample' => (is => 'ro',
		 isa => 'SampleDir',
		 required => 1);

has 'analysis_dataset' => (is => 'ro',
			   isa => 'Str',
			   required => 1);

has 'analysis_index' => (is => 'ro',
			 isa => 'Num',
			 required => 1);

has 'analysis' => (is => 'rw',
		   isa => 'SampleAnalysis');

has 'fn_grid' => (is => 'rw',
		  isa => 'Maybe[Wx::Grid]');

has 'otu_grid' => (is => 'rw',
		   isa => 'Maybe[Wx::Grid]');

has 'need_resize_update' => (is => 'rw',
			     isa => 'Bool',
			     default => 0);

has 'need_analysis_update' => (is => 'rw',
			       isa => 'Bool',
			       default => 0);

has 'update_analysis_button' => (is => 'rw',
				 isa => 'Wx::Button');
				 
sub BUILD
{
    my($self) = @_;

    my $analysis = $self->sample->get_analysis($self->analysis_dataset, $self->analysis_index);
    $self->analysis($analysis);

    my $stats = $self->sample->get_statistics();
    $self->add_param_static("Sample count:", 'sample_count', $stats->{count});
    $self->add_param_static("DNA size:", 'dna_size', $stats->{total_size});
    $self->add_param_static("Min size:", 'min_size', $stats->{min});
    $self->add_param_static("Max size:", 'max_size', $stats->{max});
    $self->add_param_static("Median size:", 'median_size', sprintf("%.1f", $stats->{median}));
    $self->add_param_static("Mean size:", 'mean_size', sprintf("%.1f", $stats->{mean}));
    $self->add_param_static("GC content:", 'gc_content', sprintf("%.1f%%", $stats->{gc_content}));

    my $params = $analysis->get_parameters();
    my $sum = $analysis->get_summary();

    if ($params)
    {
	$self->param_sizer->AddSpacer(5);
	$self->param_sizer->AddSpacer(5);
	$self->add_param_static("Kmer size", 'kmer', $params->{-kmer});
	$self->add_param_static("Max gap", 'max_gap', $params->{-maxGap});
	$self->add_param_static("Min hits", 'min_hits', $params->{-minHits});
    }

    if ($sum && %$sum)
    {
	$self->param_sizer->AddSpacer(5);
	$self->param_sizer->AddSpacer(5);

	$self->add_param_static("# distinct functions", 'fns', $sum->{distinct_functions});
	$self->add_param_static("# distinct OTUs", 'otus', $sum->{distinct_otus});
	$self->add_param_static("# hits with function", 'hits_with_function', $sum->{hits_with_function});
	$self->add_param_static("# hits with otu", 'hits_with_otu', $sum->{hits_with_otu});
	$self->add_param_static("Elapsed time", 'time', sprintf("%.1f sec", $sum->{elapsed_time}));
    }

    EVT_SIZE($self, sub {
	my($obj, $evt) = @_;
	$self->need_resize_update(1);
	$evt->Skip();
    } );
    EVT_IDLE($self, sub {
	if ($self->need_resize_update)
	{
	    $self->need_resize_update(0);
	    $self->update_list_size();
	}
    }
    );

    EVT_GRID_CELL_CHANGE($self, \&cell_changed);

    my $bbar = Wx::BoxSizer->new(wxHORIZONTAL);
    $self->top_sizer->Add($bbar, 0, wxEXPAND);

    my $compare_fn = wxPerl::Button->new($self, "Compare function vectors");
    EVT_BUTTON($self, $compare_fn, sub { $self->compare_function_vectors(); });

    $bbar->Add($compare_fn);

    my $compare_otu = wxPerl::Button->new($self, "Compare OTU vectors");
    EVT_BUTTON($self, $compare_otu, sub { $self->compare_otu_vectors(); });

    $bbar->Add($compare_otu);

    $bbar = Wx::BoxSizer->new(wxHORIZONTAL);
    $self->top_sizer->Add($bbar, 0, wxEXPAND);

    my $b = wxPerl::Button->new($self, "Create new analysis");
    EVT_BUTTON($self, $b, sub { $self->new_analysis(); });
    $bbar->Add($b);
    
    $b = wxPerl::Button->new($self, "Update analysis with new exclusions");
    EVT_BUTTON($self, $b, \&update_analysis);
    $b->Enable(0);
    $bbar->Add($b);
    $self->update_analysis_button($b);

    $b = wxPerl::Button->new($self, "Clear all exclusions");
    EVT_BUTTON($self, $b, \&clear_exclusions);
    $bbar->Add($b);

    $b = wxPerl::Button->new($self, "View exclusions");
    EVT_BUTTON($self, $b, \&view_exclusions);
    $bbar->Add($b);

    $bbar = Wx::BoxSizer->new(wxHORIZONTAL);
    $self->top_sizer->Add($bbar, 0, wxEXPAND);

    $b = wxPerl::Button->new($self, "Export function summary");
    EVT_BUTTON($self, $b, \&export_functions);
    $bbar->Add($b);
    
    $b = wxPerl::Button->new($self, "Export OTU summary");
    EVT_BUTTON($self, $b, \&export_otus);
    $bbar->Add($b);

    my $nb = wxPerl::Notebook->new($self);

    my $busy = Wx::BusyCursor->new();

    my $fn_grid = $self->load_function_grid($nb);
    $self->fn_grid($fn_grid);
    
    my $otu_grid = $self->load_otu_grid($nb);
    $self->otu_grid($otu_grid);

    $nb->AddPage($fn_grid, "Function summary") if $fn_grid;
    $nb->AddPage($otu_grid, "OTU summary") if $otu_grid;

    $self->top_sizer->Add($nb, 1, wxEXPAND);

    $self->top_sizer->Layout();
    $self->need_resize_update(1);
}

sub export_functions
{
    my($self) = @_;

    my $dlg = Wx::FileDialog->new($self, "Export functions to file", "",
				  "", "*.*", wxFD_SAVE);
    my $rc = $dlg->ShowModal();

    if ($rc == wxID_OK)
    {
	my $file = $dlg->GetPath();
	print "Save to $file\n";
	copy($self->analysis->get_function_file, $file);
    }
}

sub export_otus
{
    my($self) = @_;

    my $dlg = Wx::FileDialog->new($self, "Export OTUs to file", "",
				  "", "*.*", wxFD_SAVE);
    my $rc = $dlg->ShowModal();

    if ($rc == wxID_OK)
    {
	my $file = $dlg->GetPath();
	print "Save to $file\n";
	copy($self->analysis->get_otu_file, $file);
    }
}

sub cell_changed
{
    my($self, $evt) = @_;
    print "Cell changed ", Dumper($evt);
    if (!$self->need_analysis_update)
    {
	$self->need_analysis_update(1);
	$self->update_analysis_button->Enable(1);
    }
}

sub compare_function_vectors
{
    my($self) = @_;

    my @res = myRAST->instance->compare_samples_function($self->analysis);
    my $fr = VectorCompareFrame->new(vector_data => \@res);
    $fr->Show(1);
    
}

sub compare_otu_vectors
{
    my($self) = @_;

    my @res = myRAST->instance->compare_samples_otu($self->analysis);
    my $fr = VectorCompareFrame->new(vector_data => \@res);
    $fr->Show(1);
    
}

#
# Update the analysis based on a changed exclusion list.
#
sub update_analysis
{
    my($self) = @_;

    #
    # Update the exclusions hash.
    #

    my %excl;

    my $analysis = $self->analysis;
    my $grid = $self->fn_grid;
    
    for (my $i = 0; $i < $grid->GetNumberRows(); $i++)
    {
	my $ex = $grid->GetCellValue($i, 0);
	if ($ex)
	{
	    my $fn = $grid->GetCellValue($i, 3);
	    $excl{$fn} = 1;
	}
    }

    my $p = $analysis->get_parameters;

    %{$p->{excluded_functions}} = %excl;

    $analysis->save_parameters();
    $analysis->rerun_analysis();

    $self->show_new_window();
    $self->GetParent()->Destroy();
}

sub show_new_window
{
    my($self) = @_;

    #
    # bring up new window
    #

    my $analysis = $self->analysis;
    my $frame = wxPerl::Frame->new(undef, "View sample " . $analysis->sample->name(),
				  size => Wx::Size->new(600,600));
#				  size => Wx::Size->new(800, 1000));

    my $menubar = Wx::App::GetInstance()->default_menubar();
    $frame->SetMenuBar($menubar);

    my $sample = SampleDir->new($analysis->sample->dir);
    my $panel = SampleAnalysisPanel->new(parent => $frame,
					 sample => $sample,
					 analysis_dataset => $analysis->dataset(),
					 analysis_index => $analysis->index()
					);
    $frame->Show();
}

sub clear_exclusions
{
    my($self) = @_;
    my $p = $self->analysis->get_parameters;

    %{$p->{excluded_functions}} = ();

    $self->analysis->save_parameters();
    $self->analysis->rerun_analysis();
    $self->show_new_window();
    $self->GetParent()->Destroy();
}

sub view_exclusions
{
    my($self) = @_;
    my $ex = $self->analysis->get_parameters->{excluded_functions};
    my $dlg = Wx::MessageDialog->new($self,
				     join("\n", sort keys %$ex),
				     "Excluded functions");
    $dlg->ShowModal();
}

sub new_analysis
{
    my($self) = @_;

    my $fr = wxPerl::Frame->new(undef, "Analyze Sample",
				size => Wx::Size->new(400,400));
    my $panel = AnalyzeMGPanel->new(parent => $fr,
				    sample => $self->sample);

    my $menubar = Wx::App::GetInstance()->default_menubar();
    $fr->SetMenuBar($menubar);

    $fr->Show();
    
}

sub load_function_grid
{
    my($self, $parent) = @_;
    my $fh;

    return $self->load_grid($parent, $self->analysis->get_function_file,
			    ["Filtered", "Count", "Fraction", "Function"],
			    -showFilters => 1);
}

sub load_otu_grid
{
    my($self, $parent) = @_;
    my $fh;

    return $self->load_grid($parent, $self->analysis->get_otu_file,
			    ["Count", "Fraction", "OTU"]);
}

sub load_grid
{
    my($self, $parent, $file, $col_hdrs, %opts) = @_;
    
    my $fh;
    if (!open($fh, "<", $file))
    {
	return undef;
    }

    my $n = 0;
    while (<$fh>)
    {
	$n++;
    }
    seek($fh, SEEK_SET, 0);

    my $grid = Wx::Grid->new($parent, -1);

    $grid->CreateGrid($n, scalar @$col_hdrs);

    my $col = 0;
    for my $lbl (@$col_hdrs)
    {
	$grid->SetColLabelValue($col++, $lbl);
    }

#    $n = 10;
    print "Load $n values\n";
    my $row = 0;

    my $offset = 0;
    if ($opts{-showFilters})
    {
	$grid->SetColFormatBool(0);
	$offset = 1;
    }

    my $prog = Wx::ProgressDialog->new("Load data",
				       "Load " . $col_hdrs->[$offset + 2] . " data",
				       $n);

    my $exclusions = $self->analysis->get_parameters->{excluded_functions};
    
    while (<$fh>)
    {
	chomp;
	my($count, $frac, $fn) = split(/\t/);

	if ($opts{-showFilters})
	{
	    $grid->SetCellValue($row, 0, defined($exclusions->{$fn}));
	    $grid->SetCellEditor($row, 0, Wx::GridCellBoolEditor->new);
	    $grid->SetCellRenderer($row, 0, Wx::GridCellBoolRenderer->new);
	}

	$grid->SetCellValue($row, $offset, $count);
	$grid->SetCellValue($row, $offset + 1, $frac);
	$grid->SetCellValue($row, $offset + 2, $fn);
	$grid->SetCellRenderer($row, $offset + 2, Wx::GridCellAutoWrapStringRenderer->new);
	$grid->SetReadOnly($row, $_) for $offset .. $offset + 2;
	$row++;

	$prog->Update($row) if $row % 100 == 0;

	last if $row >= $n;
    }

    $prog->Destroy();

    $grid->SetRowLabelSize(0);
    $grid->AutoSizeRows();

    close($fh);

    print "returning $grid\n";
    return $grid;
}

sub update_list_size
{
    my($self) = @_;
    my $sz = $self->GetClientSize();
    print $sz->width,  " ", $sz->height, "\n";
    for my $ent ([$self->fn_grid, 1],
		 [$self->otu_grid, 0])
    {
	my($grid, $offset) = @$ent;
	next unless defined($grid);
	print "grid=$grid fng=", $self->fn_grid, " offset=$offset\n";
	$grid->AutoSizeRows();
	my $c1 = $grid->GetColSize($offset);
	my $c2 = $grid->GetColSize($offset + 1);
#	print "c1=$c1 c2=$c2\n";
	$grid->SetColSize($offset + 2, $sz->width - ($c1 + $c2) - 30);
	$grid->FitInside();
    }
}

1;
