
#
# This is a SAS component.
#


# Utilities for dealing with samples, function summaries,
# OTU summaries, and the vectors that represent them.
#

#
# A sample is stored in a directory.
#
# The raw DNA for the sample is in sample.fa
# Metadata about the sample is stored in a set of flat files:
#
# NAME
# DESCRIPTION
#
# Each analysis is stored in a directory
#
#  dataset-name/idx
#
# where dataset-name is the name of the Kmer dataset used for the analysis,
# and idx is a numeric index. Each analysis with a different set of
# parameters is stored in its own directory.
#
# The processing parameters are stored in a YAML file params.yml.
# The parameters file contains a serialized hash with the following keys:
#    kmer:		kmer size
#    max_gap:		max-gap parameter
#    min_size:		min-size parameter
#    dataset:		Kmer dataset identifier
#

package SampleDir;

use strict;
use SeedUtils;
use gjoseqlib;
use ANNOserver;
use Data::Dumper;
use YAML::Any qw(Dump Load DumpFile LoadFile);
use Time::HiRes 'gettimeofday';

use base qw(Class::Accessor);

__PACKAGE__->mk_accessors(qw(dir sequence_type anno));

our %kmer_defaults = (-kmer => 8,
		      -minHits => 3,
		      -maxGap => 600);

sub create
{
    my($class, $dir, $sample_file, $name, $desc) = @_;

    if (-d $dir)
    {
	die "SampleDir::create: directorty $dir already exists\n";
    }

    if (! -f $sample_file)
    {
	die "SampleDir::create: sample file $sample_file does not exist\n";
    }

    mkdir($dir) or die "SampleDir::create: mkdir $dir failed: $!";
    my $seq_type = SeedUtils::validate_fasta_file($sample_file, "$dir/sample.fa");

    my $fh;
    if (open($fh, ">", "$dir/NAME"))
    {
	print $fh "$name\n";
    }
    close($fh);
    if (open($fh, ">", "$dir/DESCRIPTION"))
    {
	print $fh $desc;
    }
    close($fh);

    my $obj = $class->new($dir);
    $obj->sequence_type($seq_type);

    return $obj;
}

sub new
{
    my($class, $dir, %args ) = @_;

    my $self = {
	dir => $dir,
	anno => ANNOserver->new(exists($args{-url}) ? (-url => $args{-url}) : ()),
	args => \%args,
    };

    bless $self, $class;

    $self->load_stats();

    return $self;
}

sub compute_and_save_stats
{
    my($self) = @_;

    my $fh;
    if (!open($fh, "<", "$self->{dir}/sample.fa"))
    {
	warn "Cannot open $self->{dir}/sample.fa: $!";
	return;
    }

    my $n = 0;
    my $tot = 0;
    my $num_at = 0;
    my $num_gc = 0;
    my($max, $min, @lens);
    while (my($id, $com, $seq) = gjoseqlib::read_next_fasta_seq($fh))
    {
	my $len = length($seq);
	$tot += $len;
	$n++;
	push(@lens, $len);
	$max = $len if !defined($max) || $len > $max;
	$min = $len if !defined($min) || $len < $min;
	$num_gc += ($seq =~ tr/gcGC//);
	$num_at += ($seq =~ tr/atAT//);
    }
    my $avg = $tot / $n;
    my $median = (sort { $a <=> $b } @lens)[int($n / 2)];
    my $data = {
	total_size => $tot,
	count => $n,
	min => $min,
	max => $max,
	mean => $avg,
	median => $median,
	gc_content => 100 * (($num_gc + 1) / ($num_gc + $num_at + 2)),
    };

    $self->{statistics} = $data;
    
    DumpFile("$self->{dir}/statistics.yml", $data);
}

sub load_stats
{
    my($self) = @_;
    my $file = "$self->{dir}/statistics.yml";

    if (-s $file)
    {
	$self->{statistics} = LoadFile($file);
    }
    else
    {
	$self->compute_and_save_stats();
    }
}
     
sub get_statistics
{
    my($self) = @_;
    return $self->{statistics};
}

sub name
{
    my($self) = @_;
    my $n = &SeedUtils::file_head("$self->{dir}/NAME",1 );
    chomp $n;
    return $n;
}

sub description
{
    my($self) = @_;
    my $n = &SeedUtils::file_read("$self->{dir}/DESCRIPTION");
    return $n;
}

sub perform_basic_analysis
{
    my($self, %args) = @_;

    my %params = %kmer_defaults;
    for my $k (keys %args)
    {
	if (defined($params{$k}))
	{
	    $params{$k} = $args{$k};
	}
    }

    #
    # If dataset not specified, look up the current
    # default and specify it with all future calls.
    #
    if (!defined($params{-kmerDataset}))
    {
	my $ds = $self->anno->get_dataset();
	$params{-kmerDataset} = $ds;
	print "Using default dataset $ds\n";
    }

    #
    # Create the dataset directory if not already present.
    #

    my $ds = $params{-kmerDataset};
    my $ds_dir = "$self->{dir}/$ds";
    if (!-d $ds_dir)
    {
	mkdir($ds_dir) or die "Cannot mkdir $ds_dir: $!";
    }
    
    #
    # Find a new analysis dir pathname. Start at zero.
    #
    my $analysis_num = 0;
    my $analysis_dir = "$ds_dir/$analysis_num";
    while (-e $analysis_dir)
    {
	$analysis_num++;
	$analysis_dir = "$ds_dir/$analysis_num";
    }

    mkdir($analysis_dir) or die "Cannot mkdir $analysis_dir: $!";
    
    print STDERR "Using analysis dir $analysis_dir\n";

    DumpFile("$analysis_dir/params.yml", \%params);

    my $fh;
    my $sample = "$self->{dir}/sample.fa";
    if (!open($fh, "<", $sample))
    {
	die "Cannot open sample file $sample: $!";
    }
    my %otu_summary;
    my %fn_summary;

    my $details_fh;
    open($details_fh, ">", "$analysis_dir/sample.out") or die "Cannot write $analysis_dir/sample.out: $!";

    my $otu_sum_fh;
    open($otu_sum_fh, ">", "$analysis_dir/sample.otu.sum") or die "Cannot write $analysis_dir/sample.otu.sum: $!";

    my $fn_sum_fh;
    open($fn_sum_fh, ">", "$analysis_dir/sample.fn.sum") or die "Cannot write $analysis_dir/sample.fn.sum: $!";

    my $start_time = gettimeofday;
    my $rh = $self->anno->assign_functions_to_dna(-input => $fh, %params);
    my $totF = 0;
    my $totO = 0;
    while (my $res = $rh->get_next())
    {
	my($id, $tuple) = @$res;

	my($count, $start, $stop, $func, $otu) = @$tuple;

	my $loc = "${id}_${start}_${stop}";
	print $details_fh "$id\t$count\t$loc\t$func\t$otu\n";

	if (defined($otu))
	{
	    $otu_summary{$otu}++;
	    $totO++;
	}
	if (defined($func))
	{
	    $fn_summary{$func}++;
	    $totF++;
	}
    }
    my $end_time = gettimeofday;

    close($details_fh);
    
    for my $fn (sort { $fn_summary{$b} <=> $fn_summary{$a} } keys %fn_summary)
    {
	print $fn_sum_fh join("\t",
			      $fn_summary{$fn},
			      sprintf("%0.6f", $fn_summary{$fn} / $totF),
			      $fn), "\n";
    }
    close($fn_sum_fh);
    
    for my $otu (sort { $otu_summary{$b} <=> $otu_summary{$a} } keys %otu_summary)
    {
	print $otu_sum_fh join("\t",
			      $otu_summary{$otu},
			      sprintf("%0.6f", $otu_summary{$otu} / $totO),
			      $otu), "\n";
    }
    close($otu_sum_fh);

    #
    # Summary data.
    #
    my $sum = {
	hits_with_function => $totF,
	hits_with_otu => $totO,
	distinct_functions => scalar(keys %fn_summary),
	distinct_otus => scalar(keys %otu_summary),
	elapsed_time => ($end_time - $start_time),
    };
    DumpFile("$analysis_dir/summary.yml", $sum);

    return ($ds, $analysis_num);
}

sub get_analysis_list
{
    my($self) = @_;

    my $out = {};
    if (opendir(my $dh1, $self->dir))
    {
	while (my $f1 = readdir($dh1))
	{
	    my $p1 = "$self->{dir}/$f1";
	    if (opendir(my $dh2, $p1))
	    {
		while (my $f2 = readdir($dh2))
		{
		    my $p2 = "$p1/$f2";
		    if ($f2 =~ /^\d+$/ && -d $p2)
		    {
			push(@{$out->{$f1}}, $f2);
		    }
		}
		closedir($dh2); 
	    }
	}
	closedir($dh1);
    }
    return $out;
}
    
sub get_analysis
{
    my($self, $which, $n) = @_;
    my $dir = "$self->{dir}/$which/$n";
    if (-d $dir)
    {
	return SampleAnalysis->new($self, $which, $n, $dir);
    }
    else
    {
	return undef;
    }
}

package SampleAnalysis;
use strict;
use YAML::Any qw(Dump Load DumpFile LoadFile);
use POSIX;

use base 'Class::Accessor';

__PACKAGE__->mk_accessors(qw(sample dataset index dir));

sub new
{
    my($class, $sample, $dataset, $index, $dir) = @_;

    my $params_file = "$dir/params.yml";
    my $summary_file = "$dir/summary.yml";

    my $params = eval { LoadFile($params_file); };
    my $summary = eval { LoadFile($summary_file); };

    my $self = {
	sample => $sample,
	dataset => $dataset,
	index => $index,
	dir => $dir,
	params => ($params || {}),
	summary => ($summary || {}),
	params_file => $params_file,
	summary_file => $summary_file,
    };
    return bless $self, $class;
}

sub get_parameters
{
    my($self) = @_;
    return $self->{params};
}

sub save_parameters
{
    my($self) = @_;
    my $now = strftime("%Y-%m-%d-%H-%M-%S", localtime);
    my $bak = "$self->{params_file}.bak.$now";
    if (!rename($self->{params_file}, $bak))
    {
	warn "Could not rename $self->{params_file} to $bak: $!";
    }
    DumpFile($self->{params_file}, $self->{params});
}

sub get_summary
{
    my($self) = @_;
    return $self->{summary};
}

sub get_function_file
{
    my($self) = @_;
    return "$self->{dir}/sample.fn.sum";
}

sub get_otu_file
{
    my($self) = @_;
    return "$self->{dir}/sample.otu.sum";
}

sub get_all_hits_file
{
    my($self) = @_;
    return "$self->{dir}/sample.out";

    my $grid = Wx::Grid->new($self, -1);
}

sub get_function_vector
{
    my($self, $basis) = @_;

    return $basis->create_vector($self->get_function_file);
}

sub get_otu_vector
{
    my($self, $basis) = @_;

    return $basis->create_vector($self->get_otu_file);
}

#
# Recreate the summarization of data based on the
# current function exclusion list.
#
sub rerun_analysis
{
    my($self) = @_;

    my $analysis_dir = $self->dir;

    my $raw_fh;
    if (!open($raw_fh, "<", "$analysis_dir/sample.out"))
    {
	warn "Cannot open $analysis_dir/sample.out: $!";
	return;
    }

    my $otu_sum_fh;
    open($otu_sum_fh, ">", "$analysis_dir/sample.otu.sum") or die "Cannot write $analysis_dir/sample.otu.sum: $!";

    my $fn_sum_fh;
    open($fn_sum_fh, ">", "$analysis_dir/sample.fn.sum") or die "Cannot write $analysis_dir/sample.fn.sum: $!";

    my $totF = 0;
    my $totO = 0;
    my $excluded = 0;

    my %otu_summary;
    my %fn_summary;
    
    my $exclusions = $self->{params}->{excluded_functions};
    while (<$raw_fh>)
    {
	chomp;
	my($id, $count, $loc, $func, $otu) = split(/\t/);

	if ($exclusions->{$func})
	{
	    $excluded++;
	    next;
	}

	if ($otu ne '')
	{
	    $otu_summary{$otu}++;
	    $totO++;
	}
	if ($func ne '')
	{
	    $fn_summary{$func}++;
	    $totF++;
	}
    }
    close($raw_fh);
    
    for my $fn (sort { $fn_summary{$b} <=> $fn_summary{$a} } keys %fn_summary)
    {
	print $fn_sum_fh join("\t",
			      $fn_summary{$fn},
			      sprintf("%0.6f", $fn_summary{$fn} / $totF),
			      $fn), "\n";
    }
    close($fn_sum_fh);
    
    for my $otu (sort { $otu_summary{$b} <=> $otu_summary{$a} } keys %otu_summary)
    {
	print $otu_sum_fh join("\t",
			      $otu_summary{$otu},
			      sprintf("%0.6f", $otu_summary{$otu} / $totO),
			      $otu), "\n";
    }
    close($otu_sum_fh);

    #
    # Summary data.
    #
    my $sum = {};
    %$sum = %{$self->{summary}};

    my $sum2 = {
	hits_with_function => $totF,
	hits_with_otu => $totO,
	distinct_functions => scalar(keys %fn_summary),
	distinct_otus => scalar(keys %otu_summary),
	excluded_hits => $excluded,
    };
    $sum->{$_} = $sum2->{$_} for keys %$sum2;

    $self->{summary} = $sum;
    
    DumpFile("$analysis_dir/summary.yml", $sum);
}

package VectorBasis;
use strict;
use PDL;

=head1 DESCRIPTION

A vector basis is used to define the indexes in the function or OTU vectors
to be used for each function or OTU string. The definition of these is
kept on the SEED servers and is retrieved via the get_vector_basis_sets
call. The resulting data file contains tab-separated pairs
(index, name). The indexes here are 1-based, so we convert them to be
0-based.

=cut
    
sub new
{
    my($class, $file) = @_;

    my $fh;
    if (!open($fh, "<", $file))
    {
	die "VectorBasis::new: cannot open $file: $!";
    }

    my $by_idx = [];
    my $by_name = {};
    my $n = 0;
    while (<$fh>)
    {
	chomp;
	my($idx, $str) = split(/\t/);
	$idx--;
	$by_idx->[$idx] = $str;
	$by_name->{$str} = $idx;
	$n = $idx if $idx > $n;
    }
    $n++;

    my $self = {
	file => $file,
	by_index => $by_idx,
	by_name => $by_name,
	length => $n,
    };

    return bless $self, $class;
}

=head2 create_vector
    
Create a PDL vector from the given file. It is to be of the format of the
function and OTU summary files - tab separated triples (count, fraction, name).

=cut

sub create_vector
{
    my($self, $file) = @_;
    my $fh;
    if (!open($fh, "<", $file))
    {
	die "VectorBasis::create_vector: cannot open $file: $!";
    }

    my $vec = zeroes($self->{length});

    while (<$fh>)
    {
	chomp;
	my($count, $frac, $str) = split(/\t/);
	my $idx = $self->{by_name}->{$str};
	if (defined($idx))
	{
	    $vec->index($idx) += $count;
	}
    }
    return $vec;
}
     

1;
