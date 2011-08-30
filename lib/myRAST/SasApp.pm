package SasApp;

use Moose;
use MooseX::NonMoose;

use Wx;
extends 'Wx::App';

use DesktopRastFrame;
use DesktopRast;

sub OnInit
{
    my($self) = @_;

    my $rast = DesktopRast->new();
    my $fr = DesktopRastFrame->new(title => "foo", rast => $rast,
				  size => Wx::Size->new(700,700));
    $fr->Show(1);
    return 1;
}

1;
