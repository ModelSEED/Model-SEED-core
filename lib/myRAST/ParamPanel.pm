package ParamPanel;


use Moose;
use MooseX::NonMoose;


use Data::Dumper;

use wxPerl::Constructors;
use Wx qw(:sizer :everything :dnd wxTheClipboard);

use Wx::Event qw(EVT_BUTTON EVT_SPINCTRL EVT_TEXT_ENTER EVT_CLOSE EVT_MENU EVT_END_PROCESS
		 EVT_COMBOBOX EVT_TIMER);

extends 'Wx::Panel';

=head1 NAME

ParamPanel

=head1 DESCRIPTION

Panel superclass that has a Nx2 flex sizer for param/value pairs.

=cut

has 'config_element_list' => (is => 'ro',
			      isa => 'ArrayRef[Wx::Control]',
			      default => sub { [] },
			      traits => ['Array'],
			      handles => {
				  add_config_element => 'push',
				  config_elements => 'elements',
			      });

has 'top_sizer' => (is => 'rw',
		    isa => 'Wx::Sizer');

has 'param_sizer' => (is => 'rw',
		      isa => 'Wx::Sizer');

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
    $self->top_sizer($top_sizer);

    #
    # Feature info stuff is inside the FlexGridSizer $flex
    #

    my $flex = Wx::FlexGridSizer->new(0, 2, 5, 5);
    $top_sizer->Add($flex, 0, wxEXPAND | wxALL, 5);
    $self->param_sizer($flex);
}

sub add_param_combo
{
    my($self, $text, $key, $default, $choices, @opts) = @_;

    $self->param_sizer->Add(wxPerl::StaticText->new($self, $text));
    my $t = wxPerl::ComboBox->new($self,
				  value => $default,
				  choices => $choices,
				  @opts);
    $self->param_sizer->Add($t);
    my $uk = "ui_$key";
    __PACKAGE__->meta->add_attribute($uk => (is => 'rw', isa => 'Wx::ComboBox'));
    $self->$uk($t);
}

sub add_param_static
{
    my($self, $text, $key, $val) = @_;

    $self->param_sizer->Add(wxPerl::StaticText->new($self, $text));
    my $t = wxPerl::StaticText->new($self, $val);
    $self->param_sizer->Add($t, 0, wxEXPAND);
    my $uk = "ui_$key";
    __PACKAGE__->meta->add_attribute($uk => (is => 'rw', isa => 'Wx::StaticText'));
    $self->$uk($t);
}

sub DEMOLISH
{
    my($self) = @_;

}

1;

