package ArrowGlyph;

=head1 NAME

ArrowGlyph - a genome display glyph

=cut

use Moose;

use Glyph;
extends 'Glyph';

use Wx ':everything';

sub render
{
    my($self, $panel, $dc, $off_x, $off_y) = @_;

    #
    # X offsets now dealt with in the overall contig->display transform
    # in $track->translate_x().
    #
    
    $off_x = 0;

    $self->set_color($dc);

    my $b = $self->track->translate_x($self->begin);
    my $e = $self->track->translate_x($self->end);

    #
    # We set $flip if we need to reverse coordinates. We
    # start out with it set, because the coords as written
    # below draw the arrow to the left, and the normal case
    # is drawing the arrow to the right.
    #

    my $flip = 1;

    #
    # If the translation flipped the direction, this means
    # the track was reversed, so we need to reverse the flip state.
    #
    if ($b > $e)
    {
	($b, $e) = ($e, $b);
	$flip = !$flip;
    }

    #
    # If the direction of the glyph is negative,
    # flip again.
    #
    if ($self->direction < 0)
    {
	$flip = !$flip;
    }


    my $h = int($self->height);

    my $back = 4;
    my $depth = 10;

    my $pointx = $b + $depth;
    my $h2 = int($self->height / 2);

    my $s_top = $h - $back;
    my $s_bot = $back;

    my @coords;
    if (($e - $b) > $depth)
    {
	@coords = ([$b, $h2],
		   [$pointx, $h],
		   [$pointx, $s_top],
		   [$e, $s_top],
		   [$e, $s_bot],
		   [$pointx, $s_bot],
		   [$pointx, 0],
		  );
    }
    else
    {
	@coords = ([$b, $h2],
		   [$e, $h],
		   [$e, 0]);
    }
    #
    # And flip the glyph if required.
    #
    if ($flip)
    {
	my $c = ($b + $e) / 2;
	map { $_->[0] = 2 * $c - $_->[0] } @coords;
    }

    my @pts = map { Wx::Point->new(@$_) } @coords;

    $dc->DrawPolygon(\@pts, $off_x, $off_y);
}

1;

