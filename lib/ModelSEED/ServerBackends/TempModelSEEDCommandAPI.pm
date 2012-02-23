#!/usr/bin/perl -w
use strict;
use ModelSEED::FIGMODEL;

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
package ModelSEED::ServerBackends::TempModelSEEDCommandAPI;

=head1 TempModelSEEDCommandAPI Function Object

=head2 Special Methods

=head3 new

Definition:
	TempModelSEEDCommandAPI::TempModelSEEDCommandAPI object = TempModelSEEDCommandAPI->new();

Description:
    Creates a new TempModelSEEDCommandAPI function object. The function object is used to invoke the server functions.

=cut
sub new {
    my ($class, $args) = @_;
    my $self = {_figmodel => ModelSEED::FIGMODEL->new()};
    return bless $self;
}

=head3 methods

Definition:

	[string] = TempModelSEEDCommandAPI->methods();

Description:

    Returns a list of the methods for the class

=cut
sub methods {
    my ($self) = @_;
	return [
		"fbasimulatekomedialist"
	];
}

=head2 Process Arguments and Authenticate
=cut
sub process_arguments_and_authenticate {
    my ($self, $args, $req, $opt) = @_;
    $args = $self->{_figmodel}->process_arguments($args, $req, $opt);
    if(defined($args->{user}) || defined($args->{username})) {
        $self->{_figmodel}->authenticate({
            username => ($args->{user}) ? $args->{user} : $args->{username}, 
            password => $args->{password}});
    }
    return $args;
}

=head
=NAME
fbasimulatekomedialist
=CATEGORY
Flux Balance Analysis Operations
=DEFINITION
Output = fbasimulatekomedialist({
	model => string:Full ID of the model to be analyzed,
	media => [string]:Name of the media conditions in the Model SEED database in which the analysis should be performed,
	rxnKO => [[string]]:delimited list of reactions to be knocked out during the analysis
	geneKO => [string]:delimited list of genes to be knocked out during the analysis
	drainRxn => [string]:list of reactions whose reactants will be added as drain fluxes in the model during the analysis
	uptakeLim => string:Specifies limits on uptake of various atoms. For example 'C:1;S:5'
	options => string:list of optional keywords that toggle the use of various additional constrains during the analysis
	fbajobdir => string:Set directory in which FBA problem output files will be stored
	savelp => string:User can choose to save the linear problem associated with the FBA run
})
Output: {
	ERROR => string,
	MESSAGE => string,
	SUCCESS => 1,
	RESULTS => {
		string:KO label => {
			growth => {
				string:media => [double:growth,double:fraction]
			}
		}
	}
}
=SHORT DESCRIPTION
checks model growth with a variety of specified knockouts and media conditions
=DESCRIPTION
This function is used simulate model growth for every combination of a specified set of media conditions and knockouts
=cut
sub fbasimulatekomedialist {
	my ($self,$args) = @_;
	my ($fh, $tmpfile) = File::Temp::tempfile("XXXXXX",DIR => $self->{_figmodel}->config("database root directory")->[0]."ReactionDB/temp/");
	close($fh);
	my $oldout;
	open($oldout, ">&STDOUT") or warn "Can't dup STDOUT: $!";
	open(STDOUT, '>', $tmpfile) or warn "Can't redirect STDOUT: $!";
	select STDOUT; $| = 1;
	my $output;
	$args = $self->process_arguments_and_authenticate($args,["model"],{
		media => ["Complete"],
		ko => [["None"]],
		rxnKO => undef,
		geneKO => undef,
		drainRxn => undef,
		uptakeLim => undef,
		options => undef,
		fbajobdir => undef,
		savelp => 0
	});
	my $medias = $args->{media};
	my $kos = $args->{ko};
	my $labels = $args->{kolabel};
	if (!defined($labels)) {
		for (my $i=0; $i < @{$kos}; $i++) {
			$labels->[$i] = join(",",@{$kos->[$i]});
		}
	}
	my $mdl = $self->{_figmodel}->get_model($args->{model});
	if (!defined($mdl)) {
		return {SUCCESS => 0,ERROR => "Model not valid ".$args->{model}};
	}
	my $input;
	for (my $i=0; $i < @{$kos}; $i++) {
		for (my $j=0; $j < @{$medias}; $j++) {
			push(@{$input->{labels}},$labels->[$i]."_".$medias->[$j]);
			push(@{$input->{mediaList}},$medias->[$j]);
			push(@{$input->{koList}},$kos->[$i]);
		}
	}
	$input->{fbaStartParameters} = {};
	$input->{findTightBounds} = 0;
	$input->{deleteNoncontributingRxn} = 0;
	$input->{identifyCriticalBiomassCpd} = 0;
	my $growthRates;
	my $result = $mdl->fbaMultiplePhenotypeStudy($input);
	my $output;
	delete $result->{fbaObj};
	delete $result->{arguments};
	foreach my $label (keys(%{$result})) {
		my $array = [split(/_/,$label)];
		$output->{$array->[0]}->{growth}->{$result->{$label}->{media}} = [$result->{$label}->{growth},$result->{$label}->{fraction}];
		$output->{$array->[0]}->{geneKO} = $result->{$label}->{geneKO};
		$output->{$array->[0]}->{rxnKO} = $result->{$label}->{rxnKO};
	}
	open(STDOUT, ">&", $oldout) or warn "Can't dup \$oldout: $!";
	unlink($oldout);
	return {
		SUCCESS => 1,
		MESSAGE => "Phenotype analysis successful!",
		RESULTS => $output
	};
}

1;
