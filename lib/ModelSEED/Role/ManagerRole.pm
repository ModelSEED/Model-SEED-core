package ModelSEED::Role::ManagerRole;
use MooseX::Role::Parameterized;
use Try::Tiny;
use Data::Dumper;

parameter types => (isa => 'ArrayRef', required => 1);

role {
    my $p = shift;
    foreach my $type (@{$p->types}) {
        # attempt to convert names correctly
        $type =~ s/ModelSEED:://;
        $type =~ s/DB:://;
        my $name = $type;
        my $Rtype = "ModelSEED::DB::$type"."::Manager";
        my $Rtype_base = "ModelSEED::DB::$type";
        my $Mtype = "ModelSEED::$type";
        # require package names
        my $Rpkg = $Rtype;
        $Rpkg =~ s/::/\//g;
        $Rpkg .= ".pm";
        my $Mpkg = $Mtype;
        $Mpkg =~ s/::/\//g;
        $Mpkg .= ".pm";
        my $Rpkg_base = $Rtype_base;
        $Rpkg_base =~ s/::/\//g;
        $Rpkg_base .= ".pm";
        try {
            require $Rpkg; 
            require $Mpkg;
            require $Rpkg_base;
        } catch {
            die("Role::ManagerRole died on $type : $_");
        };
        # now create functions
        my $get = _get_objects_wrapper($name, $Rtype, $Mtype);
        method "get_".lc($name)."s" => $get;
        my $itr = _get_objects_iterator_wrapper($name, $Rtype, $Mtype);
        method "get_".lc($name)."s_iterator" => $itr;
        my $cnt = _other_wrappers($name, $Rtype, "get_objects_count");
        method "get_".lc($name)."s_count" => $cnt;
        my $up = _other_wrappers($name, $Rtype, "update_objects");
        method "update_".lc($name)."s" => $up;
        my $del = _other_wrappers($name, $Rtype, "delete_objects");
        method "delete_".lc($name)."s" => $del;
    }
};

sub _get_objects_wrapper {
    my ($type, $Rpkg, $Mpkg) = @_;    
    my $func = sub {
        my $self = shift;
        my $Robjs = $Rpkg->get_objects(@_, object_class => $type);
        my $Mobjs = [];
        foreach my $obj (@$Robjs) {
           push(@$Mobjs, $Mpkg->new($obj));
        }
        return $Mobjs;
    }; 
    return $func;
}

sub _get_objects_iterator_wrapper {
    my ($type, $Rpkg, $Mpkg) = @_;
    my $func = sub {
        my $Ritr = $Rpkg->get_objects_iterator(@_, object_class => $type);
        return ModelSEED::Role::Iterator->new(
            { _rdbio => $Ritr, _moose_class => $Mpkg});
    };
    return $func;
}

# get_objects_count, update_objects and delete_objects all
# have the same interface
sub _other_wrappers {
    my ($type, $Rpkg, $cmd) = @_;
    my $func = sub {
        return $Rpkg->$cmd(@_, object_clsss => $type);
    };
    return $func;
}

1;
