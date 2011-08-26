#!/usr/bin/perl -w

########################################################################
# Driver script for the model database interaction module
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 8/26/2008
########################################################################

use strict;
use Data::Dumper;
use FIG;
use ModelSEED::FIGMODEL;
use FBAMODELserver;
use LWP::Simple;
$|=1;

#First checking to see if at least one argument has been provided
if (!defined($ARGV[0]) || $ARGV[0] eq "help") {
    print "Function name must be specified as input arguments!\n";;
	exit(0);
}

#This variable will hold the name of a file that will be printed when a job finishes
my $FinishedFile = "NONE";
my $Status = "SUCCESS";

#Searching for recognized arguments
my $driv = driver->new();
for (my $i=0; $i < @ARGV; $i++) {
    $ARGV[$i] =~ s/___/ /g;
    $ARGV[$i] =~ s/\.\.\./(/g;
    $ARGV[$i] =~ s/,,,/)/g;
    print "\nProcessing argument: ".$ARGV[$i]."\n";
    if ($ARGV[$i] =~ m/^finish\?(.+)/) {
        $FinishedFile = $1;
    } else {
        #Splitting argument
        my @Data = split(/\?/,$ARGV[$i]);
        my $FunctionName = $Data[0];
		for (my $j=0; $j < @Data; $j++) {
			if (length($Data[$j]) == 0) {
				delete $Data[$j];
			}
		}
		
        #Calling function
        $Status .= $driv->$FunctionName(@Data);
    }
}

#Printing the finish file if specified
if ($FinishedFile ne "NONE") {
    if ($FinishedFile =~ m/^\//) {
        ModelSEED::FIGMODEL::PrintArrayToFile($FinishedFile,[$Status]);
    } else {
        ModelSEED::FIGMODEL::PrintArrayToFile($driv->{_figmodel}->{"database message file directory"}->[0].$FinishedFile,[$Status]);
    }
}

exit();

package driver;

sub new {
	my $self = {_figmodel => ModelSEED::FIGMODEL->new(),_fig => FIG->new()};
	$self->{_outputdirectory} = $self->{_figmodel}->config("database message file directory")->[0];
	if (defined($ENV{"FIGMODEL_OUTPUT_DIRECTORY"})) {
		$self->{_outputdirectory} = $ENV{"FIGMODEL_OUTPUT_DIRECTORY"};
	}
    return bless $self;
}

=head3 figmodel
Definition:
	FIGMODEL = driver->figmodel();
Description:
	Returns a FIGMODEL object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}

=head3 fig
Definition:
	FIG = driver->fig();
Description:
	Returns a FIG object
=cut
sub fig {
	my ($self) = @_;
	return $self->{_fig};
}

=head3 check
Definition:
	FIGMODEL = driver->check([string]:expected data,(string):supplied arguments);
Description:
	Check for sufficient arguments
=cut
sub check {
	my ($self,$array,@Data) = @_;
	if ((@Data - 1) < @{$array}) {
		print "Insufficient arguments, usage:".$Data[0]."?".join("?",@{$array})."\n";
		return 0;
	}
	return 1;
}

=head3 outputdirectory
Definition:
	FIGMODEL = driver->outputdirectory();
Description:
	Returns the directory where output should be printed
=cut
sub outputdirectory {
	my ($self) = @_;
	return $self->{_outputdirectory};
}

sub makeArgumentHashFromCommand {
    my ($self, @Data);
    my $error = <<XATNYS;
Advanced command syntax:
    ProdModelDriver.sh normal?arguments?-flag?-flagWith=Value?more?normal?args
    Basically, ?-flag? for a boolean flag, ?-flag=Value? for a key -> value pair.
    Returns (hash, arrayRef) where hash is a hash of key -> value and key -> '1' for flags.
    And arrayRef is all remaining normal arguments
XATNYS
    my $args = {};
    my $otherArgs = [];
    for(my $i=0; $i< scalar(@Data); $i++) {
        if($Data[$i] =~ m/^-(.+)=(.+)/) {
            my $key = $1;
            my $value = $2;
            if(length($key) > 0 && length($value) > 0) {
                $args->{$key} = $value; 
                next;
            }
        }
        if($Data[$i] =~ m/^-(.+)/) {
            my $key = $1;
            if(length($key) > 0) {
                $args->{$key} = 1;
                next;
            }
        }
        push(@$otherArgs, $Data[$i]); # Push onto other arguments if we didn't find a flagged one
    }
    return ($args, $otherArgs);
}

sub getsims {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: getsims?(gene ID)?(filter genome)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	my @sim_results = $self->fig()->sims( $Data[1], 10000, 0.00001, "fig");
	my $genome = "->fig\\|".$Data[2];
	print "New peg\tPercent ID\tAlignment\tQuery length\tPeg length\tE-score\tFunction\n";
	for (my $i=0; $i < @sim_results; $i++) {
		if (!defined($Data[2]) || $sim_results[$i] =~ m/$genome/) {
			print $sim_results[$i]->[1]."\t".$sim_results[$i]->[2]."\t".$sim_results[$i]->[3]."\t".$sim_results[$i]->[11]."\t".$sim_results[$i]->[12]."\t".$sim_results[$i]->[10]."\t".$self->figmodel()->fig()->function_of($sim_results[$i]->[1])."\n";
		}
	}
	return "SUCCESS";
}

#FROM FIGMODEL

=head3 run_blast_on_gene
Definition:
   FIGMODEL->run_blast_on_gene(string::source genome,string::source gene ID,string::search genome);
Description:
=cut
sub run_blast_on_gene {
	my ($self,$genomeOne,$geneID,$genomeTwo) = @_;
	#Setting filename
	my $filename = $self->config("temp file directory")->[0].$self->filename().".fasta";
	my $singleGene = 1;	
	#If the input gene ID is undefined or "ALL", then the input file is the fasta file for the genome
	if (!defined($geneID) || $geneID eq "ALL") { 
		$filename = $self->fig($genomeOne)->organism_directory($genomeOne)."/Features/peg/fasta";
		$singleGene = 0;
	} else {
		#Pulling the query sequence
		my $sequence = $self->fig($genomeOne)->get_translation("fig|".$genomeOne.".".$geneID);
		#Printing the query sequence to file
		open(TMP, ">$filename") or die "could not open file '$filename': $!";
   		#FIG::display_id_and_seq("fig|".$genomeOne.".".$geneID, \$sequence, \*TMP);
    	close(TMP) or die "could not close file '$filename': $!";
	}
	#Forming blastall command line
	#my $cmd = FIG_Config::ext_bin."/blastall";
	my @args = ('-i',$filename, '-d',$self->fig($genomeTwo)->organism_directory($genomeTwo)."/Features/peg/fasta", '-T', 'T', '-F', 'F', '-e',10, '-W', 0,'-p','blastp');
	# run blast
	#my $output = $self->fig()->run_gathering_output($cmd, @args);
	#print $output;
	if ($singleGene == 1 && -e $filename) {
		unlink($filename);	
	}
}

=head3 find_genes_for_gapfill_reactions
Definition:
    FIGMODELTable::table of candidate genes FIGMODEL->find_genes_for_gapfill_reactions(string array ref::list of models)
Description:
Example:
=cut

sub find_genes_for_gapfill_reactions {
    my ($self,$model_list) = @_;

    my $fig = $self->fig();

    my $org_list = [];

    my $rxns_to_models = {};
    my $roles_to_rxns = {};
    my $rxns_to_roles = {};
    my $pegs_to_roles = {};
    my $roles_to_pegs = {};
	print "Getting gapfilled reaction list\n";
    foreach my $model_id ( @$model_list ){
        print "Finding gapfill candidates for $model_id...\n";
        # Save just the organism IDs for future use
        push @$org_list, $self->get_model( $model_id )->genome();
        # Get model data
        my $model_table = $self->database()->GetDBModel( $model_id );

        # Iterate through the reactions in a model
        REACTION: for( my $i=0; $i < $model_table->size(); $i++ ){
            my $row = $model_table->get_row($i);
            # Find reactions with no associated genes
            if( defined ($row->{"ASSOCIATED PEG"} ) ){
                if( $row->{"ASSOCIATED PEG"}->[0] =~ m/^peg/ ){
                    next REACTION;
                }
                elsif( $row->{"ASSOCIATED PEG"}->[0] =~ m/^SPONTANEOUS/ ){
                    next REACTION;
                }
                elsif( $row->{"ASSOCIATED PEG"}->[0] =~ m/^BOF/ ){
                    next REACTION;
                }
                else{
                    # Reaction is gapfilled. Do nothing and continue...
                }
            }
            # .. to here, where we save rxns and the models they came from
            if( defined( $rxns_to_models->{$row->{"LOAD"}->[0]} ) ){
                push @{$rxns_to_models->{$row->{"LOAD"}->[0]}}, $model_id;
            }
            else{
                $rxns_to_models->{$row->{"LOAD"}->[0]} = [ $model_id ];
            }
        }
    }

    my @temp = keys %$rxns_to_models;
    print @temp." gap filled reactions found!\nOrganizing by functional role:\n";

    # Hash reactions by their functional roles
    foreach my $rxn ( keys %$rxns_to_models ){
        my $rls_of_rxns = $self->roles_of_reaction( $rxn );
        $rxns_to_roles->{$rxn} = $rls_of_rxns;
        if( $rls_of_rxns ){
            foreach( @$rls_of_rxns ){
                if( defined( $roles_to_rxns->{$_} ) ){
                    push @{$roles_to_rxns->{$_}}, $rxn;
                }
                else{
                    $roles_to_rxns->{$_} = [ $rxn ];
                }
            }
        }
    }
    
    @temp = keys %$roles_to_rxns;
    print @temp." distinct functional roles found!\nLooking for pegs:\n";

    # Get the proteins associated with functional roles from FIG
    foreach my $rls ( keys %$roles_to_rxns ){
        my @prots = $fig->prots_for_role( $rls );
        $roles_to_pegs->{$rls} = [];
        foreach( @prots ){
            push @{$roles_to_pegs->{$rls}}, $_;
            if( $pegs_to_roles->{$_} ){
                push @{$pegs_to_roles->{$_}}, $rls;
            }
            else{
                $pegs_to_roles->{$_} = [ $rls ];
            }
        }
    }
    
    @temp = keys %$pegs_to_roles;
    print @temp." pegs with roles found!\Querying for sims:\n";

    my $results = [];
    my $table = ModelSEED::FIGMODEL::FIGMODELTable->new( ["similar_peg", "roles", "reaction", "query", "percent_id", "alignment_length", "mismatches", "gap_openings", "query_match_start", "query_match_end", "similar_match_start", "similar_match_end", "e_val","bit_score", "query_length", "similar_length", "method" ],
                                    "",
                                    ["similar_peg", "query" ],
                                    ";",
                                    ":",
                                    undef );

    # Create a hash for our requests to the sim server.
    # hash->{key} = 0           - make a sim server request
    # hash->{key} = 1           - don't make a request. this protein has been filtered
    # hash->{key} = ARRAYREF    - request was made, filtered the proteiins in ARRAY
    my $requests = {};
    foreach( keys %$pegs_to_roles ){
        $requests->{$_} = 0;
    }

	my $count = 1;
    # For each protien, make a request to the sim server.
    QUERY: foreach my $query_peg ( sort keys %$requests ){
        $count++;
        if (floor($count/100) == $count/100) {
       		print "Query ".$count."\n";
        }
        
        # Move on if we've determined the request would be redundant
        if( $requests->{$query_peg} == 1 ){
        #    print STDERR "\n$query_peg removed by a previous request";
            next QUERY;
        }
        # Make sure we're not making a sim request for a gene in the same organism.
        # Would indicate some fishy business, so just ends
        foreach( @$org_list ){
            if( $query_peg =~ m/$_/ ){
                $requests->{$query_peg} = 1;
            my ($roles, $reactions) = $self->_roles_rxns_in_model( $_ , $query_peg, $pegs_to_roles,$roles_to_rxns, $rxns_to_models );
                $table->add_row( {  'similar_peg' => [ $query_peg ],
                                    'roles' => $roles,
                                    'reaction', $reactions,
                                    'query' => [ "DIRECT EVIDENCE" ] } );
                last QUERY;
            }
        }
        # Make a request and figure out what genome the match came from
        #print STDERR "\nQuerying sim server with $query_peg...";
        my @sim_results = $fig->sims( $query_peg, 10000, 0.00001, "fig");
        # Record that we have return values
        if( @sim_results ){
            $requests->{$query_peg} = [];
        #    print "processing results..."
        }
        else{
        #    print "no similar pegs."
        }
        # Process results
        RESULT: foreach my $result_row ( @sim_results ){
            # Check the similar peg against our list of organisms
            my $source_org;
            foreach( @$org_list ){
                if( $result_row->[1] =~ m/$_/ ){
                    $source_org = $_;
                }
            }
            # Skip to the next row unless the match comes from one of our models
            next RESULT unless $source_org;
            # Get the roles/reactions that got us this query peg
            push @{$requests->{$query_peg}}, $query_peg;
            my ($roles, $reactions) = $self->_roles_rxns_in_model( $source_org, $query_peg, $pegs_to_roles,$roles_to_rxns, $rxns_to_models );
            # Format and return a table row
            if( (my $entry = $table->get_row_by_key($result_row->[1],'similar_peg' )) ){
                push @{$entry->{'roles'}}, @$roles;
                push @{$entry->{'reaction'}}, @$reactions;
                push @{$entry->{'query'}}, $result_row->[0];
                push @{$entry->{'percent_id'}}, $result_row->[2];
                push @{$entry->{'alignment_length'}}, $result_row->[3];
                push @{$entry->{'mismatches'}}, $result_row->[4];
                push @{$entry->{'gap_openings'}}, $result_row->[5];
                push @{$entry->{'query_match_start'}}, $result_row->[6];
                push @{$entry->{'query_match_end'}}, $result_row->[7];
                push @{$entry->{'similar_match_start'}}, $result_row->[8];
                push @{$entry->{'similar_match_end'}}, $result_row->[9];
                push @{$entry->{'e_val'}}, $result_row->[10];
                push @{$entry->{'bit_score'}}, $result_row->[11];
                push @{$entry->{'query_length'}}, $result_row->[12];
                push @{$entry->{'similar_length'}}, $result_row->[13];
                push @{$entry->{'method'}}, $result_row->[14];
            }
            else{
                $table->add_row(  { 'similar_peg' => [ $result_row->[1] ],
                                    'roles' => $roles,
                                    'reaction' => $reactions,
                                    'query' => [$result_row->[0] ],
                                    'percent_id' => [$result_row->[2] ],
                                    'alignment_length' => [$result_row->[3] ],
                                    'mismatches' => [$result_row->[4] ],
                                    'gap_openings' => [$result_row->[5] ],
                                    'query_match_start' => [$result_row->[6] ],
                                    'query_match_end' => [$result_row->[7] ],
                                    'similar_match_start' => [$result_row->[8] ],
                                    'similar_match_end' => [$result_row->[9] ],
                                    'e_val' => [$result_row->[10] ],
                                    'bit_score' => [$result_row->[11] ],
                                    'query_length' => [$result_row->[12] ],
                                    'similar_length' => [$result_row->[13] ],
                                    'method' => [ $result_row->[14] ] } );
            }
        }
    }

	print "Removing duplicates!\n";

    # Quick and dirty: remove the duplicate roles/reactions
    for( my $i=0; $i < $table->size(); $i++ ){
        my $row = $table->get_row($i);
        my %cleaner;
        foreach( @{$row->{'roles'}} ){
            $cleaner{$_} = $_;
        }
        @{$row->{'roles'}} = keys %cleaner;
        %cleaner = ();
        foreach( @{$row->{'reaction'}} ){
            $cleaner{$_} = $_;
        }
        @{$row->{'reaction'}} = keys %cleaner;
    }

	print "Generating stats!\n";
    # Give a quick summary of the requests made
    my $total = 0;
    my $requested = 0;
    my $filtered = 0;
    my $nosim = 0;
    my $candidates = 0;
    foreach( keys %$requests ){
        $total++;
        if( $requests->{$_} == 0 ){
            $nosim++;
        }
        elsif( $requests->{$_} == 1 ){
            $filtered++;
        }
        elsif( ref( $requests->{$_} ) eq "ARRAY" ){
            $requested++;
            if( @{$requests->{$_}} ){
                $candidates++;
            }
        }
        else{
            print "Strange things happened with $_ ...\n";
        }
    }
    print "Done.\n";
    print "$total candidate pegs\n";
    print "$requested pegs returned similarites. $candidates were identified as candidates.\n";
    print "$nosim pegs returned no similarities.\n";
    print "$filtered candidate pegs called on direct evidence.\n";

    return $table;
}

sub printSequencesForRole {
    $| =1;
    my ($self, $role, $outputFile) = @_;
	my $outputFD;
	if(defined($outputFile)) {
		open( $outputFD, '>', $outputFile) or die("Unable to open output file $outputFile : $!");
	} else { $outputFD = 'STDOUT'; }

	my $fig = $self->fig();
	my @pegs = $fig->role_to_pegs($role);
	foreach my $peg (@pegs) {
		my $seq = $fig->get_translation($peg);
            print {$outputFD} ">";
            print {$outputFD} $peg . "\n";
            print {$outputFD} $seq . "\n";
    }
	close( $outputFD ) or die("Unable to close output file: $!");
}

sub findPatternInterval {
    my ($self, $pattern_list, $id, $name) = @_;

    my $table = ModelSEED::FIGMODEL::FIGMODELTable->new(["pattern", "pegId", "functionalRole"],$self->{"database message file directory"}->[0].$name."-PatternSearch.tbl",["pattern", "pegId", "functionalRole"], "|", ";", undef );

    if( $id =~ m/all/ ){
        foreach( $self->fig()->genomes( 1,0, "Bacteria" ) ){
            print STDERR "Processing $_\n";
            $self->_findPatternInterval( $pattern_list, $_, $table );
            delete $self->{"CACHE"}->{$_."FEATURETABLE"};
        }
    }
    else{
        $self->_findPatternInterval( $pattern_list, $id, $table );
    }
    return $table;
}

sub _parsePatterns {
    my ($self, $pattern) = @_;

    my $temp_val;

    my $patterns = [];
    my $min = [];
    my $max = [];

    my @tokens = split /\s+/, $pattern;
    push @$patterns, (shift @tokens);

    while( @tokens ){
        # Shift, so counting backwards mod 3
       $temp_val = shift @tokens;
        if( (@tokens%3) == 0 ){
            push @$patterns, $temp_val;
        }
        elsif( (@tokens%3) == 2 ){
            push @$min, $temp_val;
        }
        else{
            push @$max, $temp_val;
        }
    }

    if( ($#$min != $#$max ) || ( $#$patterns != @$min ) ){
        #print STDERR "Incorrectly formatted pattern string.\n";
        return -1;
    }

    return [ $patterns, $min, $max ];
}

sub _findPatternInterval {
    my ($self, $pattern_list, $id, $table) = @_;

    # Get pegs
    my $retvals = [];
    my $feature_table = $self->GetGenomeFeatureTable( $id, 1 );

    OUTER: for( my $i=0; $i < $feature_table->size(); $i++ ){
        my $row = $feature_table->get_row($i);
        if( defined( $row->{"SEQUENCE"}->[0] ) ){

            PATTERN: foreach my $pat ( @$pattern_list ){
                # Is there better syntax for this?
                my $plist = $self->_parsePatterns($pat);
                if( $plist == -1 ){
                    #print STDERR "Skipping pattern in findPatternInterval.\n";
                    next PATTERN;
                }

                my $patterns = $plist->[0];
                my $min = $plist->[1];
                my $max = $plist->[2];

                my $starts = [];

                # Find the starts of all the patterns
                for( my $j=0; $j <= $#$patterns; $j++ ){
                    my $pat = $patterns->[$j];
                    if( $row->{"SEQUENCE"}->[0] =~ m/$pat/ ){
                        push @$starts, $-[0];
                    }
                }

                # Make sure we have a position for each pattern
                if( $#$patterns == $#$starts ){
                    for( my $j=0; $j< $#$starts ; $j++ ){
                        # If every gap passes the test...
                        my $gap = $starts->[$j+1] - $starts->[$j];
                        # First time we fail, get the next peg in line
                        unless( ($min->[$j] <= $gap) && ($gap <= $max->[$j]) ){
                            next PATTERN;
                        }
                    }
                    # ...return the peg
                    $table->add_row( { "pegId" => $row->{"ID"}, "pattern" =>[$pat] , "functionalRole" => $row->{"ROLES"} } );
                }
                else{
                    next PATTERN;
                }
            }
        }
    }
    return 1;
}

=head3 model_roles_not_in_subsystems
Definition:
	FIGMODELTable::No subsystem role table = figmodel->model_roles_not_in_subsystems(void);
Description:
	This function returns a table of the roles and pegs included in the genome-scale models but not found in a subsystem.
=cut
sub model_roles_not_in_subsystems {
	my ($self) = @_;

	#Loading the functional role-to-reaction mapping
	my $RoleTable = $self->database()->GetDBTable("CURATED ROLE MAPPINGS");

	#Creating the output table
	my $ResultTable = ModelSEED::FIGMODEL::FIGMODELTable->new(["ROLES","PEGS","REACTIONS"],$self->{"Reaction database directory"}->[0]."MiscDataTables/NoSubsystemRoles.tbl",["ROLES"],";","~",undef);

	#Scanning through this table and generating a hash of roles outside of subsystems
	for (my $i=0; $i < $RoleTable->size(); $i++) {
		my $Role = $RoleTable->get_row($i)->{"ROLE"}->[0];
		my $Subsystems = $self->subsystems_of_role($Role);
		if (!defined($Subsystems)) {
			#Adding role to table if not already present
			my $Row = $ResultTable->get_row_by_key($Role,"ROLES",1);
			#Getting pegs for role
			if (!defined($Row->{"REACTIONS"})) {
				my @Pegs = $self->fig()->role_to_pegs($Role);
				#Filtering the peg list based on the models
				foreach my $Peg (@Pegs) {
					if ($Peg =~ m/fig\|(\d+\.\d+)\./) {
						if ($self->status_of_model($1) >= 0) {
							push(@{$Row->{"PEGS"}},$Peg);
						}
					}
				}
			}
			$ResultTable->add_data($Row,"REACTIONS",$RoleTable->get_row($i)->{"REACTION"},1);
		}
	}
	$ResultTable->save();

	return $ResultTable;
}

=head3 TranslateGenes
Definition:
	$model->TranslateGenes($Original,$GenomeID);
Description:
Example:
=cut

sub TranslateGenes {
	my ($self,$Original,$GenomeID) = @_;

	if (!defined($self->{$GenomeID."_aliases"})) {
	if (defined($self->fig())) {
		#Getting fig object
		my $fig = $self->fig();

		#Getting genome data
		my $GenomeData = $fig->all_features_detailed_fast($GenomeID);
		for (my $j=0; $j < @{$GenomeData}; $j++) {
		#id, location, aliases, type, minloc, maxloc, assigned_function, made_by, quality
		if (defined($GenomeData->[$j]->[0]) && defined($GenomeData->[$j]->[2]) && defined($GenomeData->[$j]->[3]) && $GenomeData->[$j]->[3] eq "peg" && $GenomeData->[$j]->[0] =~ m/(peg\.\d+)/) {
			my $GeneID = $1;
			my @TempArray = split(/,/,$GenomeData->[$j]->[2]);
			for (my $i=0; $i < @TempArray; $i++) {
			$self->{$GenomeID."_aliases"}->{$TempArray[$i]} = $GeneID;
			}
		}
		}
	}

	#Loading additional gene aliases from the database
	if (-e $self->{"Translation directory"}->[0]."AdditionalAliases/".$GenomeID.".txt") {
		my $AdditionalAliases = LoadMultipleColumnFile($self->{"Translation directory"}->[0]."AdditionalAliases/".$GenomeID.".txt","\t");
		for (my $i=0; $i < @{$AdditionalAliases}; $i++) {
		$self->{$GenomeID."_aliases"}->{$AdditionalAliases->[$i]->[1]} = $AdditionalAliases->[$i]->[0];
		}
	}
	}

	#Translating the input gene data
	$Original =~ s/\sand\s/:/g;
	$Original =~ s/\sor\s/;/g;
	my @GeneNames = split(/[,\+\s\(\):;]/,$Original);
	foreach my $Gene (@GeneNames) {
		if (length($Gene) > 0 && defined($self->{$GenomeID."_aliases"}->{$Gene})) {
			my $Replace = $self->{$GenomeID."_aliases"}->{$Gene};
			$Original =~ s/([^\w])$Gene([^\w])/$1$Replace$2/g;
			$Original =~ s/^$Gene([^\w])/$Replace$1/g;
			$Original =~ s/([^\w])$Gene$/$1$Replace/g;
			$Original =~ s/^$Gene$/$Replace/g;
		}
	}
	$Original =~ s/:/ and /g;
	$Original =~ s/;/ or /g;

	#my @TempArrayOne = split(/,/,$Original);
	#for (my $k=0; $k < @TempArrayOne; $k++) {
	#my @TempArrayTwo = split(/\+/,$TempArrayOne[$k]);
	#for (my $m=0; $m < @TempArrayTwo; $m++) {
	#	my @TempArrayThree = split(/\s/,$TempArrayTwo[$m]);
	#	for (my $n=0; $n < @TempArrayThree; $n++) {
	#	my @TempArrayFour = split(/\(/,$TempArrayThree[$n]);
	#	for (my $o=0; $o < @TempArrayFour; $o++) {
	#		my @TempArrayFive = split(/\)/,$TempArrayFour[$o]);
	#		for (my $p=0; $p < @TempArrayFive; $p++) {
	#		if (length($TempArrayFive[$p]) > 0 && defined($self->{$GenomeID."_aliases"}->{$TempArrayFive[$p]})) {
	#			$TempArrayFive[$p] = $self->{$GenomeID."_aliases"}->{$TempArrayFive[$p]};
	#		}
	#		}
	#		$TempArrayFour[$o] = join(")",@TempArrayFive);
	#	}
	#	$TempArrayThree[$n] = join("(",@TempArrayFour);
	#	}
	#	$TempArrayTwo[$m] = join(" ",@TempArrayThree);
	#}
	#$TempArrayOne[$k] = join("+",@TempArrayTwo);
	#}
	#$Original = join(",",@TempArrayOne);

	#$Original =~ s/[\(\)]//g;

	return $Original;
}

=head3 ranked_list_of_genomes
Definition:
	ranked_list_of_genomes(string::genome ID)
Description:
=cut

sub ranked_list_of_genomes {
	my ($self,$GenomeID,$CompareRoles,$CompareModels) = @_;

	#Creating prototype table
	my $Output = ModelSEED::FIGMODEL::FIGMODELTable->new(["GENOME","MATCHING GENES","AVERAGE SCORE","EXTRA A GENES","EXTRA B GENES","MATCHING ROLES","EXTRA A ROLES","EXTRA B ROLES","MATCHING REACTIONS","EXTRA A REACTIONS","EXTRA B REACTIONS"],$self->{"database message file directory"}->[0]."RankedListSimilarGenomes-".$GenomeID.".tbl",["GENOME"],";","|",undef);

	#Getting genome features
	my $FeatureTable = $self->GetGenomeFeatureTable($GenomeID);

	#Comparing reaction content of genome
	if (defined($CompareModels) && $CompareModels == 1) {
		#Getting model table
		my $ModelData = $self->database()->GetDBModel("Seed".$GenomeID);
		if (defined($ModelData)) {
			#Scanning model list
			my $ModelList = $self->database()->GetDBTable("MODEL LIST");
			for (my $i=0; $i < $ModelList->size(); $i++) {
				my $Row = $ModelList->get_row($i);
				if ($Row->{"MODEL ID"}->[0] ne "Seed".$GenomeID && $Row->{"MODEL ID"}->[0] =~ m/Seed(\d+\.\d+)/) {
					my $OtherGenomeID = $1;
					my $NewRow = $Output->get_row_by_key($OtherGenomeID,"GENOME");
					if (!defined($NewRow)) {
						$NewRow = {"GENOME" => [$OtherGenomeID],"MATCHING GENES" => [0],"AVERAGE SCORE" => [0],"EXTRA A GENES" => [0],"EXTRA B GENES" => [0],"MATCHING ROLES" => [0],"EXTRA A ROLES" => [0],"EXTRA B ROLES" => [0],"MATCHING REACTIONS" => [0],"EXTRA A REACTIONS" => [0],"EXTRA B REACTIONS" => [0]};
						$Output->add_row($NewRow);
					}
					my $OtherModelData = $self->database()->GetDBModel("Seed".$OtherGenomeID);
					for (my $j=0; $j < $ModelData->size(); $j++) {
						if (defined($OtherModelData->get_row_by_key($ModelData->get_row($j)->{"LOAD"}->[0],"LOAD"))) {
							$NewRow->{"MATCHING REACTIONS"}->[0]++;
						}
					}
					$NewRow->{"EXTRA A REACTIONS"}->[0] = $ModelData->size() - $NewRow->{"MATCHING REACTIONS"}->[0];
					$NewRow->{"EXTRA B REACTIONS"}->[0] = $OtherModelData->size() - $NewRow->{"MATCHING REACTIONS"}->[0];
				}
			}
		}
		$Output->save();
	}

	#Getting sims for genes in genome
	my $fig = $self->fig($GenomeID);
	my $MaxMatch = 0;
	for (my $i=0; $i < $FeatureTable->size(); $i++) {
		my $Row = $FeatureTable->get_row($i);
		print $Row->{"ID"}->[0]."\n";
		my $SimilarGenomeHash;
		my @sim_results = $fig->sims( $Row->{"ID"}->[0], 10000, 0.00001, "fig");
		for (my $j=0; $j < @sim_results; $j++) {
			my $result_row = $sim_results[$j];
			if ($result_row->[1] =~ m/fig\|(\d+\.\d+)\./) {
				my $GenomeID = $1;
				my $Score = -1000;
				if ($result_row->[10] != 0) {
					$Score = log($result_row->[10]);
				}
				if (!defined($SimilarGenomeHash->{$GenomeID}) || $SimilarGenomeHash->{$GenomeID} > $Score) {
					$SimilarGenomeHash->{$GenomeID} = $Score;
				}
			}
		}

		#Adding similar genomes to output table
		my @GenomeList = keys(%{$SimilarGenomeHash});
		for (my $j=0; $j < @GenomeList; $j++) {
			my $GenomeID = $GenomeList[$j];
			my $NewRow = $Output->get_row_by_key($GenomeID,"GENOME");
			if (!defined($NewRow)) {
				$NewRow = {"GENOME" => [$GenomeID],"MATCHING GENES" => [0],"AVERAGE SCORE" => [0],"EXTRA A GENES" => [0],"EXTRA B GENES" => [0],"MATCHING ROLES" => [0],"EXTRA A ROLES" => [0],"EXTRA B ROLES" => [0],"MATCHING REACTIONS" => [0],"EXTRA A REACTIONS" => [0],"EXTRA B REACTIONS" => [0]};
				$Output->add_row($NewRow);
			}
			$NewRow->{"MATCHING GENES"}->[0]++;
			if ($NewRow->{"MATCHING GENES"}->[0] > $MaxMatch) {
				$MaxMatch = $NewRow->{"MATCHING GENES"}->[0];
			}
			$NewRow->{"AVERAGE SCORE"}->[0] += $SimilarGenomeHash->{$GenomeID};
		}
	}

	#Scanning through all genomes
	my @RoleArray = $FeatureTable->get_hash_column_keys("ROLES");
	my @GenomeList = $self->fig()->genomes( 1,0, "Bacteria" );
	print "Max match:".$MaxMatch."\n";
	for (my $i=0; $i < @GenomeList; $i++) {
		my $OtherGenomeID = $GenomeList[$i];
		my $NewRow = $Output->get_row_by_key($OtherGenomeID,"GENOME");
		if (!defined($NewRow) && defined($CompareRoles) && $CompareRoles == 1) {
			$NewRow = {"GENOME" => [$GenomeID],"MATCHING GENES" => [0],"AVERAGE SCORE" => [0],"EXTRA A GENES" => [0],"EXTRA B GENES" => [0],"MATCHING ROLES" => [0],"EXTRA A ROLES" => [0],"EXTRA B ROLES" => [0],"MATCHING REACTIONS" => [0],"EXTRA A REACTIONS" => [0],"EXTRA B REACTIONS" => [0]};
			$Output->add_row($NewRow);
		}
		#Getting genome annotation data
		if (defined($NewRow)) {
			if ((defined($CompareRoles) && $CompareRoles == 1) || $NewRow->{"MATCHING GENES"}->[0] >= (0.5*$MaxMatch)) {
				print $OtherGenomeID."\n";
				my $BFeatureTable = $self->GetGenomeFeatureTable($OtherGenomeID);
				if (defined($CompareRoles) && $CompareRoles == 1) {
					my @BRoleArray = $BFeatureTable->get_hash_column_keys("ROLES");
					#Finding matching roles
					for (my $j=0; $j < @RoleArray; $j++) {
						if (defined($BFeatureTable->get_row_by_key($RoleArray[$j],"ROLES"))) {
							$NewRow->{"MATCHING ROLES"}->[0]++;
						}
					}
					$NewRow->{"EXTRA A ROLES"}->[0] = @RoleArray - $NewRow->{"MATCHING ROLES"}->[0];
					$NewRow->{"EXTRA B ROLES"}->[0] = @BRoleArray - $NewRow->{"MATCHING ROLES"}->[0];
				}
				if ($NewRow->{"MATCHING GENES"}->[0] > 0) {
					$NewRow->{"AVERAGE SCORE"}->[0] = $NewRow->{"AVERAGE SCORE"}->[0]/$NewRow->{"MATCHING GENES"}->[0];
					$NewRow->{"EXTRA A GENES"}->[0] = $FeatureTable->size()-$NewRow->{"MATCHING GENES"}->[0];
					$NewRow->{"EXTRA B GENES"}->[0] = $BFeatureTable->size()-$NewRow->{"MATCHING GENES"}->[0];
				}
				delete $self->{"CACHE"}->{$NewRow->{"GENOME"}->[0]."-FEATURETABLE"};
			}
		}
	}
	$Output->save();

    return $Output;
}

=head3 minimal_genome_analysis
Definition:
	FIGMODEL->minimal_genome_analysis();
=cut
sub minimal_genome_analysis {
	my ($self) = @_;
	#Getting the genome for mycoplasma and h influenza
	my $MycoplasmaFunctions = new ModelSEED::FIGMODEL::FIGMODELTable(["ROLE","GENES","HINFORTH"],$self->{"database message file directory"}->[0]."MycoplasmaRoles.txt",["ROLE","GENES","HINFORTH"],"\t","|",undef);
	my $mGenit = $self->GetGenomeFeatureTable("243273.1");
	for (my $i=0; $i < $mGenit->size(); $i++) {
		my $row = $mGenit->get_row($i);
		if ($row->{ID}->[0] =~ m/fig\|(\d+.\d+)\.(peg\.\d+)/) {
			my $id = $2;
			my @sim_results = $self->fig()->sims($row->{ID}->[0], 10000, 0.01, "fig");
			my $bestScores = 1;
			my $bestHit = "none";
			for (my $k=0; $k < @sim_results; $k++) {
				if ($sim_results[$k]->[1] =~ m/fig\|(\d+.\d+)\.(peg\.\d+)/) {
					my $genome = $1;
					my $gene = $2;
					if ($genome eq "71421.1" && $bestScores > $sim_results[$k]->[10]) {
						$bestScores = $sim_results[$k]->[10];
						$bestHit = $gene;
					}
				}
			}
			for (my $j=0; $j < @{$row->{"ROLES"}}; $j++) {
				my $newRow = $MycoplasmaFunctions->get_row_by_key($row->{"ROLES"}->[$j],"ROLE",1);
				push(@{$newRow->{"GENES"}},$id);
				if ($bestHit ne "none") {
					push(@{$newRow->{"HINFORTH"}},$id."->".$bestHit.":".$bestScores);
				}
			}
		}
	}
	$MycoplasmaFunctions->save();
	return;
	#Go through all essential genes and find homologs and isofunctionals
	my $genomeList = ["99287.1","71421.1","158879.1","85962.1","401614.5","171101.1","83332.1","243273.1","62977.3","83333.1","272635.1","208964.1","224308.1"];
	my $genomeNames = ["Salmonella typhimurium LT2","Haemophilus influenzae KW20","Staphylococcus aureus N315","Helicobacter pylori 26695","Francisella tularensis U112","Streptococcus pneumoniae R6","Mycobacterium tuberculosis H37Rv","Mycoplasma genitalium G-37","Acinetobacter ADP1","Escherichia coli K12","Mycoplasma pulmonis UAB CTIP","Pseudomonas aeruginosa PAO1","Bacillus subtilis 168"];
	my $genomeHash;
	#BBH table
	my $assignedToFamily;
	my $essentialBBH = new ModelSEED::FIGMODEL::FIGMODELTable(["ROLES","FAMILY","NUMGENOMES","99287.1","71421.1","158879.1","85962.1","401614.5","171101.1","83332.1","243273.1","62977.3","83333.1","272635.1","208964.1","224308.1"],$self->{"database message file directory"}->[0]."EssentialFamilies.txt",["ROLES","FAMILY","99287.1","71421.1","158879.1","85962.1","401614.5","171101.1","83332.1","243273.1","62977.3","83333.1","272635.1","208964.1","224308.1"],"\t","|",undef);
	my $minBBH = new ModelSEED::FIGMODEL::FIGMODELTable(["ROLES","FAMILY","NUMGENOMES","99287.1","71421.1","158879.1","85962.1","401614.5","171101.1","83332.1","243273.1","62977.3","83333.1","272635.1","208964.1","224308.1"],$self->{"database message file directory"}->[0]."MinEssentialFamilies.txt",["ROLES","FAMILY","99287.1","71421.1","158879.1","85962.1","401614.5","171101.1","83332.1","243273.1","62977.3","83333.1","272635.1","208964.1","224308.1"],"\t","|",undef);
	#Gene hashes
	my $essentialGenes;
	my $minimalEssentials;
	#Functional role tables
	my $essentialFunctions = new ModelSEED::FIGMODEL::FIGMODELTable(["ROLE","GENOMES","NUMGENES","NUMGENOMES","99287.1","71421.1","158879.1","85962.1","401614.5","171101.1","83332.1","243273.1","62977.3","83333.1","272635.1","208964.1","224308.1"],$self->{"database message file directory"}->[0]."EssentialFunctions.txt",["ROLE",,"GENOMES","99287.1","71421.1","158879.1","85962.1","401614.5","171101.1","83332.1","243273.1","62977.3","83333.1","272635.1","208964.1","224308.1"],"\t","|",undef);
	my $minimalEssentialFunctions = new ModelSEED::FIGMODEL::FIGMODELTable(["ROLE","NUMGENES","NUMGENOMES","99287.1","71421.1","158879.1","85962.1","401614.5","171101.1","83332.1","243273.1","62977.3","83333.1","272635.1","208964.1","224308.1"],$self->{"database message file directory"}->[0]."MinimalEssentialFunctions.txt",["ROLE","99287.1","71421.1","158879.1","85962.1","401614.5","171101.1","83332.1","243273.1","62977.3","83333.1","272635.1","208964.1","224308.1"],"\t","|",undef);
	#Loading the essential functional role data tables
	for (my $i=0; $i < @{$genomeList}; $i++) {
		my $features = $self->GetGenomeFeatureTable($genomeList->[$i]);
		$genomeHash->{$genomeList->[$i]} = 1;
		my $tbl = $self->GetEssentialityData($genomeList->[$i]);
		for (my $j=0; $j < $tbl->size(); $j++) {
			my $row = $tbl->get_row($j);
			if ($row->{Essentiality}->[0] ne "nonessential") {
				my $generow = $features->get_row_by_key("fig|".$genomeList->[$i].".".$row->{Gene}->[0],"ID");
				if ($genomeList->[$i] ne "83333.1" || $row->{Media}->[0] eq "ArgonneLBMedia") {
					if (defined($generow->{"ROLES"})) {
						$essentialGenes->{$genomeList->[$i]}->{$row->{Gene}->[0]} = $generow->{"ROLES"};
						for (my $k=0; $k < @{$generow->{"ROLES"}}; $k++) {
							my $newRow = $essentialFunctions->get_row_by_key($generow->{"ROLES"}->[$k],"ROLE",1);
							$essentialFunctions->add_data($newRow,"GENOMES",$genomeNames->[$i],1);
							if (!defined($newRow->{"NUMGENES"})) {
								$newRow->{"NUMGENES"}->[0] = 0;
								$newRow->{"NUMGENOMES"}->[0] = 0;
							}
							$newRow->{"NUMGENES"}->[0]++;
							if (!defined($newRow->{$genomeList->[$i]})) {
								$newRow->{"NUMGENOMES"}->[0]++;
							}
							push(@{$newRow->{$genomeList->[$i]}},$row->{Gene}->[0]);
							$newRow = $minimalEssentialFunctions->get_row_by_key($generow->{"ROLES"}->[$k],"ROLE");
							if (defined($newRow)) {
								if (!defined($newRow->{"NUMGENES"})) {
									$newRow->{"NUMGENES"}->[0] = 0;
									$newRow->{"NUMGENOMES"}->[0] = 0;
								}
								$newRow->{"NUMGENES"}->[0]++;
								if (!defined($newRow->{$genomeList->[$i]})) {
									$newRow->{"NUMGENOMES"}->[0]++;
								}
								push(@{$newRow->{$genomeList->[$i]}},$row->{Gene}->[0]);
							}
						}
					} else {
						$essentialGenes->{$genomeList->[$i]}->{$row->{Gene}->[0]} = 1;
					}
				} else {
					if (defined($row->{"ROLES"})) {
						$minimalEssentials->{$row->{Gene}->[0]} = $generow->{"ROLES"};
						for (my $k=0; $k < @{$generow->{"ROLES"}}; $k++) {
							my $newRow = $minimalEssentialFunctions->get_row_by_key($generow->{"ROLES"}->[$k],"ROLE",1);
							if (!defined($newRow->{"NUMGENES"})) {
								$newRow->{"NUMGENES"}->[0] = 0;
								$newRow->{"NUMGENOMES"}->[0] = 0;
							}
							$newRow->{"NUMGENES"}->[0]++;
							if (!defined($newRow->{$genomeList->[$i]})) {
								$newRow->{"NUMGENOMES"}->[0]++;
							}
							push(@{$newRow->{$genomeList->[$i]}},$row->{Gene}->[0]);
						}
					} else {
						$essentialGenes->{$genomeList->[$i]}->{$row->{Gene}->[0]} = 1;
					}
				}
				
			}
		}
	}
	$essentialFunctions->save();
	$minimalEssentialFunctions->save();
	return;
	
	#Loading the BBH data tables
	for (my $i=0; $i < @{$genomeList}; $i++) {
		my $features = $self->GetGenomeFeatureTable($genomeList->[$i]);
		my $tbl = $self->GetEssentialityData($genomeList->[$i]);
		for (my $j=0; $j < $tbl->size(); $i++) {
			my $row = $tbl->get_row($i);
			if ($row->{Essentiality}->[0] ne "nonessential") {
				my $row = $features->get_row_by_key("fig|".$genomeList->[$i].".".$row->{Gene}->[0],"ID");
				if (!defined($assignedToFamily->{$genomeList->[$i]}->{$row->{Gene}->[0]})) {
					if ($genomeList->[$i] ne "83333.1" || $row->{Media}->[0] eq "ArgonneLBMedia") {
						my @sim_results = $self->fig()->sims("fig|".$genomeList->[$i].".".$row->{Gene}->[0], 10000, 0.00001, "fig");
						my $bestScores;
						my $bestEssScores;
						my $bestHit;
						my $bestEss;
						for (my $k=0; $k < @sim_results; $k++) {
							if ($sim_results[$k]->[0] =~ m/fig\|(\d+.\d+)\.(peg\.\d+)/) {
								my $genome = $1;
								my $gene = $2;
								if (defined($genomeHash->{$genome})) {
									$assignedToFamily->{$genomeList->[$i]}->{$row->{Gene}->[0]} = 1;
									my $newRow = $essentialBBH->get_row_by_key($row->{Gene}->[0],"FAMILY",1);
									if (!defined($newRow->{ROLES})) {
										$newRow->{ROLES} = $row->{"ROLES"};
										$newRow->{NUMGENOMES}->[0] = 0;
									}
									if (!defined($newRow->{$genome})) {
										$newRow->{$genome}->[3] = 0;
										$newRow->{$genome}->[4] = 0;
									}
									$newRow->{$genome}->[3]++;
									if (!defined($bestScores->{$genome}) || $bestScores->{$genome} > $sim_results[$k]->[5]) {
										$bestScores->{$genome} = $sim_results[$k]->[5];
										$bestHit->{$genome} = $gene;
									}
									if (defined($essentialGenes->{$genome}->{$gene})) {
										$newRow->{$genome}->[4]++;
										if (!defined($bestEssScores->{$genome}) || $bestEssScores->{$genome} > $sim_results[$k]->[5]) {
											$bestEssScores->{$genome} = $sim_results[$k]->[5];
											$bestEss->{$genome} = $gene;
										}
									}
								}
							}
						}
						my $newRow = $essentialBBH->get_row_by_key($row->{Gene}->[0],"FAMILY");
						my @temp = keys(%{$bestScores});
						for (my $k=0; $k < @temp;$k++) {
							$newRow->{$temp[$k]}->[1] = $bestHit->{$temp[$k]}.":".$bestScores->{$temp[$k]};
						}
						@temp = keys(%{$bestEssScores});
						for (my $k=0; $k < @temp;$k++) {
							$newRow->{$temp[$k]}->[0] = $bestEss->{$temp[$k]}.":".$bestEssScores->{$temp[$k]};
							$assignedToFamily->{$temp[$k]}->{$bestEss->{$temp[$k]}} = 1;
							$newRow->{NUMGENOMES}->[0]++;
						}
					} else {
						my @sim_results = $self->fig()->sims("fig|".$genomeList->[$i].".".$row->{Gene}->[0], 10000, 0.00001, "fig");
						my $bestScores;
						my $bestEssScores;
						my $bestHit;
						my $bestEss;
						for (my $k=0; $k < @sim_results; $k++) {
							if ($sim_results[$k]->[0] =~ m/fig\|(\d+.\d+)\.(peg\.\d+)/) {
								my $genome = $1;
								my $gene = $2;
								if (defined($genomeHash->{$genome})) {
									my $newRow = $minBBH->get_row_by_key($row->{Gene}->[0],"FAMILY",1);
									if (!defined($newRow->{ROLES})) {
										$newRow->{ROLES} = $row->{"ROLES"};
										$newRow->{NUMGENOMES}->[0] = 0;
									}
									if (!defined($newRow->{$genome})) {
										$newRow->{$genome}->[3] = 0;
										$newRow->{$genome}->[4] = 0;
									}
									$newRow->{$genome}->[3]++;
									if (!defined($bestScores->{$genome}) || $bestScores->{$genome} > $sim_results[$k]->[5]) {
										$bestScores->{$genome} = $sim_results[$k]->[5];
										$bestHit->{$genome} = $gene;
									}
									if (defined($essentialGenes->{$genome}->{$gene})) {
										$newRow->{$genome}->[4]++;
										if (!defined($bestEssScores->{$genome}) || $bestEssScores->{$genome} > $sim_results[$k]->[5]) {
											$bestEssScores->{$genome} = $sim_results[$k]->[5];
											$bestEss->{$genome} = $gene;
										}
									}
								}
							}
						}
						my $newRow = $minBBH->get_row_by_key($row->{Gene}->[0],"FAMILY");
						my @temp = keys(%{$bestScores});
						for (my $k=0; $k < @temp;$k++) {
							$newRow->{$temp[$k]}->[1] = $bestHit->{$temp[$k]}.":".$bestScores->{$temp[$k]};
						}
						@temp = keys(%{$bestEssScores});
						for (my $k=0; $k < @temp;$k++) {
							$newRow->{$temp[$k]}->[0] = $bestEss->{$temp[$k]}.":".$bestEssScores->{$temp[$k]};
							$newRow->{NUMGENOMES}->[0]++;
						}
					}
				}
			}
		}
	}
	$essentialBBH->save();
	$minBBH->save();
}

#From FIGMODELdatabase

sub loadsubsystems {
	my($self,@Data) = @_;
		if (!defined($self->figmodel()->fig())) {
			$self->figmodel()->error_message("FIGMODELdatabase->load_ppo(subsystem):Fig object could not be created!");
			return $self->fail();
		}
		my @SubsystemList = $self->figmodel()->fig()->all_subsystems();
		for (my $i=0; $i < @SubsystemList; $i++) {
			my $obj = $self->get_object("subsystem",{id => $SubsystemList[$i]});
			if (!defined($obj)) {
				my $class = $self->figmodel()->fig()->subsystem_classification($SubsystemList[$i]);
				if (!defined($class) || !defined($class->[0])) {
					$class->[0] = "none";
				}
				if (!defined($class->[1])) {
					$class->[1] = "none";
				}
				my $ssMgr = $self->get_object_manager("subsystem");
				my $newID = $self->check_out_new_id("subsystem");
				my $status = "core";
				if ($self->figmodel()->fig()->is_experimental_subsystem($SubsystemList[$i]) == 1) {
					$status = "experimental";
				}
				$obj = $ssMgr->create({id=>$newID,name=>$SubsystemList[$i],status=>$status,classOne=>$class->[0],classTwo=>$class->[1]});
			}
			my @roles = $self->figmodel()->fig()->subsystem_to_roles($SubsystemList[$i]);
			my $roleHash;
			for (my $j=0; $j < @roles; $j++) {
				my $searchname = $self->figmodel()->convert_to_search_role($roles[$j]);
				my $roleobj = $self->get_object("role",{searchname => $searchname});
				if (!defined($roleobj)) {
					my $newRoleID = $self->check_out_new_id("role");
					my $roleMgr = $self->get_object_manager("role");
					$roleobj = $roleMgr->create({id=>$newRoleID,name=>$roles[$j],searchname=>$searchname});
				}
				$roleobj->name($roles[$j]);
				$roleHash->{$roleobj->id()} = 0;
			}
			my $ssRoleObjs = $self->get_objects("ssroles",{SUBSYSTEM=>$obj->id()});
			for (my $j=0; $j < @{$ssRoleObjs}; $j++) {
				if (defined($roleHash->{$ssRoleObjs->[$j]->ROLE()})) {
					$roleHash->{$ssRoleObjs->[$j]->ROLE()} = 1;
				} else {
					$ssRoleObjs->[$j]->delete();
				}
			}
			my @ssRoles = keys(%{$roleHash});
			for (my $j=0; $j < @ssRoles; $j++) {
				if ($roleHash->{$ssRoles[$j]} == 0) {
					my $ssRoleMgr = $self->get_object_manager("ssroles");
					$ssRoleMgr->create({ROLE=>$ssRoles[$j],SUBSYSTEM=>$obj->id()});
				}
			}
		}