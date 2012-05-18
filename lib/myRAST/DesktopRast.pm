package DesktopRast;

use Moose;
use Moose::Util::TypeConstraints;
use PipelineStage;
use File::HomeDir;
use SOAP::Lite;
use File::Path;
use File::Copy;
use Data::Dumper;
use POSIX;
use IPC::Run;
use SeedUtils;
use ViewableFile;

with 'PipelineHost';

if ($^O =~ /win32/i)
{
    require Win32;
}

=head1 NAME
    
DesktopRast - the core Desktop RAST engine

=head1 DESCRIPTION

An instance of this object handles the processing of an input file
through the Desktop RAST pipeline.

It is responsible for instantiating the graph of PipelineStage instances
and attaching them in the correct order. 

=head1 METHODS

=over 4

=cut

has 'stages' => (is => 'ro',
		 traits => ['Array'],
		 isa => 'ArrayRef[PipelineStage]',
		 default => sub { [] },
		 handles => {
		     add_stage => 'push',
		     all_stages => 'elements',
		 },
		 );

has 'dir' => (is => 'rw',
	      isa => 'Str');

has 'input_file' => (is => 'rw',
		     isa => 'Str');

has 'genbank_dir' => (is => 'rw',
		      isa => 'Str');

has 'processing_speed' => (is => 'rw',
			   isa => enum([qw(fast faster)]),
			   default => 'faster');

has 'sequence_type' => (is => 'rw',
			isa => enum([qw(dna protein genbank)]),
		       );

has 'kmer_size' => (is => 'rw',
		    isa => enum([7..12]),
		    default => 8);

has 'score_thresh' => (is => 'rw',
		       isa => 'Num',
		       default => 3);

has 'seq_hit_thresh' => (is => 'rw',
			 isa => 'Num',
			 default => 2);

has 'genome_id' => (is => 'rw',
		    isa => 'Str');

has 'dominant_otu' => (is => 'rw',
		       isa => 'Str');

has 'genetic_code' => (is => 'rw',
		       isa => 'Num',
		       default => 11);

has 'inhibit_correspondence_computation' => (is => 'ro',
					     isa => 'Bool');

=item B<< $rast->start() >>

Start the pipeline. 

We begin by attempting to allocate a new genome id in the 6666667 range (for
personal genomes). If that does not work, allocate one of the form YYYYMMDDHH.MM since it really
doesn't matter what it is.

Create a genome directory in our designated work directory. Use File::HomeDir to
find the "Documents" directory, and put this in DesktopRast underneath.

=cut

sub setup
{
    my($self) = @_;

    $self->setup_input();

    #
    # Set up pipeline, depending on kind of input.
    #
    if (lc($self->sequence_type) eq 'dna')
    {
	$self->configure_dna_pipeline();
    }
    else
    {
	$self->configure_protein_pipeline();
    }
}

=item B<< $rast->setup_input() >>

Determine if the input file is a genbank or fasta file. (This is a
quick test that won't cope with badly-line-ended input files, etc).

If it is genbank, scan the file to attempt to find a db_xref with the
taxon ID in it. If found use that for the genome, otherwise allocate one
from the 6666667 space. Create the work directory, and parse the genbank
into that directory. Point the input_file attribute at the contigs there.

If it is fasta, just set up the directory.

=cut

sub setup_input
{
    my($self) = @_;

    open(my $inp_fh, "<", $self->input_file) or die "Cannot open input file: " . $self->input_file . ": $!";

    $_ = <$inp_fh>;
    if (/LOCUS/)
    {
	$self->setup_genbank($inp_fh);
    }
    else
    {
	close($inp_fh);
	$self->setup_fasta();
    }
}

sub setup_genbank
{
    my($self, $inp_fh) = @_;
    my $tax = 6666667;
    while (<$inp_fh>)
    {
	if (m,/db_xref.*taxon.*?(\d+),)
	{
	    $tax = $1;
	}
    }
    close($inp_fh);
    my $genome_id = $self->allocate_genome_id($tax);
    $self->genome_id($genome_id);
    my $dir = File::HomeDir->my_documents . "/myRAST/$genome_id";
    mkpath($dir);
    
    $self->dir($dir);

    my $gb_dir = "$dir/original_genbank";
    my $rc = system("parse_genbank", "-i=" . $self->input_file,
		    $tax, $gb_dir);

    if ($rc != 0)
    {
	die "Error parsing genbank file (rc=$rc)\n";
    }
    #
    # Copy the original file into the job directory too.
    #
    copy($self->input_file, "$dir/genbank_file");
	 
    #
    # Parse successful, retarget input file to the contigs file in
    # the genbank directory.
    #
    $self->genbank_dir($gb_dir);
    $self->input_file("$gb_dir/contigs");
    $self->sequence_type('dna');

}

sub setup_fasta
{
    my($self) = @_;
    my $genome_id = $self->allocate_genome_id();
    $self->genome_id($genome_id);
    my $dir = File::HomeDir->my_documents . "/myRAST/$genome_id";
    mkpath($dir);
    
    $self->dir($dir);
}
   

sub start
{
    my($self) = @_;
    
    $_->check_for_inputs_ready() for $self->all_stages;
}

sub configure_dna_pipeline
{
    my($self) = @_;

    my $dir = $self->dir;
    my $file = $self->input_file;

    #
    # Normalize the input data into the contigs file.
    #

    SeedUtils::validate_fasta_file($file, "$dir/contigs");

    #
    # Set up pipeline.
    #

    my $contigs = ViewableFile->new(filename => "$dir/contigs",
				      label => "original contigs");
    
    my $peg_fasta = ViewableFile->new(filename => "$dir/peg.fa",
				      label => "PEG fasta");
    my $peg_tbl = ViewableFile->new(filename => "$dir/peg.tbl",
				    label => "PEG table");

    my $rna_fasta = ViewableFile->new(filename => "$dir/rna.fa",
				      label => "RNA fasta");
    my $rna_tbl = ViewableFile->new(filename => "$dir/rna.tbl",
				    label => "RNA table");

    my $funcs = ViewableFile->new(filename => "$dir/functions.tbl",
				  label => "annotated genes");
    my $uncalled_funcs = ViewableFile->new(filename => "$dir/uncalled.tbl",
					   label => "unannotated genes");

    my $dom_otu = ViewableFile->new(filename => "$dir/otu_summary.tbl",
				    label => "OTU distribution");

    my $otus = ViewableFile->new(filename => "$dir/gene_otus.tbl",
				    label => "OTU table");

    my $metab_recon = ViewableFile->new(filename => "$dir/meta_recon.tbl",
					label => "metabolic reconstruction");
    
    my $metab_unused = ViewableFile->new(filename => "$dir/meta_recon_unused.tbl",
					label => "metabolic reconstruction unused roles");

    ###

    my @call_genes_files = ($contigs, $peg_fasta, $peg_tbl);
    my $call_genes = PipelineStage->new(rast => $self,
					name => "Gene calling",
					key => "call_genes",
					program => "dtr_call_genes",
					args => [$self->genetic_code, map { $_->get_path } @call_genes_files],
					viewable_files => \@call_genes_files,
					dir => $self->dir,
					);

    $self->add_stage($call_genes);

    my @call_rnas_files = ($dom_otu, $contigs, $rna_fasta, $rna_tbl);
    my @call_rnas_files_view = ($rna_fasta, $rna_tbl);
    my $call_rnas = PipelineStage->new(rast => $self,
				       name => "RNA calling",
				       key => "call_rnas",
				       program => "dtr_call_rnas",
				       args => [map { $_->get_path } @call_rnas_files],
				       viewable_files => \@call_rnas_files_view,
				       dir => $self->dir,
				      );
    $self->add_stage($call_rnas);

    my @anno_args;
    if ($self->processing_speed eq 'fast')
    {
	push(@anno_args, "-assignToAll", 1);
    }
    push(@anno_args,
	 -kmer => $self->kmer_size,
	 -scoreThreshold => $self->score_thresh,
	 -seqHitThreshold => $self->seq_hit_thresh);


    my @anno_files = ($peg_fasta, $funcs, $otus, $uncalled_funcs, $dom_otu);
    my $annotate = PipelineStage->new(rast => $self,
				      key => 'annotate',
				      name => "Annotation",
				      program => 'dtr_assign_functions',
				      args => [@anno_args, map { $_->get_path } @anno_files],
				      viewable_files => \@anno_files,
				      on_completion => sub {
					  $self->complete_annotation($dom_otu);
				      },
				      dir => $self->dir,
				      );
    $self->add_stage($annotate);
    $call_genes->connect_output($annotate);
    $annotate->connect_output($call_rnas);

    my $metabolic_recon = PipelineStage->new(rast => $self,
					     key => 'metab_recon',
					     name => "Metabolic reconstruction",
					     input_file => $funcs->get_path,
					     output_file => $metab_recon->get_path,
					     error_file => $metab_unused->get_path,
					     program => "svr_metabolic_reconstruction",
					     viewable_files => [$funcs, $metab_recon, $metab_unused],
					     notify_enabled => 0,
					     dir => $self->dir,
					    );
    
    $self->add_stage($metabolic_recon);
    $annotate->connect_output($metabolic_recon);

    my $genome_dir = $self->dir . "/" . $self->genome_id;

    my $dirpath = $dir;
    my $gdirpath = $genome_dir;
    my $closest_path = "$genome_dir/closest.genomes";
    if ($^O =~ /win32/i)
    {
	$dirpath = Win32::GetShortPathName($dir);
	$gdirpath = $dirpath . "\\" . $self->genome_id;
	$closest_path = $gdirpath . "\\closest.genomes";
    }

    my $make_genome_dir = PipelineStage->new(rast => $self,
 					name => "Create genome dir",
					key => 'create_genome_dir',
					program => "dtr_make_genome_dir",
					args => [$self->genome_id, $dirpath, $dirpath],
					dir => $self->dir,
				       );
     $self->add_stage($make_genome_dir);
     $call_rnas->connect_output($make_genome_dir);
     $metabolic_recon->connect_output($make_genome_dir);

     if (!$self->inhibit_correspondence_computation)
     {

	 my $neighbors_file = ViewableFile->new(filename => $closest_path,
						label => "closest genomes");
	 
	 my $compute_neighbors = PipelineStage->new(rast => $self,
						    key => "compute_neighbors",
						    name => "Compute closest neighbors",
						    program => 'dtr_get_neighbors',
						    args => [ $gdirpath, $closest_path],
						    notify_enabled => 0,
						    viewable_files => [$neighbors_file],
						    dir => $self->dir,
						   );
	 $self->add_stage($compute_neighbors);
	 $make_genome_dir->connect_output($compute_neighbors);

	 my $compute_corr = PipelineStage->new(rast => $self,
					       key => "compute_corr",
					       name => "Compute correspondences",
					       program => 'dtr_compute_correspondences',
					       args => [ $gdirpath, $closest_path],
					       notify_enabled => 0,
					       dir => $self->dir,
					       );
	 $self->add_stage($compute_corr);
	 $compute_neighbors->connect_output($compute_corr);
     }
}

sub configure_protein_pipeline
{
    my($self) = @_;

    my $dir = $self->dir;
    my $file = $self->input_file;

    #
    # Normalize the input data into the peg.fa file.
    #

    SeedUtils::validate_fasta_file($file, "$dir/peg.fa");

    #
    # Set up pipeline.
    #

    my $peg_fasta = ViewableFile->new(filename => "$dir/peg.fa",
				      label => "PEG fasta");

    my $funcs = ViewableFile->new(filename => "$dir/functions.tbl",
				  label => "annotated genes");
    my $uncalled_funcs = ViewableFile->new(filename => "$dir/uncalled.tbl",
					   label => "unannotated genes");

    my $dom_otu = ViewableFile->new(filename => "$dir/otu_summary.tbl",
				    label => "OTU distribution");

    my $otus = ViewableFile->new(filename => "$dir/gene_otus.tbl",
				    label => "OTU table");

    my $metab_recon = ViewableFile->new(filename => "$dir/meta_recon.tbl",
					label => "metabolic reconstruction");
    
    my $metab_unused = ViewableFile->new(filename => "$dir/meta_recon_unused.tbl",
					label => "metabolic reconstruction unused roles");

    my @anno_args;
    if ($self->processing_speed eq 'fast')
    {
	push(@anno_args, "-assignToAll", 1);
    }
    push(@anno_args,
	 -kmer => $self->kmer_size,
	 -scoreThreshold => $self->score_thresh,
	 -seqHitThreshold => $self->seq_hit_thresh);


    my @anno_files = ($peg_fasta, $funcs, $otus, $uncalled_funcs, $dom_otu);
    my $annotate = PipelineStage->new(rast => $self,
				      key => 'annotate',
				      name => "Annotation",
				      program => 'dtr_assign_functions',
				      args => [@anno_args, map { $_->get_path } @anno_files],
				      viewable_files => \@anno_files,
				      on_completion => sub {
					  $self->complete_annotation($dom_otu);
				      },
				      dir => $self->dir,
				      );
    $self->add_stage($annotate);

    my $metabolic_recon = PipelineStage->new(rast => $self,
					     key => 'metab_recon',
					     name => "Metabolic reconstruction",
					     input_file => $funcs->get_path,
					     output_file => $metab_recon->get_path,
					     error_file => $metab_unused->get_path,
					     program => "svr_metabolic_reconstruction",
					     viewable_files => [$funcs, $metab_recon, $metab_unused],
					     notify_enabled => 0,
					     dir => $self->dir,
					    );
    
    $self->add_stage($metabolic_recon);
    $annotate->connect_output($metabolic_recon);

    my $genome_dir = $self->dir . "/" . $self->genome_id;

    my $dirpath = $dir;
    my $gdirpath = $genome_dir;
    my $closest_path = "$genome_dir/closest.genomes";
    if ($^O =~ /win32/i)
    {
	$dirpath = Win32::GetShortPathName($dir);
	$gdirpath = $dirpath . "\\" . $self->genome_id;
	$closest_path = $gdirpath . "\\closest.genomes";
    }

    my $make_genome_dir = PipelineStage->new(rast => $self,
 					name => "Create genome dir",
					key => 'create_genome_dir',
					program => "dtr_make_genome_dir",
					args => [$self->genome_id, $dirpath, $dirpath],
					dir => $self->dir,
				       );
     $self->add_stage($make_genome_dir);
     $metabolic_recon->connect_output($make_genome_dir);

     if (!$self->inhibit_correspondence_computation)
     {

	 my $neighbors_file = ViewableFile->new(filename => $closest_path,
						label => "closest genomes");
	 
	 my $compute_neighbors = PipelineStage->new(rast => $self,
						    key => "compute_neighbors",
						    name => "Compute closest neighbors",
						    program => 'dtr_get_neighbors',
						    args => [ $gdirpath, $closest_path],
						    notify_enabled => 0,
						    viewable_files => [$neighbors_file],
						    dir => $self->dir,
						   );
	 $self->add_stage($compute_neighbors);
	 $make_genome_dir->connect_output($compute_neighbors);

	 my $compute_corr = PipelineStage->new(rast => $self,
					       key => "compute_corr",
					       name => "Compute correspondences",
					       program => 'dtr_compute_correspondences',
					       args => [ $gdirpath, $closest_path],
					       notify_enabled => 0,
					       dir => $self->dir,
					       );
	 $self->add_stage($compute_corr);
	 $compute_neighbors->connect_output($compute_corr);
     }
}

sub complete_annotation
{
    my($self, $dom_otu_file) = @_;

    if (open(my $id, "<", $dom_otu_file->filename))
    {
	my $l = <$id>;
	if ($l)
	{
	    chomp $l;
	    print "GOT $l\n";
	    my($name, $genus, $species, $domain) = split(/\t/, $l);
	    $self->dominant_otu($name);
	}
	close($id);
    }
}

#
# I have no idea why we did this before. Well, we did it because the
# Mac app did it, (via glue_tbl_to_metabolic_reconstruction) but I
# don't know why we did it there either.
#
sub complete_reconstruction
{
    my($self, $mr_stage, $call_genes_stage) = @_;

    #
    # Take the metabolic reconstruction output and the tbl-file output
    # from the gene caller. Column 2 of the reconstruction is a protein ID;
    # create a new output file that has the contig/beg/end from the tbl file appended.
    #

    my %tbl;
    open(IN, "<", $call_genes_stage->error_file());
    while (<IN>)
    {
	chomp;
	my(@a) = split(/\t/);
	$tbl{$a[0]} = [@a];
    }
    close(IN);

    my $new_output = $mr_stage->output_file . ".orig";
    rename($mr_stage->output_file, $new_output);
    open(IN, "<", $new_output);
    open(OUT, ">", $mr_stage->output_file);
    while (<IN>)
    {
	chomp;
	my(@a) = split(/\t/);
	my $l = $tbl{$a[1]};
	if ($l)
	{
	    splice(@a, 1, 1, @$l);
	}
	print OUT join("\t", @a), "\n";
    }
    close(IN);
    close(OUT); 
   
}

sub complete_call_genes
{
    my($self, $stage) = @_;
}

sub check_pipeline
{
    my($self) = @_;
    my $all_done = 1;
    for my $stage ($self->all_stages)
    {
	my $state = $stage->check_for_completion();
	$all_done = 0 unless $state eq 'complete';
    }
    return $all_done;
}

sub allocate_genome_id
{
    my($self, $tax) = @_;

    print "allocate_genome_id: tax=$tax\n";
    $tax = 6666667 unless defined($tax);

    my $proxy = SOAP::Lite->uri('http://www.soaplite.com/Scripts') ->
	proxy("http://clearinghouse.theseed.org/Clearinghouse/clearinghouse_services.cgi");

    my $r;
    eval {
	$r = $proxy->register_genome($tax);
    };
    
    if ($@ || $r->fault) {
	print "Failed to allocate: \$\@=$@\n";
	if (defined($r))
	{
	    print "fault=" . $r->faultstring . "\n";
	}
	$r = strftime("%y%j%H.%M%S", localtime);
    }
    else
    {
	$r = $tax . "." . $r->result;
    }

    return $r;
}
1;
