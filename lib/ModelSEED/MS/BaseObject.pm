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
use Data::Dumper;
$Data::Dumper::Maxdepth = 2;

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
				my $dataArray = $self->$function();
				my $newData = {};
				foreach my $data (@{$dataArray}) {
					$data->{parent} = $self;
					push(@{$newData->{$data->{$attribute}}},$subclass->new($data));
				}
				$self->$function($newData);
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
				$data->{$name} = $self->$name();
			} elsif ($attr->type() =~ m/child\((.+)\)/ || $attr->type() =~ m/encompassed\((.+)\)/ ) {
				my $arrayRef = $self->$name();
				foreach my $subobject (@{$arrayRef}) {
					push(@{$data->{$name}},$subobject->serializeToDB());
				}
			} elsif ($attr->type() =~ m/hasharray\((.+)\)/) {
				my $hashRef = $self->$attr();
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
	if (!defined($self->_typeToFunction()) || !defined($self->_typeToFunction()->{$type})) {
    	ModelSEED::utilities::ERROR("Object doesn't have a subobject of type ".$type);	
    }
	my $package = "ModelSEED::MS::$type";
	eval {
		require $package;
	};
	my $object = $package->new($data);
	$self->add($type, $object);
	return $object;
}

sub add {
    my ($self, $attribute, $object) = @_;
    my $type = $object->_type();
    if (!defined($self->_typeToFunction()) || !defined($self->_typeToFunction()->{$type})) {
    	ModelSEED::utilities::ERROR("Object doesn't have a subobject of type ".$type);	
    }
    my $attrMeta;
    {
        my $class = 'ModelSEED::MS::DB::' . $self->_type;
        $attrMeta = $class->find_attribute_by_name($attribute);
        ModelSEED::utilities::ERROR("Unknown attribute: $attribute!")
            unless (defined($attrMeta));
    }
    if($attrMeta->isa('ModelSEED::Meta::Attribute::Typed')) {
        # Case of simple array of objects (linked or encompassed)
        if ($attrMeta->type() =~ m/child\((.+)\)/ || $attrMeta->type() =~ m/encompassed\((.+)\)/ ) {
            push(@{$self->$attribute}, $object);
        # Case of hashed array of objects (aliases and the like)
        } elsif ($attrMeta->type() =~ m/hasharray\((.+)\)/) {
            my ($subType, $hashOn) = [split(/,/,$1)];
            my $key = $object->$hashOn;
            $self->$attribute->{$key} = [] unless(defined($self->$attribute->{$key}));
            push(@{$self->$attribute->{$key}}, $object);
        } else {
            ModelSEED::utilities::ERROR("Unknown type " . $attrMeta->type . "!");
        }
    } else {
        ModelSEED::utilities::ERROR("Unable to call add on attribute that is not typed!")
    }
}

sub getLinkedObject {
	my ($self,$soureType,$type,$attribute,$value) = @_;
	$soureType = lc($soureType);
	my $parent = $self->$soureType();
	my $object;
	if (ref($parent) eq "ModelSEED::MS::ObjectManager") {
		$object = $parent->get($type,$value);
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
	if (ref($parent) ne "ModelSEED::MS::ObjectManager") {
		return $parent->biochemistry();
	} elsif (ref($parent) eq "ModelSEED::MS::Biochemistry") {
		return $parent;
	}
	ModelSEED::utilities::ERROR("Cannot find Biochemistry object in tree!");
}

sub model {
	my ($self) = @_;
	my $parent = $self->parent();
	if (ref($parent) ne "ModelSEED::MS::ObjectManager") {
		return $parent->model();
	} elsif (ref($parent) eq "ModelSEED::MS::Model") {
		return $parent;
	}
	ModelSEED::utilities::ERROR("Cannot find Model object in tree!");
}

sub annotation {
	my ($self) = @_;
	my $parent = $self->parent();
	if (ref($parent) ne "ModelSEED::MS::ObjectManager") {
		return $parent->annotation();
	} elsif (ref($parent) eq "ModelSEED::MS::Annotation") {
		return $parent;
	}
	ModelSEED::utilities::ERROR("Cannot find Annotation object in tree!");
}

sub mapping {
	my ($self) = @_;
	my $parent = $self->parent();
	if (ref($parent) ne "ModelSEED::MS::ObjectManager") {
		return $parent->mapping();
	} elsif (ref($parent) eq "ModelSEED::MS::Mapping") {
		return $parent;
	}
	ModelSEED::utilities::ERROR("Cannot find mapping object in tree!");
}

sub objectmanager {
	my ($self) = @_;
	my $parent = $self->parent();
	if (ref($parent) ne "ModelSEED::MS::ObjectManager") {
		return $parent->objectmanager();
	}
	return $parent;
}

__PACKAGE__->meta->make_immutable;
1;
