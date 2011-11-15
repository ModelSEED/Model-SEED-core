package ModelSEED::Biochemistry;

use Moose;

with 'ModelSEED::Role::DBObject';
with 'ModelSEED::Role::UUID';
with 'ModelSEED::Role::Owned';
with 'ModelSEED::Role::Versioned';
with 'ModelSEED::Role::ModDate';

has name => ( is => 'rw', isa => 'Str|Undef' );
