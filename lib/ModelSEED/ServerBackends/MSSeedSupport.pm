#!/usr/bin/perl -w
use strict;
use warnings;
use Data::Dumper;
use ModelSEEDbootstrap;
use ModelSEED::FIGMODEL;
use FIG;

#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
#
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License.
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#
package MSSeedSupport;
    use SeedUtils;
    use ServerThing;
    use DBMaster;

=head1 FBA Model Function Object

=head2 Special Methods

=head3 new

Definition:
	MSSeedSupport::MSSeedSupport object = MSSeedSupport->new();

Description:
    Creates a new MSSeedSupport function object. The function object is used to invoke the server functions.

=cut
sub new {
    my ($class) = @_;
    my $MSSeedSupport;
	$MSSeedSupport->{_figmodel} = ModelSEED::FIGMODEL->new();
	$MSSeedSupport->{_fig} = FIG->new();
	bless $MSSeedSupport, $class;
    return $MSSeedSupport;
}

=head3 figmodel

Definition:

	FIGMODEL::figmodel object = MSSeedSupport->figmodel();

Description:

    Returns the FIGMODEL object required to get model data from the server

=cut
sub figmodel {
    my ($self) = @_;
	return $self->{_figmodel};
}
=head3 fig

Definition:

	FIG::fig object = MSSeedSupport->fig();

Description:

    Returns the FIG object required to get model data from the server

=cut
sub fig {
    my ($self) = @_;
	return $self->{_fig};
}
=head3 methods

Definition:

	[string]:list of methods = MSSeedSupport->methods();

Description:

    Returns a list of the methods for the class

=cut
sub methods {
    my ($self) = @_;
	if (!defined($self->{_methods})) {
		$self->{_methods} = [
			"get_user_info",
			"blast_sequence",
			"pegs_of_function",
			"getRastGenomeData",
			"users_for_genome"
        ];
	}
	return $self->{_methods};
}
=head3 authenticate_user

Definition:

	void MSSeedSupport->authenticate_user( { user => string:username,password => string:password} );

Description:

    Determines if user data was input and points to a valid account

=cut
sub authenticate_user {
    my ($self,$args) = @_;
	if (defined($args->{user}) && defined($args->{password})) {
		$self->figmodel()->authenticate({username => $args->{user},password => $args->{password}});
    } elsif (defined($args->{username}) && defined($args->{password})) {
		$self->figmodel()->authenticate({username => $args->{username},password => $args->{password}});
	} elsif (defined($self->{cgi})) {
		$self->figmodel()->authenticate({cgi => $self->{cgi}});
	}
	return $args;
}
=head3 process_arguments

Definition:

	{key=>value} = MSSeedSupport->process_arguments( {key=>value} );
Description:

    Processes arguments to authenticate users and perform other needed tasks

=cut
sub process_arguments {
    my ($self,$args,$mandatoryArguments,$optionalArguments) = @_;
    if (defined($mandatoryArguments)) {
    	for (my $i=0; $i < @{$mandatoryArguments}; $i++) {
    		if (!defined($args->{$mandatoryArguments->[$i]})) {
				push(@{$args->{_error}},$mandatoryArguments->[$i]);
    		}
    	}
    }
	ModelSEED::utilities::ERROR("Mandatory arguments ".join("; ",@{$args->{_error}})." missing. Usage:".$self->print_usage($mandatoryArguments,$optionalArguments,$args)) if (defined($args->{_error}));
    if (defined($optionalArguments)) {
    	foreach my $argument (keys(%{$optionalArguments})) {
    		if (!defined($args->{$argument})) {
    			$args->{$argument} = $optionalArguments->{$argument};
    		}
    	}	
    }
    $self->authenticate_user($args);
    return $args;
}
=head3 get_user_info

=item Definition:

    Output = MSSeedSupport->get_user_info({
    	username => string,
    	password => string
    });
    Output: {
    	username => string,
    	password => string,
    	firstname => string,
    	lastname => string,
    	email => string,
    	id => integer
    }

=item Description:
	
	Returns a hash of the pegs associated with each input functional role.

=cut
sub get_user_info {
	my($self,$args) = @_;
	$args = $self->process_arguments($args,["username","password"],{});
	if ($self->figmodel()->user() ne $args->{username} || !defined($self->figmodel()->userObj())) {
		return {error => "No account found in SEED matching input username and password"};
	}
	return {
		username => $self->figmodel()->userObj()->login(),
    	password => $self->figmodel()->userObj()->password(),
    	firstname => $self->figmodel()->userObj()->firstname(),
    	lastname => $self->figmodel()->userObj()->lastname(),
    	email => $self->figmodel()->userObj()->email(),
    	id => $self->figmodel()->userObj()->_id()
	};
}
=head3 blast_sequence

=item Definition:

    Output = MSSeedSupport->blast_sequence({
    	sequences => [string]
    	genomes => [string]
    });
    Output: {
    }

=item Description:
	Return data about any hits of the input sequences against the input genome set
=cut
sub blast_sequence {
	my($self,$args) = @_;
	$args = $self->process_arguments($args,["sequences","genomes"],{});
	if (@{$args->{genomes}} > 10) {
		ModelSEED::utilities::ERROR("This is not the appropriate function to use for blasting > 10 genomes.");
	}
	my $dbname = join(".",sort(@{$args->{genomes}}));
	if (!-e $self->figmodel()->config("blastdb cache directory")->[0].$dbname."/db.fasta") {
		my $sapObject = $self->figmodel()->sapSvr();
		my $genomeHash = $sapObject->genome_contigs({
			-ids => $args->{genomes}
		});
		my $contigs;
		foreach my $key (keys(%{$genomeHash})) {
			push(@{$contigs},@{$genomeHash->{$key}});
		}
		my $contigHash = $sapObject->contig_sequences({
			-ids => $contigs
	    });
	    File::Path::mkpath $self->figmodel()->config("blastdb cache directory")->[0].$dbname."/";
	    open( TMP, ">".$self->figmodel()->config("blastdb cache directory")->[0].$dbname."/db.fasta") || die "could not open";
	    foreach my $contig (keys(%{$contigHash})) {
	    	my $fastaString = SeedUtils::create_fasta_record($contig,undef,$contigHash->{$contig});
	    	print TMP $fastaString;
	    }
	    close(TMP);
	    system("formatdb -i ".$self->figmodel()->config("blastdb cache directory")->[0].$dbname."/db.fasta -p F");   
	}
	#Querying each input sequence
	my ($fh, $filename) = File::Temp::tempfile("XXXXXXX",DIR => $self->figmodel()->config("blastdb cache directory")->[0].$dbname."/");
	close($fh);
	my $results;
	for (my $i=0; $i < @{$args->{sequences}};$i++) {
		my $fastaString = SeedUtils::create_fasta_record("Sequence ".$i,undef, $args->{sequences}->[$i]);
		open( TMP, ">".$filename) || die "could not open";
		print TMP  $fastaString;
		close(TMP);
		system("blastall -i ".$filename." -d ".$self->figmodel()->config("blastdb cache directory")->[0].$dbname."/db.fasta -p blastn -FF -e 1.0e-5 -m 8 -o ".$filename.".out");
		my $data = $self->figmodel()->database()->load_multiple_column_file($filename.".out","\t");
		for (my $j=0; $j < @{$data}; $j++) {
			if (defined($data->[$j]->[11])) {
				$results->{$args->{sequences}->[$i]}->{$data->[$j]->[1]} = {
					identity => $data->[$j]->[2],
					"length" => $data->[$j]->[3],
					qstart => $data->[$j]->[6],
					qend => $data->[$j]->[7],
					tstart => $data->[$j]->[8],
					tend => $data->[$j]->[9],
					evalue => $data->[$j]->[10],
					bitscore => $data->[$j]->[11],
				}
			}
		}
	}
	unlink($filename);
	unlink($filename.".out");
	return $results;
}

=head3 pegs_of_function

=item Definition:

    Output = MSSeedSupport->pegs_of_function({
    	roles => [string]:role names
    });
    Output: {
    	string:role name=>[string]:peg ID
    }

=item Description:
	
	Returns a hash of the pegs associated with each input functional role.

=cut

sub pegs_of_function {
	my ($self,$args) = @_;
    $args = $self->process_arguments($args);
 	my $result;
 	for (my $i=0; $i < @{$args->{roles}}; $i++) {
 		my @pegs = $self->fig()->prots_for_role($args->{roles}->[$i]);
 		push(@{$result->{$args->{roles}[$i]}},@pegs);
 	}
 	return $result;
}

=head3 getRastGenomeData

=item Definition:
	
	Output = MSSeedSupport->getRastFeatureTable({
		genome => string:genome ID
	});
	Output: {
		source => string:source of genome,
		genome => string:genome ID,
		features => FIGMODELTable:table of features
		name => string:organism name,
		taxonomy => string:taxonomy,
		size => int:genome size in nucleotides,
		owner => string:owner login
	}
	
=item Description:
	
	Returns a table of features in the genome

=cut
sub getRastGenomeData {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args, ['genome'],{
		getSequences => 0,
		getDNASequence => 0	
	});
	my $figmodel = $self->figmodel();
	my $output = {
		features => ModelSEED::FIGMODEL::FIGMODELTable->new(["ID","GENOME","ESSENTIALITY","ALIASES","TYPE","LOCATION","LENGTH","DIRECTION","MIN LOCATION","MAX LOCATION","ROLES","SOURCE","SEQUENCE"],"NONE",["ID","ALIASES","TYPE","ROLES","GENOME"],"\t","|",undef),
		gc => 0.5,
		genome => $args->{genome},
		owner => "master"
	};
	my $directory;
	#Checking if this is a pubseed genome
	if (-d "/vol/public-pseed/FIGdisk/FIG/Data/Organisms/".$args->{genome}) {
		$directory = "/vol/public-pseed/FIGdisk/FIG/Data/Organisms/".$args->{genome};
		$output->{source} = "TEMPPUBSEED";
	}
	#Checking RAST
	if (!defined($directory)) {
		my $job = $figmodel->database()->get_object("rastjob",{genome_id => $args->{genome}});
		if (defined($job)) {
			$output->{source} = "RAST:".$job->id();
			$directory = "/vol/rast-prod/jobs/".$job->id()."/rp/".$args->{genome};
			#$FIG_Config::rast_jobs = "/vol/rast-prod/jobs";
			$output->{gc} = 0.01*$job->metaxml()->get_metadata('genome.gc_content');
			$output->{owner} = $figmodel->database()->load_single_column_file("/vol/rast-prod/jobs/".$job->id()."/USER","\t")->[0];
		}
	}
	#Checking TEST RAST
	if (!defined($directory)) {
		my $job = $figmodel->database()->get_object("rasttestjob",{genome_id => $args->{genome}});
		if (defined($job)) {
			$output->{source} = "TESTRAST:".$job->id();
			$directory = "/vol/rast-test/jobs/".$job->id()."/rp/".$args->{genome};
			#$FIG_Config::rast_jobs = "/vol/rast-test/jobs";
			$output->{gc} = 0.01*$job->metaxml()->get_metadata('genome.gc_content');
			$output->{owner} = $figmodel->database()->load_single_column_file("/vol/rast-test/jobs/".$job->id()."/USER","\t")->[0];
		}
	}
	#Getting MGRAST genome data
	if (-d $figmodel->config("Metagenome directory")->[0].$args->{genome}.".tbl") {
		$output->{source} = "MGRAST";
		$directory = $figmodel->config("Metagenome directory")->[0].$args->{genome}.".tbl";
	}
	#Bailing if we still haven't found the genome
	if (!defined($directory)) {
		ModelSEED::utilities::WARNING("Could not find data for genome".$args->{genome});
		return undef;
	}
	#Checking for rights
	if ($output->{source} =~ m/^MGRAST/ || $output->{source} =~ m/^RAST/ || $output->{source} =~ m/^TESTRAST/) {
		if ($figmodel->user() eq "PUBLIC") {
			ModelSEED::utilities::WARNING("Must be authenticated to access model");
			return undef;
		} elsif (!defined($figmodel->config("super users")->{$figmodel->user()})) {
			my $haveRight = 0;
			my $userScopes = $figmodel->database()->get_objects("userscope",{
				user => $figmodel->userObj()
			});
			for (my $i=0; $i < @{$userScopes}; $i++) {
				my $right = $figmodel->database()->get_object("right",{
					data_type => "genome",
					data_id => $args->{genome},
					granted => 1,
					scope => $userScopes->[$i]->scope()
				});
				if (defined($right)) {
					$haveRight = 1;
					last;
				}
			}
			if ($haveRight == 0) {
				ModelSEED::utilities::WARNING("Do not have rights to requested genome");
				return undef;
			}
		}
	}
	#Loading MGRAST genomes
	if ($output->{source} eq "MGRAST") {
		my $output = {
			source => "MGRAST",
			genome => $args->{genome},
			features => ModelSEED::FIGMODEL::FIGMODELTable::load_table($figmodel->config("Metagenome directory")->[0].$args->{genome}.".tbl","\t","|",0,["ID","GENOME","ROLES","SOURCE"]),
			name => "Unknown",
			taxonomy => "Metagenome",
			size => 0,
			owner => $figmodel->user()
		};
		return $output;
	}
	#Loading genomes with FIGV
	require FIGV;
	my $figv = new FIGV($directory);	
	if (!defined($figv)) {
		ModelSEED::utilities::WARNING("Could not create FIGV object for RAST genome:".$args->{genome});
		return undef;
	}
	if ($args->{getDNASequence} == 1) {
		my @contigs = $figv->all_contigs($args->{genome});
		for (my $i=0; $i < @contigs; $i++) {
			my $contigLength = $figv->contig_ln($args->{genome},$contigs[$i]);
			push(@{$output->{DNAsequence}},$figv->get_dna($args->{genome},$contigs[$i],1,$contigLength));
		}
	}
	$output->{activeSubsystems} = $figv->active_subsystems($args->{genome});
	my $completetaxonomy = $figmodel->database()->load_single_column_file($directory."/TAXONOMY","\t")->[0];
	$completetaxonomy =~ s/;\s/;/g;
	my $taxArray = [split(/;/,$completetaxonomy)];
	$output->{name} = pop(@{$taxArray});
	$output->{taxonomy} = join("|",@{$taxArray});
	$output->{size} = $figv->genome_szdna($args->{genome});
	my $GenomeData = $figv->all_features_detailed_fast($args->{genome});
	foreach my $Row (@{$GenomeData}) {
		my $RoleArray;
		if (defined($Row->[6])) {
			push(@{$RoleArray},$figmodel->roles_of_function($Row->[6]));
		} else {
			$RoleArray = ["NONE"];
		}
		my $AliaseArray;
		push(@{$AliaseArray},split(/,/,$Row->[2]));
		my $Sequence;
		if (defined($args->{getSequences}) && $args->{getSequences} == 1) {
			$Sequence = $figv->get_translation($Row->[0]);
		}
		my $Direction ="for";
		my @temp = split(/_/,$Row->[1]);
		if ($temp[@temp-2] > $temp[@temp-1]) {
			$Direction = "rev";
		}
		my $newRow = $output->{features}->add_row({"ID" => [$Row->[0]],"GENOME" => [$args->{genome}],"ALIASES" => $AliaseArray,"TYPE" => [$Row->[3]],"LOCATION" => [$Row->[1]],"DIRECTION" => [$Direction],"LENGTH" => [$Row->[5]-$Row->[4]],"MIN LOCATION" => [$Row->[4]],"MAX LOCATION" => [$Row->[5]],"SOURCE" => [$output->{source}],"ROLES" => $RoleArray});
		if (defined($Sequence) && length($Sequence) > 0) {
			$newRow->{SEQUENCE}->[0] = $Sequence;
		}
	}
	return $output;
}
=head3 users_for_genome

=item Definition:

    Output = FBAMODEL->users_for_genome({
        genome => string  
    });
    Output: {
    	genome:string => [string]:users
    }
    
=item Description:
    
    Returns list of users for specified genome

=cut
sub users_for_genome {
    my ($self,$args) = @_;
    $args = $self->process_arguments($args, ["genome","username","password"],{});
    my $user_scopes = $self->figmodel()->database()->get_objects("userscope"); 
    my $scopeHash;
    for (my $i=0; $i < @{$user_scopes}; $i++) {
    	push(@{$scopeHash->{$user_scopes->[$i]->scope()->_id()}},$user_scopes->[$i]->user()->login());
    }
    my $objs = $self->figmodel()->database()->get_objects("right",{
    	data_type => "genome",
    	granted => 1,
    	data_id => $args->{genome}
    });
    my $result;
    for (my $i=0; $i < @{$objs}; $i++) {
        my $right = "view";
        if ($objs->[$i]->name() ne "view") {
            $right = "admin";
        }
        if (defined($scopeHash->{$objs->[$i]->scope()->_id()})) {
        	for (my $j=0; $j < @{$scopeHash->{$objs->[$i]->scope()->_id()}}; $j++) {
        		$result->{$args->{genome}}->{$scopeHash->{$objs->[$i]->scope()->_id()}->[$j]} = $right;
        	}
        }
    }
    if (!defined($result->{$args->{genome}}->{$self->figmodel()->user()}) && 
    	(!defined($self->figmodel()->config("model administrators")->{$args->{username}}) ||
    		$args->{password} eq $self->figmodel()->config("model administrators")->{$args->{username}}->[0])) {
    	return {error => "Must have rights to genome before user list can be returned!"};
    }
    return $result;
}
#TODO: These are function specific to the SEED environment that may still be useful, but will not work as they currently stand
=head3 ParseHopeSEEDReactionFiles

Definition:
	$model->ParseHopeSEEDReactionFiles();

Description:

Example:
	$model->ParseHopeSEEDReactionFiles();

=cut
sub ParseHopeSEEDReactionFiles {
	my($self) = @_;

	#Gathering all of the filesnames in the subsystems directory
	print "Parsing subsystems...\n";
	my @Filenames = &RecursiveGlob($self->{"subsystems directory"}->[0]);
	print "Subsystem filenames gathered...\n";

	#Scanning through the filenames for the Hope and SEED reaction files
	my %SubsystemDataHash;
	for (my $i=0; $i < @Filenames; $i++) {
	if ($Filenames[$i] =~ m/\/([^\/]+)\/hope_reactions$/) {
		my $Subsystem = $1;
		#Loading the entire file into a 2D array
		my $Data = FIGMODEL::LoadMultipleColumnFile($Filenames[$i],"\t");
		#For each line in the file, saving the subsystem name, the functional role, and the hope reaction
		for (my $j=0; $j < @{$Data}; $j++) {
		if (defined($Data->[$j]->[0]) && defined($Data->[$j]->[1])) {
			my @Reactions = split(/,/,$Data->[$j]->[1]);
			for (my $k=0; $k < @Reactions; $k++) {
			if (defined($SubsystemDataHash{$Subsystem}->{$Data->[$j]->[0]}->{$Reactions[$k]}->{"SOURCE"})) {
				$SubsystemDataHash{$Subsystem}->{$Data->[$j]->[0]}->{$Reactions[$k]}->{"SOURCE"}->[0] .= "|Hope";
			} else {
				$SubsystemDataHash{$Subsystem}->{$Data->[$j]->[0]}->{$Reactions[$k]}->{"SOURCE"}->[0] = "Hope";
			}
			}
		}
		}
	#} elsif ($Filenames[$i] =~ m/\/([^\/]+)\/reactions$/) {
	#    my $Subsystem = $1;
	#    #Loading the entire file into a 2D array
	#    my $Data = FIGMODEL::LoadMultipleColumnFile($Filenames[$i],"\t");
	#    #For each line in the file, saving the subsystem name, the functional role, and the hope reaction
	#    for (my $j=0; $j < @{$Data}; $j++) {
	#   if (defined($Data->[$j]->[0]) && defined($Data->[$j]->[1])) {
	#       my @Reactions = split(/,/,$Data->[$j]->[1]);
	#       for (my $k=0; $k < @Reactions; $k++) {
	#       my $Reaction = $Reactions[$k];
	#       if ($Reaction =~ m/(R\d\d\d\d\d)/ || $Reaction =~ m/(rxn\d\d\d\d\d)/) {
	#           $Reaction = $1;
	#           if (defined($SubsystemDataHash{$Subsystem}->{$Data->[$j]->[0]}->{$Reactions[$k]}->{"SOURCE"})) {
	#           $SubsystemDataHash{$Subsystem}->{$Data->[$j]->[0]}->{$Reactions[$k]}->{"SOURCE"}->[0] .= "|SEED";
	#           } else {
	#           $SubsystemDataHash{$Subsystem}->{$Data->[$j]->[0]}->{$Reactions[$k]}->{"SOURCE"}->[0] = "SEED";
	#           }
	#       }
	#       }
	#   }
	#    }
	}
	}

	my $Filename = $self->{"hope and seed subsystems filename"}->[0];
	open (SEEDHOPEANNOTATIONS, ">$Filename");
	print SEEDHOPEANNOTATIONS "SUBSYSTEM\tROLE\tREACTION\tSOURCE\n";
	foreach my $Subsystem (keys(%SubsystemDataHash)) {
	foreach my $Role (keys(%{$SubsystemDataHash{$Subsystem}})) {
		foreach my $Reaction (keys(%{$SubsystemDataHash{$Subsystem}->{$Role}})) {
		print SEEDHOPEANNOTATIONS $Subsystem."\t".$Role."\t".$Reaction."\t".$SubsystemDataHash{$Subsystem}->{$Role}->{$Reaction}->{"SOURCE"}->[0]."\n";
		}
	}
	}
	close(SEEDHOPEANNOTATIONS);

	#Gathering all of the filesnames in the subsystems directory
	print "Parsing scenarios...\n";
	@Filenames = &RecursiveGlob($self->{"scenarios directory"}->[0]);
	print "Scenario filenames gathered...\n";
	my %ScenarioHash;
	for (my $i=0; $i < @Filenames; $i++) {
	if ($Filenames[$i] =~ m/reactions$/) {
		my $ScenarioName = substr($Filenames[$i],length($self->{"scenarios directory"}->[0]));
		my @DirectoryList = split(/\//,$ScenarioName);
		shift(@DirectoryList);
		$ScenarioName = join(":",@DirectoryList);
		$ScenarioName =~ s/path\_//g;
		$ScenarioName =~ s/\_/ /g;
		my $ScenarioReactions = LoadSingleColumnFile($Filenames[$i],"");
		foreach my $Line (@{$ScenarioReactions}) {
		if ($Line =~ m/(R\d\d\d\d\d)/ || $Line =~ m/(rxn\d\d\d\d\d)/) {
			$ScenarioHash{$ScenarioName}->{$1} = 1;
		}
		}
	}
	}

	$Filename = $self->{"hope scenarios filename"}->[0];
	open (SEEDHOPEANNOTATIONS, ">$Filename");
	print SEEDHOPEANNOTATIONS "SCENARIO\tREACTION\n";
	foreach my $Scenario (keys(%ScenarioHash)) {
	foreach my $Reaction (keys(%{$ScenarioHash{$Scenario}})) {
		print SEEDHOPEANNOTATIONS $Scenario."\t".$Reaction."\n";
	}
	}
	close(SEEDHOPEANNOTATIONS);
}

1;
