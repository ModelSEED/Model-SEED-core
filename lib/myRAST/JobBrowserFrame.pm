package JobBrowserFrame;

use SeedV;
use SeedUtils;
use Data::Dumper;
use File::HomeDir;
use File::Basename;
use File::Path;
use Browser;
use ProteinPanel;
use DesktopRast;
use DesktopRastFrame;

use Moose;
use MooseX::NonMoose;

use wxPerl::Constructors;
use Wx qw(:sizer :everything);
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX EVT_COMBOBOX EVT_TIMER EVT_LIST_ITEM_ACTIVATED);

extends 'Wx::Frame';

has 'menubar' => (is => 'rw',
		  isa => 'Wx::MenuBar');

has 'panel' => (is => 'rw',
		isa => 'Object');

has 'genome_list' => (isa => 'Wx::ListCtrl',
		      is  => 'rw');

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

    if ($self->menubar)
    {
	$self->SetMenuBar($self->menubar);
    }

    my $panel = wxPerl::Panel->new($self);
    $self->panel($panel);

    my $top_sz = Wx::BoxSizer->new(wxVERTICAL);

    $panel->SetSizer($top_sz);
    # $top_sz->SetSizeHints($self);

    my $list = wxPerl::ListCtrl->new($panel,
				     style => wxLC_REPORT);
    $self->genome_list($list);
    $top_sz->Add($list, 1, wxEXPAND | wxALL, 5);

    my $bsizer = Wx::BoxSizer->new(wxHORIZONTAL);
    $top_sz->Add($bsizer, 0, wxEXPAND | wxALL, 5);

    my $b = wxPerl::Button->new($panel, "Process new genome");
    $bsizer->Add($b, 0, wxALIGN_LEFT | wxALL, 5);
    EVT_BUTTON($self, $b, sub { $self->process_new_genome(); });

    $b = wxPerl::Button->new($panel, "Open genome");
    $bsizer->Add($b, 0, wxALIGN_RIGHT | wxALL, 5);
    EVT_BUTTON($self, $b, sub { $self->open_genome(); });

    $b = wxPerl::Button->new($panel, "Delete genome");
    $bsizer->Add($b, 0, wxALIGN_RIGHT | wxALL, 5);
    EVT_BUTTON($self, $b, sub { $self->delete_genome(); });

    $b = wxPerl::Button->new($panel, "Cancel");
    $bsizer->Add($b, 0, wxALIGN_RIGHT | wxALL, 5);
    EVT_BUTTON($self, $b, sub { $self->cancel(); });

    $self->load_jobs();
    EVT_LIST_ITEM_ACTIVATED($self, $list, sub { $self->open_genome(); } );
    
}

sub load_jobs
{
    my($self) = @_;

    my $list = $self->genome_list();
    my @items = $self->enumerate_jobs();

    $list->ClearAll();

    $list->InsertColumn(0, "Genome ID");
    $list->InsertColumn(1, "Name");
    $list->InsertColumn(2, "Contigs");
    $list->InsertColumn(3, "Size");
    $list->InsertColumn(4, "Correpondences Computed");
    $list->InsertColumn(5, "Subsystem Count");

    my $have_nonempty_name = 0;
    my $row = 0;
    for my $ent (@items)
    {
	$list->InsertStringItem($row, $ent->{genome_id});
	$list->SetItem($row, 1, $ent->{genome_name});
	$have_nonempty_name++ if length($ent->{genome_name}) > 0;
	$list->SetItem($row, 2, $ent->{num_contigs});
	$list->SetItem($row, 3, $ent->{num_basepairs});
	$list->SetItem($row, 4, $ent->{num_correspondences});
	$list->SetItem($row, 5, $ent->{num_subsystems});
	$row++;
    }

    $list->SetColumnWidth(0, wxLIST_AUTOSIZE_USEHEADER);
    $list->SetColumnWidth(1, wxLIST_AUTOSIZE) if $have_nonempty_name;
    $list->SetColumnWidth(2, wxLIST_AUTOSIZE_USEHEADER);
    $list->SetColumnWidth(3, wxLIST_AUTOSIZE) if @items;
    $list->SetColumnWidth(4, wxLIST_AUTOSIZE_USEHEADER);
    $list->SetColumnWidth(5, wxLIST_AUTOSIZE_USEHEADER);

}


=item B<<@jobs = $obj->enumerate-jobs()>>

Enumerate all jobs in the user's DesktopRast directory. Returns a list of hashes
with keys:

	genome_id
	num_subsystems
	num_contigs   
	num_basepairs 
	genome_name   
	genome_domain 
	genome_pegs   
	genome_rnas   

=cut

sub enumerate_jobs
{
    my($self) = @_;

    my $doc_dir = File::HomeDir->my_documents . "/myRAST";

    my @jobs;
    if (opendir(my $jdh, $doc_dir))
    {
	@jobs = map { "$doc_dir/$_" } grep { /^\d+\.\d+$/ } sort readdir($jdh);
	closedir($jdh);
    }

    my @out;
    for my $dir (@jobs)
    {
	my $genome = basename($dir);
	
	next if $genome !~ /^\d+\.\d+$/;

	my $genome_dir = "$dir/$genome";
	my $sv = SeedV->new($genome_dir);
	my $info = $sv->get_basic_statistics();
	$info->{genome_id} = $genome;
	$info->{dir} = $genome_dir;

	#
	# Count the number of comparison genomes.
	#
	my $comp = 0;
	if (opendir(my $dh, "$genome_dir/CorrToReferenceGenomes"))
	{
	    $comp = grep { /^\d+\.\d+$/ } readdir($dh);
	    closedir($dh);
	}
	$info->{num_correspondences} = $comp;
	push(@out, $info);
    }

    return sort { $a->{genome_id} cmp $b->{genome_id} } @out;
}

#
# Open the selected genome.
sub open_genome
{
    my($self) = @_;

    my $sel = -1;

    while (1)
    {
	$sel = $self->genome_list->GetNextItem($sel, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED);
	last if $sel == -1;

	my $id = $self->genome_list->GetItemText($sel);

	print "Found $sel $id\n";

	$self->view_genome($id);
    }
}
    

sub view_genome
{
    my($self, $genome) = @_;

    my $browser = Browser->new();

    my $frame = wxPerl::Frame->new(undef, "Genome Browser -- $genome",
				  size => Wx::Size->new(800,500));
    my $panel = ProteinPanel->new(parent => $frame, browser => $browser);
    
    $frame->Show();

    my $peg = "fig|$genome.peg.1";
    $browser->set_peg($peg);
}

sub delete_genome
{
    my($self) = @_;

    my $sel = -1;

    my @genomes;
    while (1)
    {
	$sel = $self->genome_list->GetNextItem($sel, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED);
	last if $sel == -1;

	my $genome = $self->genome_list->GetItemText($sel);
	push(@genomes, $genome);
    }

    return if (@genomes == 0);
    my $msg;
    if (@genomes == 1)
    {
	$msg = "Delete genome $genomes[0]? (This action cannot be undone)";
    }
    else
    {
	my $n = @genomes;
	$msg = "Delete $n genomes? (This action cannot be undone)";
    }
    my $dlg = Wx::MessageDialog->new($self, $msg,
				     "Delete genome",
				     wxYES_NO | wxNO_DEFAULT | wxICON_EXCLAMATION);
    my $rc = $dlg->ShowModal();
    
    if ($rc == wxID_YES)
    {
	for my $genome(@genomes)
	{
	    my $dir = File::HomeDir->my_documents . "/myRAST/$genome";
	    print "Delete genome $genome in $dir\n";
	    if (-d $dir)
	    {
		File::Path::remove_tree($dir);
	    }
	}
	$self->load_jobs();
    }
}

sub process_new_genome()
{
    my($self) = @_;
    
    my $rast = DesktopRast->new();
    my $fr = DesktopRastFrame->new(title => "myRAST", rast => $rast,
				   size => Wx::Size->new(700,700),
				   job_browser => $self);
    $fr->Show(1);
    
}

1;
