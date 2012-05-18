package NewSampleFrame;

use SeedV;
use SeedUtils;
use Data::Dumper;
use File::HomeDir;
use File::Basename;
use File::Path;

use myRAST;
use AnalyzeMGPanel;

use Moose;
use MooseX::NonMoose;

use wxPerl::Constructors;
use Wx qw(:sizer :everything);
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX EVT_COMBOBOX EVT_TIMER EVT_LIST_ITEM_ACTIVATED);

extends 'Wx::Frame';

has 'panel' => (is => 'rw',
		isa => 'Object');

has 'file' => (is => 'rw',
	       isa => 'Str');

has 'ui_name' => (is => 'rw',
		  isa => 'Wx::TextCtrl');

has 'ui_description' => (is => 'rw',
			 isa => 'Wx::TextCtrl');

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

    my $flex = Wx::FlexGridSizer->new(0, 2, 5, 5);
    $flex->AddGrowableCol(1);

    $top_sz->Add($flex, 0, wxEXPAND | wxALL, 5);

    my $r1_box = Wx::BoxSizer->new(wxHORIZONTAL);

    $flex->Add(wxPerl::StaticText->new($panel, "Data file:"));
    $flex->Add($r1_box, 0, wxEXPAND);

    my $browse_but = wxPerl::Button->new($panel, "Browse");

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
	    $self->file($file);
	}
    });

    $flex->Add(wxPerl::StaticText->new($panel, "Sample name: "));
    my $t = wxPerl::TextCtrl->new($panel, "");
    $self->ui_name($t);
    $flex->Add($t, 0, wxEXPAND);

    $flex->Add(wxPerl::StaticText->new($panel, "Sample description: "));
    $t = wxPerl::TextCtrl->new($panel, "",
			       style => wxTE_MULTILINE);
    $self->ui_description($t);
    $flex->Add($t, 0, wxEXPAND);

    my $sub_button = wxPerl::Button->new($panel, "Load sample");
    EVT_BUTTON($panel, $sub_button, sub { $self->load(); });
    $top_sz->Add($sub_button);
}

sub load
{
    my($self) = @_;

    my $name = $self->ui_name->GetValue();
    my $desc = $self->ui_description->GetValue();

    my $file = $self->file;

    print "file=$file name=$name desc='$desc'\n";

    my $nbase = $name;
    $nbase =~ s/\s+/_/g;

    my $num = '1';
    my $dir;
    while (1)
    {
	my $p = myRAST->instance->doc_dir . "/$nbase.$num";
	if (! -e $p)
	{
	    $dir = $p;
	    last;
	}
	$num++;
    }

    print "Save to $dir\n";

    my $sample = SampleDir->create($dir, $file, $name, $desc);

    my $frame = wxPerl::Frame->new(undef, "myRAST",
				  size => Wx::Size->new(600,600));
#				  size => Wx::Size->new(800, 1000));

    my $panel = AnalyzeMGPanel->new(parent => $frame,
				    sample => $sample,
				   );

    $frame->Show(1);

    $self->Destroy();

}

1;
