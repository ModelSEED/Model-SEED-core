package ExportSubsystemsPanel;

use Moose;
use MooseX::NonMoose;

use IPC::Run;

use Data::Dumper;

use wxPerl::Constructors;
use Wx qw(:sizer :everything);

use Wx::Event qw(EVT_BUTTON EVT_SPINCTRL EVT_TEXT_ENTER EVT_CLOSE EVT_MENU EVT_END_PROCESS
		 EVT_COMBOBOX);

extends 'Wx::Panel';

=head1 NAME

ExportSubsystemPanel - wxPanel that holds the subsystem export GUI.

=cut


has 'seedv' => (isa => 'SeedV',
		is => 'ro');

has 'format_options' => (isa => 'ArrayRef',
			 is => 'ro',
			 default => sub { [['tabsep', 'Tab-separated text', [["txt", "Text files (*.txt)|*.txt"]], 'export_tabsep'],
#					   ['xls', 'XLS', [["xls", "Excel files (*.xls)|*.xls"]], 'export_xls'],
					   ['csv', 'Comma-separated text',
					    [["csv", 'CSV files (*.csv)|*.csv'],
					     ["txt", 'Text files (*.txt)|*.txt']
					     ], 'export_csv'],
					   ] },
			);



#
# UI elements.
#

has 'sizer' => (isa => 'Wx::Sizer', is => 'rw');

has 'ui_format' => (isa => 'Wx::ComboBox',
		    is => 'rw');

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

    if ($sel < 0)
    {
	Wx::MessageBox("Please select an export format.","Error");
	return 0;
    }

    my $dat = $self->format_options->[$sel];

    my($name, $desc, $suffix_list, $method) = @$dat;

    my $wildcard = join("|", map { $_->[1] } @$suffix_list);
    
    my $dlg = Wx::FileDialog->new($self, "Export subsystems",
				  File::HomeDir->my_documents,
				  "",
				  $wildcard,
				  wxFD_SAVE | wxFD_OVERWRITE_PROMPT);
    
    my $rc = $dlg->ShowModal();

    if ($rc == wxID_OK)
    {
	my $file = $dlg->GetPath();
	my $idx = $dlg->GetFilterIndex();
	my $ext = $suffix_list->[$idx];
	if ($ext)
	{
	    $ext = $ext->[0];

	    if ($file !~ /\.$ext$/)
	    {
		$file .= ".$ext";
	    }
	    return $self->write_export($file, $name);
	}
	return 0;
    }

    return 0;
}

sub write_export
{
    my($self, $file, $output_type) = @_;
    print "Export $output_type to $file\n";

    my $fh;
    if (!open($fh, ">", $file))
    {
	Wx::MessageBox("Cannot open $file for writing: $!",
		       "Write error");
	return 0;
    }

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

    my $dat = $self->seedv->get_genome_subsystem_data();

    for my $ent (@$dat)
    {
	next unless defined($ent);
	my($ss, $role, $fid) = @$ent;

	if ($columnar)
	{
	    my @cols = map { /$sep/ ? qq("$_") : $_ } ($ss, $role, $fid);
	    
	    print $fh join($sep, @cols) . $recsep;
	}
    }
    close($fh);
    return 1;
    
}


1;

