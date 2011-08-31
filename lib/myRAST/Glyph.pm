package Glyph;

=head1 NAME

Glyph - a genome display glyph

=cut

use Moose;

use Wx ':everything';

has 'panel' => (isa => 'RegionPanel',
		is => 'ro');

has 'id' => (isa => 'Str',
	     is => 'ro');

has 'function' => (isa => 'Str',
		   is => 'ro');

has 'track' => (isa => 'Track',
		is => 'ro');

has 'begin' => (isa => 'Num',
		is => 'ro');

has 'end' => (isa => 'Num',
	      is => 'ro');

has 'contig' => (isa => 'Str',
		 is => 'ro');

has 'html' => (isa => 'Str',
	       is => 'ro');

has 'direction' => (isa => 'Num',
		    is => 'ro');

has 'height' => (isa => 'Num',
		 is => 'rw',
		 default => 20);

#has 'selected' => (isa => 'Bool',
#		   is => 'rw');

has 'focus' => (isa => 'Bool',
		is => 'rw');

has 'hovered' => (isa => 'Bool',
		   is => 'rw');

has 'brush' => (isa => 'Object',
		is => 'rw');

sub selected
{
    my($self, $val) = @_;

    if (defined($val))
    {
	$self->panel->selected_id->{$self->{id}} = $val;
    }
    else
    {
	return $self->panel->selected_id->{$self->{id}};
    }
}

sub overlaps
{
    my($self, $other_glyph) = @_;

    return ($self->begin < $other_glyph->end && $other_glyph->begin < $self->end)
}

sub overlaps_position
{
    my($self, $pos) = @_;
    return $self->begin <= $pos && $pos < $self->end;
}

sub set_color
{
    my($self, $dc) = @_;
    
    if ($self->selected)
    {
	$dc->SetBrush(wxRED_BRUSH);
    }
#     elsif ($self->hovered)
#     {
# 	$dc->SetBrush(wxBLUE_BRUSH);
#     }
    elsif (defined(my $brush = $self->brush))
    {
	$dc->SetBrush($brush);
    }
    else
    {
	$dc->SetBrush(wxWHITE_BRUSH);
    }

}

sub render
{
    my($self, $panel, $dc, $off_x, $off_y) = @_;
    $off_x = 0;

    $self->set_color($dc);

    my $cscale = $panel->contig_scale;
    my $h = int($self->height);
    my $b = $self->track->translate_x($self->begin);
    my $e = $self->track->translate_x($self->end);


    my @pts = map { Wx::Point->new(@$_) }([$b, 0],
					  [$b, $h],
					  [$e, $h],
					  [$e, 0]);

    $dc->DrawPolygon(\@pts, $off_x, $off_y);
}

1;

