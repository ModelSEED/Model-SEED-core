########################################################################
# ModelSEED::MS::BaseObject - This is a base object that serves as a foundation for all other objects
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/11/2012
########################################################################
use strict;
use ModelSEED::MS::Metadata::Types;
use DateTime;
use Data::UUID;
use JSON::Any;
use Digest::MD5 qw(md5_hex);
use Module::Load;

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
    my $class = 'ModelSEED::MS::DB::'.$self->_type();
    for my $attr ( $class->meta->get_all_attributes ) {
		if ($attr->isa('ModelSEED::Meta::Attribute::Typed')) {
			if ($attr->type() =~ m/child\((.+)\)/ || $attr->type() =~ m/encompassed\((.+)\)/ ) {
	    		my $subclass = 'ModelSEED::MS::'.$1;
	    		my $function = $attr->name();
				my $dataArray = $self->$function();
				my $newData = [];
				foreach my $data (@{$dataArray}) {
					$data->{parent} = $self;
					push(@{$newData},$subclass->new($data));
				}
				$self->$function($newData);
			} elsif ($attr->type() =~ m/hasharray\((.+)\)/) {
	    		my $parameters = [split(/,/,$1)];
	    		my $subclass = 'ModelSEED::MS::'.$parameters->[0];
	    		my $attribute = $parameters->[1];
	    		my $function = $attr->name();
				my $data = $self->$function // {};
                if(ref($data) eq 'ARRAY') {
                    foreach my $d (@$data) {
                        $self->create($subclass, $d);
                    }
				} else {
                    $self->$function($data);
                }
			}
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
sub create {
	my ($self,$type,$data) = @_;
   	foreach my $key (keys(%{$data})) {
   		if (!defined($data->{$key})) {
   			delete $data->{$key};
   		}
   	}
	my $attribute = $self->_typeToFunction()->{$type};
	if (!defined($attribute)) {
    	ModelSEED::utilities::ERROR("Object doesn't have a subobject of type ".$type);	
    }
	my $package = "ModelSEED::MS::$type";
    Module::Load::load $package;
	my $object = $package->new($data);
	$self->add($attribute, $object);
	return $object;
}

sub add {
    my ($self, $attribute, $object) = @_;
    my $type = $object->_type();
    if (!defined($self->_typeToFunction()) || !defined($self->_typeToFunction()->{$type})) {
    	ModelSEED::utilities::ERROR("Object doesn't have a subobject of type ".$type);	
    }
    $attribute = $self->_typeToFunction()->{$type};
    my $attrMeta;
    {
        my $class = 'ModelSEED::MS::DB::' . $self->_type;
        $attrMeta = $class->meta->find_attribute_by_name($attribute);
        ModelSEED::utilities::ERROR("Unknown attribute: $attribute!")
            unless (defined($attrMeta));
    }
    if($attrMeta->isa('ModelSEED::Meta::Attribute::Typed')) {
        $object->parent($self);
        # Case of simple array of objects (linked or encompassed)
        if ($attrMeta->type() =~ m/child\((.+)\)/ || $attrMeta->type() =~ m/encompassed\((.+)\)/ ) {
            push(@{$self->$attribute}, $object);
        # Case of hashed array of objects (aliases and the like)
        } elsif ($attrMeta->type() =~ m/hasharray\((.+)\)/) {
            my ($subType, $hashOn) = split(/,/,$1);
            unless(defined($subType) && defined($hashOn)) {
                ModelSEED::utilities::ERROR("Unknown type " . $attrMeta->type());
            }
            my $key = $object->$hashOn;
            $self->$attribute->{$key} = [] unless(defined($self->$attribute->{$key}));
            push(@{$self->$attribute->{$key}}, $object);
        } else {
            ModelSEED::utilities::ERROR("Unknown type " . $attrMeta->type . "!");
        }
    } else {
        ModelSEED::utilities::ERROR("Unable to call add on attribute that is not typed!")
    }
    return $self;
}

sub remove {
    my ($self, $type, $object) = @_;
    my $attribute = $self->_typeToFunction()->{$type};
    my $removedCount = 0;
    my $attrMeta;
    {
        my $class = 'ModelSEED::MS::DB::' . $self->_type;
        $attrMeta = $class->meta->find_attribute_by_name($attribute);
        ModelSEED::utilities::ERROR("Unknown attribute: $attribute!")
            unless (defined($attrMeta));
    }
    if($attrMeta->isa('ModelSEED::Meta::Attribute::Typed')) {
        # Case of simple array of objects (linked or encompassed)
        if ($attrMeta->type() =~ m/child\((.+)\)/ || $attrMeta->type() =~ m/encompassed\((.+)\)/ ) {
            my $array = $self->$attribute;
            for(my $i=0; $i<@$array; $i++) {
                my $obj = $array->[$i];
                if($object eq $obj) {
                    splice(@$array, $i, 1); 
                    $removedCount += 1;
                }
            }
        # Case of hashed array of objects (aliases and the like)
        } elsif ($attrMeta->type() =~ m/hasharray\((.+)\)/) {
            foreach my $key (keys %{$self->$attribute}) {
                my $array = $self->$attribute->{$key};
                for(my $i=0; $i<@$array; $i++) {
                    my $obj = $array->[$i];
                    if($object eq $obj) {
                        splice(@$array, $i, 1);
                        $removedCount += 1;
                    }
                }
            }
        } else {
            ModelSEED::utilities::ERROR("Unknown type " . $attrMeta->type . "!");
        }
    } else {
        ModelSEED::utilities::ERROR("Unable to call add on attribute that is not typed!")
    }
    return $removedCount;
}

sub getLinkedObject {
	my ($self,$soureType,$type,$attribute,$value) = @_;
	$soureType = lc($soureType);
	my $parent = $self->$soureType();
	my $object;
	if (ref($parent) eq "ModelSEED::Store") {
		$object = $parent->get_object($type,$value);
	} else {
		$object = $parent->getObject($type,{$attribute => $value});
	}
	if (!defined($object)) {
		ModelSEED::utilities::ERROR($type.' '.$value." not found in ".$soureType."!");
	}
	return $object;
}

sub biochemistry {
	my ($self) = @_;
	my $parent = $self->parent();
	if (defined($parent) && ref($parent) eq "ModelSEED::MS::Biochemistry") {
		return $parent;
	} elsif (defined($parent) && ref($parent) ne "ModelSEED::Store") {
        ModelSEED::utilities::ERROR("Cannot find Biochemistry object in tree!");
	}
	ModelSEED::utilities::ERROR("Cannot find Biochemistry object in tree!");
}

sub model {
	my ($self) = @_;
	my $parent = $self->parent();
	if (defined($parent) && ref($parent) eq "ModelSEED::MS::Model") {
		return $parent;
	} elsif (defined($parent) && ref($parent) ne "ModelSEED::Store") {
        ModelSEED::utilities::ERROR("Cannot find Model object in tree!");
	}
	ModelSEED::utilities::ERROR("Cannot find Model object in tree!");
}

sub annotation {
	my ($self) = @_;
	my $parent = $self->parent();
	if (defined($parent) && ref($parent) eq "ModelSEED::MS::Annotation") {
		return $parent;
	} elsif (defined($parent) && ref($parent) ne "ModelSEED::Store") {
        ModelSEED::utilities::ERROR("Cannot find Annotation object in tree!");
	}
	ModelSEED::utilities::ERROR("Cannot find Annotation object in tree!");
}

sub mapping {
	my ($self) = @_;
	my $parent = $self->parent();
	if (defined($parent) && ref($parent) eq "ModelSEED::MS::Mapping") {
		return $parent;
	} elsif (defined($parent) && ref($parent) ne "ModelSEED::Store") {
        ModelSEED::utilities::ERROR("Cannot find mapping object in tree!");
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

__PACKAGE__->meta->make_immutable;
1;
