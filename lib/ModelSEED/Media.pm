package ModelSEED::Media;
use Moose;

use ModelSEED::Role::DBObject;
use ModelSEED::DB::Media;
use ModelSEED::Role::Relationship;


with (
    'ModelSEED::Role::DBObject',
    'ModelSEED::Role::UUID',
    'ModelSEED::Role::ModDate',
    'ModelSEED::Role::Relationship' => {
    role_type => 'one to many',
    object_type => 'ModelSEED::MediaCompound',
    object_name => 'compounds',
    },
);

has 'id'  => (is => 'rw', isa => 'Str|Undef');
has 'name' => (is => 'rw', isa => 'Str|Undef');
has 'type' => (is => 'rw', isa => 'Str|Undef');

sub _buildMediaCompound {
    my ($self) = @_;
    my $roseObjs = $self->_rdbo->media_compound;
    my $mooseObjs = [];
    foreach my $obj (@$roseObjs) {
        push(@$mooseObjs, ModelSEED::MediaCompound($obj));
    }
    return $mooseObjs;
}
    
        

sub _buildModDate {
    return DateTime->now;
}

sub _buildDate {
    return time();
}

1;
