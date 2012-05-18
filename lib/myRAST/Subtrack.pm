package Subtrack;
use List::Util 'first';
use Data::Dumper;

=head1 NAME

Subtrack - sequence of non-overlapping glyphs

=cut

use Moose;

has 'glyph_list' => (is => 'ro',
		     isa => 'ArrayRef[Glyph]',
		     default => sub { [] },
		     traits => ['Array'],
		     handles => {
			 glyphs => 'elements',
			 push_glyph => 'push',
		     },
		);


has 'x' => (is => 'rw',
	    isa => 'Num');

has 'y' => (is => 'rw',
	    isa => 'Num');

has 'height' => (is => 'rw',
		 isa => 'Num');

has 'track' => (is => 'ro',
		isa => 'Track');

has 'panel' => (is => 'ro',
		isa => 'RegionPanel');

sub add_glyph
{
    my($self, $glyph) = @_;

    #
    # See if we can add without overlapping.
    #
    my $overlaps = first { $_->overlaps($glyph) } $self->glyphs;

    return undef if $overlaps;

    $self->push_glyph($glyph);
}

sub find_glyph
{
    my($self, $panel, $x, $y) = @_;

    #
    # Compute the contig coordinates of the given mouseclick X
    #

    my $cx = $self->track->translate_x_rev($x);

    my $hit = first { $_->overlaps_position($cx)} $self->glyphs;
    # print "Found hit " . Dumper($hit);
    return $hit;
}

sub find_glyphs_in_region
{
    my($self, $panel, $x, $y, $x2, $y2) = @_;

    #
    # Compute the contig coordinates of the region boundaries
    #

    my $cx = $self->track->translate_x_rev($x);
    my $cx2 = $self->track->translate_x_rev($x2);

    ($x, $x2) = ($x2, $x) if $x > $x2;
    ($cx, $cx2) = ($cx2, $cx) if $cx > $cx2;

    my @hits = grep { $_->begin < $cx2 && $cx < $_->end } $self->glyphs;

    return @hits;
}

sub render
{
    my($self, $panel, $dc) = @_;

    my $x = $self->x;
    my $y = $self->y;
    my $mh = 0;
    for my $glyph ($self->glyphs)
    {
	if ($glyph->selected)
	{
	    $dc->SetPen($panel->selected_pen);
	}
	elsif ($glyph->focus)
	{
	    $dc->SetPen($panel->focus_pen);
	}
	else
	{
	    $dc->SetPen($panel->normal_pen);
	}

	$glyph->render($panel, $dc, $x, $y);
	if ((my $gh = $glyph->height) > $mh)
	{
	    $mh = $gh;
	}
    }
    $self->height($mh);
}


1;
