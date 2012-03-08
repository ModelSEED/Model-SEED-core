########################################################################
# ModelSEED::MooseDB::media - This is the moose object corresponding to the ModelReaction object in the database
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 11/6/2011
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::MS::BiomassCompound;
use ModelSEED::MS::Model;
package ModelSEED::MS::Biomass;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Digest::MD5 qw(md5_hex);

#Parent object link
has model => (is => 'rw',isa => 'ModelSEED::MS::Model',weak_ref => 1);

#Attributes
has id     => (is => 'rw', isa => 'Str', required => 1);
has uuid     => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildUUID');
has modDate     => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildModDate');
has locked    => (is => 'rw', isa => 'Int', default => 0);
has name   => (is => 'rw', isa => 'Str', default => '');

#Subobjects
has biomass_compounds => (
    is      => 'rw',
    isa     => 'ArrayRef|ArrayRef[ModelSEED::MS::BiomassCompound]',
    default => sub { [] }
);

#Computed attributes
has equation => (is => 'rw',isa => 'Str',lazy => 1,builder => '_buildEquation');

#Constants
has 'dbAttributes' => ( is => 'ro', isa => 'ArrayRef[Str]', 
    builder => '_buildDbAttributes' );
has '_type' => (is => 'ro', isa => 'Str',default => "Biomass");

sub BUILDARGS {
    my ($self,$params) = @_;
    my $attr = $params->{attributes};
    my $rels = $params->{relationships};
    # Set up attributes
    if(defined($attr)) {
        map { $params->{$_} = $attr->{$_} } grep { defined($attr->{$_}) } keys %$attr;
        delete $params->{attributes};
    }
    return $params;
}

sub BUILD {
    my ($self, $params) = @_;
    my $rels = $params->{relationships};
    if(defined($rels)) {
		my $subObjects = {
			compounds => ["biomass_compounds","ModelSEED::MS::BiomassCompound"]
		};
        my $order = ["compounds"];
        foreach my $name (@$order) {
            if (defined($rels->{$name})) {
	            my $values = $rels->{$name};
	            my $function = $subObjects->{$name}->[0];
	            my $class = $subObjects->{$name}->[1];
	            my $objects = [];
            	foreach my $data (@$values) {
	                $data->{model} = $self->model();
	                push(@$objects, $class->new($data));
	            }
	            $self->$function($objects);
            }
		}
        delete $params->{relationships}
    }
}

sub serializeToDB {
    my ($self) = @_;
	my $data = {};
	my $attributes = $self->dbAttributes();
	for (my $i=0; $i < @{$attributes}; $i++) {
		my $function = $attributes->[$i];
		$data->{attributes}->{$function} = $self->$function();
	}
	return $data;
}

sub _buildEquation {
	my $equation = "NONE";
	return $equation;
}

sub _buildDbAttributes { return [qw( uuid  id name modDate locked)]; }

__PACKAGE__->meta->make_immutable;
1;
