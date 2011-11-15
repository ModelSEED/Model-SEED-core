package ModelSEED::Media;
use Moose;

use ModelSEED::Role::DBObject;
use ModelSEED::DB::Media;

with 'ModelSEED::Role::DBObject';
with 'ModelSEED::Role::UUID';

has 'modDate' => (is => 'rw', isa => 'DateTime', lazy => 1, builder => '_buildModDate');
has 'id'  => (is => 'rw', isa => 'Str|Undef');
has 'name' => (is => 'rw', isa => 'Str|Undef');
has 'type' => (is => 'rw', isa => 'Str|Undef');

# Need role for linking to many to many, one to many, many to one, one to one
# has_many 'compounds' => ( table => 'media_compound', ... )
# ... results in
# has compounds => ( is => 'rw', isa => 'ArrayRef[ModelSEED::MediaCompound]', lazy => 1, ...
# sub add_compound {}
# sub remove_compound {}
# save() 


#has 'compounds' => (is => 'rw', isa => 'ArrayRef[ModelSEED::MediaCompound]', lazy => 1,
#    builder => '_buildMediaCompound');

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
