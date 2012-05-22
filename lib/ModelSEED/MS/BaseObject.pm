########################################################################
# ModelSEED::MS::BaseObject - This is a base object that serves as a foundation for all other objects
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/11/2012
########################################################################
use strict;
use DateTime;
use Data::UUID;
use JSON::Any;
use Digest::MD5 qw(md5_hex);
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

1;

package Moose::Meta::Attribute::Custom::Typed;
sub register_implementation { 'ModelSEED::Meta::Attribute::Typed' }

package ModelSEED::MS::BaseObject;
use Moose;
use ModelSEED::MS::Metadata::Types;
use namespace::autoclean;

sub BUILD {
    my ($self,$params) = @_;
    return;
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

sub setParents {
	my ($self,$parent) = @_;
	if (defined($parent)) {
		$self->parent($parent);
	}
	my $class = 'ModelSEED::MS::'.$self->_type();
	for my $attr ( $class->meta->get_all_attributes ) {
		if ($attr->isa('ModelSEED::Meta::Attribute::Typed') && ($attr->type() =~ m/child\((.+)\)/ || $attr->type() =~ m/encompassed\((.+)\)/)) {
			my $name = $attr->name();
			for (my $i=0; $i < @{$self->$name()}; $i++) {
				$self->$name()->[$i]->setParents($self);
			}
		}
	}
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
	my $aliasowner = lc($self->_aliasowner());
	my $owner = $self->$aliasowner();
	my $aliasSetClass = $self->_type()."AliasSet";
	if (!defined($aliasSet)) {
		$aliasSet = $owner->defaultNameSpace();
	}
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
	return $self->getAlias();
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
	my ($self,$sourceType,$type,$attribute,$value) = @_;
	my $sourceTypeLC = lc($sourceType);
    if(ref($self) =~ /:$sourceType$/) {
        return $self->getObject($type, {$attribute => $value}); 
    } elsif (defined($self->$sourceTypeLC())) {
        return $self->$sourceTypeLC()->getLinkedObject($sourceType, $type, $attribute, $value);;
    } elsif(ref($self->parent) eq 'ModelSEED::Store') {
        if($attribute eq 'uuid') {
            my $o = $self->parent->get_object_by_uuid($type, $value);
            warn "Getting object ".ref($o);
            return $o;
        } else {
            return $self->parent->get_object($type, $value);
        }
    } elsif (!defined($self->parent)) {
    	ModelSEED::utilities::ERROR("Attempting to get linked object from parent that doesn't exist!");
    } else {
        return $self->parent->getLinkedObject($sourceType, $type, $attribute, $value);
    }
}

sub biochemistry {
	my ($self) = @_;
	my $parent = $self->parent();
	if (defined($parent) && ref($parent) eq "ModelSEED::MS::Biochemistry") {
		return $parent;
	} elsif (defined($parent) && ref($parent) ne "ModelSEED::Store") {
        return $parent->biochemistry();
	}
	ModelSEED::utilities::ERROR("Cannot find Biochemistry object in tree!");
}

sub fbaproblem {
	my ($self) = @_;
	my $parent = $self->parent();
	if (defined($parent) && ref($parent) eq "ModelSEED::MS::FBAProblem") {
		return $parent;
	} elsif (defined($parent) && ref($parent) ne "ModelSEED::Store") {
        return $parent->fbaproblem();
	}
	ModelSEED::utilities::ERROR("Cannot find FBAProblem object in tree!");
}

sub model {
	my ($self) = @_;
	my $parent = $self->parent();
	if (defined($parent) && ref($parent) eq "ModelSEED::MS::Model") {
		return $parent;
	} elsif (defined($parent) && ref($parent) ne "ModelSEED::Store") {
        return $parent->model();
	}
	ModelSEED::utilities::ERROR("Cannot find Model object in tree!");
}

sub annotation {
	my ($self) = @_;
	my $parent = $self->parent();
	if (defined($parent) && ref($parent) eq "ModelSEED::MS::Annotation") {
		return $parent;
	} elsif (defined($parent) && ref($parent) ne "ModelSEED::Store") {
        return $parent->annotation();
	}
	ModelSEED::utilities::ERROR("Cannot find Annotation object in tree!");
}

sub mapping {
	my ($self) = @_;
	my $parent = $self->parent();
	if (defined($parent) && ref($parent) eq "ModelSEED::MS::Mapping") {
		return $parent;
	} elsif (defined($parent) && ref($parent) ne "ModelSEED::Store") {
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

__PACKAGE__->meta->make_immutable;
1;
