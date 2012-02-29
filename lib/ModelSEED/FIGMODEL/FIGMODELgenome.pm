use strict;
package ModelSEED::FIGMODEL::FIGMODELgenome;
use Scalar::Util qw(weaken);
use Carp qw(cluck);

=head1 FIGMODELgenome object
=head2 Introduction
Module for holding genome related access functions
=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELgenome = FIGMODELgenome->new({figmodel => $self,genome => $genome});
Description:
	This is the constructor for the FIGMODELgenome object.
=cut
sub new {
	my ($class,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["genome"],{});
	my $self = {_genome => $args->{genome}};
	bless $self;
    $self->{_ppo} = $self->figmodel()->database()->get_object("genomestats",{GENOME => $self->genome()});
	if (!defined($self->{_ppo})) {
		if (!defined($self->{_ppo})) {
			$self->{_ppo} = $self->update_genome_stats();
		}
		if (!defined($self->{_ppo})) {
			ModelSEED::utilities::ERROR("Could not find genome in database:".$self->genome());
		}
	}
	return $self;
}

=head3 figmodel
Definition:
	FIGMODEL = FIGMODELgenome->figmodel();
Description:
	Returns the figmodel object
=cut
sub figmodel {
	my ($self) = @_;
	return ModelSEED::globals::GETFIGMODEL();
}

=head3 ppo
Definition:
	PPO:genomestats = FIGMODELgenome->ppo();
Description:
	Returns the PPO genomestats object for the genome
=cut
sub ppo {
	my ($self) = @_;
	return $self->{_ppo};
}

=head3 genome_stats
Definition:
	FIGMODELTable:feature table = FIGMODELgenome->genome_stats();
Description:
=cut
sub genome_stats {
	my ($self) = @_;
	return $self->ppo();
}

=head3 genome
Definition:
	string:genome ID = FIGMODELgenome->genome();
Description:
	Returns the genome ID
=cut
sub genome {
	my ($self) = @_;
	return $self->{_genome};
}

=head3 error_message
Definition:
	string:message text = FIGMODELgenome->error_message(string::message);
Description:
=cut
sub error_message {
	my ($self,$message) = @_;
	return $self->figmodel()->error_message("FIGMODELgenome:".$self->genome().":".$message);
}

=head3 source
Definition:
	string:source = FIGMODELgenome->source();
Description:
	Returns the source of the genome
=cut
sub source {
	my ($self) = @_;
	return $self->ppo()->source();
}

=head3 name
Definition:
	string:source = FIGMODELgenome->name();
Description:
	Returns the name of the genome
=cut
sub name {
	my ($self) = @_;
	return $self->ppo()->name();
}

=head3 taxonomy
Definition:
	string:taxonomy = FIGMODELgenome->taxonomy();
Description:
	Returns the taxonomy of the genome
=cut
sub taxonomy {
	my ($self) = @_;
	return $self->ppo()->taxonomy();
}

=head3 owner
Definition:
	string:source = FIGMODELgenome->owner();
Description:
	Returns the owner of the genome
=cut
sub owner {
	my ($self) = @_;
	return $self->ppo()->owner();
}

=head3 size
Definition:
	string:source = FIGMODELgenome->size();
Description:
	Returns the size of the genome
=cut
sub size {
	my ($self) = @_;
	return $self->ppo()->size();
}

=head3 modelObj
Definition:
	FIGMODELmodel:model object = FIGMODELgenome->modelObj();
Description:
	Returns the model object for the default model for this genome
=cut
sub modelObj {
	my ($self) = @_;
	my $mdl = $self->figmodel()->get_model("Seed".$self->genome());
	if (!defined($mdl)) {
		$mdl = $self->figmodel()->get_model("Seed".$self->genome().".796");
	}
	return $mdl;
}

=head3 feature_table
Definition:
	FIGMODELTable:feature table = FIGMODELgenome->feature_table({
		genome =>
		getSequences =>
		getEssentiality =>
		models =>
		source =>	
	});
Description:
	Returns a table of features in the genome
=cut
sub feature_table {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		genome => $self->genome(),
		getSequences => 0,
		getEssentiality => 1,
		models => undef,
		source => undef,
		owner => undef
	});
	if (!defined($args->{source}) && defined($self->ppo())) {
		$args->{source} = $self->ppo()->source();
	}
	if (!defined($args->{owner}) && defined($self->ppo())) {
		$args->{owner} = $self->ppo()->owner();
	}
	if (!defined($self->{_features})) {
		if ($args->{source} =~ m/RAST/) {
			my $output = $self->getRastGenomeData();
		} elsif ($args->{source} =~ m/SEED/) {
			$self->{_features} = ModelSEED::FIGMODEL::FIGMODELTable->new(["ID","GENOME","ESSENTIALITY","ALIASES","TYPE","LOCATION","LENGTH","DIRECTION","MIN LOCATION","MAX LOCATION","ROLES","SOURCE","SEQUENCE"],$self->figmodel()->config("database message file directory")->[0]."Features-".$args->{genome}.".txt",["ID","ALIASES","TYPE","ROLES","GENOME"],"\t","|",undef);
			$self->{_features}->{_source} = $args->{source};
			$self->{_features}->{_owner} = $args->{owner};
			my $sap = $self->figmodel()->sapSvr($args->{source});
			#TODO: I'd like to see if we could possibly get all of this data with a single call
			#Getting feature list for genome
			my $featureHash = $sap->all_features({-ids => $args->{genome}});
			my $featureList = $featureHash->{$args->{genome}};
			#Getting functions for each feature
			my $functions = $sap->ids_to_functions({-ids => $featureList});
			#Getting locations for each feature
			my $locations = $sap->fid_locations({-ids => $featureList});
			#Getting aliases
			my $aliases;
			#my $aliases = $sap->fids_to_ids({-ids => $featureList,-protein => 1});
			#Getting sequences for each feature
			my $sequences;
			if ($args->{getSequences} == 1) {
				$sequences = $sap->ids_to_sequences({-ids => $featureList,-protein => 1});
			}
			#Placing data into feature table
			for (my $i=0; $i < @{$featureList}; $i++) {
				my $row = {ID => [$featureList->[$i]],GENOME => [$args->{genome}],TYPE => ["peg"]};
				if ($featureList->[$i] =~ m/\d+\.([^\.]+)\.\d+$/) {
					$row->{TYPE}->[0] = $1;
				}
				if (defined($locations->{$featureList->[$i]}->[0]) && $locations->{$featureList->[$i]}->[0] =~ m/(\d+)([\+\-])(\d+)$/) {
					if ($2 eq "-") {
						$row->{"MIN LOCATION"}->[0] = ($1-$3);
						$row->{"MAX LOCATION"}->[0] = ($1);
						$row->{LOCATION}->[0] = $1."_".($1-$3);
						$row->{DIRECTION}->[0] = "rev";
						$row->{LENGTH}->[0] = $3;
					} else {
						$row->{"MIN LOCATION"}->[0] = ($1);
						$row->{"MAX LOCATION"}->[0] = ($1+$3);
						$row->{LOCATION}->[0] = $1."_".($1+$3);
						$row->{DIRECTION}->[0] = "for";
						$row->{LENGTH}->[0] = $3;
					}
				}
				if (defined($aliases->{$featureList->[$i]})) {
					my @types = keys(%{$aliases->{$featureList->[$i]}});
					for (my $j=0; $j < @types; $j++) {
						push(@{$row->{ALIASES}},@{$aliases->{$featureList->[$i]}->{$types[$j]}});
					}
				}
				if (defined($functions->{$featureList->[$i]})) {
					push(@{$row->{ROLES}},$self->figmodel()->roles_of_function($functions->{$featureList->[$i]}));
				}
				if (defined($args->{getSequences}) && $args->{getSequences} == 1 && defined($sequences->{$featureList->[$i]})) {
					$row->{SEQUENCE}->[0] = $sequences->{$featureList->[$i]};
				}
				$self->{_features}->add_row($row);
			}
		}
		#Adding gene essentiality data to the table
		if ($args->{getEssentiality} == 1 && defined($self->{_features})) {
			my $sets = $self->figmodel()->database()->get_objects("esssets",{GENOME => $self->genome()});
			for (my $i=0; $i < $self->{_features}->size(); $i++) {
				my $row = $self->{_features}->get_row($i);
				if (defined($sets->[0])) {
					if ($row->{ID}->[0] =~ m/(peg\.\d+)/) {
						my $gene = $1;
						for (my $i=0; $i < @{$sets}; $i++) {
							my $essGene = $self->figmodel()->database()->get_object("essgenes",{FEATURE=>$gene,ESSENTIALITYSET=>$sets->[$i]->id()});
							if (defined($essGene)) {
								push(@{$row->{ESSENTIALITY}},$sets->[$i]->MEDIA().":".$essGene->essentiality());
							}
						}
					}
				}
			}
		}
	}
	#Adding model data to feature table
	if (defined($args->{models})) {
		for (my $i=0; $i < @{$args->{models}}; $i++) {
			my $mdl = $self->figmodel()->get_model($args->{models}->[$i]);
			my $geneHash = $mdl->featureHash();
			my @genes = keys(%{$geneHash});
			for (my $j=0; $j < @genes; $j++) {
				my $row = $self->{_features}->get_row_by_key("fig|".$self->genome().".".$genes[$j],"ID");
				if (defined($row)) {
					$row->{$args->{models}->[$i]} = $geneHash->{$genes[$j]};
				}	
			}
		}
	}
	return $self->{_features};
}

=head3 getRastGenomeData
Definition:
	FIGMODELTable:feature table = FIGMODELgenome->getRastGenomeData({});
Description:
=cut
sub getRastGenomeData {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	#Getting RAST feature data from the FBAMODEL server for now
	my $svr = $self->figmodel()->server("MSSeedSupportClient");
	my $output = $svr->getRastGenomeData({genome => $self->genome(),username => $self->figmodel()->userObj()->login(),password => $self->figmodel()->userObj()->password()});
	if (!defined($output->{features})) {
		$self->error_message("Could not load feature table for rast genome:".$output->{error});
		return undef;
	}
	$self->{_features}->{_source} = $output->{source};
	$self->{_features}->{_owner} = $output->{owner};
	$self->{_features}->{_name} = $output->{name};
	$self->{_features}->{_taxonomy} = $output->{taxonomy};
	$self->{_features}->{_size} = $output->{size};
	$self->{_features}->{_active_subsystems} = $output->{activeSubsystems};
	$self->{_active_subsystems} = $output->{activeSubsystems};
	$self->{_features}->{_gc} = $output->{gc};
	$self->{_features} = $output->{features};
	return $output;
}

=head3 intervalGenes
Definition:
	{genes => [string:gene IDs]} = FIGMODELgenome->intervalGenes({start => integer:start location,stop => integer:stop location});
Description:
=cut
sub intervalGenes {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["start","stop"],{});
	if (defined($args->{error})) {return {error => $args->{error}};}
	my $tbl = $self->feature_table();
	if (!defined($tbl)) {return {error => $self->error_message("intervalGenes:could not load feature table for genome")};}
	my $results;
	for (my $i=0; $i < $tbl->size(); $i++) {
		my $row = $tbl->get_row($i);
		if ($row->{ID}->[0] =~ m/fig\|\d+\.\d+\.(peg\.\d+)/) {
			my $id = $1;
			if (defined($row->{"MIN LOCATION"}->[0]) && defined($row->{"MAX LOCATION"}->[0]) && $args->{stop} > $row->{"MIN LOCATION"}->[0] && $args->{start} < $row->{"MAX LOCATION"}->[0]) {
				push(@{$results->{genes}},$id);
			}
		}
	}
	return $results;
}
=head3 update_genome_stats
Definition:
	FIGMODELgenome->update_genome_stats();
Description:
=cut
sub update_genome_stats {
	my ($self) = @_;
	#Initializing the empty stats hash with default values
	my $genomeStats = {
		GENOME => $self->genome(),
		class => "Unknown",
		source => "PUBSEED",
		owner => "master",
		name => undef,
		taxonomy => undef,
		size => undef,
		public => 1,
		genes => 0,
		gramPosGenes => 0,
		gramNegGenes => 0,
		genesWithFunctions => 0,
		genesInSubsystems => 0,
		gcContent => 0
	};
	#Determining the source, name, size, taxonomy of the genome
	my $GenomeData;
	my $sap = $self->figmodel()->sapSvr("PUBSEED");
	my $result = $sap->exists({-type => 'Genome',-ids => [$self->genome()]});
	if ($result->{$self->genome()} eq "0") {
		my $output = $self->getRastGenomeData();
		if (!defined($self->{_features})) {
			$self->error_message("FIGMODELgenome:genome_stats:Could not find genome ".$self->genome()." in database");
			return undef;
		}
		my $rastDataHeadings = {
			_gc => "gcContent",
			_owner => "owner",
			_size => "size",
			_name => "name",
			_taxonomy => "taxonomy",
			_source => "source"
		};
		foreach my $key (keys(%{$rastDataHeadings})) {
			if (defined($self->{_features}->{$key})) {
				$genomeStats->{$rastDataHeadings->{$key}} = $self->{_features}->{$key};
			}
		}
		$GenomeData = $self->{_features};
	} else {
		$genomeStats->{source} = "PUBSEED";
		my $genomeHash = $self->figmodel()->sapSvr("PUBSEED")->genome_data({
			-ids => [$self->genome()],
			-data => ["gc-content", "dna-size","name","taxonomy"]
		});
		if (defined($genomeHash->{$self->genome()})) {
			$genomeStats->{name} = $genomeHash->{$self->genome()}->[2];
			$genomeStats->{size} = $genomeHash->{$self->genome()}->[1];
			$genomeStats->{taxonomy} = $genomeHash->{$self->genome()}->[3];
			$genomeStats->{gcContent} = $genomeHash->{$self->genome()}->[0];
		}
		$GenomeData = $self->feature_table({
			getSequences => 0,
			getEssentiality => 0,
			source => $genomeStats->{source},
			owner => $genomeStats->{owner}
		});
	}
	if (!defined($GenomeData)) {
		$self->error_message("FIGMODELgenome:genome_stats:Could not load features table!");
		return undef;
	}
	#Looping through the genes and gathering statistics
	my $roleObj = $self->figmodel()->get_role();
	my $roleHash = $roleObj->role_object_hash({attribute => "searchname"});
	my $ssHash = $roleObj->role_subsystem_hash();
	for (my $j=0; $j < $GenomeData->size(); $j++) {
		my $GeneData = $GenomeData->get_row($j);
		if (defined($GeneData) && $GeneData->{"ID"}->[0] =~ m/(peg\.\d+)/) {
			$GeneData->{"ID"}->[0] = $1;
			$genomeStats->{genes}++;
			#Checking that the gene has roles
			if (defined($GeneData->{"ROLES"}->[0])) {
				my $functionFound = 0;
				my $subsystemFound = 0;
				my $gramPosFound = 0;
				my $gramNegFound = 0;
				my @Roles = @{$GeneData->{"ROLES"}};
				foreach my $Role (@Roles) {					
					if ($roleObj->role_is_valid({name => $Role}) != 0) {
						$functionFound = 1;
						#Looking for role subsystems
						my $searchName = $roleObj->convert_to_search_role({name => $Role});
						if (defined($roleHash->{$searchName})) {
							if (defined($ssHash->{$roleHash->{$searchName}->[0]->id()})) {
								$subsystemFound = 1;
								for (my $k=0; $k < @{$ssHash->{$roleHash->{$searchName}->[0]->id()}}; $k++) {
									if ($ssHash->{$roleHash->{$searchName}->[0]->id()}->[$k]->classOne() =~ m/Gram\-Negative/ || $ssHash->{$roleHash->{$searchName}->[0]->id()}->[$k]->classTwo() =~ m/Gram\-Negative/) {
										$gramNegFound = 1;
									} elsif ($ssHash->{$roleHash->{$searchName}->[0]->id()}->[$k]->classOne() =~ m/Gram\-Positive/ || $ssHash->{$roleHash->{$searchName}->[0]->id()}->[$k]->classTwo() =~ m/Gram\-Positive/) {
										$gramPosFound = 1;
									}
								}
							}
						}
					}
				}
				if ($functionFound == 1) {
					$genomeStats->{genesWithFunctions}++;
					if ($subsystemFound == 1) {
						$genomeStats->{genesInSubsystems}++;
						if ($gramPosFound == 1) {
							$genomeStats->{gramPosGenes}++;
						} elsif ($gramNegFound == 1) {
							$genomeStats->{gramNegGenes}++;
						}
					}
				}
			}
		}
	}
	#Setting the genome class
	foreach my $ClassSetting (@{$self->figmodel()->config("class list")}) {
		if (defined($self->{$ClassSetting}->{$self->genome()})) {
			$genomeStats->{class} = $ClassSetting;
			last;
		} else {
			for (my $i=0; $i < @{$self->figmodel()->config($ClassSetting." families")}; $i++) {
				my $family = $self->figmodel()->config($ClassSetting." families")->[$i];
				if ($genomeStats->{name} =~ m/$family/) {
					$genomeStats->{class} = $ClassSetting;
					last;
				}
			}
		}
	}
	#Determining the genome class
	if ($genomeStats->{class} eq "Unknown") {
		if ($genomeStats->{source} eq "MGRAST") {
			$genomeStats->{class} = "Metagenome";
		} elsif ($genomeStats->{gramNegGenes} > $genomeStats->{gramPosGenes}) {
			$genomeStats->{class} = "Gram negative";
		} elsif ($genomeStats->{gramNegGenes} < $genomeStats->{gramPosGenes}) {
			$genomeStats->{class} = "Gram positive";
		}
	}
	#Loading the data into the PPO database
	$self->{_ppo} = $self->figmodel()->database()->get_object("genomestats",{GENOME => $self->genome()});
	if (defined($self->{_ppo})) {	
		foreach my $key (keys(%{$genomeStats})) {
			$self->{_ppo}->$key($genomeStats->{$key});	
		}
	} else {
		$self->{_ppo} = $self->figmodel()->database()->create_object("genomestats",$genomeStats);
	}
}
=head3 roles_of_peg
Definition:
	my @Roles = roles_of_peg($self,$GeneID,$SelectedModel);
Description:
	Returns list of functional roles associated with the input peg in the SEED for the specified model
=cut
sub roles_of_peg {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["gene"],{});
	if (!defined($args->{error})) {
		$self->error_message({message=>$args->{error}});
		return undef;
	}
	my $ftrTbl = $self->feature_table();
	if (!defined($ftrTbl)) {
		$self->error_message({message=>"Could not load feature table"});
		return undef;
	}
	my $gene = $ftrTbl->get_object({ID => "fig|".$self->genome().".".$args->{gene}});
	if (!defined($gene)) {
		$self->error_message({message=>"Could not find gene ".$args->{gene}});
		return undef;
	}
	return $gene->{ROLES};
	
}

sub active_subsystems {
	my ($self) = @_;
	if (!defined($self->{_active_subsystems})) {
		if ($self->source() =~ m/SEED/) {
			my $sap = $self->figmodel()->sapSvr($self->source());
			my $output = $sap->genomes_to_subsystems({
				-ids => [$self->genome()],
				-exclude => ['cluster-based','experimental']	
			});
			if (defined($output->{$self->genome()})) {
				for (my $i=0; $i < @{$output->{$self->genome()}}; $i++) {
					$self->{_active_subsystems}->{$output->{$self->genome()}->[$i]} = 1;
				}	
			}
		} else {
			my $output = $self->getRastGenomeData();
		}
	}
	return $self->{_active_subsystems};
}

sub totalGene {
	my ($self) = @_;
	return $self->ppo()->genes();
}

=head3 get_genome_sequence
Definition:
	[string] = FIGMODEL->get_genome_sequence(string::genome ID);
Description:
	This function returns a list of the DNA sequence for every contig of the genome
=cut
sub get_genome_sequence {
	my ($self) = @_;
	if ($self->source() =~ m/SEED/) {
		my $sap = $self->figmodel()->sapSvr("PUBSEED");
		my $genomeHash = $sap->genome_contigs({-ids => [$self->genome()]});
		my $contigHash = $sap->contig_sequences({-ids => $genomeHash->{$self->genome()}});
		return [values(%{$contigHash})];
	} elsif ($self->source() =~ m/RAST/) {
		my $output = $self->getRastGenomeData({
			getDNASequence => 1
		});
		return $output->{DNAsequence};
	}
	return undef;
}

=head3 classifyrespiration
Definition:
	[string] = FIGMODELgenome->classifyrespiration();
Description:
	This function returns a list of the DNA sequence for every contig of the genome
=cut

sub classifyrespiration {
    my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		genome => $self->genome(),
	});

	my $g_id = $args->{genome};

	  if ($g_id eq "ALL"){
	  	
	  	print " Got it ALL\n";
	  	
	  }

	print "Here is the genome ....$g_id\n";

	my $sap = $self->figmodel()->sapSvr($args->{source});
	my $subsys = $sap->ids_in_subsystems({
		-subsystems => ["TCA Cycle"],
		-genome => $args->{genome},
		-roleForm => "full",
	});
	if (defined($subsys->{"TCA Cycle"})) {
		if (defined($subsys->{"TCA Cycle"}->{"Malate dehydrogenase (EC 1.1.1.37)"})) {
			if (@{$subsys->{"TCA Cycle"}->{"Malate dehydrogenase (EC 1.1.1.37)"}} > 0) {
				return $args->{genome}." is an aerobic organism!";
			}
		}
	}
	return $args->{genome}." is not handled by our current tests!";
}

sub getGeneSimilarityHitTable {
    my ($self, $args) = @_;
    my $sap = SAPserver->new();

    print "Getting genes for: " . $self->genome;
    my $time = time();
    my $feature_objs = $self->feature_table()->get_objects();
    print " (took " . (time() - $time) . "s)\n";

    my @features;
    map {push(@features, $_->ID)} @$feature_objs;

    my $role = $self->figmodel()->get_role();

    # get the distances from the tree
    print "Getting genome distances";
    $time = time();
    my $tree_file = "data/genome/16s.tree";
    if (!-e $tree_file) {
	die "Error: Couldn't find tree file: $tree_file\n";
    }

    my $tree = ffxtree::read_tree($tree_file);
    my $distances = ffxtree::distances_from_tip($tree, $self->genome());
    print " (took " . (time() - $time) . "s)\n";

    my $start = 0;
    my $results = [];
    $time = time();
    while ($start < scalar @features) {
	my $stop = ($start + 99) >= scalar @features ? scalar @features - 1 : $start + 99;

	print "Processing genes " . ($start+1) . " to " . ($stop+1);

	my @feat_chunk = @features[$start..$stop];
	my @all_sims = SeedUtils::sims(\@feat_chunk, undef, 1, 'fig');

	$start += 100;

	# reduce the data, only need gene, sim gene, and score
	my @sims;
	my $features_to_match = [];
	foreach my $sim (@all_sims) {
	    push(@sims, [$sim->[0], $sim->[1], $sim->[10]]);
	    push(@$features_to_match, $sim->[1]);
	}

	my $gene_to_function = $sap->ids_to_functions({
	    -ids => $features_to_match
        });

	# hash from gene to feature to list of sim genes
	my $gene_hash = {};
	foreach my $sim (@sims) {
	    my $gene = $sim->[0];
	    my $sim_gene = $sim->[1];
	    unless (exists($gene_hash->{$gene})) {
		$gene_hash->{$gene} = {};
	    }

	    my $function = $gene_to_function->{$sim_gene};

	    if (defined $function && $function ne '') {
		$function = $role->convert_to_search_role({ name => $function });

		unless (exists($gene_hash->{$gene}->{$function})) {
		    $gene_hash->{$gene}->{$function} = [];
		}

		push(@{$gene_hash->{$gene}->{$function}}, $sim);
	    }
	}

	# loop through genes
	foreach my $gene (keys %$gene_hash) {
	    # loop through functions
	    foreach my $function (keys %{$gene_hash->{$gene}}) {
		my $sims = $gene_hash->{$gene}->{$function};

		my $first = 1;
		my $min_score_sim;
		my $min_dist_sim;
		my $avg_score = 0;
		my $avg_dist = 0;
		my $num_hits = scalar @$sims;

		# loop through sim hits, want to find:
		#  1. sim with lowest score (including distance)
		#  2. sim with lowest distance (including score)
		#  3. average score
		#  4. average distance

		foreach my $sim (@$sims) {
		    # calculate distance
		    my $genome = $sim->[1];
		    $genome =~ s/fig\|//;
		    $genome =~ s/\.peg.*//;

		    if (exists $distances->{$genome}) {
			$sim->[3] = $distances->{$genome};
		    } else {
			$sim->[3] = 100;
		    }

		    if ($first) {
			$min_score_sim = $sim;
			$min_dist_sim = $sim;
			$first = 0;
		    } else {
			# see if score is lower
			if ($sim->[2] > $min_score_sim->[2]) {
			    # majority of cases
			} elsif ($sim->[2] = $min_score_sim->[2]) {
			    # pick sim with lowest genome distance
			    if ($sim->[3] < $min_score_sim->[3]) {
				$min_score_sim = $sim;
			    }
			} else {
			    $min_score_sim = $sim;
			}

			# see if distance is lower
			if ($sim->[3] > $min_dist_sim->[3]) {
			    # majority of cases
			} elsif ($sim->[3] = $min_dist_sim->[3]) {
			    # pick sim with lowest score
			    if ($sim->[2] < $min_dist_sim->[2]) {
				$min_dist_sim = $sim;
			    }
			} else {
			    $min_dist_sim = $sim;
			}
		    }

		    # add values to averages
		    if ($sim->[2] > 0) {
			$avg_score += log($sim->[2])/log(10);
		    } else {
			$avg_score -= 300;
		    }

		    $avg_dist += $sim->[3];
		}

		$avg_score = $avg_score / $num_hits;
		$avg_dist = $avg_dist / $num_hits;

		my $row = [
			 $gene,
			 $function,
			 $min_score_sim->[2],
			 $min_score_sim->[3],
			 $min_score_sim->[1],
			 $min_dist_sim->[3],
			 $min_dist_sim->[2],
			 $min_dist_sim->[1],
			 $avg_score,
			 $avg_dist,
			 $num_hits
		    ];

		push(@$results, $row);
	    }
	}

	print " (took " . (time() - $time) . "s)\n";
	$time = time();

	# stop early
#	if ($start > 300) {
#	    last;
#	}
    }

    # print results to a table
    open GENEHITS, ">" . $self->genome() . "GeneHitTable.tbl" or die $!;
    print GENEHITS join("\t", qw(Gene SimFunction MinScore MinScoreDist MinScoreGene MinDist MinDistScore MinDistGene AvgScore AvgDist NumHits)), "\n";

    foreach my $row (@$results) {
	print GENEHITS join("\t", @$row), "\n";
    }

    return;
}

sub getTreeSimilarityHitTable {

}

1;
