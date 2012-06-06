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

has printOrder => (
      is        => 'rw',
      isa       => 'Int',
      predicate => 'has_printOrder',
      default => '-1',
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
    my $attributes = $self->_attributes();
    foreach my $item (@{$attributes}) {
    	my $name = $item->{name};	
		if (defined($self->$name())) {
    		$data->{$name} = $self->$name();	
    	}
    }
    my $subobjects = $self->_subobjects();
    foreach my $item (@{$subobjects}) {
    	my $name = "_".$item->{name};
    	my $arrayRef = $self->$name();
    	foreach my $subobject (@{$arrayRef}) {
			if ($subobject->{created} == 1) {
				push(@{$data->{$item->{name}}},$subobject->{object}->serializeToDB());	
			} else {
				my $newData;
				foreach my $key (keys(%{$subobject->{data}})) {
					if ($key ne "parent") {
						$newData->{$key} = $subobject->{data}->{$key};
					}
				}
				push(@{$data->{$item->{name}}},$newData);
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
    my $aliasobj = $owner->queryObject("aliasSets",{
    	name => $aliasSet,
    	class => $self->_type()
    });
    if (!defined($aliasobj)) {
        print "Alias set ".$aliasSet." not found!\n";
        return [];
    }
    my $aliases = $aliasobj->aliasesByuuid()->{$self->uuid()};
}

sub _buildid {
    my ($self) = @_;
    return $self->getAlias($self->parent()->defaultNameSpace());
}

######################################################################
#Output functions
######################################################################
sub createReadableStringArray {
	my ($self) = @_;
	my $output = ["Attributes {"];
	my $data = $self->createReadableData();
	for (my $i=0; $i < @{$data->{attributes}->{headings}}; $i++) {
		push(@{$output},"\t".$data->{attributes}->{headings}->[$i].":".$data->{attributes}->{data}->[0]->[$i])
	}
	push(@{$output},"}");
	if (defined($data->{subobjects})) {
		for (my $i=0; $i < @{$data->{subobjects}}; $i++) {
			push(@{$output},$data->{subobjects}->[$i]->{name}." (".join("\t",@{$data->{subobjects}->[$i]->{headings}}).") {");
			for (my $j=0; $j < @{$data->{subobjects}->[$i]->{data}}; $j++) {
				push(@{$output},join("\t",@{$data->{subobjects}->[$i]->{data}->[$j]}));
			}
			push(@{$output},"}");
		}
	}
	return $output;
}

sub createReadableData {
	my ($self) = @_;
	my $data;
	my ($sortedAtt,$sortedSO) = $self->getReadableAttributes();
	$data->{attributes}->{headings} = $sortedAtt;
	for (my $i=0; $i < @{$data->{attributes}->{headings}}; $i++) {
		my $att = $data->{attributes}->{headings}->[$i];
		push(@{$data->{attributes}->{data}->[0]},$self->$att());
	}
	for (my $i=0; $i < @{$sortedSO}; $i++) {
		my $so = $sortedSO->[$i];
		my $soData = {name => $so};
		my $objects = $self->$so();
		if (defined($objects->[0])) {
			my ($sortedAtt,$sortedSO) = $objects->[0]->getReadableAttributes();
			$soData->{headings} = $sortedAtt;
			for (my $j=0; $j < @{$objects}; $j++) {
				for (my $k=0; $k < @{$sortedAtt}; $k++) {
					my $att = $sortedAtt->[$k];
					$soData->{data}->[$j]->[$k] = ($objects->[$j]->$att() || "");
				}
			}
			push(@{$data->{subobjects}},$soData);
		}
	}
	return $data;
 }
 
sub getReadableAttributes {
	my ($self) = @_;
	my $priority = {};
	my $attributes = [];
	my $prioritySO = {};
	my $attributesSO = [];
	my $class = 'ModelSEED::MS::'.$self->_type();
	foreach my $attr ( $class->meta->get_all_attributes ) {
		if ($attr->isa('ModelSEED::Meta::Attribute::Typed') && $attr->printOrder() != -1 && ($attr->type() eq "attribute" || $attr->type() eq "msdata")) {
			push(@{$attributes},$attr->name());
			$priority->{$attr->name()} = $attr->printOrder();
		} elsif ($attr->isa('ModelSEED::Meta::Attribute::Typed') && $attr->printOrder() != -1) {
			push(@{$attributesSO},$attr->name());
			$prioritySO->{$attr->name()} = $attr->printOrder();
		}
	}
	my $sortedAtt = [sort { $priority->{$a} <=> $priority->{$b} } @{$attributes}];
	my $sortedSO = [sort { $prioritySO->{$a} <=> $prioritySO->{$b} } @{$attributesSO}];
	return ($sortedAtt,$sortedSO);
}
######################################################################
#Object addition functions
######################################################################
sub add {
    my ($self, $attribute, $data_or_object) = @_;

    my $attr_info = $self->_subobjects($attribute);
    if (!defined($attr_info)) {
        ModelSEED::utilities::ERROR("Object doesn't have subobject with name: $attribute");
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
    return $obj_info->{object};
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
   	my $source = lc($sourceType);
   	my $sourceObj = $self->$source();
   	if (!defined($sourceObj)) {
   		ModelSEED::utilities::ERROR("Cannot obtain source object ".$sourceType." for ".$attribute." link!");
   	}
   	return $sourceObj->getObject($attribute,$uuid);
}

sub biochemistry {
    my ($self) = @_;
    my $parent = $self->parent();
    if (defined($parent) && ref($parent) eq "ModelSEED::MS::Biochemistry") {
        return $parent;
    } elsif (defined($parent)) {
        return $parent->biochemistry();
    }
    ModelSEED::utilities::ERROR("Cannot find Biochemistry object in tree!");
}

sub model {
    my ($self) = @_;
    my $parent = $self->parent();
    if (defined($parent) && ref($parent) eq "ModelSEED::MS::Model") {
        return $parent;
    } elsif (defined($parent)) {
        return $parent->model();
    }
    ModelSEED::utilities::ERROR("Cannot find Model object in tree!");
}

sub annotation {
    my ($self) = @_;
    my $parent = $self->parent();
    if (defined($parent) && ref($parent) eq "ModelSEED::MS::Annotation") {
        return $parent;
    } elsif (defined($parent)) {
        return $parent->annotation();
    }
    ModelSEED::utilities::ERROR("Cannot find Annotation object in tree!");
}

sub mapping {
    my ($self) = @_;
    my $parent = $self->parent();
    if (defined($parent) && ref($parent) eq "ModelSEED::MS::Mapping") {
        return $parent;
    } elsif (defined($parent)) {
        return $parent->mapping();
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
	my $attInfo = $self->_subobjects($attribute);
    if (!defined($attInfo->{class})) {
    	ModelSEED::utilities::ERROR("No class for attribute ".$attribute);	
    }
    my $class = 'ModelSEED::MS::' . $attInfo->{class};
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
