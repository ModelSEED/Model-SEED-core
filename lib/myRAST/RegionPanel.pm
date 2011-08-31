package RegionPanel;

use Moose;
use MooseX::NonMoose;

use Glyph;
use IntergenicGlyph;
use ArrowGlyph;

use List::Util qw(min);

use Data::Dumper;

use wxPerl::Constructors;
use Wx::Grid;
use Wx::Html;
use Wx qw(:sizer :everything);

use Wx::Event qw(EVT_PAINT EVT_SIZE EVT_KEY_DOWN EVT_LEFT_DOWN EVT_LEFT_UP
		 EVT_RIGHT_DOWN EVT_MOTION EVT_LEAVE_WINDOW);

extends 'Wx::ScrolledWindow';
#extends 'Wx::Panel';

=head1 NAME

RegionPanel - wxPanel that renders a region display.

=cut

use Track;

has 'track_list' => (isa => 'ArrayRef[Track]',
		     is => 'rw',
		     traits => ['Array'],
		     handles => {
			 tracks => 'elements',
		       },
		     lazy => 1,
		     default => sub { [] },
		    );

has 'observer_list' => (is => 'rw',
			isa => 'ArrayRef[CodeRef]',
			traits => ['Array'],
			handles => {
			    add_observer => 'push',
			    observers => 'elements',
			},
			lazy => 1,
			default => sub { [] } ,
		       );

#
# contig-coords * contig-scale = screen-coords
#
has 'contig_scale' => (isa => 'Num',
		       is => 'rw',
		       default => 0.1);

#
# Contig range is the size in contig coordinates of the
# data currently being displayed.
#
has 'contig_range' => (isa => 'Num',
		       is => 'rw');

has 'left_offset' => (isa => 'Num',
		      is => 'rw');

has 'right_offset' => (isa => 'Num',
		      is => 'rw');

has 'mouse_is_down' => (isa => 'Bool',
			is => 'rw',
			default => 0);

has 'drag_origin' => (isa => 'ArrayRef',
		      is => 'rw');
has 'drag_dest' => (isa => 'ArrayRef',
		      is => 'rw');
has 'dragging' => (isa => 'Bool',
		   is => 'rw',
		   default => 0);

has 'selected_glyph' => (isa => 'Maybe[Glyph]',
			 is => 'rw');
has 'hovered_glyph' => (isa => 'Maybe[Glyph]',
			 is => 'rw');
has 'popup' => (isa => 'Maybe[Object]',
		is => 'rw');

has 'height' => (isa => 'Num',
		 is => 'rw');

has 'text_gutter_size' => (isa => 'Num',
			   is => 'rw',
			   default => 100);
has 'genome_name_font' => (isa => 'Wx::Font',
			   is => 'rw');

has 'normal_pen' => (isa => 'Wx::Pen',
		     is => 'rw');

has 'focus_pen' => (isa => 'Wx::Pen',
		    is => 'rw');

has 'selected_pen' => (isa => 'Wx::Pen',
		       is => 'rw');

has 'selected_id' => (isa => 'HashRef',
		      is => 'ro',
		      default => sub { {} });

sub FOREIGNBUILDARGS
{
    my($self, %args) = @_;

    return ($args{parent}, -1);
};

sub BUILD
{
    my($self) = @_;

    EVT_PAINT($self, \&OnPaint);
    EVT_SIZE($self, sub { $self->update_scale(); });

    EVT_KEY_DOWN($self, \&OnKeyPress);
    EVT_LEFT_DOWN($self, \&OnClick);
    EVT_LEFT_UP($self, \&OnRelease);
    EVT_RIGHT_DOWN($self, \&OnRightClick);
    EVT_MOTION($self, \&OnMotion);
    EVT_LEAVE_WINDOW($self, \&OnLeave);

    $self->genome_name_font(Wx::Font->new(12, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL,
					  wxFONTWEIGHT_BOLD));

    #
    # Set up some pens.
    #
    $self->normal_pen(Wx::Pen->new(wxBLACK, 1, wxSOLID));
    $self->focus_pen(Wx::Pen->new(wxBLACK, 3, wxSOLID));
    $self->selected_pen(Wx::Pen->new(wxBLACK, 3, wxDOT));
}

sub update_tracks
{
    my($self, $data) = @_;

    my($focus_peg, $pin, $context, $index, $group, $group_count, $genome_names) = @$data;

    my %pin = map { $_ => 1 } @$pin, $focus_peg;
    
    my %brush;
    for my $val (values %$group)
    {
	my $brush;
	if ($group_count->{$val} > 1)
	{
	    my @c = &SeedUtils::compare_region_color($val - 1);
	    $brush = Wx::Brush->new(Wx::Colour->new(@c), wxSOLID);
	}
	else
	{
	    $brush = wxGREY_BRUSH;
	}
	$brush{$val} = $brush;
    }
    #
    # undefined funcs
    #
    $brush{-1} = wxBLACK_BRUSH;
    
    my @tracks;
    
    # print "Pin: " . Dumper($pin);
    
    #my $pin_direction = '+';
    my $pin_direction = $index->{$focus_peg}->[4];

    my $dc = Wx::ClientDC->new($self);

    my($cmin, $cmax);
    my $txt_max = 0;
    my $is_focus_row = 1;
    for my $row (@$context)
    {
	if (@$row == 0)
	{
	    # print "Weird, empty row!\n";
	    next;
	}

	my $tg = &SeedUtils::genome_of($row->[0]->[0]);
	my $tgs = $genome_names->{$tg};

	my ($txt_width, $txt_height, $txt_descent, $txt_external_leading) =
	    $dc->GetTextExtent($tgs, $self->genome_name_font);
	# print "Extent for $tgs: $txt_width $txt_height\n";
	$txt_max = $txt_width if $txt_width > $txt_max;

	my $track = Track->new(panel => $self, genome_id => $tg, genome_name => $tgs);

	my($tmin, $tmax);

	my @endpoints;
	my %contig;
	for my $ent (@$row)
	{
	    my($peg, $contig, $min, $max, $dir, $func, $row, $group) = @$ent;
	    $contig{$contig}++;
	    #
	    # Collect data for marking intergenic regions
	    #
	    if ($is_focus_row)
	    {
		push(@endpoints, [$peg, $min, 1, $contig]);
		push(@endpoints, [$peg, $max, -1, $contig]);
	    }

	    if (defined($tmin))
	    {
		$tmin = $min if $min < $tmin;
		$tmax = $max if $max > $tmax;
	    }
	    else
	    {
		$tmin = $min;
		$tmax = $max;
	    }

	    $func = "" unless defined($func);
	    $group = -1 unless defined($group);

	    if ($pin{$peg})
	    {
		$track->center(int(($min + $max) / 2));
		# print "Set center to $min for $peg $track dir=$dir pindir=$pin_direction\n";
		
		if ($dir ne $pin_direction)
		{
		    # print "Mirroring\n";
		    $track->mirror(1);
		}
	    }
	    
	    my $html = "<table><tr><td>ID:</td><td>$peg</td></tr>";
	    $html .= "<tr><td>Function:</td><td>$func</td></tr>";
	    my $len = $max - $min;
	    my $len_aa = int($len / 3);
	    $html .= "<tr><td>Contig:</td><td>$contig</td></tr>";
	    if ($dir eq '+')
	    {
		$html .= "<tr><td>Start:</td><td>$min</td></tr>";
		$html .= "<tr><td>Stop:</td><td>$max</td></tr>";

	    }
	    else
	    {
		$html .= "<tr><td>Start:</td><td>$max</td></tr>";
		$html .= "<tr><td>Stop:</td><td>$min</td></tr>";
	    }
	    if ($peg =~ /\.peg\./)
	    {
		$html .= "<tr><td>Length:</td><td>$len bp $len_aa aa</td></tr>";
	    }
	    else
	    {
		$html .= "<tr><td>Length:</td><td>$len bp</td></tr>";
	    }
	    
		
	    $html .= "</table>";
	    
	    my $class = 'Glyph';
	    if ($peg =~ /peg/)
	    {
		$class = 'ArrowGlyph';
	    }
	    
	    my $g = $class->new(panel => $self,
				id => $peg,
				($peg eq $focus_peg) ? (focus => 1) : (),
				begin => $min, end => $max, html => $html, brush => $brush{$group},
				direction => ($dir eq '+' ? 1 : -1), track => $track,
				contig => $contig,
				function => $func);
	    my $ok = $track->add_glyph($g);
	}

	my @contigs_seen = keys %contig;
	if (@contigs_seen > 1)
	{
	    warn "WEIRD: more than one contig seen\n";
	}
	
	if ($is_focus_row)
	{
	    my $depth = 0;
	    my @intergenic;
	    
	    my($beg_intergenic_id, $beg_intergenic_pos);
	    for my $ent (sort { $a->[1] <=> $b->[1] } @endpoints)
	    {
		my($peg, $pos, $val, $contig) = @$ent;
		$depth += $val;
		if ($depth == 0)
		{
		    $beg_intergenic_id = $peg;
		    $beg_intergenic_pos = $pos + 1;
		}
		elsif ($depth == 1 && defined($beg_intergenic_id))
		{
		    # print "Intergenic $beg_intergenic_id - $peg ($beg_intergenic_pos - $pos)\n";
		    push(@intergenic, [$beg_intergenic_id, $peg, $beg_intergenic_pos, $pos - 1, $contig]);
		    undef $beg_intergenic_id;
		    undef $beg_intergenic_pos;
		}
	    }
	    # print Dumper(\@endpoints, \@intergenic);

	    my $igid = "intergenic001";
	    for my $ent (@intergenic)
	    {
		my($id1, $id2, $beg, $end, $contig) = @$ent;

		my $len = $end - $beg;
		my $html = "Intergenic from $id1 to $id2<br>";
		$html .= "<table>";
		$html .= "<tr><td>Start:</td><td>$beg</td></tr>";
		$html .= "<tr><td>Stop:</td><td>$end</td></tr>";
		$html .= "<tr><td>Length:</td><td>$len bp</td></tr>";
		
		$html .= "</table>";

		my $igg = IntergenicGlyph->new(panel => $self,
					       id => $igid,
					       begin => $beg, end => $end,
					       html => $html,
					       contig => $contig,
					       track => $track);
		$track->add_glyph($igg);
		
	    }
	    continue
	    {
		$igid++;
	    }
	    for my $contig (@contigs_seen)
	    {
		# would 
	    }
	}
	
	push(@tracks, $track);

	$track->min($tmin);
	$track->max($tmax);
	    
	my $off_left = $track->center - $tmin;
	my $off_right = $tmax - $track->center;

	if ($track->mirror)
	{
	    ($off_left, $off_right) = ($off_right, $off_left);
	}

	$track->left_offset($off_left);
	$track->right_offset($off_right);
	
	# print "offsets: $tmin $tmax " . $track->center . " $off_left $off_right\n";
	if (defined($cmin))
	{
	    
	    $cmin = $off_left if $off_left > $cmin;
	    $cmax = $off_right if $off_right > $cmax;
	}
	else
	{
	    $cmin = $off_left;
	    $cmax = $off_right;
	}
    }
    continue
    {
	$is_focus_row = 0;
    }

    $self->text_gutter_size($txt_max + 10);


    #
    # Add a few pixels on the right.
    #
    $cmax += 30;

    $self->left_offset($cmin);
    $self->right_offset($cmax);

    for my $track (@tracks)
    {
	$track->origin($track->center - $self->left_offset);
    }

    # print "cmax=$cmax cmin=$cmin\n";
    #
    # Compute scaling based on current window size & contig range.
    $self->contig_range($cmax + $cmin);
    
    $self->update_scale();
    $self->track_list(\@tracks);
    $self->Refresh();
}

sub update_scale
{
    my($self) = @_;

    my $sz = $self->GetClientSize();
    my $w = $sz->GetWidth();
    my $h = $sz->GetHeight();

    my $psz = $self->GetParent()->GetClientSize();
    my $pw = $psz->GetWidth();
    my $ph = $psz->GetHeight();
    my $myh = $self->height;
#    print "Resize $w $h ($myh) $pw $ph\n";

    if ($self->height)
    {
#	$self->SetVirtualSize($pw, $self->height);
	$self->SetScrollbars(1, 1, $w, $self->height);
    }

    return unless defined($self->contig_range);

    my $active_width = $w - $self->text_gutter_size;
    my $scale = ($w - $self->text_gutter_size) / $self->contig_range;

#    print "width=$w range=" . $self->contig_range . " active_width=$active_width scale=$scale\n";

    $self->contig_scale($scale);
}

sub center_on_glyph
{
    my($self, $glyph) = @_;

    my $sz = $self->GetClientSize();
    my $w = $sz->GetWidth();
    my $h = $sz->GetHeight();

    my $gcenter = ($glyph->begin + $glyph->end) / 2;
    my $wcenter = $w / 2;

    $self->track->x(-int($gcenter * $self->contig_scale - $wcenter));
    
}

sub OnKeyPress
{
    my($self, $event) = @_;
    my $kc = $event->GetKeyCode();
    if ($kc == WXK_LEFT)
    {
	$self->track->x($self->track->x - 100);
	$self->Refresh();
    }
    elsif ($kc == WXK_RIGHT)
    {
	$self->track->x($self->track->x + 100);
	$self->Refresh();
    }
    elsif ($kc == WXK_UP)
    {
	$self->contig_scale($self->contig_scale * 2.0);
	$self->Refresh();
    }
    elsif ($kc == WXK_DOWN)
    {
	$self->contig_scale($self->contig_scale / 2.0);
	$self->Refresh();
    }
}

sub find_glyph
{
    my($self, $x, $y) = @_;
    my $hit;

    for my $track ($self->tracks)
    {
	if ($y >= $track->y && $y < $track->y +  $track->height)
	{
	    $hit = $track->find_glyph($self, $x, $y);
	}
    }

    return $hit;
}
	
sub find_glyphs_in_region
{
    my($self, $x, $y, $x2, $y2) = @_;

    my @hits;

    for my $track ($self->tracks)
    {
	my $ty1 = $track->y;
	my $ty2 = $track->y + $track->height;

	if ($ty1 < $y2 && $y < $ty2)
	{
	    push(@hits, $track->find_glyphs_in_region($self, $x, $y, $x2, $y2));
	}
    }

    return @hits;
}
	

sub OnMotion
{
    my($self, $event) = @_;
    my $x = $event->GetX();
    my $y = $event->GetY();

    my($ux, $uy) = $self->CalcUnscrolledPosition($x, $y);

    if ($self->mouse_is_down)
    {
	$self->drag_dest([$ux, $uy]);
	$self->dragging(1);
#	print "Dragging rectangle from @{$self->{drag_origin}} to $ux $uy\n";

	my @hits = $self->find_glyphs_in_region(@{$self->{drag_origin}}, $ux, $uy);

	my $n = @hits;

	%{$self->{selected_id}} = map { $_->{id} => 1 } @hits;
#	print "Hits: $n\n";
#	print "\t" . $_->id . "\n" for @hits;
	$self->Refresh();
    }
    else
    {
	my $pos = $self->GetScreenPosition();
	my $winx =$pos->x;
	my $winy = $pos->y;
	
	$winx += $x;
	$winy += $y;
	
	my $hit = $self->find_glyph($ux, $uy);
	
	my $cur = $self->hovered_glyph;
	if ($hit)
	{
	    if ($cur)
	    {
		if ($cur ne $hit)
		{
		    $self->hover_end($cur, $event, $winx, $winy);
		    $self->hover_start($hit, $event, $winx, $winy);
		    $hit->hovered(1);
		    $self->hovered_glyph($hit);
		    $cur->hovered(0);
		    #		$self->Refresh();
		}
		else
		{
		    $self->hover_update($cur, $event, $winx, $winy);
		}
	    }
	    else
	    {
		$hit->hovered(1);
		$self->hover_start($hit, $event, $winx, $winy);
		$self->hovered_glyph($hit);
		#	    $self->Refresh();
	    }
	}
	elsif ($cur)
	{
	    $self->hover_end($cur, $event, $winx, $winy);
	    $cur->hovered(0);
	    $self->hovered_glyph(undef);
	    #	$self->Refresh();
	}
    }
	
}

sub OnLeave
{
    my($self, $event) = @_;
    my $cur = $self->hovered_glyph;
    if (defined($cur))
    {
	$self->hover_end($cur, $event);
	$cur->hovered(0);
	$self->hovered_glyph(undef);
	$self->Refresh();
    }

    if ($self->mouse_is_down)
    {
	$self->end_drag();
    }
}

sub hover_start
{
    my($self, $g, $event, $winx, $winy) = @_;

    #
    # Determine where we should put the window so that it is entirely shown on this display.
    #

    my $this_display = Wx::Display::GetFromPoint(Wx::Point->new($winx, $winy));
    # print "Hover start: this_display=$this_display\n";

    my $width = 300;
    my $height = 300;
    my $offset = 30;
    #
    # Default to something.
    #
    my($loc_x, $loc_y) = ($winx + $offset, $winy + $offset);

    #
    # But compute ideal.
    #
    for my $dir ([1,1], [-1, 1], [1, -1], [-1, -1])
    {
	my ($dir_x, $dir_y) = @$dir;
	my $corner_x = $winx + $offset * $dir_x;
	my $corner_y = $winy + $offset * $dir_y;

	if (Wx::Display::GetFromPoint(Wx::Point->new($corner_x, $corner_y)) != $this_display)
	{
	    # print "Corner fail: $corner_x $corner_y\n";
	    next;
	}

	my $far_corner_x = $corner_x + $width * $dir_x;
	my $far_corner_y = $corner_y + $height * $dir_y;
	
	if (Wx::Display::GetFromPoint(Wx::Point->new($far_corner_x, $far_corner_y)) != $this_display)
	{
	    # print "Far corner fail: $far_corner_x $far_corner_y\n";
	    next;
	}

	# print "Solved: @$dir corner=$corner_x $corner_y far=$far_corner_x $far_corner_y\n";
	$loc_x = min($corner_x, $far_corner_x);
	$loc_y = min($corner_y, $far_corner_y);
	last;
    }

    my $popup = wxPerl::MiniFrame->new($self, $g->id . " details",
				       position => Wx::Point->new($loc_x, $loc_y),
				       size => Wx::Size->new($width, $height),
				       style => wxCAPTION);
#    my $popup = Wx::PopupWindow->new($self, wxRAISED_BORDER);
#    $popup->Move($winx + 30, $winy + 30);
#    $popup->SetSize(100,100);

    my $h = Wx::HtmlWindow->new($popup, -1);
    $h->SetPage($g->html);
    
    $popup->Show();
    $self->popup($popup);
}

sub hover_update
{
    my($self, $g, $event) = @_;
}

sub hover_end
{
    my($self, $g, $event) = @_;
    $self->popup->Destroy();
    $self->popup(undef);
}

    

sub OnClick
{
    my($self, $event) = @_;
    my $x = $event->GetX();
    my $y = $event->GetY();

    my($ux, $uy) = $self->CalcUnscrolledPosition($x, $y);
    my $hit = $self->find_glyph($ux, $uy);

    if ($hit)
    {
	&$_('click', $hit->id) for $self->observers;
    }

    $self->drag_origin([$ux, $uy]);
    $self->mouse_is_down(1);
}

sub OnRelease
{
    my($self) = @_;
    if ($self->mouse_is_down)
    {
	$self->end_drag();
    }
}

sub end_drag
{
    my($self) = @_;
    
    $self->mouse_is_down(0);
    $self->dragging(0);
    $self->Refresh();
}
     

sub OnRightClick
{
    my($self, $event) = @_;
    my $x = $event->GetX();
    my $y = $event->GetY();

    my($ux, $uy) = $self->CalcUnscrolledPosition($x, $y);
    my $hit = $self->find_glyph($ux, $uy);

    if ($hit)
    {
	my $cur = $self->hovered_glyph;
	if (defined($cur))
	{
	    $self->hover_end($cur, $event);
	    $cur->hovered(0);
	    $self->hovered_glyph(undef);
	    $self->Refresh();
	}
	
	&$_('right_click', $hit->id, $hit) for $self->observers;
    }
}

sub OnPaint
{
    my($self, $event) = @_;

    my $sz = $self->GetClientSize();
    my $w = $sz->GetWidth();
    my $h = $sz->GetHeight();

    my $wcenter = $w / 2;

    my $dc = Wx::PaintDC->new($self);

    $self->DoPrepareDC($dc);

    if ($self->dragging)
    {
	$dc->DrawRectangle(@{$self->drag_origin},
			   $self->drag_dest->[0] - $self->drag_origin->[0],
			   $self->drag_dest->[1] - $self->drag_origin->[1]);
    }

    my $y = 5;
    for my $track ($self->tracks)
    {
	$track->x($self->text_gutter_size - int($track->center * $self->contig_scale - $wcenter));

#	$dc->DrawRectangle($self->text_gutter_size, 0, 100, 100);

	
	$track->y($y);
	$track->render($self, $dc);

	$y += $track->height();
	$y += 10;
    }

    $self->height($y);
}
    
sub clear_selection
{
    my($self) = @_;
    %{$self->{selected_id}} = ();
}

sub selected_ids
{
    my($self) = @_;
    return keys %{$self->{selected_id}};
}

1;
