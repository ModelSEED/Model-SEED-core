package ModelSEED::Compound;

use Moose;
use Data::UUID;
use ModelSEED::Role::DBObject;

with 'ModelSEED::Role::DBObject';
with 'ModelSEED::Role::UUID';

has 'modDate' => (is => 'rw', isa => 'DateTime', lazy => 1, builder => '_buildModDate');
has 'id' => ( is => 'rw', isa => 'Str');
has 'name' => (is => 'rw', isa => 'Str|Undef');
has 'abbreviation' => ( is => 'rw', isa => 'Str|Undef');
has 'md5' => ( is => 'rw', isa => 'Str|Undef');
has 'unchargedFormula' => ( is => 'rw', isa => 'Str|Undef');
has 'formula' => ( is => 'rw', isa => 'Str|Undef');
has 'mass' => ( is => 'rw', isa => 'Num|Undef');
has 'defaultCharge' => ( is => 'rw', isa => 'Num|Undef');

sub _buildModDate {
    return DateTime->now;
}

1;
