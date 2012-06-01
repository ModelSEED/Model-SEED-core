########################################################################
# ModelSEED::MS::BaseObject - This is a base object that serves as a foundation for all other objects
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/11/2012
########################################################################
use ModelSEED::MS::Metadata::Types;
use DateTime;
use Data::UUID;
use JSON::Any;
use Module::Load;
use Carp qw(confess);

package ModelSEED::Meta::Attribute::Typed;
use Moose;
use namespace::autoclean;
extends 'Moose::Meta::Attribute';

has type => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_type',
);

package Moose::Meta::Attribute::Custom::Typed;
sub register_implementation { 'ModelSEED::Meta::Attribute::Typed' }

package ModelSEED::MS::BaseObject;
use Moose;
use namespace::autoclean;

sub BUILD {
    my ($self,$params) = @_;

    # replace subobject data with info hash
    foreach my $subobj (@{$self->_subobjects}) {
        my $name = $subobj->{name};
        my $class = $subobj->{class};
        my $method = "_$name";
        my $subobjs = $self->$method();

        for (my $i=0; $i<scalar @$subobjs; $i++) {
            my $data = $subobjs->[$i];

            # create the info hash
            my $info = {
                created => 0,
                class   => $class,
                data    => $data
            };

            $data->{parent} = $self; # set the parent
            $subobjs->[$i] = $info; # reset the subobject with info hash
        }
    }
}

sub serializeToDB {
    my ($self) = @_;
    my $data = {};
    my $class = 'ModelSEED::MS::DB::'.$self->_type();
    for my $attr ( $class->meta->get_all_attributes ) {
        if ($attr->isa('ModelSEED::Meta::Attribute::Typed')) {
            my $name = $attr->name();
            if ($attr->type() eq "attribute") {
                if (defined($self->$name())) {
                    $data->{$name} = $self->$name();
                }
            } elsif ($attr->type() =~ m/child\((.+)\)/ || $attr->type() =~ m/encompassed\((.+)\)/ ) {
                my $arrayRef = $self->$name();
                foreach my $subobject (@{$arrayRef}) {
                    push(@{$data->{$name}},$subobject->serializeToDB());
                }
            } elsif ($attr->type() =~ m/hasharray\((.+)\)/) {
                my $hashRef = $self->$name();
                foreach my $key (keys(%{$hashRef})) {
                    foreach my $obj (@{$hashRef->{$key}}) {
                        push(@{$data->{$name}},$obj->serializeToDB());
                    }
                }
            }
        }
    }
    return $data;
}

sub printJSONFile {
    my ($self,$filename) = @_;
    my $data = $self->serializeToDB();
    my $jsonData = JSON::Any->encode($data);
    ModelSEED::utilities::PRINTFILE($filename,[$jsonData]);
}

######################################################################
#Alias functions
######################################################################
sub getAlias {
    my ($self,$set) = @_;
    my $aliases = $self->getAliases($set);
    if (defined($aliases->[0])) {
        return $aliases->[0];
    }
    print "No alias of type ".$set."!\n";
    return $self->uuid();
}

sub getAliases {
    my ($self,$aliasSet) = @_;
    if (!defined($aliasSet)) {
        ModelSEED::utilities::ERROR("The 'getAliases' function requires a 'set' as input!");
    }
    my $aliasowner = lc($self->_aliasowner());
    my $owner = $self->$aliasowner();
    my $aliasSetClass = $self->_type()."AliasSet";
    my $aliasset = $owner->getObject($aliasSetClass,{type => $aliasSet});
    if (!defined($aliasset)) {
        print "Alias set ".$aliasset." not found!\n";
        return [];
    }
    my $aliasObjects = $aliasset->getObjects($self->_type()."Alias",{lc($self->_type())."_uuid" => $self->uuid()});
    my $aliases = [];
    for (my $i=0; $i < @{$aliasObjects}; $i++) {
        push(@{$aliases},$aliasObjects->[$i]->alias());
    }
    return $aliases;
}

sub _buildid {
    my ($self) = @_;
    my $aliasSetClass = $self->_type()."AliasSet";
    my $set = $self->objectmanager()->getSelectedAliases($aliasSetClass);
    if (!defined($set)) {
        return $self->uuid();
    }
    return $self->getAlias($set);
}

######################################################################
#Output functions
######################################################################
sub createReadableFormat {
    my ($self) = @_;
    my $output = ["Attributes{"];
    my $class = 'ModelSEED::MS::DB::'.$self->_type();
    my $blacklist = {
        modDate => 1,
        locked => 1,
        cksum => 1
    };
    my $line = "";
    foreach my $attr ( $class->meta->get_all_attributes ) {
        if ($attr->isa('ModelSEED::Meta::Attribute::Typed') && $attr->type() eq "attribute" && !defined($blacklist->{$attr->name()})) {
            my $name = $attr->name();
            if (length($line) == 0) {
                $line .= "\t";  
            }
            $line .= $self->$name();
        }
    }
    foreach my $attr ( $class->meta->get_all_attributes ) {
        if ($attr->isa('ModelSEED::Meta::Attribute::Typed')) {
            if ($attr->type() =~ m/child\((.+)\)/ || $attr->type() =~ m/encompassed\((.+)\)/ ) {
                my $name = $attr->name();
                push(@{$output},$name."(){");
                my $objects = $self->$name();
                foreach my $object ($objects) {
                    push(@{$output},$object->createReadableLine());
                }
                push(@{$output},"}");
            }
        }
    }
    return $output;
}

sub createReadableLine {
    my ($self) = @_;
    my $output = ["Attributes{"];
    my $class = 'ModelSEED::MS::DB::'.$self->_type();
    foreach my $attr ( $class->meta->get_all_attributes ) {
        if ($attr->isa('ModelSEED::Meta::Attribute::Typed' && $attr->type() eq "attribute")) {
            my $name = $attr->name();
            push(@{$output},$name." = ".$self->$name());
        }
    }
    push(@{$output},"}");
    foreach my $attr ( $class->meta->get_all_attributes ) {
        if ($attr->isa('ModelSEED::Meta::Attribute::Typed')) {
            if ($attr->type() =~ m/child\((.+)\)/ || $attr->type() =~ m/encompassed\((.+)\)/ ) {
                my $name = $attr->name();
                push(@{$output},$name."(){");
                my $objects = $self->$name();
                foreach my $object ($objects) {
                    push(@{$output},$object->createReadableLine());
                }       
                push(@{$output},"}");
            }
        }
    }
    return $output;
}

######################################################################
#Object addition functions
######################################################################

=head

removing create method, use add instead

sub create {
    my ($self, $attribute, $data) = @_;
    foreach my $key (keys(%{$data})) {
        if (!defined($data->{$key})) {
            delete $data->{$key};
        }
    }
    if (!$self->meta->has_attribute($attribute)) {
        ModelSEED::utilities::ERROR("Object doesn't have attribute with name: $attribute");
    }
    my $package = "ModelSEED::MS::$type";
    Module::Load::load $package;
    my $object = $package->new($data);
    $self->add($attribute, $object);
    return $object;
}

=cut

sub add {
    my ($self, $attribute, $data_or_object) = @_;

    my $attr_info = $self->_attributes($attribute);
    if (!defined($attr_info)) {
        ModelSEED::utilities::ERROR("Object doesn't have attribute with name: $attribute");
    }

    my $obj_info = {
        created => 0,
        class => $attr_info->{class}
    };

    my $ref = ref($data_or_object);
    if ($ref eq "HASH") {
        # need to create object first
        $obj_info->{data} = $data_or_object;
        $self->_build_object($attribute, $obj_info);
    } elsif ($ref =~ m/ModelSEED::MS/) {
        $obj_info->{object} = $data_or_object;
        $obj_info->{created} = 1;
    } else {
        ModelSEED::utilities::ERROR("Neither data nor object passed into " . ref($self) . "->add");
    }

    $obj_info->{object}->parent($self);
    my $method = "_$attribute";
    push(@{$self->$method}, $obj_info);

    return $self;
}

sub remove {
    my ($self, $attribute, $object) = @_;

    my $attr_info = $self->_attributes($attribute);
    if (!defined($attr_info)) {
        ModelSEED::utilities::ERROR("Object doesn't have attribute with name: $attribute");
    }

    my $removedCount = 0;
    my $method = "_$attribute";
    my $array = $self->$method;
    for (my $i=0; $i<@$array; $i++) {
        my $obj_info = $array->[$i];
        if ($obj_info->{created}) {
            if ($object eq $obj_info->{object}) {
                splice(@$array, $i, 1);
                $removedCount += 1;
            }
        }
    }

    return $removedCount;
}

# can only get via uuid
sub getLinkedObject {
    my ($self, $sourceType, $attribute, $uuid) = @_;

    if (ref($self) =~ /$sourceType/) {
        return $self->getObject($attribute, $uuid);
    } elsif (ref($self->parent) eq 'ModelSEED::Store') {
        my $o = $self->parent->get_object_by_uuid($attribute, $uuid);
        warn "Getting object ".ref($o);
        return $o;
    } else {
        return $self->parent->getLinkedObject($sourceType, $attribute, $uuid);
    }
}

sub biochemistry {
    my ($self) = @_;
    my $parent = $self->parent();
    if (defined($parent) && ref($parent) eq "ModelSEED::MS::Biochemistry") {
        return $parent;
    } elsif (defined($parent) && ref($parent) ne "ModelSEED::Store") {
        confess "Cannot find Biochemistry object in tree!";
    }
    ModelSEED::utilities::ERROR("Cannot find Biochemistry object in tree!");
}

sub model {
    my ($self) = @_;
    my $parent = $self->parent();
    if (defined($parent) && ref($parent) eq "ModelSEED::MS::Model") {
        return $parent;
    } elsif (defined($parent) && ref($parent) ne "ModelSEED::Store") {
        confess "Cannot find Model object in tree!";
    }
    ModelSEED::utilities::ERROR("Cannot find Model object in tree!");
}

sub annotation {
    my ($self) = @_;
    my $parent = $self->parent();
    if (defined($parent) && ref($parent) eq "ModelSEED::MS::Annotation") {
        return $parent;
    } elsif (defined($parent) && ref($parent) ne "ModelSEED::Store") {
        confess "Cannot find Annotation object in tree!";
    }
    ModelSEED::utilities::ERROR("Cannot find Annotation object in tree!");
}

sub mapping {
    my ($self) = @_;
    my $parent = $self->parent();
    if (defined($parent) && ref($parent) eq "ModelSEED::MS::Mapping") {
        return $parent;
    } elsif (defined($parent) && ref($parent) ne "ModelSEED::Store") {
        confess "Cannot find mapping object in tree!";
    }
    ModelSEED::utilities::ERROR("Cannot find mapping object in tree!");
}

sub objectmanager {
    return $_[0]->store;
}

sub store {
    my ($self) = @_;
    my $parent = $self->parent();
    if (defined($parent) && ref($parent) ne "ModelSEED::Store") {
        return $parent->store();
    }
    return $parent;
}

sub _build_object {
    my ($self, $attribute, $obj_info) = @_;

    if ($obj_info->{created}) {
        return $obj_info->{object};
    }

    my $class = 'ModelSEED::MS::' . $obj_info->{class};
    Module::Load::load $class;
    my $obj = $class->new($obj_info->{data});

    $obj_info->{created} = 1;
    $obj_info->{object} = $obj;
    delete $obj_info->{data};

    return $obj;
}

sub _build_all_objects {
    my ($self, $attribute) = @_;

    my $objs = [];
    my $method = "_$attribute";
    my $subobjs = $self->$method();
    foreach my $subobj (@$subobjs) {
        push(@$objs, $self->_build_object($attribute, $subobj));
    }

    return $objs;
}

__PACKAGE__->meta->make_immutable;
1;
