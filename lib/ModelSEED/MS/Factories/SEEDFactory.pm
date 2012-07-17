########################################################################
# ModelSEED::MS::Factories::Annotation
# 
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location:
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#
# Date of module creation: 2012-06-03
########################################################################
=pod
=head1 ModelSEED::MS::Factories::Annotation

A factory for producing an Annotation object from several data
sources.

=head2 ABSTRACT

    my $fact = ModelSEED::MS::Factories::Annotation->new;

    # Get list of available genome IDs
    my $genomes = $fact->availableGenomes();
    my $kbase_genomes = $fact->availableGenomes(source => 'KBase');
    my $rast_genomes = $fact->availableGenomes(source => 'RAST');
    my $pubseed_genomes = $fact->availableGenomes(source => 'PubSEED');
    # These are all array refs of genome IDs

=cut
package ModelSEED::MS::Factories::SEEDFactory;
use common::sense;
use Moose;
use Class::Autouse qw(
	ModelSEED::MS::Mapping
	ModelSEED::MS::Annotation
	ModelSEED::utilities
	ModelSEED::MS::Utilities::GlobalFunctions
    Bio::KBase::CDMI::Client
    SAPserver
    MSSeedSupportClient
);
use Data::Dumper; # DEBUG

# ATTRIBUTES:
has auth => (is => 'rw', isa => 'ModelSEED::Auth');
has sapsvr => ( is => 'rw', isa => 'SAPserver', lazy => 1, builder => '_build_sapsvr' );
has kbsvr => ( is => 'rw', isa => 'Bio::KBase::CDMI::Client', lazy => 1, builder => '_build_kbsvr');
has msseedsvr => ( is => 'rw', isa => 'MSSeedSupportClient', lazy => 1, builder => '_build_msseedsvr' );
has om => ( is => 'rw', isa => 'ModelSEED::Store');


# BUILDERS:
sub _build_sapsvr { return SAPserver->new(); }
sub _build_kbsvr { return Bio::KBase::CDMI::Client->new("http://bio-data-1.mcs.anl.gov/services/cdmi_api") };
sub _build_msseedsvr { return MSSeedSupportClient->new(); }


# CONSTANTS:
sub _type { return 'SEEDFactory'; }

# FUNCTIONS:
sub availableGenomes {
    my $self = shift @_;
    my $args = $self->_getArgs(@_);
    my $source = $args->{source};
    my $servers = [qw(sapsvr kbsvr msseedsvr)];
    if(defined($source)) {
        my %sourceMap = qw(
            pubseed sapsvr
            kbase kbsvr
            rast msseedsvr
        );
        die "Unknown Source: $source" unless(defined $sourceMap{lc($source)});
        $servers = [ $sourceMap{lc($source)} ];
    }
    my $data;
    foreach my $server (@$servers) {
        my $hash;
        if($server eq 'sapsvr') {
            $hash = $self->$server->all_genomes({-prokaryotic => 0})
        } elsif($server eq 'kbsvr') {
            $hash = $self->$server->all_entities_Genome(0, 10000000, [qw(scientific_name)]);
            $hash = { map { $_ => $hash->{$_}->{scientific_name} } keys %$hash };
        }
        foreach my $key (keys %$hash) {
            $data->{$key} = $hash->{$key};
        }
    }
    return $data;
}

sub buildMooseAnnotation {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["genome_id"],{
        mapping_uuid => undef,
        mapping      => undef,
        source       => undef,
        verbose      => 0,
	});
	if (!defined($args->{source})) {
		$args->{source} = $self->getGenomeSource($args->{genome_id});	
        print "Genome source is " . $args->{source} . ".\n" if($args->{verbose});
	}
	if (!defined($args->{mapping})) {
		$args->{mapping} = $self->getMappingObject({mapping_uuid => $args->{mapping_uuid}});
	}
    print "Getting genome attributes...\n" if($args->{verbose});
	my $genomeData = $self->getGenomeAttributes($args->{genome_id});
    my $annoationObj = ModelSEED::MS::Annotation->new({
        name => $genomeData->{name}
    });
    my $genomeObj = $annoationObj->add("genomes", {
        id       => $args->{genome_id},
        name     => $genomeData->{name},
        source   => $args->{source},
        taxonomy => $genomeData->{taxonomy},
        size     => $genomeData->{size},
        gc       => $genomeData->{gc},
    });
	$annoationObj->mapping_uuid($args->{mapping}->uuid());
	$annoationObj->mapping($args->{mapping});
	if (!defined($genomeData->{features})) {
		$genomeData->{features} = $self->getGenomeFeatures({
                genome_id => $args->{genome_id},
                source    => $args->{source},
        });
	}
    my $featureCount = scalar(@{$genomeData->{features}});
    print "Mapping $featureCount genome feature to metabolic roles...\n" if($args->{verbose});
	for (my $i=0; $i < @{$genomeData->{features}}; $i++) {
		my $row = $genomeData->{features}->[$i]; 
		if (defined($row->{ID}->[0]) && defined($row->{START}->[0]) && defined($row->{STOP}->[0]) && defined($row->{CONTIG}->[0])) {
			my $featureObj = $annoationObj->add("features",{
				id => $row->{ID}->[0],
				genome_uuid => $genomeObj->uuid(),
				start => $row->{START}->[0],
				stop => $row->{STOP}->[0],
				contig => $row->{CONTIG}->[0]
			});
			if (defined($row->{ROLES}->[0])) {
				for (my $j=0; $j < @{$row->{ROLES}}; $j++) {
					my $roleObj = $self->getRoleObject({mapping => $args->{mapping},roleString => $row->{ROLES}->[$j]});
					my $ftrRoleObj =$featureObj->add("featureroles",{
						feature_uuid => $featureObj->uuid(),
						role_uuid => $roleObj->uuid(),
						compartment => join("|",@{$row->{COMPARTMENT}}),
						comment => $row->{COMMENT}->[0],
						delimiter => $row->{DELIMITER}->[0]
					});
				}
			}
		}
	}
	return $annoationObj;
}

sub buildSerialAnnotation {
	my ($self,$args) = @_;
	my $mooseObj = $self->buildMooseAnnotation();
	return $mooseObj->serializeToDB();
}
				
# FUNCTIONS:
sub getRoleObject {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["roleString","mapping"],{});					
	my $searchName = ModelSEED::MS::Utilities::GlobalFunctions::convertRoleToSearchRole($args->{roleString});
	my $roleObj = $args->{mapping}->queryObject("roles",{searchname => $searchName});
	if (!defined($roleObj)) {
		$roleObj = $args->{mapping}->add("roles",{
			name => $args->{roleString},
		});
	}
	return $roleObj;
}

sub getMappingObject {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		mapping_uuid => undef
	});
	my $mappingObj;
	if (defined($args->{mapping_uuid})) {
		$mappingObj = $self->om()->get("Mapping",$args->{mapping_uuid});
		if (!defined($mappingObj)) {
			ModelSEED::utilities::ERROR("Mapping with uuid ".$args->{mapping_uuid}." not found in database!");
		}
	} else {
		$mappingObj = $self->om()->add("mappings",{name=>"Test"});
	}
	return $mappingObj;
}

sub getGenomeSource {
	my ($self,$id) = @_;
    my $result;
	$result = $self->sapsvr->exists({-type => 'Genome', -ids => [$id]});
	if (defined $result->{$id} && $result->{$id} eq 1) {
		return "PUBSEED";
	}
    $result = $self->kbsvr->get_entity_Genome([$id], []);
    if(defined($result->{$id})) {
        return "KBase";
    }
	$result = $self->mssvr->genomeType({ids => [$id]});
	return $result->{$id};
}

sub getGenomeFeatures {
	my ($self, $id, $source) = @_;
    $source = $self->getGenomeSource($id) unless defined $source;
	my $features;
	if ($source eq "PUBSEED") {
		my $featureHash = $self->sapsvr->all_features({-ids => $id});
		if (!defined($featureHash->{$id})) {
			die "Could not load features for pubseed genome: $id";
		}
		my $featureList = $featureHash->{$id};
		my $functions = $self->sapsvr()->ids_to_functions({-ids => $featureList});
		my $locations = $self->sapsvr()->fid_locations({-ids => $featureList});
		#my $aliases = $self->sapsvr()->fids_to_ids({-ids => $featureList,-protein => 1});
		my $sequences;
		for (my $i=0; $i < @{$featureList}; $i++) {
			my $row = {ID => [$featureList->[$i]],TYPE => ["peg"]};
			if ($featureList->[$i] =~ m/\d+\.\d+\.([^\.]+)\.\d+$/) {
				$row->{TYPE}->[0] = $1;
			}
			if (defined($locations->{$featureList->[$i]}->[0]) && $locations->{$featureList->[$i]}->[0] =~ m/^(.+)_(\d+)([\+\-])(\d+)$/) {
				my $array = [split(/:/,$1)];
				$row->{CONTIG}->[0] = $array->[1];
				if ($3 eq "-") {
					$row->{START}->[0] = ($2-$4);
					$row->{STOP}->[0] = ($2);
					$row->{DIRECTION}->[0] = "rev";
				} else {
					$row->{START}->[0] = ($2);
					$row->{STOP}->[0] = ($2+$4);
					$row->{DIRECTION}->[0] = "for";
				}
			}
			if (defined($functions->{$featureList->[$i]})) {
				my $output = ModelSEED::MS::Utilities::GlobalFunctions::functionToRoles($functions->{$featureList->[$i]});
				$row->{COMPARTMENT} = $output->{compartments};
				$row->{COMMENT}->[0] = $output->{comment};
				$row->{DELIMITER}->[0] = $output->{delimiter};
				$row->{ROLES} = $output->{roles};
			}
			if (defined($sequences->{$featureList->[$i]})) {
				$row->{SEQUENCE}->[0] = $sequences->{$featureList->[$i]};
			}
			push(@{$features},$row);			
		}
	} elsif($source eq "KBase") {
        my $contigs  = $self->kbsvr->get_relationship_IsComposedOf([$id], [], [], [qw(id)]);
        $contigs = [ map { $_->[2]->{id} } @$contigs ]; # extract contig ids
        my $features = $self->kbsvr->get_relationship_IsLocusFor(
            $contigs, [qw(id)],
            [qw(begin dir len ordinal)],
            [qw(id feature_type function source_id alias)]
        );
        map {
            $_ = {
                ID => $_->[2]->{id},
                TYPE => $_->[2]->{feature_type},
                CONTIG => $_->[0]->{id},
                START => $_->[1]->{begin},
                STOP => $_->[1]->{begin} + $_->[1]->{len},
                DIRECTION => ($_->[1]->{dir} eq "+") ? "for" : "rev",
            };
        } @$features; # reformat features
        my $feature_ids = [ map { $_->{ID} } @$features ];
        my $functions = $self->kbsvr->get_relationship_HasFunctional(
            $feature_ids, [qw(id)], [], [qw(id)],
        ); # get feature roles
        # generate map from features to functions
        my $feature_to_functions = {};
        foreach my $entry (@$functions) {
            my $feature = $entry->[0]->{id};
            my $function = $entry->[2]->{id};
            if(!defined($feature_to_functions->{$feature})) {
                $feature_to_functions->{$feature} = [];
            }
            push(@{$feature_to_functions->{$feature}}, $function);
        }
        # add functions to each feature
        foreach my $feature (@$features) {
            my $id = $feature->{ID};
            if(defined($feature_to_functions->{$id})) {
                my $function = $feature_to_functions->{$id};
                push(@{$feature->{ROLES}}, $function);
            }
        }
    } elsif(defined($self->auth) && $self->auth->isa("ModelSEED::Auth::Basic")) {
        my $output = $self->msseedsvr()->genomeData(
            {
                ids      => [ $id ],
                username => $self->auth->username,
                password => $self->auth->password,
            }
        );
		if (!defined($output->{features})) {
			die "Could not load data for rast genome: $id";
		}
		for (my $i=0; $i < $output->{features}; $i++) {
			my $ftr = $output->{features}->[$i];
			my $row = {ID => [$ftr->{ID}->[0]],TYPE => "peg"};
			if ($ftr->{ID}->[0] =~ m/\d+\.\d+\.([^\.]+)\.\d+$/) {
				$row->{TYPE}->[0] = $1;
			}
			if (defined($ftr->{LOCATION}->[0]) && $ftr->{LOCATION}->[0] =~ m/^(.+)_(\d+)([\+\-])(\d+)$/) {
				my $array = [split(/:/,$1)];
				$row->{CONTIG}->[0] = $array->[1];
				if ($3 eq "-") {
					$row->{START}->[0] = ($2-$4);
					$row->{STOP}->[0] = ($2);
					$row->{DIRECTION}->[0] = "rev";
				} else {
					$row->{START}->[0] = ($2);
					$row->{STOP}->[0] = ($2+$4);
					$row->{DIRECTION}->[0] = "for";
				}
			}
			if (defined($ftr->{FUNCTION}->[0])) {
				my $output = ModelSEED::MS::Utilities::GlobalFunctions::functionToRoles($ftr->{FUNCTION}->[0]);
				$row->{COMPARTMENT}->[0] = $output->{compartments};
				$row->{COMMENT}->[0] = $output->{comment};
				$row->{DELIMITER}->[0] = $output->{delimiter};
				$row->{ROLES} = $output->{roles};
			}
			if (defined($ftr->{SEQUENCE}->[0])) {
				$row->{SEQUENCE}->[0] = $ftr->{SEQUENCE}->[0];
			}
			push(@{$features},$row);
		}
	}
	return $features;
}

sub getGenomeAttributes {
	my ($self,$id, $source) = @_;
    my ($data, $attributes);
    $source = $self->getGenomeSource($id) unless defined $source;
    if( $source eq 'PUBSEED') {
        $data = $self->sapsvr()->genome_data({
            -ids => [$id],
            -data => [qw(gc-content dna-size name taxonomy)]
        });
        if(defined($data->{$id})) {
            $attributes = {
                name => $data->{$id}->[2],
                taxonomy => $data->{$id}->[3],
                size => $data->{$id}->[1],
                gc => $data->{$id}->[0],
            };
        }
    } elsif($source eq "KBase") {
        $data = $self->kbsvr->get_entity_Genome([$id],
            [qw(scientific_name source_id dna_size gc_content)]
        );
        if(defined($data->{$id})) {
            $attributes = {
                name     => $data->{$id}->{scientific_name},
                taxonomy => $data->{$id}->{source_id},
                size     => $data->{$id}->{dna_size},
                gc       => $data->{$id}->{gc_content},
            };
        }
    } elsif(defined($self->auth) && $self->auth->isa("ModelSEED::Auth::Basic")) {
        $data = $self->msseedsvr->genomeData({
            ids      => [ $id ],
            username => $self->auth->username,
            password => $self->auth->password,
        });
        $attributes = $data;
    }
    return $attributes;
}

# _getArgs : @_ -> \%
# Convert ARGS to Hash
# Either $_[0] == \%
# or @_ casts to \%
# or \% := {}
sub _getArgs {
    my $self = shift @_;
    if(ref($_[0]) eq 'HASH') {
        return $_[0];
    } elsif(scalar(@_) % 2 == 0) {
        my %hash = @_;
        return \%hash;
    } else {
        return {};
    }
}

__PACKAGE__->meta->make_immutable;
