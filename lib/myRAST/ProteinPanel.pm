package ProteinPanel;

use Moose;
use MooseX::NonMoose;

use POSIX;
use IPC::Run;
use Time::HiRes 'gettimeofday';
use File::Temp 'tempfile';
use List::Util qw(min);
use List::MoreUtils qw(part);

eval {
    require Win32;
};

use Data::Dumper;

use ExportFeaturePanel;
use ExportSubsystemsPanel;
use wxPerl::Constructors;
use Wx::Grid;
use Wx::Html;
use Wx::DND;
use Wx qw(:sizer :everything :dnd wxTheClipboard);

use Wx::Event qw(EVT_BUTTON EVT_SPINCTRL EVT_TEXT_ENTER EVT_CLOSE EVT_MENU EVT_END_PROCESS
		 EVT_COMBOBOX);

use GenbankComparisonFrame;
use RegionPanel;
use WebBrowser;
use Psiblast;
use SAPserver;
use NotifyServer;
use FS_RAST;
use gjoseqlib;

extends 'Wx::Panel';

=head1 NAME

ProteinPanel - wxPanel that renders a "protein page".

=cut

has 'browser' => (isa => 'Browser',
		  is => 'ro');

has 'genbank_file' => (isa => 'Str',
		       is => 'rw');

#
# UI elements.
#

has 'genbank_dep_buttons' => (isa => 'ArrayRef[Wx::Button]',
			      is => 'ro',
			      default => sub { [] },
			      );

has 'peg_txt' => (isa => 'Wx::StaticText',
		  is => 'rw');

has 'genome_txt' => (isa => 'Wx::StaticText',
		     is => 'rw');

has 'function_txt' => (isa => 'Wx::StaticText',
		       is => 'rw');

has 'function_box' => (isa => 'Wx::Sizer',
		       is => 'rw');

has 'new_function_txt' => (isa => 'Wx::TextCtrl',
			   is => 'rw');

has 'find_peg_txt' => (isa => 'Wx::TextCtrl',
		       is => 'rw');

has 'region_size_combo' => (isa => 'Wx::ComboBox',
			   is => 'rw');

has 'region_count_combo' => (isa => 'Wx::ComboBox',
			   is => 'rw');

has 'region_panel' => (isa => 'RegionPanel',
		       is => 'rw');

has 'psiblast_cache' => (isa => 'HashRef',
			 is => 'ro',
			 default => sub { {} },
			 );

has 'psiblast' => (isa => 'Psiblast',
		   is => 'ro',
		   default => sub { Psiblast->new() },
		   );

has 'sap' => (isa => 'SAPserver',
		   is => 'ro',
		   default => sub { SAPserver->new() },
		   );

has 'notify_server' => (isa => 'NotifyServer',
			is => 'rw');

has 'selected_features_list' => (isa => 'ArrayRef',
				 is => 'ro',
				 default => sub { [] },
				 traits => ['Array'],
				 handles => {
				     add_selected_feature => 'push',
				     selected_features => 'elements',
				     clear_selected_features => 'clear',
				 });
    

sub FOREIGNBUILDARGS
{
    my($self, %args) = @_;

    return ($args{parent}, -1);
};

sub BUILD
{
    my($self) = @_;

    $self->notify_server(NotifyServer->new(window => $self));

    my $top_sizer = Wx::BoxSizer->new(wxVERTICAL);
    $self->SetSizer($top_sizer);

    #
    # Feature info stuff is inside the FlexGridSizer $flex
    #

    my $flex = Wx::FlexGridSizer->new(4, 3, 5, 5);
    $top_sizer->Add($flex, 0, wxEXPAND | wxALL, 5);
    $self->function_box($flex);

    #
    # Feature ID
    #
    $flex->Add(wxPerl::StaticText->new($self, "Feature ID:"));

    my $t = wxPerl::StaticText->new($self, "peg");
    $self->peg_txt($t);
    $flex->Add($t, 0, wxEXPAND);
    $flex->AddSpacer(0);

    #
    # Genome name
    #

    $flex->Add(wxPerl::StaticText->new($self, "Genome:"));
    
    $t = wxPerl::StaticText->new($self, "genome");
    $self->genome_txt($t);
    $flex->Add($t, 0, wxEXPAND);
    my $sz = Wx::BoxSizer->new(wxHORIZONTAL);
    #
    # find-peg text/button
    #
    $t = wxPerl::TextCtrl->new($self, "",
			       style => wxTE_PROCESS_ENTER);
    EVT_TEXT_ENTER($self, $t, sub { $self->find_peg(); });
    $self->find_peg_txt($t);
    $sz->Add($t, 0, wxEXPAND);
    $t = wxPerl::Button->new($self, "Find");
    EVT_BUTTON($self, $t, sub { $self->find_peg(); });

    $sz->Add($t);
    $flex->Add($sz);

    #
    # Function, with edit button
    #
    $flex->Add(wxPerl::StaticText->new($self, "Function:"));

#    my $bs = Wx::BoxSizer->new(wxHORIZONTAL);
#    $flex->Add($bs);
#    $self->function_box($bs);

    $t = wxPerl::StaticText->new($self, "func");
    $self->function_txt($t);
    $flex->Add($t, 0, wxEXPAND);
    my $t2 = wxPerl::Button->new($self, "Edit");
    EVT_BUTTON($self, $t2, sub { $self->edit_assignment(); });
    $flex->Add($t2, 0, wxLEFT, 10);
    
#     my $sz = Wx::BoxSizer->new(wxHORIZONTAL);
#     $t = wxPerl::TextCtrl->new($self, "");
#     $self->new_function_txt($t);
#     $sz->Add($t, 1);

#     $t = wxPerl::Button->new($self, "Change assignment");
#     $sz->Add($t);
#     EVT_BUTTON($self, $t, sub { $self->change_assignment(); });
#     $top_sizer->Add($sz, 0, wxEXPAND);

    #
    # Region control buttons
    #
#    my $sz_region = Wx::BoxSizer->new(wxHORIZONTAL);
#    $top_sizer->Add($sz_region, 0, wxEXPAND);

    $flex->Add(wxPerl::StaticText->new($self, "Region count: "), 0, wxALIGN_CENTER_VERTICAL);
    $t = wxPerl::ComboBox->new($self,
			       style => wxCB_DROPDOWN | wxTE_PROCESS_ENTER,
			       value => $self->browser->region_count,
			       choices => [qw(1 2 5 10 20 50)]);
    $self->region_count_combo($t);
    $flex->Add($t);
    EVT_COMBOBOX($self, $t, sub {
	$self->browser->region_count($self->region_count_combo->GetValue());
	$self->update_region();
    });
    EVT_TEXT_ENTER($self, $t, sub {
	if ($self->region_count_combo->GetValue() =~ /(\d+)/)
	{
	    print "set region to '$1'\n";
	    $self->browser->region_count($1);
	    $self->update_region();
	}
	else
	{
	    $self->region_count_combo->SetValue($self->browser->region_count());
	}
    });
    $flex->AddSpacer(0);


    $flex->Add(wxPerl::StaticText->new($self, "Region size: "), 0, wxALIGN_CENTER_VERTICAL);
    $t = wxPerl::ComboBox->new($self,
			       value => $self->browser->region_width,
			       style => wxCB_DROPDOWN | wxTE_PROCESS_ENTER,
			       choices => [qw(3000 5000 10000 15000 25000 50000 100000)]);
			 
    $self->region_size_combo($t);
    $flex->Add($t);
    EVT_TEXT_ENTER($self, $t, sub {
	if ($self->region_size_combo->GetValue() =~ /(\d+)/)
	{
	    print "set region to '$1'\n";
	    $self->browser->region_width($1);
	    $self->update_region();
	}
	else
	{
	    $self->region_size_combo->SetValue($self->browser->region_width());
	}
    });
    EVT_COMBOBOX($self, $t, sub {
	my $val = $self->region_size_combo->GetValue();
	print "set region to '$val'\n";
	$self->browser->region_width($val);
	$self->update_region();
    });
    $flex->AddSpacer(0);

    #
    # Command buttons
    #
    my $sz_cmd = Wx::BoxSizer->new(wxHORIZONTAL);
    $top_sizer->Add($sz_cmd, 0, wxEXPAND);

    my $b = wxPerl::Button->new($self, "Compute genbank comparison");
    $sz_cmd->Add($b);
    EVT_BUTTON($self, $b, sub { $self->compute_genbank_comparison(); });
    push(@{$self->genbank_dep_buttons}, $b);
    
    $b = wxPerl::Button->new($self, "Show genbank comparison");
    $sz_cmd->Add($b);
    EVT_BUTTON($self, $b, sub { $self->show_genbank_comparison(); });
    push(@{$self->genbank_dep_buttons}, $b);

    $b = wxPerl::Button->new($self, "Export data");
    $sz_cmd->Add($b);
    EVT_BUTTON($self, $b, sub { $self->perform_export(); });
    
    #
    # movement buttons
    #
    my $sz_move = Wx::BoxSizer->new(wxHORIZONTAL);
    $top_sizer->Add($sz_move, 0, wxEXPAND | wxALL, 5);

    for my $button (qw(<Contig< <<< << < > >> >>> >Contig>))
    {
	my $b = wxPerl::Button->new($self, $button);
	$sz_move->Add($b);
	EVT_BUTTON($self, $b, sub { $self->move($button) });
    }

#    my $swin = wxPerl::ScrolledWindow->new($self);

    $t = RegionPanel->new(parent => $self);
    $top_sizer->Add($t, 1, wxEXPAND | wxALL, 5);
    $self->region_panel($t);
    $t->EnableScrolling(0, 1);

    $self->browser->add_observer(sub { $self->browser_change(@_); });

    $self->region_panel->add_observer(sub { $self->region_event(@_); });
}

sub DEMOLISH
{
    my($self) = @_;

    #
    # latent memory leak bug - we still have an observer registered - the anonymous sub
    # created at the end of the BUILD routine.
    #
}

sub window_closing
{
    my($self, $event) = @_;
    print "Close $event\n";
}

sub move
{
    my($self, $where) = @_;
    print "Move $where\n";

    my $d = $self->browser->region;
    my $cur = $d->[0];
    my $context = $d->[2];

    #
    # Focus row is always the top one.
    #

    my $row = $context->[0];

    #
    # Find the right peg.
    #

    my %mmap = ('<Contig<' => 'prev_contig',
		'<<<' => 'prev_page',
		'<<' => 'prev_halfpage',
		'<' => 'prev_peg',
		'>' => 'next_peg',
		'>>' => 'next_halfpage',
		'>>>' => 'next_page',
		'>Contig>' => 'next_contig');
    my $peg;
    if (defined(my $method = $mmap{$where}))
    {
	$peg = $self->browser->$method();
    }
    if (defined($peg))
    {
	print "Move to $peg\n";
	$self->browser->set_peg($peg);
    }
}

sub region_event
{
    my($self, $kind, $id, $glyph) = @_;
    print "Got region event $kind $id\n";
    if ($kind eq 'click')
    {
	#
	# Only process clicks for our current genome.
	#
	if (SeedUtils::genome_of($id) eq $self->browser->current_genome)
	{
	    $self->browser->set_peg($id);
	}
    }
    elsif ($kind eq 'right_click')
    {
	print "Process right click on $id\n";

	$self->show_feature_menu($id, $glyph);
    }
}

sub show_feature_menu
{
    my($self, $id, $glyph) = @_;

    my $menu = Wx::Menu->new($id =~ /intergenic/ ? "Actions for intergenic region" : "Actions for $id");
    my $w;

    #
    # Do we have an intergenic region selected?
    #
    my $selected_peg;
    my @sel = $self->selected_features;
    if (@sel && $sel[0]->[0] =~ /intergenic/)
    {
	$w = $menu->Append(-1, "Find this gene in selection");
	EVT_MENU($self, $w, sub { $self->find_gene_in_selection($id, $glyph, $sel[0]); });
    }
    elsif (@sel && $sel[0]->[0] =~ /fig\|/)
    {
	$selected_peg = $sel[0]->[0];
    }

    if ($id =~ /intergenic/)
    {
	$w = $menu->Append(-1, "Select intergenic region");
    }
    else
    {
	$w = $menu->Append(-1, "Select feature");
    }

    EVT_MENU($self, $w, sub { $self->select_feature($id, $glyph); });
    
    if ($id =~ /^fig/)
    {
	$w = $menu->Append(-1, "NCBI - Psiblast");
	EVT_MENU($self, $w, sub { $self->view_psiblast($id); });
	$w = $menu->Append(-1, "NCBI - Domain structure");
	EVT_MENU($self, $w, sub { $self->view_domain($id); });
    
	if (SeedUtils::genome_of($id) eq $self->browser->current_genome)
	{
	    my $w = $menu->Append(-1, "Delete feature");
	    EVT_MENU($self, $w, sub { $self->delete_feature($id);});
	    
	}
	else
	{
	    my $w = $menu->Append(-1, "View in seedviewer");
	    EVT_MENU($self, $w, sub { $self->view_in_seedviewer($id); });
	}
	
	$w = $menu->Append(-1, "Assign function to focus peg: " . $glyph->function);
	EVT_MENU($self, $w, sub { $self->assign_function_to_focus_from($id, $glyph->function); });
	if ($selected_peg)
	{
	    $w = $menu->Append(-1, "Assign function to selected peg: " . $glyph->function);
	    EVT_MENU($self, $w, sub { $self->assign_function_to_selected_from($id, $glyph->function, $selected_peg); });
	}

	$menu->AppendSeparator();
	$w = $menu->Append(-1, "Copy feature DNA");
	EVT_MENU($self, $w, sub { $self->copy_feature_dna($id); });
	$w = $menu->Append(-1, "Copy feature translation");
	EVT_MENU($self, $w, sub { $self->copy_feature_translation($id); });

#	$menu->AppendSeparator();
#	$w = $menu->Append(-1, "Align selected features");
#	EVT_MENU($self, $w, sub { $self->align_selection() });
    }

    $self->PopupMenu($menu, wxDefaultPosition);
}

sub delete_feature
{
    my($self, $fid) = @_;

    my $new_peg;
    if ($fid eq $self->browser->current_peg)
    {
	$new_peg = $self->browser->next_peg();
    }
    print "Deleting feature $fid\n";

    $self->browser->seedv->delete_feature(undef, $fid);
    if (defined($new_peg))
    {
	$self->browser->set_peg($new_peg);
    }
    else
    {
	$self->update_region();
    }
}

sub select_feature
{
    my($self, $id, $glyph) = @_;

    $self->region_panel->clear_selection();
#    for my $ent ($self->selected_features)
#    {
#	my($sid, $sg) = @$ent;
#	$sg->selected(0);
#    }
    $self->clear_selected_features();
    $glyph->selected(1);
    $self->add_selected_feature([$id, $glyph]);
    $self->Refresh();
}

sub view_in_seedviewer
{
    my($self, $id) = @_;
    print "View in seedviewer $id\n";
    my $url = "http://seed-viewer.theseed.org/linkin.cgi?id=$id";
    WebBrowser::open($url);
}

sub get_psiblast_info
{
    my($self, $id, $method) = @_;
    my $info = $self->psiblast_cache->{$id};
    if (!defined($info))
    {
	my $trans;
	if (SeedUtils::genome_of($id) eq $self->browser->current_genome)
	{
	    $trans = $self->browser->seedv->get_translation($id);
	}
	else
	{
	    my $res = $self->sap->ids_to_sequences(-ids => [$id], -protein => 1);
	    $trans = $res->{$id};
	}

	print "psiblast $trans\n";

	#
	# Time to fire up the psiblast helper.
	#

	my $handle = "CB." . gettimeofday;
	my $output;

 	my $dialog = Wx::Dialog->new(undef, -1, "NCBI Psiblast Progress");
	
 	my $sizer = Wx::BoxSizer->new(wxVERTICAL);
 	my $msg = wxPerl::StaticText->new($dialog, "");
 	$sizer->Add($msg, 0, wxLEFT | wxTOP, 16);
	
 	my $gauge = wxPerl::Gauge->new($dialog, 10, style => wxGA_HORIZONTAL);
 	$sizer->Add($gauge, 0, wxLEFT | wxRIGHT | wxTOP | wxEXPAND, 16);
	
 	my $bsizer = $dialog->CreateButtonSizer(wxCANCEL);
 	$sizer->Add($bsizer, 0, wxALIGN_RIGHT | wxALL, 8);
	
 	$dialog->SetSizer($sizer);
 	$dialog->Layout();
	$sizer->Fit($dialog);

#        $::run = IPC::Run::start(["dtr_helper_psiblast", $handle, $self->notify_server->port],
#				  "<", \$trans,
#				  ">", \$output);

#	my($fh, $file) = tempfile();
#	print $fh ">$id\n$trans\n";
#	close($fh);

	my $evt_id = Wx::NewId();
	my $proc = Wx::Process->new($self, $evt_id);
	$proc->Redirect();

	my $pid;
	my $cancelled;
	EVT_BUTTON($dialog, wxID_CANCEL, sub {
	    print "CANCEL dialog $pid " . wxSIGTERM . "\n";
	    $cancelled = 1;
	    if ($pid)
	    {
		my $rc = kill(15, $pid);
		print "Kill on $pid returns $rc\n";
	    }
	    $dialog->Destroy();
	});
 	$dialog->Show();

	
	$self->notify_server->set_callback($handle, sub {
	    my($handle, $data) = @_;
	    if ($data)
	    {
		for my $ent (@$data)
		{
		    my($key, $value) = @$ent;
		    if ($key eq 'status')
		    {
			$msg->SetLabel($value);
		    }
		    elsif ($key eq 'progress_range')
		    {
			if ($value == -1)
			{
			    $gauge->Pulse();
			}
			else
			{
			    $gauge->SetRange($value);
			}
		    }
		    elsif ($key eq 'progress_value')
		    {
			$gauge->SetValue($value);
		    }
		}
	    }
	});
	EVT_END_PROCESS($self, $evt_id, sub {
	    if ($cancelled)
	    {
		print "Process finished after cancel\n";
	    }
	    else
	    {
		print "Process finished\n";
		
		my $in = $proc->GetInputStream();
		print "in=$in\n";
		my $buf;
		#	    my $n = $out->Read($buf, 10000);
		my $rid = <$in>;
		chomp $rid;
		my $cid = <$in>;
		chomp $cid;
		print "rid=$rid cid=$cid'\n";
		$self->psiblast_cache->{$id} = [$rid, $cid];
		$dialog->Destroy();
		undef $dialog;
		if (defined($method))
		{
		    $self->$method($id);
		}
	    }
	});

	my $helper = "dtr_helper_psiblast";
	#
	# win32 can't find .cmd in the path without the full name.
	#
	if ($^O =~ /win32/i)
	{
	    $helper .= ".cmd";
	}
	$pid = Wx::ExecuteCommand("$helper $handle " . $self->notify_server->port, wxEXEC_ASYNC, $proc);
	my $out = $proc->GetOutputStream();
	if (!defined($out))
	{
	    warn "Could not run helper\n";
	}
	else
	{
	    print "out=$out\n";
	    print $out ">$id\n$trans\n";
	}
	$proc->CloseOutput();

	return;
    }
    return $info;
}

sub view_psiblast
{
    my($self, $id) = @_;
    my $info = $self->get_psiblast_info($id, 'view_psiblast');
    if (!defined($info))
    {
	#Wx::MessageBox("Could not retrieve PSIBLAST information from NCBI.",
	#	       "NCBI Error");

	#
	# handled by async stuff
	#
 		       
	return;
    }
       
    $self->psiblast->show_psiblast(@$info);
}

sub view_domain
{
    my($self, $id) = @_;
    my $info = $self->get_psiblast_info($id, 'view_domain');
    if (!defined($info))
    {
	#Wx::MessageBox("Could not retrieve PSIBLAST information from NCBI.",
	#	       "NCBI Error");
	
	#
	# handled by async stuff
	#
	return;
    }
       
    $self->psiblast->show_cdd($info->[1]);
}

sub browser_change
{
    my($self, $browser, $peg) = @_;
    print "Change: browser=$browser peg=$peg\n";

    $self->peg_txt->SetLabel($peg);
    $self->genome_txt->SetLabel($browser->current_genome);
    $self->function_txt->SetLabel($browser->current_function);
    $self->function_box->Layout();
    
    #
    # Determine if we have a genbank file.
    # GB file lives in the doc dir that also contains the org dir.
    #
    my $gb_file = $self->browser->seedv->organism_directory() . "/../genbank_file";
    if (-f $gb_file)
    {
	$self->genbank_file($gb_file);
	map { $_->Enable() } @{$self->genbank_dep_buttons};
    }
    else
    {
	map { $_->Disable() } @{$self->genbank_dep_buttons};
    }

    $self->Refresh();
    $self->Update();
    $self->update_region();

}

sub update_region
{
    my($self) = @_;
    $self->browser->compute_region();
    $self->region_panel->update_tracks($self->browser->region);
    $self->clear_selected_features();
}
    
sub change_assignment
{
    my($self) = @_;
    my $fn = $self->new_function_txt->GetValue();

    print "Got function value $fn\n";

    my $peg = $self->browser->current_peg;
    $self->browser->seedv->assign_function($peg, undef, $fn);
    $self->browser->set_peg($peg);
}

sub assign_function_to_focus_from
{
    my($self, $from_id, $fn) = @_;

    my $peg = $self->browser->current_peg;
    $self->browser->seedv->add_annotation($peg, undef, "Assign from peg $from_id");
    $self->browser->seedv->assign_function($peg, undef, $fn);
    $self->browser->set_peg($peg);
}

sub assign_function_to_selected_from
{
    my($self, $from_id, $fn, $selected_peg) = @_;

    my $peg = $selected_peg;
    $self->browser->seedv->add_annotation($peg, undef, "Assign from peg $from_id");
    $self->browser->seedv->assign_function($peg, undef, $fn);
    $self->update_region();
}

sub find_gene_in_selection
{
    my($self, $id, $pattern_glyph, $selected_info) = @_;
    my($selected_id, $selected_glyph) = @$selected_info;

    #
    # Pull dna from the intergenic region (selected glyph)
    #
    my $contig = $selected_glyph->contig;
    my $len = $self->browser->seedv->contig_ln($contig);

    my $beg = $selected_glyph->begin - 2000;
    $beg = 1 if $beg < 1;
    my $end = $selected_glyph->end + 2000;
    $end = $len if $end > $len;

    my $dna = $self->browser->seedv->dna_seq(join("_", $contig, $beg, $end));
    print "match $contig $beg-$end dna=$dna\n";

    my $res = $self->sap->ids_to_sequences(-ids => [$id], -protein => 1);
    my $prot = [$id, undef, $res->{$id}];
    print "template protein=" . Dumper($prot);

    my $params =  {
	family => [$prot],
	is_term => ['TAA','TAG','TGA' ],
    };
    my $frag = [$contig, $beg, $end, $dna];
    my($new_loc, $new_trans, undef, $new_anno) = &FS_RAST::best_match_in_family($params, $frag);
    print "Result: ". Dumper($new_loc, $new_trans, $new_anno);

    if ($new_loc)
    {
	
	my $new_id = $self->browser->seedv->add_feature(undef, $self->browser->current_genome, 'peg',
							$new_loc, "", $new_trans);
	if ($new_id)
	{
	    print "Created $new_id\n";
	    $self->browser->seedv->add_annotation($new_id, undef, "created new feature based on $id and location $contig $beg-$end");
	    $self->browser->seedv->add_annotation($new_id, undef, $new_anno) if $new_anno;
	    my $fn = $pattern_glyph->function;
	    if ($fn ne '')
	    {
		$self->browser->seedv->assign_function($new_id, undef, $fn);
	    }
	    $self->update_region();
	}
    }
    else
    {
	Wx::MessageBox("Could not find a match for id $id in the specified region.",
		       "No gene found");
    }
}

sub find_peg
{
    my($self) = @_;
    my $peg = $self->find_peg_txt->GetValue();
    $peg =~ s/^\s*//;
    $peg =~ s/\s*$//;

    my $genome = $self->browser->current_genome();

    my $dest;
    
    if ($peg =~ /^\d+$/)
    {
	$dest = "fig|$genome.peg.$peg";
    }
    elsif ($peg =~ /^(peg|rna)\.\d+$/)
    {
	$dest = "fig|$genome.$peg";
    }
    elsif ($peg =~ /fig\|(\d+\.\d+).*/)
    {
	if ($1 eq $genome)
	{
	    $dest = $peg;
	}
	else
	{
	    #
	    # Try to find in correpsondences
	    #
	    my $c = $self->browser->seedv->get_correspondences_rev($peg);
	    if ($c && @$c)
	    {
		$dest = $c->[0]->id1;
	    }
	}
    }
    elsif ($peg =~ /^(\S+):(\d+)$/)
    {
	#
	# Find by contig location
	#

	my $contig = $1;
	my $loc = $2;
	my ($ids, $l1, $l2) = $self->browser->seedv->genes_in_region($contig, $loc - 100, $loc + 100);
	print Dumper($ids);
	my $best = min { $_->[5] },
		map { my($c, $start, $stop, $dir) = SeedUtils::parse_location($self->browser->seedv->feature_location($_));
		      my $x = [$_, $c, $start, $stop, $dir, abs($stop - $loc)];
		      print Dumper($x);
		      $x;
		  } @$ids;
	if (defined($best))
	{
	    $dest = $best->[0];
	}
    }
    
    if (defined($dest))
    {
	$self->browser->set_peg($dest);
    }
    else
    {
	Wx::MessageBox("Could not find $peg",
		       "Not found");
    }
	
}

sub edit_assignment
{
    my($self) = @_;

    my $peg = $self->browser->current_peg();
    my $func = $self->browser->current_function();

    my $d = Wx::Dialog->new($self, -1, "Edit Function",
			    wxDefaultPosition,
			    Wx::Size->new(400, 200),
			    wxDEFAULT_DIALOG_STYLE | wxRESIZE_BORDER);
    my $sz = Wx::BoxSizer->new(wxVERTICAL);
    $d->SetSizer($sz);

    $sz->Add(wxPerl::StaticText->new($d, "Edit function for $peg:"));

    my $txt = wxPerl::TextCtrl->new($d, "$func");
    $sz->Add($txt, 0, wxEXPAND);
    
    my $buttons = $d->CreateButtonSizer(wxOK | wxCANCEL | wxCENTRE);
    $sz->Add($buttons);

    my $ret = $d->ShowModal();
    if ($ret == wxID_OK)
    {
	my $new = $txt->GetValue();
	print "Assigned $new\n";
	$self->browser->seedv->assign_function($peg, undef, $new);
	$self->browser->set_peg($peg);
    }
    else
    {
	print "Canceled edit\n";
    }
}

sub show_genbank_comparison
{
    my($self) = @_;

    my $seedv = $self->browser->seedv;
    my $dir = $seedv->organism_directory();

    my $comp_out = "$dir/genbank_comp.tbl";
    my $comp_sum = "$dir/genbank_comp.summary";

    if (! -f $comp_out || ! -f $comp_sum)
    {
	$self->compute_genbank_comparison();
    }
    my $frame = GenbankComparisonFrame->new(title => "myRAST - Genbank comparison for " . $seedv->genome_id,
					    browser => $self->browser,
					    summary_file => $comp_sum,
					    table_file => $comp_out,
					    genome_id => $seedv->genome_id);
    $frame->Show();
}

sub compute_genbank_comparison
{
    my($self) = @_;
    
    my $seedv = $self->browser->seedv;
    my $dir = $seedv->organism_directory();
    if ($^O =~ /win32/i)
    {
	$dir = Win32::GetShortPathName($dir);
    }
    
    my $seedv_file = "$dir/seedv_data.tbl";
    if (open(my $fh, ">", $seedv_file))
    {
	$seedv->write_features_for_comparison($fh);
	close($fh);
    }
    else
    {
	Wx::MessageBox("Could not write data file $seedv_file",
		       "Error");
	return;
    }

    #
    # Parse Genbank & write comparison
    #

    my $gb_parsed = "$dir/genbank_data.tbl";
    my $res = IPC::Run::run(["svr_genbank_to_table"], "<", $self->genbank_file, ">", $gb_parsed);
    if (!$res)
    {
	Wx::MessageBox("Error parsing genbank: $!",
		       "Error");
	return;
    }

    my $comp_out = "$dir/genbank_comp.tbl";
    my $comp_sum = "$dir/genbank_comp.summary";
    $res = IPC::Run::run(["svr_compare_feature_tables", $gb_parsed, $seedv_file, $comp_sum], ">", $comp_out);
}

sub perform_export
{
    my($self) = @_;
    
    my $frame = wxPerl::Frame->new(undef, "myRAST - Export",
				  size => Wx::Size->new(600,600));
#				  size => Wx::Size->new(800, 1000));

    my $sz = Wx::BoxSizer->new(wxVERTICAL);
    $frame->SetSizer($sz);

    my $note = wxPerl::Notebook->new($frame);
    $sz->Add($note, 1, wxEXPAND | wxALL, 5);

    my $feature_panel = ExportFeaturePanel->new(parent => $note, seedv => $self->browser->seedv);
    $note->AddPage($feature_panel, "Export Features");

    my $subsys_panel = ExportSubsystemsPanel->new(parent => $note, seedv => $self->browser->seedv);
    $note->AddPage($subsys_panel, "Export Subsystems");

    my $bsz = Wx::BoxSizer->new(wxHORIZONTAL);
    $sz->Add($bsz, 0, wxEXPAND | wxALL, 5);
    $b = wxPerl::Button->new($frame, "Export", id => wxID_OK);
    $bsz->Add($b);
    EVT_BUTTON($frame, $b, sub {
	my $p = $note->GetCurrentPage();
	my $ok = 0;
	print "EXPORT p=$p\n";
	if (defined($p))
	{
	    $ok = $p->perform_export();
	}
	if ($ok)
	{
	    print "Closing frame ok=$ok\n";
	    $frame->Close();
	}
	else
	{
	    #
	    # On windows, if this fails we want to re-raise
	    # the frame otherwise it vanishes.
	    #
	    $frame->Raise();
	    $frame->Iconize(0);
	}
    });
    
    my $b = wxPerl::Button->new($frame, "Cancel", id => wxID_CANCEL);
    $bsz->Add($b);
    EVT_BUTTON($frame, $b, sub {
	$frame->Close();
    });
    
#    $note->fit_to($frame);
    $sz->SetSizeHints($frame);
    $frame->Show();
    return 1;
}

sub copy_feature_dna
{
    my($self, $id) = @_;

    my $sv = $self->browser->seedv;

    my($dna, $fn);
    if (SeedUtils::genome_of($id) eq $self->browser->current_genome)
    {
	my $loc = $sv->feature_location($id);
	$dna = $sv->dna_seq($loc);
	$fn = $sv->function_of($id);
    }
    else
    {
	my $res = $self->sap->ids_to_sequences(-ids => [$id]);
	my $fnres = $self->sap->ids_to_functions(-ids => [$id]);

	$dna = $res->{$id};
	$fn = $fnres->{$id};
    }

    my $fh;
    my $buf;
    open($fh, ">", \$buf);
    gjoseqlib::print_alignment_as_fasta($fh, [[$id, $fn, $dna]]);
    close($fh);

    if ($^O =~ /win32/i)
    {
	$buf =~ s/\n/\r\n/g;
    }
	
    wxTheClipboard->Open();
    my $res = wxTheClipboard->SetData(Wx::TextDataObject->new($buf . "\0"));
    wxTheClipboard->Close();
    
}

sub copy_feature_translation
{
    my($self, $id) = @_;

    my $sv = $self->browser->seedv;

    my($trans, $fn);
    if (SeedUtils::genome_of($id) eq $self->browser->current_genome)
    {
	$trans = $sv->get_translation($id);
	$fn = $sv->function_of($id);
    }
    else
    {
	my $res = $self->sap->ids_to_sequences(-ids => [$id], -protein => 1);
	my $fnres = $self->sap->ids_to_functions(-ids => [$id]);

	$trans = $res->{$id};
	$fn = $fnres->{$id};
    }

    my $fh;
    my $buf;
    open($fh, ">", \$buf);
    gjoseqlib::print_alignment_as_fasta($fh, [[$id, $fn, $trans]]);
    close($fh);

    if ($^O =~ /win32/i)
    {
	$buf =~ s/\n/\r\n/g;
    }
	
    wxTheClipboard->Open();
    my $res = wxTheClipboard->SetData(Wx::TextDataObject->new($buf . "\0"));
    wxTheClipboard->Close();
    
}

sub selection_to_filehandle
{
    my($self, $fh) = @_;
    
    my $this_genome = $self->browser->current_genome;
    my($mine, $others) = part { SeedUtils::genome_of($_) eq $this_genome ? 0 : 1 } $self->region_panel->selected_ids;

    for my $id (@$mine)
    {
	my $trans = $self->browser->seedv->get_translation($id);
	gjoseqlib::print_alignment_as_fasta($fh, [[$id, undef, $trans]]);
    }
}

sub align_selection
{
    my($self) = @_;

}


1;

