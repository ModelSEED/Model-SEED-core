package Browser;

#
# primary controlling logic for the browser.
#

use Moose;

use File::HomeDir;
use SeedV;
use List::Util qw(sum reduce );
use List::MoreUtils qw(first_value last_value first_index);
use Data::Dumper;

has 'current_peg' => (isa => 'Str',
		      is => 'rw');
has 'current_function' => (isa => 'Str',
		      is => 'rw');
has 'current_genome' => (isa => 'Str',
		      is => 'rw');

has 'seedv' => (isa => 'SeedV',
		is => 'rw');

has 'seedv_cache' => (isa => 'HashRef[SeedV]',
		      is => 'ro',
		      default => sub { {} },
		      );

has 'region_width' => (isa => 'Num',
		       is => 'rw',
		       default => 5000);

has 'region_count' => (isa => 'Num',
		       is => 'rw',
		       default => 10);

has 'region_cutoff' => (isa => 'Num',
			is => 'rw',
			default => 1e-20);

has 'region' => (isa => 'ArrayRef',
		 is => 'rw');

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
has 'next_peg' => (is => 'rw', isa => 'Str');
has 'prev_peg' => (is => 'rw', isa => 'Str');
has 'next_halfpage' => (is => 'rw', isa => 'Str');
has 'prev_halfpage' => (is => 'rw', isa => 'Str');
has 'next_page' => (is => 'rw', isa => 'Str');
has 'prev_page' => (is => 'rw', isa => 'Str');
has 'next_contig' => (is => 'rw', isa => 'Str');
has 'prev_contig' => (is => 'rw', isa => 'Str');

sub set_peg
{
    my($self, $peg) = @_;

    my $genome = &SeedUtils::genome_of($peg);
    $self->current_peg($peg);
    $self->set_current_seedv();

    if (!$self->seedv)
    {
	Wx::MessageBox("Could not set peg to $peg",
		       "Internal Error");
	return;
    }

    $self->current_genome($genome);
    my $fn = $self->seedv->function_of($peg);
    $self->current_function(defined($fn) ? $fn : "");

    $self->compute_motion_targets($peg);

    &$_($self, $peg) for $self->observers();
}

sub compute_motion_targets
{
    my($self, $peg) = @_;

    #
    # Determine targets for motion in the chromosome.
    #

    my $seedv = $self->seedv;
    my $peg_loc = $seedv->feature_location($peg);
    my ($contig, $min, $max, $dir) = &SeedUtils::boundaries_of($peg_loc);
    my $center = ($min + $max) / 2;

    my $left = $center - $self->region_width;
    $left = 0 if $left < 0;
    my $right = $center + $self->region_width;

    my ($my_genes, $minV, $maxV) = $seedv->genes_in_region($contig, $left, $right);

    
    my @sorted = sort { $a->[2] <=> $b->[2] } map { [$_, SeedUtils::boundaries_of($seedv->feature_location($_))] } @$my_genes;

    my $contig_lengths = $seedv->contig_lengths();
    my @contigs = sort $seedv->all_contigs();

    my $ctg_index = first_index { $_ eq $contig } @contigs;

 #   print Dumper(\@sorted, \@contigs, $ctg_index);


    #
    # If we are at one end of the contig or the other, the "next X"
    # in that direction is the start / end of the next / previous contig.
    #

    my $peg_idx = first_index { $_->[0] eq $peg } @sorted;

    my($prev_contig, $prev_contig_peg, $next_contig, $next_contig_peg);
    
    if (@contigs > 0)
    {

	$prev_contig = $contigs[($ctg_index - 1 + @contigs) % @contigs];
	$prev_contig_peg = $self->last_peg_in_contig($prev_contig);
	
	$next_contig = $contigs[($ctg_index + 1) % @contigs];
	$next_contig_peg = $self->first_peg_in_contig($next_contig);
	
	$self->prev_contig($prev_contig_peg);
	$self->next_contig($next_contig_peg);
	#print "me: $contig $peg\n";
	#print "nxt: $next_contig $next_contig_peg\n";
	#print "prv: $prev_contig $prev_contig_peg\n";
    }
	
    my @left = @sorted[0..$peg_idx - 1];
    my @right = @sorted[$peg_idx + 1 .. $#sorted];
    # print "left=" . join(" ", map { $_->[0] } @left) . "\n";
    # print "right=" . join(" ", map { $_->[0] } @right) . "\n";

    #
    # Compute prev-peg addresses.
    #
    if ($peg_idx == 0)
    {
	$self->prev_peg($prev_contig_peg);
	$self->prev_halfpage($prev_contig_peg);
	$self->prev_page($prev_contig_peg);
    }
    else
    {
	$self->prev_peg($left[$#left]->[0]);
	$self->prev_page($left[0]->[0]);
	#
	# half-page is first peg width/2 from the center
	#
	my $offset = $center - $self->region_width / 2;
	my $ent = first_value { $_->[2] > $offset } @left;
	
	$self->prev_halfpage(defined($ent) ? $ent->[0] : $self->prev_page);
    }

    #
    # Compute next-peg addresses
    if ($peg_idx == $#sorted)
    {
	$self->next_peg($next_contig_peg);
	$self->next_halfpage($next_contig_peg);
	$self->next_page($next_contig_peg);
    }
    else
    {
	$self->next_peg($right[0]->[0]);
	$self->next_page($right[$#right]->[0]);
	#
	# half-page is first peg width/2 from the center
	#
	my $offset = $center + $self->region_width / 2;
	my $ent = last_value { $_->[2] < $offset } @right;
	$self->next_halfpage(defined($ent) ? $ent->[0] : $self->next_page);
    }
	    
#     print "$peg :\n";
#     for my $x (qw(prev_page prev_halfpage prev_peg next_peg next_halfpage next_page))
#     {
# 	print "  $x $self->{$x}\n";
#     }
}

sub first_peg_in_contig
{
    my($self, $contig) = @_;

    my $seedv = $self->seedv;

    my $ent = reduce { $a->[2] < $b->[2] ? $a : $b }
	      map { [$_, &SeedUtils::boundaries_of($seedv->feature_location($_))] }
    	      @{($seedv->genes_in_region($contig, 0, 5000))[0]};
    return defined($ent) ? $ent->[0] : undef;
}

sub last_peg_in_contig
{
    my($self, $contig) = @_;

    my $seedv = $self->seedv;
    my $len = $seedv->contig_ln($contig);

    my($pegs, $min, $max) = $seedv->genes_in_region($contig, $len - 5000, $len);
    # print "Got pegs @$pegs\n";
    my $ent = reduce { $a->[3] > $b->[3] ? $a : $b }
	      map { [$_, &SeedUtils::boundaries_of($seedv->feature_location($_))] }
    	      @$pegs;
    return defined($ent) ? $ent->[0] : undef;
}


    
sub compute_region
{
    my($self) = @_;
    
    my $peg = $self->current_peg;
    my $width = $self->region_width;
    my $cutoff = $self->region_cutoff;
    my $size = $self->region_count;

    my $s = $self->seedv;

    my $pin = $s->get_pin($peg, $size, $cutoff);
    my %pin = map { $_ => 1 } @$pin, $peg;

    my($context, $index, $genome_names) = $s->get_context($peg, $pin, $width);

    #
    # Sort by distance in the display from the center.
    #
    my $ctr = $index->{$peg}->[2];
    my @sorted = sort { abs($a->[2] - $ctr) <=> abs($b->[2] - $ctr) or $a->[6] <=> $b->[6] } values %$index;
    
    #
    # Now cluster by function.
    #
    
    my $next = 1;
    my %group;
    my %group_count;
    for my $ent (@sorted)
    {
	my($peg, $contig, $min, $max, $dir, $func, $row) = @$ent;
	next unless defined($func);
	$func =~ s/\s+#.*$//;
	my $group = $group{$func};
	if (!defined($group))
	{
	    $group = $next++;
	    $group{$func} = $group;
	}
	
	$group_count{$group}++;
	$ent->[7] = $group;
    }

    #
    # Sort the context based on the number groups matching the focus row.
    #
    my $num_in_focus = @{$context->[0]};
    my %funcs_in_focus = map { $_->[5] => 1 } @{$context->[0]};
    my %matching;
    my $nomatch_penalty = 0.1;
    for my $row (@$context)
    {
	my $id = $row->[0]->[0];
	my $rowlen = @$row;
	
	$matching{$id} = sum map { my $func = $_->[5];
				   my $in_focus = $funcs_in_focus{$func};
				   defined($in_focus) ? $in_focus : 0 } @$row;
	#
	# Penalty for non-matching pegs
	# 
	$matching{$id} -= $nomatch_penalty * ($rowlen - $matching{$id});
    }
    my @rest = sort { $matching{$b->[0]->[0]} <=> $matching{$a->[0]->[0]} } @$context[1..$#$context];
    my $ncontext = [$context->[0], @rest];

    $self->region([$peg, $pin, $ncontext, $index, \%group, \%group_count, $genome_names ]);
}

sub set_current_seedv
{
    my($self) = @_;
    my $genome_id = &SeedUtils::genome_of($self->current_peg);

    if (defined(my $sv = $self->seedv_cache->{$genome_id}))
    {
	$self->seedv($sv);
	return;
    }

    #
    # Assume the standard DesktopRast document structure, for now anyway.
    #
    my $dir = File::HomeDir->my_documents . "/myRAST/$genome_id";
    my $gdir = "$dir/$genome_id";

    if (-d $gdir)
    {
	$self->seedv(SeedV->new($gdir));
	return;
    }

    #
    # Otherwise, we don't have a seedv. Need to use SAP based functions.
    # Not implmented yet.
    #
    return;
}

sub remove_observer
{
    my($self, $obs) = @_;
    $self->observer_list([ grep { $_ ne $obs } $self->observers]);
}

1;
