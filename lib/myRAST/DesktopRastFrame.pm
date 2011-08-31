package DesktopRastFrame;

use SeedUtils;
use Data::Dumper;

use Moose;
use MooseX::NonMoose;

use List::Util qw(first);
use Browser;
use ProteinPanel;
    
use wxPerl::Constructors;
use Wx qw(:sizer :everything);
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX EVT_COMBOBOX EVT_TIMER EVT_SIZE EVT_CLOSE EVT_TEXT);

#
# Win32 needs some grunge for file opening.
#

our $text_viewer;

if ($^O =~ /win32/i)
{
    require Env::Path;
    require Win32;
    Win32->import;
    require Win32::Process;
    Win32::Process->import;
    my $path = Env::Path->PATH;
    
    my @np = $path->Whence("notepad.exe");
    if (@np)
    {
	$text_viewer = $np[0];
    }
    else
    {
	$text_viewer = 'c:\windows\notepad.exe';
    }
}
else
{
   sub DETACHED_PROCESS {};
   sub NORMAL_PRIORITY_CLASS {};
}

extends 'Wx::Frame';

has 'job_browser' => (is => 'rw',
		      isa => 'JobBrowserFrame');

has 'rast' => (is => 'rw',
	       isa => 'DesktopRast');

has 'filename' => (is => 'rw',
		   isa => 'Str',
		   trigger => \&_set_filename);

has 'sequence_type' => (is => 'rw',
			isa => 'Str',
			trigger => \&_set_sequence_type,
		       );

has 'sequence_type_radiobox' => (is => 'rw',
			isa => 'Object');

has 'processing_speed' => (is => 'rw',
			   isa => 'Str',
			   default => 'Faster');

has 'kmer_size' => (is => 'rw',
		    isa => 'Str',
		    default => 8);

has 'score_threshold' => (is => 'rw',
			  isa => 'Num',
			  default => 3);

has 'seq_hit_threshold' => (is => 'rw',
			    isa => 'Num',
			    default => 2);

has 'genetic_code' => (is => 'rw',
		       isa => 'Str',
		       default => 11);
has 'genetic_code_gui' => (is => 'rw',
			   isa => 'Wx::ComboBox');

has 'panel' => (is => 'rw',
		isa => 'Object');

has 'timer' => (is => 'rw',
		isa => 'Object');
has 'otu_text' => (is => 'rw',
		   isa => 'Object');

has 'genome_id_text' => (is => 'rw',
		   isa => 'Object');

has 'notify_server' => (is => 'rw',
			isa => 'NotifyServer');

has 'start_button' => (is => 'rw',
		       isa => 'Wx::Button');
has 'stop_button' => (is => 'rw',
		       isa => 'Wx::Button');
has 'pipeline_gui_elements' => (is => 'rw',
				isa => 'ArrayRef',
                                lazy => 1,
				default => sub { [] });


sub FOREIGNBUILDARGS
{
    my($self, %args) = @_;

    my $title = $args{title};

    return (undef, -1, $title, wxDefaultPosition,
	    (exists($args{size}) ? $args{size} : wxDefaultSize));
};

sub BUILD
{
    my($self) = @_;

    my $panel = wxPerl::Panel->new($self);
    $self->panel($panel);

    my $top_sz = Wx::BoxSizer->new(wxVERTICAL);
    my $inp_sz = Wx::StaticBoxSizer->new(Wx::StaticBox->new($panel, -1, "Input Properties"), wxVERTICAL);
    my $prog_sz = Wx::StaticBoxSizer->new(Wx::StaticBox->new($panel, -1, "Processing progress"), wxVERTICAL);
    my $view_sz = Wx::StaticBoxSizer->new(Wx::StaticBox->new($panel, -1, "Viewing output"), wxVERTICAL);
    $top_sz->Add($inp_sz, 0, &Wx::wxEXPAND);
    $top_sz->Add($prog_sz, 0, &Wx::wxEXPAND);
    $top_sz->Add($view_sz, 0, &Wx::wxEXPAND);

    $panel->SetSizer($top_sz);
    # $top_sz->SetSizeHints($self);

    my $top_grid = Wx::FlexGridSizer->new(1, 2, 5, 5);
    $inp_sz->Add($top_grid, 1, wxEXPAND);
    $top_grid->AddGrowableCol(1);
    #
    # Row 1
    #
    $top_grid->Add(Wx::StaticText->new($panel, -1, 'Data file'));
    my $r1_box = Wx::BoxSizer->new(&Wx::wxHORIZONTAL);
    $top_grid->Add($r1_box, 0, wxEXPAND);
    my $browse_but = Wx::Button->new($panel, -1, "Browse");
    my $file_txt = wxPerl::TextCtrl->new($panel, "");
    $r1_box->Add($browse_but);
    $r1_box->AddSpacer(5);
    $r1_box->Add($file_txt, 1, wxEXPAND);
    EVT_BUTTON($self, $browse_but, sub {
	print "Click!\n";
	my $dlg = Wx::FileDialog->new($panel, "Open File", '', '', "*");
	if ($dlg->ShowModal == &Wx::wxID_OK)
	{
	    my $file = $dlg->GetPath;
	    print "Got path " . Dumper($file);
	    $file_txt->SetValue($file);
	    $self->filename($file);
	    $self->start_button->Enable(1);
	}
    });

    #
    # Row 2.
    #
    $top_grid->Add(Wx::StaticText->new($panel, -1, 'Sequence Type'));
    my $stype = wxPerl::RadioBox->new($panel, "",
				      choices => [qw(dna protein genbank)]);
    $self->sequence_type_radiobox($stype);
    $top_grid->Add($stype);
    EVT_RADIOBOX($self, $stype, sub {
	my($obj, $evt) = @_;
	print "RB " . $evt->GetString() . "\n";
	$self->sequence_type($evt->GetString());
    });

    #
    # Row 2a :-)
    #
    $top_grid->Add(Wx::StaticText->new($panel, -1, 'Genetic Code'));
    my $gc_ui = wxPerl::ComboBox->new($panel,
				     value => $self->genetic_code,
				     choices => [4, 11],
				     style => wxCB_READONLY,
				    );
    $self->genetic_code_gui($gc_ui);
    
    $top_grid->Add($gc_ui);
    EVT_COMBOBOX($self, $gc_ui, sub {
	my($obj, $evt) = @_;
	print "GC " . $evt->GetString() . "\n";
	$self->genetic_code($evt->GetString());
    });

    #
    # Row 3.
    #
    $top_grid->Add(Wx::StaticText->new($panel, -1, 'Processing Speed'));
    my $ptype = wxPerl::RadioBox->new($panel, "",
				      choices => [qw(Fast Faster)]);
    $ptype->SetStringSelection($self->processing_speed);
    $top_grid->Add($ptype);
    EVT_RADIOBOX($self, $ptype, sub {
	my($obj, $evt) = @_;
	print "PS " . $evt->GetString() . "\n";
	$self->processing_speed($evt->GetString());
    });

    #
    # Row 4.
    #
    $top_grid->Add(Wx::StaticText->new($panel, -1, 'Kmer Size'));
    my $kmer = wxPerl::ComboBox->new($panel,
				     style => wxCB_READONLY,
				     value => $self->kmer_size,
				     choices => [(7..12)]);
    
    $top_grid->Add($kmer);
    EVT_COMBOBOX($self, $kmer, sub {
	my($obj, $evt) = @_;
	print "KS " . $evt->GetString() . "\n";
	$self->kmer_size($evt->GetString());
    });

    #
    # Row 4a
    #
    $top_grid->Add(Wx::StaticText->new($panel, -1, 'Kmer score threshold'));
    my $kscore = wxPerl::ComboBox->new($panel,
				     style => wxCB_READONLY,
				     value => $self->score_threshold,
				     choices => [0..10]);
    
    $top_grid->Add($kscore);
    EVT_COMBOBOX($self, $kscore, sub {
	my($obj, $evt) = @_;
	print "KScore " . $evt->GetString() . "\n";
	$self->score_threshold($evt->GetString());
    });

    #
    # Row 4b
    #
    $top_grid->Add(Wx::StaticText->new($panel, -1, 'Kmer nonoverlapping hit threshold'));
    my $kseq = wxPerl::ComboBox->new($panel,
				     style => wxCB_READONLY,
				     value => $self->seq_hit_threshold,
				     choices => [0..10]);
    
    $top_grid->Add($kseq);
    EVT_COMBOBOX($self, $kseq, sub {
	my($obj, $evt) = @_;
	print "KSeq " . $evt->GetString() . "\n";
	$self->seq_hit_threshold($evt->GetString());
    });


    #
    # Row 5
    #
    $top_grid->AddSpacer(8);
    $top_grid->AddSpacer(8);
    $top_grid->Add(wxPerl::StaticText->new($panel, "Dominant OTU"));
    my $otu_text = wxPerl::StaticText->new($panel, "");
    $top_grid->Add($otu_text);
    $self->otu_text($otu_text);

    $top_grid->AddSpacer(8);
    $top_grid->AddSpacer(8);
    $top_grid->Add(wxPerl::StaticText->new($panel, "Assigned Genome ID"));
    my $genome_id_text = wxPerl::StaticText->new($panel, "");
    $top_grid->Add($genome_id_text);
    $self->genome_id_text($genome_id_text);

    #
    # Row 6.
    #
    $top_grid->AddSpacer(8);
    $top_grid->AddSpacer(8);

    my $process_but = Wx::Button->new($panel, -1, "Start processing");
    $top_grid->Add($process_but);
    $process_but->Enable(0);

    $self->start_button($process_but);
    EVT_BUTTON($self, $process_but, sub {
	#
	# When we start up, turn off the active bits of the interface.
	#
	for my $elt ($browse_but, $file_txt, $stype, $ptype, $kmer, $gc_ui)
	{
	    $elt->Enable(0);
	}
	   
	$self->start_processing($prog_sz);
	$top_sz->Fit($self);
    });

    my $stop_but = Wx::Button->new($panel, -1, "Stop processing");
    $stop_but->Enable(0);
    $top_grid->Add($stop_but);
    $self->stop_button($stop_but);
    EVT_BUTTON($self, $stop_but, sub {
	$self->stop_processing();
    });

    #
    # Viewing stuf.
    #
    my $view_but = Wx::Button->new($panel, -1, "View processed genome");
    $view_sz->Add($view_but);
    EVT_BUTTON($self, $view_but, sub {
	$self->view_genome();
    });

    EVT_CLOSE($self, sub {
	print "Window closing\n";
	$self->stop_processing();
	$self->Destroy();
    });

    #$self->notify_server(NotifyServer->new(window => $self));
    #$self->rast->notify_port($self->notify_server->port);

    $top_sz->Fit($self);
}

sub start_processing
{
    my($self, $sizer) = @_;

    $self->start_button->Enable(0);
    $self->stop_button->Enable(1);
    
    print "Process! $sizer\n";
    my $rast = $self->rast;
    $rast->processing_speed(lc($self->processing_speed));
    $rast->kmer_size($self->kmer_size);
    $rast->score_thresh($self->score_threshold);
    $rast->seq_hit_thresh($self->seq_hit_threshold);
    $rast->sequence_type(lc($self->sequence_type));
    $rast->input_file($self->filename);
    $rast->genetic_code($self->genetic_code);

    $rast->setup();

    $self->genome_id_text->SetLabel($rast->genome_id);

    #
    # Pipeline created, pull the stages and
    # create the GUI elements.
    #

    my $grid = Wx::FlexGridSizer->new(1, 5, 5, 5);
#    $grid->AddGrowableCol(2);
#    $grid->AddGrowableCol(3);
    $sizer->Add($grid, 1, wxEXPAND);

    my @elts;
    for my $stage ($rast->all_stages)
    {
	my $elt = $self->create_stage_gui($stage, $grid);
	push(@elts, $elt);
    }
    $self->panel->Layout();
    
    #
    # Start clock.
    #
    my $timer = Wx::Timer->new($self);
    
    EVT_TIMER($self, $timer, sub {
	my $all_done = $rast->check_pipeline();

	if ($all_done)
	{
	    $timer->Stop();
	    print "Pipeline done\n";
	}
	else
	{
	    $self->stage_gui_tick(@$_) for @elts;
	}
    });

    $self->pipeline_gui_elements(\@elts);
    
    $self->timer($timer);
    $timer->Start(1000);

    $rast->start();
}

sub stop_processing
{
    my($self) = @_;

    $self->timer->Stop() if defined($self->timer);

    for my $elt (@{$self->pipeline_gui_elements})
    {
	my($stage, $elap_txt, $gauge, $timer) = @$elt;
	$timer->Stop();
	if ($stage->state eq 'running')
	{
	    $gauge->SetValue(0);
	    $stage->stop();
	}
    }
}

sub create_stage_gui
{
    my($self, $stage, $sizer) = @_;

    my $panel = $self->panel;

    $sizer->Add(wxPerl::StaticText->new($panel, $stage->name));
    
    my $elap_txt = wxPerl::StaticText->new($panel, "00:00:00");
    $sizer->Add($elap_txt);
    
    #    my $gauge = wxPerl::Gauge->new($panel, 10, style => wxGA_HORIZONTAL);
    my $gauge = Wx::Gauge->new($panel, -1, 10, wxDefaultPosition, Wx::Size->new(150, -1), wxGA_HORIZONTAL);
    $sizer->Add($gauge, 0, 0);
    
    my $choices = [ map { $_->label } @{$stage->viewable_files} ];
    if (@$choices)
    {
	my $file_dropdown = wxPerl::ComboBox->new($panel,
						  style => wxCB_READONLY,
						  value => (@$choices ? $choices->[0] : ""),
						  choices => $choices);
	my $b = wxPerl::Button->new($panel, "View file");
	EVT_BUTTON($self, $b, sub {
	    my $which = $file_dropdown->GetValue();
	    my $vf = first { $_->label eq $which } @{$stage->viewable_files};
	    if ($vf)
	    {
		$self->open_file($vf->filename);
	    }
	});
	
	$sizer->Add($file_dropdown);
	$sizer->Add($b);
    }
    else
    {
	$sizer->AddSpacer(8);
	$sizer->AddSpacer(8);
    }

#     my $bsizer = Wx::BoxSizer->new(wxHORIZONTAL);
#     $sizer->Add($bsizer);
#     for my $vf (@{$stage->viewable_files})
#     {
# 	my $view_output = wxPerl::Button->new($panel, "View " . $vf->label);
# 	EVT_BUTTON($self, $view_output, sub {
# 	    print "View output for " . $vf->label . "\n";
# 	    $self->open_file($vf->filename);
# 	});
# 	$bsizer->Add($view_output);
#     }
    
    #     my $view_output = wxPerl::Button->new($panel, "View " . $stage->stdout_name);
#     EVT_BUTTON($self, $view_output, sub {
# 	print "View output for " . $stage->name . "\n";
# 	$self->open_file($stage->output_file);
#     });
#     my $view_error = wxPerl::Button->new($panel, "View " . $stage->stderr_name);
#     EVT_BUTTON($self, $view_error, sub {
# 	print "View error for " . $stage->name . "\n";
# 	$self->open_file($stage->error_file);
#     });

#     $sizer->Add($view_output, 0, wxEXPAND);
#     $sizer->Add($view_error, 0, wxEXPAND);

    #
    # Fast timer for gauge pulses.
    #
    my $timer = Wx::Timer->new($self);
    EVT_TIMER($self, $timer, sub {
	$gauge->Pulse();
    });
    

    $stage->add_state_observer(sub { $self->stage_change($stage, $elap_txt, $gauge, $timer) });

    #
    # If the stage is annotations stage, we add an additional observer to update the dominant OTU
    # text.
    #
    if ($stage->name =~ /annotation/i)
    {
	$stage->add_state_observer(sub { $self->update_dominant_otu() if $stage->state eq 'complete'; });
    }
    elsif ($stage->key eq 'create_genome_dir' ||
	   $stage->key eq 'compute_correspondences')
    {
	$stage->add_state_observer(sub { $self->job_browser->load_jobs() if $stage->state eq 'complete'; });
    }

    #$self->notify_server->set_callback($stage->handle, sub { $self->stage_notify($gauge, @_); });

    return [$stage, $elap_txt, $gauge, $timer];
}

sub stage_notify
{
    my($self, $gauge, $handle, $data) = @_;
#    print Dumper($data);
    for my $ent (@$data)
    {
	my($k, $v) = @$ent;
	if ($k eq 'progress')
	{
	    my($val, $range) = @$v;
	    
	    if ($val < 0)
	    {
		$gauge->Pulse();
	    }
	    else
	    {
		$gauge->SetRange($range);
		$gauge->SetValue($val);
	    }
	}
	elsif ($k eq 'status')
	{
	    print "Status: $v\n";
	}
    }
}

sub open_file
{
    my($self, $file) = @_;

    if ($^O =~ /darwin/i)
    {
	system("open", "-a", "TextEdit", $file);
    }
    elsif ($^O =~ /win32/i)
    {
	my $proc;
	Win32::Process::Create($proc, $text_viewer, "notepad \"$file\"", 0,
			       DETACHED_PROCESS | NORMAL_PRIORITY_CLASS , ".");
    }
    elsif ($^O =~ /linux/)
    {
	my $pid = fork;
	if ($pid == 0)
	{
	    if (fork == 0)
	    {
		exec("gedit", "--new-window", $file);
		die "gedit $file failed: $!";
	    }
	    else
	    {
		exit;
	    }
	}
	else
	{
	    waitpid($pid, -1);
	}
    }
    
}

sub update_dominant_otu
{
    my($self) = @_;
    print "UPDATE dom otu\n";
    $self->otu_text->SetLabel($self->rast->dominant_otu);
}

sub stage_gui_tick
{
    my($self, $stage, $elap_txt, $gauge) = @_;
    return if $stage->state ne 'running';

    $gauge->Pulse();
    my $elap = int($stage->elapsed_time());

    my $hrs = int($elap / 3600);
    $elap -= $hrs * 3600;
    my $sec = $elap % 60;
    my $min = int($elap / 60);
    $elap_txt->SetLabel(sprintf("%02d:%02d:%02d", $hrs, $min, $sec));
}

sub stage_change
{
    my($self, $stage, $elap_txt, $gauge, $timer) = @_;

    if ($stage->state eq 'running')
    {
	$gauge->Pulse();
	$timer->Start(100);
    }
    elsif ($stage->state eq 'complete')
    {
	$timer->Stop();
	my $elap = int($stage->elapsed_time());
	my $hrs = int($elap / 3600);
	$elap -= $hrs * 3600;
	my $sec = $elap % 60;
	my $min = int($elap / 60);
	$elap_txt->SetLabel(sprintf("%02d:%02d:%02d", $hrs, $min, $sec));
	$gauge->SetValue(100);
    }
}

sub _set_filename
{
    my($self, $new) = @_;
    print "New filename is $new\n";

    my $seqtype;
    if (open(my $inp_fh, "<", $new))
    {
	$_ = <$inp_fh>;
	if (/LOCUS/)
	{
	    $seqtype = 'genbank';
	    while (<$inp_fh>)
	    {
		if (m,/transl_table=(\d+),)
		{
		    $self->genetic_code($1);
		    $self->genetic_code_gui->SetValue($1);
		    last;
		}
	    }
	}
	close($inp_fh);
    }
    else
    {
	Wx::MessageBox("Could not open $new.",
		       "Error opening file");
	return;
    }

    if (!defined($seqtype))
    {
	eval {
	    $seqtype = &SeedUtils::validate_fasta_file($new);
	};
    }
    
    if ($seqtype)
    {
	print "Got seq type $seqtype\n";
	$self->sequence_type($seqtype);
    }
    else
    {
	Wx::MessageBox("Could not open $new, or it was not a valid fasta file.",
		       "Error opening file");
    }
}

sub _set_sequence_type
{
    my($self, $new) = @_;
    $self->sequence_type_radiobox->SetStringSelection($new);
}

sub view_genome
{
    my($self) = @_;

    my $browser = Browser->new();

    my $frame = wxPerl::Frame->new(undef, "myRAST Genome Browser",
				  size => Wx::Size->new(800,500));
    my $panel = ProteinPanel->new(parent => $frame, browser => $browser);
    
    $frame->Show();
    my $g = $self->rast->genome_id;
    my $peg = "fig|$g.peg.1";
    $browser->set_peg($peg);
}

1;
