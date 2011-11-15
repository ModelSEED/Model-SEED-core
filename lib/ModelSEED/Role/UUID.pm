package ModelSEED::Role::UUID;
use Moose::Role;
use Data::UUID;
use Try::Tiny;
use Data::Dumper;

has 'uuid' => (is => 'rw', isa => 'Str', lazy => 1, builder => '_buildUUID');

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift; 
    if (@_ == 1 && !ref($_[0])) {
        my $ug = Data::UUID->new();
        my $uuid;
        $uuid = $ug->from_string($_[0]);
        if(defined($uuid)) {
            return $class->$orig({uuid => $_[0]});
        } else {
            return $class->$orig(@_);
        }
    } else {
        return $class->$orig(@_);
    }
};

sub _buildUUID {
    my ($self) = @_;
    my $ug = Data::UUID->new();
    return $ug->create_str();
}

1;
