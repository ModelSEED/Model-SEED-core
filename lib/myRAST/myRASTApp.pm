package myRASTApp;

use Data::Dumper;
use Moose;
use MooseX::NonMoose;
use GenomeInfoPanel;
use RegionPanel;
use File::Temp 'tempfile';
use SeedAware;
use LWP::UserAgent;

use wxPerl::Constructors;

use Wx qw(:everything);
use Wx::RichText qw(:richtextctrl);
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX EVT_COMBOBOX EVT_TIMER EVT_SIZE EVT_CLOSE EVT_MENU);

extends 'Wx::App';

use JobBrowserFrame;
use SampleJobBrowserFrame;

my $version;
eval
{
    require myRASTVersion;
    $version = myRASTVersion->new;
};


sub OnInit
{
    my($self) = @_;

    $self->open_genome();

    return 1;
}

sub default_menubar
{
    my($self) = @_;

    my $bar = Wx::MenuBar->new();
    my $file = Wx::Menu->new();

    my $i_open_g = $file->Append(-1, "&Open genome\tCtrl+O");
    my $i_open_s = $file->Append(-1, "Open s&ample\tShift+Ctrl+O");
#    my $i_all_to_all = $file->Append(-1, "Export all-to-all analysis");
#    my $i_tree_all_to_all = $file->Append(-1, "Compute tree for all-to-all analysis");

    EVT_MENU($self, $i_open_g, \&open_genome);
    EVT_MENU($self, $i_open_s, \&open_sample);
#    EVT_MENU($self, $i_all_to_all, \&export_all_to_all);
#    EVT_MENU($self, $i_tree_all_to_all, \&all_to_all_to_tree);

    my $help = Wx::Menu->new();
    my $i_about = $help->Append(wxID_ABOUT, "About myRAST");
    EVT_MENU($self, $i_about, \&OnAbout);
    
#    my $i_docs = $help->Append(-1, "Docs");

    $bar->Append($file,"File");
    $bar->Append($help, "&Help");

    return $bar;
}

sub export_all_to_all
{
    my($self, $samples_to_compare) = @_;

    my $dlg = Wx::FileDialog->new(undef, "Export all-to-all analysis to file", "",
				  "", "*.*", wxFD_SAVE);
    my $rc = $dlg->ShowModal();

    if ($rc != wxID_OK)
    {
	return;
    }
    my $file = $dlg->GetPath();

    my $fh;
    if (!open($fh, ">", $file))
    {
	my $dlg = Wx::MessageDialog->new(undef, "Cannot open file $file: $!",
					 "Error opening file",
					 wxOK);
	$dlg->Show();
	return;
    }

    my $busy = Wx::BusyCursor->new();

    my($samples, $scores, $prog_dlg, $max) = $self->interactive_compute_all_to_all($samples_to_compare);

    if ($prog_dlg)
    {
	$prog_dlg->Destroy();
    }

    #
    # Was it canceled?
    #
    if (!$samples)
    {
	return;
    }

    $self->write_all2all_to_file($fh, $samples, $scores);
    close($fh);
}

sub write_all2all_to_file
{
    my($self, $fh, $samples, $scores) = @_;
    my $close = 0;
    if (!ref($fh))
    {
	$fh = open($fh, ">", $fh);
	if (!$fh)
	{
	    return undef;
	}
	$close = 1;
    }
    my $n = @$samples;
    
    for my $i (0..$n-1)
    {
	my $s = $samples->[$i];
	print $fh join("\t", $i, @$s{qw(name kmer max_gap min_hits dataset dataset_index)}), "\n";
    }
    print $fh "//\n";
    for my $i (0..$n-1)
    {
	my $rref = $scores->[$i];
	
	my @row = ref($rref) ? @{$scores->[$i]} : ();
	$#row = $n-1;
	print $fh join("\t", @row), "\n";

    }

    close($fh) if $close;
}

sub all_to_all_to_tree
{
    my($self, $samples_to_compare) = @_;

#    print "tree: ",Dumper($samples_to_compare);
    my $busy = Wx::BusyCursor->new();

    my $file = SeedAware::location_of_tmp() . "/tree.$$";

    my $fh;
    if (!open($fh, ">", $file))
    {
	my $dlg = Wx::MessageDialog->new(undef, "Cannot open temp file $file: $!",
					 "Error opening file",
					 wxOK);
	$dlg->ShowModal();
	return;
    }

    binmode($fh);

    my($samples, $scores, $prog_dlg, $max) = $self->interactive_compute_all_to_all($samples_to_compare);

    #
    # Was it canceled?
    #
    if (!$samples)
    {
	$prog_dlg->Destroy();
	return;
    }

    $prog_dlg->Update($max - 1, "Computing tree...");
    Wx::App::GetInstance()->Yield();

    $self->write_all2all_to_file($fh, $samples, $scores);
    close($fh);

    print "posting\n";
    my $ua = LWP::UserAgent->new();
    my $res = $ua->post("http://bioseed.mcs.anl.gov/~redwards/FIG/neighbor_tree.cgi",
			Content_Type => ['form-data'],
			Content => [request => 1,
				    uploadedfile => [$file],
				    ]);
    print "done\n";
    undef $busy;
    $prog_dlg->Destroy();
    if ($res->is_success)
    {
	$self->process_and_display_tree($res->content);
    }
    else
    {
	my $dlg = Wx::MessageDialog->new(undef,
					 "We encountered an error computing the tree:\n" . $res->content,
					 "Error computing tree",
					 wxOK);
	$dlg->ShowModal();
	return;
    }
}

sub process_and_display_tree
{
    my($self, $txt) = @_;
    
    my($tree) = $txt =~ m,<pre>(.*?)</pre>,s;
    
    my $dlg = wxPerl::Dialog->new(undef, "All to all tree",
				  size => Wx::Size->new(900, 600),
				  style => wxRESIZE_BORDER | wxDEFAULT_DIALOG_STYLE);

    my $sz = Wx::BoxSizer->new(wxVERTICAL);
    $dlg->SetSizer($sz);
    
    my $txtctrl = Wx::RichTextCtrl->new($dlg, -1, "", [-1, -1], [-1, -1], wxRE_READONLY);

    $sz->Add($txtctrl, 1, wxEXPAND | wxALL, 5);
    my $a = $txtctrl->GetDefaultStyle();

    my $font = Wx::Font->new(10, wxFONTFAMILY_MODERN, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_NORMAL);
    $txtctrl->SetFont($font);
    print "font is " . $font->GetFaceName() . "\n";
    #$a->SetFont($font);
    #$txtctrl->SetDefaultStyle($a);
    #print "using ", $txtctrl->GetDefaultStyle()->GetFont()->GetFaceName(), "\n";
    
    $txtctrl->AppendText($tree);

    $sz->Add($dlg->CreateStdDialogButtonSizer(wxOK), 0, wxALL, 5);

    $dlg->Show(1);
}


sub interactive_compute_all_to_all
{
    my($self, $samples_to_compare) = @_;

    my $prog_dlg;
    my $max;
    my $count_cb = sub {
	my($c) = @_;
	$max = $c + 2;
	$prog_dlg = Wx::ProgressDialog->new("All to all progress",
					    "Computing distances...",
					    $max, undef,
					    wxPD_APP_MODAL | wxPD_CAN_ABORT);
	$prog_dlg->Show(1);
    };
    my $update_cb = sub {
	my($i) = @_;
	my $exit = $prog_dlg->Update($i);
	Wx::App::GetInstance()->Yield();
	return $exit;
    };
    
    my($samples,$scores) = myRAST->instance->compute_all_to_all_distances($samples_to_compare, $count_cb, $update_cb);

    return($samples, $scores, $prog_dlg, $max);
}

sub open_genome
{
    my($self) = @_;

    my $jb = JobBrowserFrame->new(title=> "myRAST Job Browser",
				  menubar => $self->default_menubar());

    $jb->Show();
}

sub open_sample
{
    my($self) = @_;

    my $jb = SampleJobBrowserFrame->new(title=> "myRAST Job Browser",
					menubar => $self->default_menubar());

    $jb->Show();
}

sub OnAbout
{
    my($self) = @_;

    my $ver_str;
    if (defined($version))
    {
	$ver_str = "Version " . $version->release;
    }
    else
    {
	$ver_str = "Development build";
    }
    my $dlg = Wx::MessageDialog->new(undef, "myRAST\n$ver_str", "About myRAST");
    $dlg->ShowModal();
}

1;
