package ExportFeaturePanel;

use Moose;
use MooseX::NonMoose;

use IPC::Run;
use gjoseqlib;

use Data::Dumper;

use wxPerl::Constructors;
use Wx qw(:sizer :everything);

use Wx::Event qw(EVT_BUTTON EVT_SPINCTRL EVT_TEXT_ENTER EVT_CLOSE EVT_MENU EVT_END_PROCESS
		 EVT_COMBOBOX);

extends 'Wx::Panel';

=head1 NAME

ExportFeaturePanel - wxPanel that holds the feature export GUI.

=cut


has 'seedv' => (isa => 'SeedV',
		is => 'ro');

has 'feature_types' => (isa => 'ArrayRef[Str]',
			is => 'rw');

has 'format_options' => (isa => 'ArrayRef',
			 is => 'ro',
			 default => sub { [['tabsep', 'Tab-separated text', [["txt", "Text files (*.txt)|*.txt"]], 'export_tabsep'],
#					   ['xls', 'XLS', [["xls", "Excel files (*.xls)|*.xls"]], 'export_xls'],
					   ['csv', 'Comma-separated text',
					    [["csv", 'CSV files (*.csv)|*.csv'],
					     ["txt", 'Text files (*.txt)|*.txt']
					     ], 'export_csv'],
					   ['fasta', 'FASTA',
					    [["fa", 'FASTA files (*.fa)|*.fa'],
					     ["txt", 'Text files(*.txt)|*.txt'],
					     ], 'export_fasta']
					   ] },
			);

#
# UI elements.
#

has 'sizer' => (isa => 'Wx::Sizer', is => 'rw');

has 'ui_format' => (isa => 'Wx::ComboBox',
		    is => 'rw');

#
# Hash from type => WxCheckbox
#
has 'ui_feature_types' => (isa => 'HashRef[Wx::CheckBox]',
			   is => 'ro',
			   default => sub { {} },
			  );

has 'ui_include_dna' => (isa => 'Wx::CheckBox',
			 is => 'rw');

has 'ui_include_translation' => (isa => 'Wx::CheckBox',
				 is => 'rw');


sub FOREIGNBUILDARGS
{
    my($self, %args) = @_;

    return ($args{parent}, -1);
};

sub BUILD
{
    my($self) = @_;

    my @feature_types = $self->seedv->feature_types;
    $self->feature_types(\@feature_types);

    my $top_sizer = Wx::BoxSizer->new(wxVERTICAL);
    $self->SetSizer($top_sizer);
    $self->sizer($top_sizer);

    my $flex = Wx::FlexGridSizer->new(0, 2, 10, 10);
    $top_sizer->Add($flex, 0, wxALIGN_CENTRE | wxALL, 5);

    #
    # Format
    #
    $flex->Add(wxPerl::StaticText->new($self, "Format:"), 0, wxALIGN_CENTER_VERTICAL);

    my $t = wxPerl::ComboBox->new($self,
				  choices => [map { $_->[1] } @{$self->format_options}],
				  value => $self->format_options->[0]->[1],
				  style => wxCB_READONLY);
    $self->ui_format($t);
    $flex->Add($t);

    #
    # Feature types.
    #
    my $first = 1;
    for my $ftype (@feature_types)
    {
	if ($first)
	{
	    $flex->Add(wxPerl::StaticText->new($self, "Feature types:"), 0, wxALIGN_CENTER_VERTICAL);
	    $first = 0;
	}
	else
	{
	    $flex->AddSpacer(0);
	}

	my $t = wxPerl::CheckBox->new($self, $ftype);
	$flex->Add($t);
	$self->ui_feature_types->{$ftype} = $t;
    }

    #
    # Sequence types to export
    #

    $flex->Add(wxPerl::StaticText->new($self, "Include DNA:"), 0, wxALIGN_CENTER_VERTICAL);
    $t = wxPerl::CheckBox->new($self, '');
    $flex->Add($t);
    $self->ui_include_dna($t);
    
    $flex->Add(wxPerl::StaticText->new($self, "Include translations:"), 0, wxALIGN_CENTER_VERTICAL);
    $t = wxPerl::CheckBox->new($self, '');
    $flex->Add($t);
    $self->ui_include_translation($t);
}

sub fit_to
{
    my($self, $frame) = @_;
    $self->sizer->SetSizeHints($frame);
}

sub perform_export
{
    my($self) = @_;
    

    my $sel = $self->ui_format->GetSelection();
    print "sel=$sel\n";

    my @types;
    for my $type (@{$self->feature_types})
    {
	my $box = $self->ui_feature_types->{$type};
	if ($box->IsChecked())
	{
	    push(@types, $type);
	}
    }

    if (@types == 0)
    {
	Wx::MessageBox("Please select one or more feature types.","Error");
	return 0;
    }

    my $opts = {
	types => \@types,
	want_dna => $self->ui_include_dna->IsChecked(),
	want_translation => $self->ui_include_translation->IsChecked(),
    };

    print Dumper($opts);

    if ($sel < 0)
    {
	Wx::MessageBox("Please select an export format.","Error");
	return 0;
    }

    my $dat = $self->format_options->[$sel];

    my($name, $desc, $suffix_list, $method) = @$dat;

    my $wildcard = join("|", map { $_->[1] } @$suffix_list);
    
    my $dlg = Wx::FileDialog->new($self, "Export features",
				  File::HomeDir->my_documents,
				  "",
				  $wildcard,
				  wxFD_SAVE | wxFD_OVERWRITE_PROMPT);
    
    my $rc = $dlg->ShowModal();
    print "Dialog returns $rc\n";

    if ($rc == wxID_OK)
    {
	my $file = $dlg->GetPath();
	my $idx = $dlg->GetFilterIndex();
	my $ext = $suffix_list->[$idx];
	print "Got file=$file idx=$idx ext=$ext\n";
	if ($ext)
	{
	    $ext = $ext->[0];

	    if ($file !~ /\.$ext$/)
	    {
		$file .= ".$ext";
	    }
	    return $self->write_export($file, $name, $opts);
	}
	return 0;
    }

    return 0;
}

sub write_export
{
    my($self, $file, $output_type, $opts) = @_;
    print "Export $output_type to $file\n";

    my $fh;
    if (!open($fh, ">", $file))
    {
	Wx::MessageBox("Cannot open $file for writing: $!",
		       "Write error");
	return 0;
    }
    my %types = map { $_ => 1 } @{$opts->{types}};

    my $sep;
    my $recsep;
    my $columnar = 0;
    if ($output_type eq 'tabsep')
    {
	$sep = "\t";
	$recsep = "\n";
	$columnar = 1;
    }
    elsif ($output_type eq 'csv')
    {
	$sep = ",";
	$recsep = "\n";
	$columnar = 1;
    }

    my $flist = $self->seedv->all_features_detailed_fast();
    for my $ent (sort { SeedUtils::by_fig_id($a->[0], $b->[0]) } @$flist)
    {
	my($fid, $loc, undef, $type, $min, $max, $fn) = @$ent;
	next unless $types{$type};

	$fn = '' unless defined($fn);
	my $dna;
	if ($opts->{want_dna})
	{
	    $dna = $self->seedv->dna_seq($loc);
	}
	my $translation;
	if ($opts->{want_translation})
	{
	    $translation = $self->seedv->get_translation($fid);
	}

	if ($columnar)
	{
	    print $fh join($sep, $fid, $loc, $fn,
			   (defined($dna) ? $dna : ()),
			   (defined($translation) ? $translation : ()),
			   ) . $recsep;
	}
	elsif ($output_type eq 'fasta')
	{
	    if (defined($dna))
	    {
		&gjoseqlib::print_alignment_as_fasta($fh, [$fid, "$loc $fn", $dna]);
	    }
	    if (defined($translation))
	    {
		&gjoseqlib::print_alignment_as_fasta($fh, [$fid, "$loc $fn", $translation]);
	    }
	}
	
    }
    close($fh);
    return 1;
    
}


1;

