########################################################################
# ModelSEED::MS::Compoundset - This is the moose object corresponding to the Compoundset object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-14T07:56:20
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::Compound
package ModelSEED::MS::Compoundset
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::Biochemistry',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', default => '0' );
has id => ( is => 'rw', isa => 'Str', required => 1 );
has name => ( is => 'rw', isa => 'Str', default => '' );
has searchname => ( is => 'rw', isa => 'Str', default => '' );
has class => ( is => 'rw', isa => 'Str', default => 'unclassified' );
has type => ( is => 'rw', isa => 'Str', required => 1 );


# SUBOBJECTS:
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Compound]');


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Compoundset'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
