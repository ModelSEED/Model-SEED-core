package ModelSEED::Role::ManagerRole;
use MooseX::Role::Parameterized;
use Try::Tiny;
use Data::Dumper;

parameter types => (isa => 'ArrayRef', required => 1);

requires '_managers';
role {
    my $p = shift;
    my $self = shift;
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
        my $managerObj = {
            get_objects => _get_objects_wrapper($Rtype_base, $Rtype, $Mtype),
            get_objects_iterator => _get_objects_iterator_wrapper($Rtype_base, $Rtype, $Mtype),
            get_objects_count => _other_wrappers($Rtype_base, $Rtype, "get_objects_count"),
            update_objects => _other_wrappers($Rtype_base, $Rtype, "update_objects"),
            delete_objects => _other_wrappers($Rtype_base, $Rtype, "delete_objects"),
        };
        my $tableName = $Rpkg_base->table;
        $self->_managers->{$tableName} = $managerObj;
=cut
        my $create = _create_object($name, $Mtype);
        method "create_".lc($name) => $create;
        my $get = _get_objects_wrapper($Rtype_base, $Rtype, $Mtype);
        method "get_".lc($name) => $get;
        my $itr = _get_objects_iterator_wrapper($Rtype_base, $Rtype, $Mtype);
        method "get_".lc($name)."_iterator" => $itr;
        my $cnt = _other_wrappers($Rtype_base, $Rtype, "get_objects_count");
        method "get_".lc($name)."_count" => $cnt;
        my $up = _other_wrappers($Rtype_base, $Rtype, "update_objects");
        method "update_".lc($name) => $up;
        my $del = _other_wrappers($Rtype_base, $Rtype, "delete_objects");
        method "delete_".lc($name) => $del;
=cut
    }
};

sub _addDBObjectUnlessDefined {
    my $self = shift;
    # if we're getting a hash that does not contain the "db" key
    if(ref($_[0]) eq 'HASH' && !defined($_[0]->{db})) {
        $_[0]->{db} = $self->db;
    } elsif (ref($_[0]) ne 'HASH' && 0 == grep(/^db/, @_)) {
        # if we get an array that doesn't contain "db"
        push(@_, ( 'db', $self->db ));
    }
    return @_;
}

# Basic query syntax is:
# get_type({ key => 'value' })
# we convert this into:
# get_type({query => [ key => value ]})
sub _handleBasicQuerySyntax {
    my $self = shift;
    if(ref($_[0]) eq 'HASH' && !defined($_[0]->{query})) {
        return { query => $_[0] };
    } else {
        return @_; 
    }
}

sub _create_object {
    my ($type, $Mpkg) = @_;
    my $func = sub {
        my $self = shift;
        @_ = $self->_addDBObjectUnlessDefined(@_);
        return $Mpkg->new(@_);
    };
    return $func;
}
    

sub _get_objects_wrapper {
    my ($type, $Rpkg, $Mpkg) = @_;    
    my $func = sub {
        my $self = shift;
        @_ = $self->_handleBasicQuerySyntax(@_);
        @_ = $self->_addDBObjectUnlessDefined(@_);
        my $Robjs = $Rpkg->get_objects(@_, object_class => $type, db => $self->db);
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
        my $self = shift;
        @_ = $self->_handleBasicQuerySyntax(@_);
        @_ = $self->_addDBObjectUnlessDefined(@_);
        my $Ritr = $Rpkg->get_objects_iterator(@_, object_class => $type, db => $self->db);
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
        my $self = shift;
        @_ = $self->_handleBasicQuerySyntax(@_);
        @_ = $self->_addDBObjectUnlessDefined(@_);
        return $Rpkg->$cmd(@_, object_clsss => $type, db => $self->db);
    };
    return $func;
}

1;
