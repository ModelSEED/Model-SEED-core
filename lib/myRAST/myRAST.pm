package myRAST;

#
# Application singleton. Global state lives here.
#

use MooseX::Singleton;

use strict;

use Data::Dumper;
use ANNOserver;
use SampleDir;
use File::HomeDir;
use PDL qw();

has 'doc_dir' => (isa => 'Str',
		  is => 'rw',
		  builder => '_build_doc_dir');

has 'anno' => (isa => 'ANNOserver',
	       is => 'rw',
	       lazy => 1,
	       default => sub {
		   my($self) = @_;
		   return ANNOserver->new(url => $self->anno_url); },
	       );

has 'anno_url' => (isa => 'Maybe[Str]',
		   is => 'rw');


sub enumerate_samples
{
    my($self) = @_;

    my $doc_dir = $self->doc_dir;
    opendir(my $jdh, $doc_dir);

    my @jobs = grep { -d $_ } map { "$doc_dir/$_" }  sort readdir($jdh);
    closedir($jdh);

    my @out;
    for my $dir (@jobs)
    {
	next unless -f "$dir/NAME" && -f "$dir/sample.fa";

	my $sample = SampleDir->new($dir);

	my $alist = $sample->get_analysis_list();

	my $info = $sample->get_statistics();

	$info->{dir} = $dir;
	$info->{name} = $sample->name;
	$info->{description} = $sample->description;

	my $found = 0;
	for my $dataset (sort keys %$alist)
	{
	    for my $index (@{$alist->{$dataset}})
	    {
		my $ent = { %$info };
		$ent->{dataset} = $dataset;
		$ent->{dataset_index} = $index;
		
		my $an = $sample->get_analysis($dataset, $index);
		
		my $params = $an->get_parameters();
		$ent->{kmer} = $params->{-kmer};
		$ent->{max_gap} = $params->{-maxGap};
		$ent->{min_hits} = $params->{-minHits};
		$ent->{andir} = $an->dir();

		my $sum = $an->get_summary();
		$ent->{$_} = $sum->{$_} for keys %$sum;
		push(@out, $ent);
		$found++;
	    }
	}
	if ($found == 0)
	{
	    my $ent = { %$info };
	    $ent->{dataset} = "No analyses found";
	    push(@out, $ent);
	}
    }

    return sort { $a->{name} cmp $b->{name} or
		      $a->{dir} cmp $b->{dir} or
		      $a->{dataset} cmp $b->{dataset} or
			  $a->{dataset_index} <=> $b->{dataset_index} } @out;
}

sub compute_all_to_all_distances
{
    my($self, $samples_to_compare, $count_cb, $update_cb) = @_;

    my @samples;

    if (ref($samples_to_compare) eq 'ARRAY' && @$samples_to_compare)
    {
	@samples = @$samples_to_compare;
    }
    else
    {
	@samples = $self->enumerate_samples();
    }

    my $scores = [];

    if ($count_cb)
    {
	$count_cb->((@samples * (@samples + 1)) / 2);
    }

    my $count = 0;
    for my $i (0..$#samples)
    {
	my $enti = $samples[$i];

	next if $enti->{dataset} eq 'No analyses found';
	my $sampi = SampleDir->new($enti->{dir});
	my $ai = $sampi->get_analysis($enti->{dataset}, $enti->{dataset_index});

	my $fn_basis = $self->get_function_basis($enti->{dataset});
	my $avi = PDL::norm($ai->get_function_vector($fn_basis));

	for my $j (0..$i)
	{
	    if ($update_cb)
	    {
		my $continue = $update_cb->($count++);
		if (!$continue)
		{
		    return;
		}
	    }
	    # print "Compute $i $j\n";
	    my $entj= $samples[$j];
	    next if $entj->{dataset} eq 'No analyses found';
	    next if $entj->{dataset} ne $enti->{dataset};
	    
	    my $sampj = SampleDir->new($entj->{dir});
	    my $aj = $sampj->get_analysis($entj->{dataset}, $entj->{dataset_index});

	    my $avj = PDL::norm($aj->get_function_vector($fn_basis));

	    my $dot = PDL::inner($avi, $avj);
	    ($dot) = PDL::list($dot);
	    $scores->[$i]->[$j] = $dot;
	    $scores->[$j]->[$i] = $dot;
	}
    }
    return \@samples, $scores;
}

#
# Compare the given analysis $a to the
# rest of the samples that share the same dataset.
#
sub compare_samples_function
{
    my($self, $a1) = @_;

    my $ds = $a1->dataset();
    print "Compare $ds\n";

    my @samples = $self->enumerate_samples();
    @samples = grep { $_->{dataset} eq $ds } @samples;

    my $fn_basis = $self->get_function_basis($ds);
    my $av = PDL::norm($a1->get_function_vector($fn_basis));

    my %sobjs;
    my @out;
    for my $sample (@samples)
    {
	my $sobj = $sobjs{$sample->{dir}};
	if (!defined($sobj))
	{
	    $sobj = SampleDir->new($sample->{dir});
	}
	my $a2 = $sobj->get_analysis($sample->{dataset}, $sample->{dataset_index});
	my $av2 = PDL::norm($a2->get_function_vector($fn_basis));

	my $dot = PDL::inner($av, $av2);
	($dot) = PDL::list($dot);
	my $ent = { %$sample };
	$ent->{score} = $dot;
	$ent->{analysis_obj} = $a2;
	push(@out, $ent);
    }

    return sort { $b->{score} <=> $a->{score} } @out;
}

sub compare_samples_otu
{
    my($self, $a1) = @_;

    my $ds = $a1->dataset();
    print "Compare $ds\n";

    my @samples = $self->enumerate_samples();
    @samples = grep { $_->{dataset} eq $ds } @samples;

    my $otu_basis = $self->get_otu_basis($ds);
    my $av = PDL::norm($a1->get_otu_vector($otu_basis));

    my %sobjs;
    my @out;
    for my $sample (@samples)
    {
	my $sobj = $sobjs{$sample->{dir}};
	if (!defined($sobj))
	{
	    $sobj = SampleDir->new($sample->{dir});
	}
	my $a2 = $sobj->get_analysis($sample->{dataset}, $sample->{dataset_index});
	my $av2 = PDL::norm($a2->get_otu_vector($otu_basis));

	my $dot = PDL::inner($av, $av2);
	($dot) = PDL::list($dot);
	my $ent = { %$sample };
	$ent->{score} = $dot;
	$ent->{analysis_obj} = $a2;
	push(@out, $ent);
    }

    return sort { $b->{score} <=> $a->{score} } @out;
}

sub get_function_basis
{
    my($self, $ds) = @_;

    my $file = $self->doc_dir . "/basis.function.$ds";

    if (! -f $file)
    {
	$self->install_basis_sets($ds);
    }
    return VectorBasis->new($file);
}

sub get_otu_basis
{
    my($self, $ds) = @_;

    my $file = $self->doc_dir . "/basis.otu.$ds";

    if (! -f $file)
    {
	$self->install_basis_sets($ds);
    }
    return VectorBasis->new($file);
}

sub install_basis_sets
{
    my($self, $ds) = @_;
    my $res = $self->anno->get_vector_basis_sets(-kmerDataset => $ds);
    if ($res->{function})
    {
	if (open(my $fh, ">", $self->doc_dir . "/basis.function.$ds"))
	{
	    print $fh $res->{function};
	    close($fh);
	}
    }
    if ($res->{otu})
    {
	if (open(my $fh, ">", $self->doc_dir . "/basis.otu.$ds"))
	{
	    print $fh $res->{otu};
	    close($fh);
	}
    }
}

sub _build_doc_dir
{
    my($self) = @_;
    return File::HomeDir->my_documents . "/myRAST";
}

1;
