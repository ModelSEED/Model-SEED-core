########################################################################
# ModelSEED::MS::DB::FBAObjectiveTerm - This is the moose object corresponding to the FBAObjectiveTerm object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-24T02:58:25
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::FBAObjectiveTerm;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Modelfba|FBASolution', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has coefficient => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has variableType => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has uuid => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has compartment_uuid => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }


# CONSTANTS:
sub _type { return 'FBAObjectiveTerm'; }


__PACKAGE__->meta->make_immutable;
1;
