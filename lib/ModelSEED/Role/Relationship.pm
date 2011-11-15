package ModelSEED::Role::Relationship;

use Moose::Role;
use Moose::Role::Parameterized;

parameter role_type => (
    isa => 'Str',
    required => 1,
); 

parameter object_type => (
    isa => 'Str',
    required => 1,
);

parameter object_name => (
    isa => 'Str',
);

paraemeter relationship => )
    isa => 'Str',
    required => 1,
);

role {

    my $p = shift;
    my $objName;
    if(defined($p->object_name)) {
        $objName = $p->object_name;
    } else { 
        $objName = $p->object_type;
        $objName =~ s/ModelSEED:://;
        $objName = lc($objName);
    }
    my $objType = $p->object_type;
    if($p->relationship eq 'many to many' ||
       $p->relatiohship eq 'one to many') {
        $objType = 'ArrayRef[' . $objType . ']';
    }
    has $objName => ( is => 'rw', isa => $objType );
        

};
