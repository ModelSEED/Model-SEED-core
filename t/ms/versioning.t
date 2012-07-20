# Tests for versioning on MS::BaseObject
package Point; # Basic object with version, __version__
use Moose;
extends 'ModelSEED::MS::BaseObject';
our $VERSION = 1.0;
sub _subobjects { return []; }
sub _attributes {
    my $a = [
        { name => 'y', perm => 'ro', type => 'Int', req => 1 },
        { name => 'x', perm => 'ro', type => 'Int', req => 1 },
    ];
    return (defined $_[1]) ? grep { $_->{name} eq $_[1] } @$a : $a;
}
has [qw(x y)] => ( is => 'ro', isa => 'Int', required => 1);
sub __version__ { $VERSION }
1;
package Point3; # Add additional attribute 'z'
use Moose;
extends 'ModelSEED::MS::BaseObject';
our $VERSION = 1.1;
sub _subobjects { return []; }
sub _attributes {
    my $a = [
        { name => 'y', perm => 'ro', type => 'Int', req => 1 },
        { name => 'x', perm => 'ro', type => 'Int', req => 1 },
        { name => 'z', perm => 'ro', type => 'Int', req => 1 },
    ];
    return (defined $_[1]) ? grep { $_->{name} eq $_[1] } @$a : $a;
}
has [qw(x y z)] => ( is => 'ro', isa => 'Int', required => 1);
# __upgrade__ function accepts version number
# returns a function: \% -> \% that converts old version to current
sub __version__ { $VERSION }
sub __upgrade__ { 
    my ($self, $version) = @_;
    my $routines = {
        1.0 => sub { $_[0]->{z} = 0; $_[0] },
    };
    my ($v) = grep { $version == $_ } keys %$routines;
    return $routines->{$v} if defined $v;
}
1;
package B; # Simple class with no version
use Moose;
extends 'ModelSEED::MS::BaseObject';
has a => ( is => 'ro', isa => 'str', required => 1 );
1;
use Test::More;
use Test::Exception;
my $testCount = 0;
{
    # Test object construction
    my $point = Point->new(x => 1, y => 1);
    ok defined $point, "Create object with hash";
    $point = Point->new({x => 1, y => 2});
    ok defined $point, "Create object with hashref";

    # Test VERSION functions
    ok $point->VERSION(), "has VERSION function";
    is $point->VERSION, $Point::VERSION, "version is correct";

    # Test serailize 
    my $serial = $point->serializeToDB();
    is $serial->{__VERSION__}, $point->VERSION, "Version should exist an be correct";
    $testCount += 5;

    # Test upgrade with good previous version
    isnt $Point::VERSION, $Point3::VERSION, "different versions";
    my $point3 = Point3->new($serial);
    ok defined $point3, "Should create new object";
    ok defined $point3->z, "With z attribute";
    is $point3->VERSION, $Point3::VERSION, "version is correct";
    $testCount += 4;

    # Test upgrade with bad previous version
    $serial->{__VERSION__} = 0.9;
    dies_ok { Point3->new($serial) } "Dies on bad version";
    $testCount += 1;
}
done_testing($testCount);
