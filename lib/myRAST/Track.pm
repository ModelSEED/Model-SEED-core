package Track;

=head1 NAME

Track - a genome display track

=head1 DESCRIPTION

A track is responsible for rendering one genome in a multi-genome display. It may have 
multiple L<SubTrack> instances created when genes overlap.

=cut

use Moose;

use List::Util 'first';
use Subtrack;

has 'subtrack_list' => (is => 'ro',
			isa => 'ArrayRef[Subtrack]',
			default => sub { [] },
			traits => ['Array'],
			handles => {
			    subtracks => 'elements',
			    push_subtrack => 'push',
			},
		    );

has 'x' => (is => 'rw',
	    isa => 'Num',
	    default => 0);

has 'y' => (is => 'rw',
	    isa => 'Num',
	    default => 0);

has 'height' => (is => 'rw',
		 isa => 'Num');

has 'center' => (is => 'rw',
		 isa => 'Num');
has 'mirror' => (is => 'rw',
		 isa => 'Bool');

has 'min' => (isa => 'Num',
		      is  => 'rw');

has 'max' => (isa => 'Num',
		       is  => 'rw');

has 'left_offset' => (isa => 'Num',
		      is  => 'rw');

has 'right_offset' => (isa => 'Num',
		       is  => 'rw');

has 'origin' => (isa => 'Num',
		 is => 'rw');

has 'panel' => (isa => 'RegionPanel',
		is => 'ro');

has 'genome_name' => (isa => 'Str', is => 'ro');
has 'genome_id' => (isa => 'Str', is => 'ro');

sub add_glyph
{
    my($self, $glyph) = @_;

    #
    # Yup, it's O(n^2)
    #
    my $added = first { $_->add_glyph($glyph) } $self->subtracks;
    if (!$added)
    {
	my $st = Subtrack->new(track => $self, panel => $self->panel);
	$st->add_glyph($glyph);
	$self->push_subtrack($st);
    }
}

sub find_glyph
{
    my($self, $panel, $x, $y) = @_;

    my $cy = $self->y;
    my $n = 0;
    my $in_st;
    for my $st ($self->subtracks)
    {
	$cy += $st->height();
	if ($y < $cy)
	{
	    # print "Found in subtrack $n\n";
	    $in_st = $st;
	    last;
	}
	$n++;
    }
    if ($in_st)
    {
	return $in_st->find_glyph($panel, $x, $y);
    }
}

sub find_glyphs_in_region
{
    my($self, $panel, $x, $y, $x2, $y2) = @_;

    my $cy = $self->y;

    my @hits;
    for my $st ($self->subtracks)
    {
	my $ty1 = $cy;
	my $ty2 = $ty1 + $st->height();
	
	if ($ty1 < $y2 && $y < $ty2)
	{
	    my @th = $st->find_glyphs_in_region($panel, $x, $y, $x2, $y2);

	    push(@hits, @th);
	}
	$cy = $ty2;
    }

    return @hits;
}

sub render
{
    my($self, $panel, $dc) = @_;

    $self->render_label($panel, $dc);

    my $orig_y = my $y = $self->y;
    for my $st ($self->subtracks)
    {
	$st->x($self->x);
	$st->y($y);
	$st->render($panel, $dc);
	$y += $st->height();
    }
    $self->height($y - $orig_y);
}

sub render_label
{
    my($self, $panel, $dc) = @_;
    $dc->SetFont($panel->genome_name_font);
    $dc->DrawText($self->genome_name, 5, $self->y);
}

sub translate_x
{
    my($self, $cx) = @_;

    if ($self->mirror)
    {
	$cx = 2 * $self->center - $cx;
    }

    return ($cx - $self->origin) * $self->panel->contig_scale + $self->panel->text_gutter_size;
}

sub translate_x_rev
{
    my($self, $wx) = @_;

    my $cx = ($wx - $self->panel->text_gutter_size) / $self->panel->contig_scale + $self->origin;
    
    if ($self->mirror)
    {
	$cx = 2 * $self->center - $cx;
    }

    return $cx;
}

1;
