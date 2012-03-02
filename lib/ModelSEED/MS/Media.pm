########################################################################
# ModelSEED::MooseDB::media - This is the moose object corresponding to the media object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/6/2011
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::MS::MediaCompound;
package ModelSEED::MS::Media;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use DateTime;
use Data::UUID;

#Attributes

has uuid    => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildUUID');
has modDate => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildModDate');
has id      => (is => 'rw', isa => 'Str', default => '');
has locked  => (is => 'rw', isa => 'Int', default => 0);
has name    => (is => 'rw', isa => 'Str', default => '');
has type    => (is => 'rw', isa => 'Str', default => '');

#Subobjects
has media_compounds => (
    is      => 'rw',
    isa     => 'ArrayRef|ArrayRef[ModelSEED::MS::MediaCompound]',
    default => sub { [] }
);

#Constants
has 'dbAttributes' => (
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    builder => '_buildDbAttributes'
);
has 'dbType' => (is => 'ro', isa => 'Str', default => "Media");

#Internally maintained variables
has 'changed' => (is => 'rw', isa => 'Bool', default => 0);

sub BUILDARGS {
    my ($self, $params) = @_;
    if (defined($params->{file})) {
    	$params = $self->parseTextFile($params);
    }
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    my $bio  = $params->{biochemistry};
    delete $params->{biochemistry};
    if (defined($attr)) {
        map { $params->{$_} = $attr->{$_} }
            grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
    if (defined($rels)) {
        foreach my $media_compound (@{$rels->{media_compounds}}) {
            $media_compound->{biochemistry} = $bio if (defined($bio));
            push(
                @{$params->{media_compounds}},
                ModelSEED::MS::MediaCompound->new($media_compound)
            );
        }
        delete $params->{relationships};
    }
    return $params;
}

sub minFluxes {
    return [map { $_->minflux } @{$_[0]->media_compounds}];
}

sub maxFluxes {
    return [map { $_->maxflux } @{$_[0]->media_compounds}];
}

sub compounds {
    return [map { $_->compound } @{$_[0]->media_compounds}];
}

sub compound_uuids {
    return [map { $_->compound_uuid } @{$_[0]->media_compounds}];
}

sub concentrations {
    return [map { $_->concentration } @{$_[0]->media_compounds}];
}

sub serializeToDB {
    my ($self,$params) = @_;
	$params = ModelSEED::utilities::ARGS($params,[],{});
	my $data = {};
	my $attributes = $self->dbAttributes();
	for (my $i=0; $i < @{$attributes}; $i++) {
		my $function = $attributes->[$i];
		$data->{attributes}->{$function} = $self->$function();
	}
	$data->{relationships}->{media_compounds} = [];
    foreach my $mediaCpd (@{$self->media_compounds}) {
		push(@{$data->{relationships}->{media_compounds}}, $mediaCpd->serializeToDB());
	}	
	return $data;
}

sub _buildDbAttributes {
    return [qw( uuid modDate locked id name type )];
}

sub parseTextFile {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["file"],{});
	if (-e $args->{file}) {
		$args->{file} = ModelSEED::utilities::LOAD($args->{file});
	}
	my $data;
	my $acceptedAttributes = {
		id => 1,name => 1,type => 1
	};
	my $translation = {
		"ID" => "compound_id",
		"Concentration"  => "concentration",
		"Min flux"  => "minflux",
		"Max flux"  => "maxflux"
	};
	my $section = "none";
	my $headings;
	for (my $i=0; $i < @{$args->{file}}; $i++) {
		if ($args->{file}->[$i] =~ m/^Attributes\{/) {
			$section = "attributes";	
		} elsif ($args->{file}->[$i] =~ m/^\}/) {
			$section = "none";
		} elsif ($args->{file}->[$i] =~ m/^Compounds\{/) {
			$section = "compounds";
			$headings = [split(/\t/,$args->{file}->[$i+1])];
			$i++;
		} elsif ($section eq "attributes") {
			my $array = [split(/\t/,$args->{file}->[$i])];
			if (defined($acceptedAttributes->{$array->[0]})) {
				$data->{attributes}->{$array->[0]} = $array->[1];
			}
		} elsif ($section eq "compounds") {
			my $cpdData = {
				attributes => {media_id = $data->{attributes}->{id}},
				relationships => []
			};
			my $array = [split(/\t/,$args->{file}->[$i])];
			for (my $j=0; $j < @{$array}; $j++) {
				$cpdData->{attributes}->{$translation->{$headings->[$j]}} = $array->{$j};
			}
			push(@{$data->{relationships}},$cpdData);
		}
	}
	return $data;
}

sub printToFile {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{filename => undef});
	my $data = [
		"Attributes{",
		"id\t".$self->id(),
		"name\t".$self->name(),
		"type\t".$self->type(),
		"}",
		"Compounds{",
		"Compound ID\tConcentration\tMin flux\tMax flux"
	];
	my $compounds = $self->compounds();
	for (my $i=0; $i < @{$compounds}; $i++) {
		push(@{$data},$compounds->[$i]->id()."\t".$compounds->[$i]->concentration()."\t".$compounds->[$i]->minflux()."\t".$compounds->[$i]->maxflux());
	}
	push(@{$data},"}");
	if (defined($args->{filename})) {
		ModelSEED::utilities::PRINTFILE($args->{filename},$data);
	}
	return $data;
}

sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }

__PACKAGE__->meta->make_immutable;
1;
