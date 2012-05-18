package AnalyzeMGPanel;

use Moose;
use MooseX::NonMoose;

with 'PipelineHost';

use POSIX;
use IPC::Run;
use Time::HiRes 'gettimeofday';
use File::Temp 'tempfile';

eval {
    require Win32;
};

use Data::Dumper;

use ViewableFile;
use PipelineStage;
use SampleAnalysisPanel;
use SampleDir;

use wxPerl::Constructors;
use Wx::Grid;
use Wx::Html;
use Wx::DND;
use Wx qw(:sizer :everything :dnd wxTheClipboard);

use Wx::Event qw(EVT_BUTTON EVT_SPINCTRL EVT_TEXT_ENTER EVT_CLOSE EVT_MENU EVT_END_PROCESS
		 EVT_COMBOBOX EVT_TIMER);

use SAPserver;

extends 'Wx::Panel';

=head1 NAME

AnalyzeMGPanel

=head1 DESCRIPTION

Shows the process of a MG analysis run. Created from either the
initial upload dialog or from the analysis summary dialog
and the user has added a new analysis.

=cut

has 'sample' => (is => 'ro',
		 isa => 'SampleDir',
		 required => 1);

has 'ui_kmer' => (is => 'rw',
		  isa => 'Wx::ComboBox');

has 'ui_max_gap' => (is => 'rw',
		     isa => 'Wx::ComboBox');
		  
has 'ui_min_hits' => (is => 'rw',
		      isa => 'Wx::ComboBox');

has 'ui_progress' => (is => 'rw',
		      isa => 'Wx::Gauge');

has 'ui_start_button' => (is => 'rw',
			 isa => 'Wx::Button');

has 'ui_view_button' => (is => 'rw',
			 isa => 'Wx::Button');

has 'timer' => (is => 'rw',
		isa => 'Wx::Timer');

has 'process' => (is => 'rw',
		  isa => 'PipelineStage');

has 'config_element_list' => (is => 'ro',
			      isa => 'ArrayRef[Wx::Control]',
			      default => sub { [] },
			      traits => ['Array'],
			      handles => {
				  add_config_element => 'push',
				  config_elements => 'elements',
			      });
				      
has 'generated_dataset' => (is => 'rw',
			    isa => 'Str');
has 'generated_index' => (is => 'rw',
			  isa => 'Num');


sub FOREIGNBUILDARGS
{
    my($self, %args) = @_;

    return ($args{parent}, -1);
};

sub BUILD
{
    my($self) = @_;

    my $top_sizer = Wx::BoxSizer->new(wxVERTICAL);
    $self->SetSizer($top_sizer);

    #
    # Feature info stuff is inside the FlexGridSizer $flex
    #

    my $flex = Wx::FlexGridSizer->new(4, 2, 5, 5);
    $top_sizer->Add($flex, 0, wxEXPAND | wxALL, 5);

    $self->add_param_static($flex, "Sample name:", $self->sample->name);
    $self->add_param_static($flex, "Description:", $self->sample->description);

    my $stats = $self->sample->get_statistics();
    $self->add_param_static($flex, "Sample count:", $stats->{count});
    $self->add_param_static($flex, "DNA size:", $stats->{total_size});
    $self->add_param_static($flex, "Min size:", $stats->{min});
    $self->add_param_static($flex, "Max size:", $stats->{max});
    $self->add_param_static($flex, "Median size:", sprintf("%.1f", $stats->{median}));
    $self->add_param_static($flex, "Mean size:", sprintf("%.1f", $stats->{mean}));
    $self->add_param_static($flex, "GC content:", sprintf("%.1f%%", $stats->{gc_content}));
    $self->add_param_combo($flex, "Kmer size:", "kmer", 8, [7..12], style => wxCB_READONLY);
    $self->add_param_combo($flex, "Max gap:", "max_gap", 600, [100,200,300,600]);
    $self->add_param_combo($flex, "Min hits:", "min_hits", 3, [1..10]);
    $self->add_config_element($self->ui_kmer);
    $self->add_config_element($self->ui_max_gap);
    $self->add_config_element($self->ui_min_hits);

    my $b = wxPerl::Button->new($self, "Process sample");
    EVT_BUTTON($self, $b, sub { $self->start_processing(); });
    $flex->Add($b);
    $self->ui_start_button($b);
    $self->add_config_element($b);

    $b = wxPerl::Button->new($self, "View analysis");
    EVT_BUTTON($self, $b, sub { $self->view_analysis(); });
    $b->Enable(0);
    $flex->Add($b);
    $self->ui_view_button($b);

    my $gauge = wxPerl::Gauge->new($self, 10, style => wxGA_HORIZONTAL);
    $flex->Add($gauge, 0, wxEXPAND);
    $self->ui_progress($gauge);
}

sub add_param_combo
{
    my($self, $sizer, $text, $key, $default, $choices, @opts) = @_;

    $sizer->Add(wxPerl::StaticText->new($self, $text));
    my $t = wxPerl::ComboBox->new($self,
				  value => $default,
				  choices => $choices,
				  @opts);
    $sizer->Add($t);
    my $uk = "ui_$key";
    $self->$uk($t);
}

sub add_param_static
{
    my($self, $sizer, $text, $val) = @_;

    $sizer->Add(wxPerl::StaticText->new($self, $text));
    my $t = wxPerl::StaticText->new($self, $val);
    $sizer->Add($t, 0, wxEXPAND);
}

sub DEMOLISH
{
    my($self) = @_;

}

sub window_closing
{
    my($self, $event) = @_;
    print "Close $event\n";
}

sub start_processing
{
    my($self) = @_;
    
    $_->Enable(0) for $self->config_elements();

    my $kmer = $self->ui_kmer->GetValue();
    my $max_gap = $self->ui_max_gap->GetValue();
    my $min_hits = $self->ui_min_hits->GetValue();

    # hack
    my @url = ();
    # @url = (-url => "http://bioseed.mcs.anl.gov/~olson/FIG/anno_server.cgi");

    my $process = PipelineStage->new(rast => $self,
				     key => "process_sample." . time,
				     name => "Process sample",
				     program => "dtr_process_sample",
				     args => [$self->sample->dir,
					      -kmer => $kmer,
					      -maxGap => $max_gap,
					      -minHits => $min_hits,
					      @url],
				     dir => $self->sample->dir);
    $self->process($process);

    my $timer = Wx::Timer->new($self);
    
    EVT_TIMER($self, $timer, sub {
	my $all_done = $self->check_pipeline();

	if ($all_done)
	{
	    $timer->Stop();
	    print "Pipeline done\n";

	    if (open(my $fh, "<", $process->output_file))
	    {
		while (<$fh>)
		{
		    chomp;
		    if (/^dataset\t([^\t]+)\t(\d+)/)
		    {
			print "Generated dataset '$1' and index '$2'\n";
			$self->generated_dataset($1);
			$self->generated_index($2);
		    }
		}
	    }
	    
	    $self->ui_progress->SetValue(10);
	    $self->ui_view_button->Enable(1);
	}
	else
	{
	    $self->ui_progress->Pulse();
	}
    });

    $self->timer($timer);
    $timer->Start(100);
    $process->start();
}

sub check_pipeline
{
    my($self) = @_;
    my $all_done = 1;
    for my $stage ($self->process)
    {
	my $state = $stage->check_for_completion();
	$all_done = 0 unless $state eq 'complete';
    }
    return $all_done;
}

sub view_analysis
{
    my($self) = @_;

    my $sample = SampleDir->new($self->sample->dir());

    my $frame = wxPerl::Frame->new(undef, "View sample " . $sample->name(),
				  size => Wx::Size->new(600,600));
#				  size => Wx::Size->new(800, 1000));

    my $menubar = Wx::App::GetInstance()->default_menubar();
    $frame->SetMenuBar($menubar);

    my $panel = SampleAnalysisPanel->new(parent => $frame,
					 sample => $sample,
					 analysis_dataset => $self->generated_dataset(),
					 analysis_index => $self->generated_index(),
					);
    $frame->Show();
}

1;

