package IntergenicGlyph;

=head1 NAME

IntergenicGlyph - a genome display glyph

=cut

use Moose;

use Glyph;
extends 'Glyph';

use Wx ':everything';

override 'render' => sub {

    my($self, $panel, $dc, $off_x, $off_y) = @_;

    if ($self->selected)
    {
	super();
    }

};

1;

