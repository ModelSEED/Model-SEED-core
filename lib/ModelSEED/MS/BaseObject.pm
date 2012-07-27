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
use JSON;
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
use ModelSEED::utilities;
use Scalar::Util qw(weaken);
our $VERSION = undef;

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my $hash = {};
    if ( ref $_[0] eq 'HASH' ) {
        $hash = shift;    
    } elsif ( scalar @_ % 2 == 0 ) {
        my %h = @_;
        $hash = \%h;
    }
    my $objVersion = $hash->{__VERSION__};
    my $classVersion = $class->__version__;
    if (defined $objVersion && $objVersion != $classVersion) {
        if (defined(my $fn = $class->__upgrade__($objVersion))) {
            $hash = $fn->($hash);
        } else {
            die "Invalid Object\n";
        }
    }
    return $class->$orig($hash);
};


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
            weaken($data->{parent}); # and make it weak
            $subobjs->[$i] = $info; # reset the subobject with info hash
        }
    }
}

sub serializeToDB {
    my ($self) = @_;
    my $data = {};
    my $v = $self->VERSION;
    $data = { __VERSION__ => $v } if defined $v;
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

sub toJSON {
    my ($self,$args) = @_;
    $args = ModelSEED::utilities::ARGS($args,[],{pp => 0});
    my $data = $self->serializeToDB();
    my $JSON = JSON->new->utf8(1);
    $JSON->pretty(1) if($args->{pp} == 1);
    return $JSON->encode($data)
}
sub printJSONFile {
    my ($self,$filename,$args) = @_;
    my $text = $self->toJSON($args);
    ModelSEED::utilities::PRINTFILE($filename,[$text]);
}

######################################################################
#Alias functions
######################################################################
sub getAlias {
    my ($self,$set) = @_;
    my $aliases = $self->getAliases($set);
    return (@$aliases) ? $aliases->[0] : undef;
}

sub getAliases {
    my ($self,$setName) = @_;
    return [] unless(defined($setName));
    my $aliasRootClass = lc($self->_aliasowner());
    my $rootClass = $self->$aliasRootClass();
    my $aliasSet = $rootClass->queryObject("aliasSets",{
    	name => $setName,
    	class => $self->_type()
    });
    return [] unless(defined($aliasSet));
    my $aliases = $aliasSet->aliasesByuuid->{$self->uuid()};
    return (defined($aliases)) ? $aliases : [];
}

sub defaultNameSpace {
    return $_[0]->parent->defaultNameSpace();
}

sub _build_id {
    my ($self) = @_;
    my $alias = $self->getAlias($self->defaultNameSpace());
    return (defined($alias)) ? $alias : $self->uuid;
}

sub interpretReference {
	my ($self,$ref,$expectedType) = @_;
	my $array = [split(/\//,$ref)];
	if (!defined($array->[2]) || (defined($expectedType) && $array->[0] ne $expectedType)) {
		if (defined($expectedType) && @{$array} == 1) {
			$array = [$expectedType,"id",$ref];
		} else {
			ModelSEED::utilities::ERROR($ref." is not a valid  reference!");
		}
	}
	my $refTypeProvObj = {
		"Role" => ["mapping","roles"],
		"Reaction" => ["biochemistry","reactions"],
		"Media" => ["biochemistry","media"],
		"Feature" => ["annotation","features"],
		"Genome" => ["annotation","genomes"],
		"Compound" => ["biochemistry","compounds"],
		"Compartment" => ["biochemistry","compartments"],
		"Biomass" => ["model","biomasses"]
	};
	if (!defined($refTypeProvObj->{$array->[0]})) {
		ModelSEED::utilities::ERROR("No specs to handle ref type ".$array->[0]);
	}	
	my $prov = $refTypeProvObj->{$array->[0]}->[0];
	my $func = $refTypeProvObj->{$array->[0]}->[1];
	my $obj;
	if ($array->[1] eq "ModelSEED") {
		$obj = $self->$prov()->queryObject($func,{"id" => $array->[2]});
	} else {
		$obj = $self->$prov()->queryObject($func,{$array->[1] => $array->[2]});
	}
	if (!defined($obj)) {
		print STDERR "Could not find ".$ref."!\n";
	}
	return ($obj,$array->[0],$array->[1],$array->[2]);
}

sub parseReferenceList {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		string => "none",
		delimiter => "|",
		data => "obj",
		class => undef
	});
	my $output = [];
	if (!defined($args->{array})) {
		$args->{array} = ModelSEED::utilities::parseArrayString($args);
	}
	for (my $i=0; $i < @{$args->{array}}; $i++) {
		(my $obj) = $self->interpretReference($args->{array}->[$i],$args->{class});
		if (defined($obj)) {
			if ($args->{data} eq "obj") {
				push(@{$output},$obj);
			} elsif ($args->{data} eq "uuid") {
				push(@{$output},$obj->uuid());
			}	
		}
	}
	return $output;
}
######################################################################
#Output functions
######################################################################
sub createHTML {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{internal => 0});
	my $data = $self->createReadableData();
	my $output = [];
	if ($args->{internal} == 0) {
		push(@{$output},(
			'<!doctype HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">',
			'<html><head>',
			'<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"></script>',
			'    <script type="text/javascript">',
			'        function UpdateTableHeaders() {',
			'            $("div.divTableWithFloatingHeader").each(function() {',
			'                var originalHeaderRow = $(".tableFloatingHeaderOriginal", this);',
			'                var floatingHeaderRow = $(".tableFloatingHeader", this);',
			'                var offset = $(this).offset();',
			'                var scrollTop = $(window).scrollTop();',
			'                if ((scrollTop > offset.top) && (scrollTop < offset.top + $(this).height())) {',
			'                    floatingHeaderRow.css("visibility", "visible");',
			'                    floatingHeaderRow.css("top", Math.min(scrollTop - offset.top, $(this).height() - floatingHeaderRow.height()) + "px");',
			'                    // Copy row width from whole table',
			'                    floatingHeaderRow.css(\'width\', "1200px");',
			'                    // Copy cell widths from original header',
			'                    $("th", floatingHeaderRow).each(function(index) {',
			'                        var cellWidth = $("th", originalHeaderRow).eq(index).css(\'width\');',
			'                        $(this).css(\'width\', cellWidth);',
			'                    });',
			'                }',
			'                else {',
			'                    floatingHeaderRow.css("visibility", "hidden");',
			'                    floatingHeaderRow.css("top", "0px");',
			'                }',
			'            });',
			'        }',
			'        $(document).ready(function() {',
			'            $("table.tableWithFloatingHeader").each(function() {',
			'                $(this).wrap("<div class=\"divTableWithFloatingHeader\" style=\"position:relative\"></div>");',
			'                var originalHeaderRow = $("tr:first", this)',
			'                originalHeaderRow.before(originalHeaderRow.clone());',
			'                var clonedHeaderRow = $("tr:first", this)',
			'                clonedHeaderRow.addClass("tableFloatingHeader");',
			'                clonedHeaderRow.css("position", "absolute");',
			'                clonedHeaderRow.css("top", "0px");',
			'                clonedHeaderRow.css("left", $(this).css("margin-left"));',
			'                clonedHeaderRow.css("visibility", "hidden");',
			'                originalHeaderRow.addClass("tableFloatingHeaderOriginal");',
			'            });',
			'            UpdateTableHeaders();',
			'            $(window).scroll(UpdateTableHeaders);',
			'            $(window).resize(UpdateTableHeaders);',
			'        });',
			'    </script>',
			'<style type="text/css">',
			'h1 {',
			'    font-size: 16px;',
			'}',
			'table.tableWithFloatingHeader {',
			'    font-size: 12px;',
			'    text-align: left;',
			'	 border: 0;',
			'	 width: 1200px;',
			'}',
			'th {',
			'    font-size: 14px;',
			'    background: #ddd;',
			'	 border: 1px solid black;',
			'    vertical-align: top;',
			'    padding: 5px 5px 5px 5px;',
			'}',
			'td {',
			'   font-size: 16px;',
			'	vertical-align: top;',
			'	border: 1px solid black;',
			'}',
			'</style></head>'
		));
	}
	push(@{$output},'<h2>'.$self->_type().' attributes</h2>');
	push(@{$output},'<table>');
	for (my $i=0; $i < @{$data->{attributes}->{headings}}; $i++) {
		push(@{$output},"<tr><th>".$data->{attributes}->{headings}->[$i]."</th><td style='font-size:16px;border: 1px solid black;'>".$data->{attributes}->{data}->[0]->[$i]."</td></tr>");
	}
	push(@{$output},'</table>');
	foreach my $subobject (@{$data->{subobjects}}) {
		push(@{$output},(
			'<h2>'.$subobject->{name}.' subobjects</h2>',
			'<table class="tableWithFloatingHeader">',
			'<tr><th>'.join("</th><th>",@{$subobject->{headings}}).'</th></tr>'
		));
		foreach my $row (@{$subobject->{data}}) {
			push(@{$output},'<tr><td>'.join("</td><td>",@{$row}).'</td></tr>');
		}
		push(@{$output},'</table>');
	}
	if (defined($data->{results})) {
		for (my $i=0; $i < @{$data->{results}}; $i++) {
			my $rs = $data->{results}->[$i];
			my $objects = $self->$rs();
			if (defined($objects->[0])) {
				push(@{$output},"<h2>".$rs." objects</h2>");
				for (my $j=0; $j < @{$objects}; $j++) {
					push(@{$output},$objects->[$j]->createHTML({internal => 1}));
				}
			}
		}
	}
	if ($args->{internal} == 0) {
		push(@{$output},'</html>');
	}
	my $html = join("\n",@{$output});
	return $html;
}

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
	if (defined($data->{results})) {
		for (my $i=0; $i < @{$data->{results}}; $i++) {
			my $rs = $data->{results}->[$i];
			my $objects = $self->$rs();
			if (defined($objects->[0])) {
				push(@{$output},$rs." objects {");
				for (my $j=0; $j < @{$objects}; $j++) {
					push(@{$output},@{$objects->[$j]->createReadableStringArray()});
				}
				push(@{$output},"}");
			}
		}
	}
	return $output;
}

sub createReadableData {
	my ($self) = @_;
	my $data;
	my ($sortedAtt,$sortedSO,$sortedRS) = $self->getReadableAttributes();
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
	for (my $i=0; $i < @{$sortedRS}; $i++) {
		push(@{$data->{results}},$sortedRS->[$i]);
	}
	return $data;
 }
 
sub getReadableAttributes {
	my ($self) = @_;
	my $priority = {};
	my $attributes = [];
	my $prioritySO = {};
	my $attributesSO = [];
	my $priorityRS = {};
	my $attributesRS = [];
	my $class = 'ModelSEED::MS::'.$self->_type();
	foreach my $attr ( $class->meta->get_all_attributes ) {
		if ($attr->isa('ModelSEED::Meta::Attribute::Typed') && $attr->printOrder() != -1 && ($attr->type() eq "attribute" || $attr->type() eq "msdata")) {
			push(@{$attributes},$attr->name());
			$priority->{$attr->name()} = $attr->printOrder();
		} elsif ($attr->isa('ModelSEED::Meta::Attribute::Typed') && $attr->printOrder() != -1 && $attr->type() =~ m/^result/) {
			push(@{$attributesRS},$attr->name());
			$priorityRS->{$attr->name()} = $attr->printOrder();
		} elsif ($attr->isa('ModelSEED::Meta::Attribute::Typed') && $attr->printOrder() != -1) {
			push(@{$attributesSO},$attr->name());
			$prioritySO->{$attr->name()} = $attr->printOrder();
		}
	}
	my $sortedAtt = [sort { $priority->{$a} <=> $priority->{$b} } @{$attributes}];
	my $sortedSO = [sort { $prioritySO->{$a} <=> $prioritySO->{$b} } @{$attributesSO}];
	my $sortedRS = [sort { $priorityRS->{$a} <=> $priorityRS->{$b} } @{$attributesRS}];
	return ($sortedAtt,$sortedSO,$sortedRS);
}
######################################################################
#SubObject manipulation functions
######################################################################
sub clearSubObject {
    my ($self, $attribute) = @_;
	$self->$attribute([]);	
}

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
    my $source = lc($attribute);
    if ($sourceType eq 'ModelSEED::Store') {
        my $ref = ModelSEED::Reference->new(uuid => $uuid, type => $source);
        return $self->store->get_object($ref);
    } else {
        my $source = lc($sourceType);
        my $sourceObj = $self->$source();
        if (!defined($sourceObj)) {
            ModelSEED::utilities::ERROR("Cannot obtain source object ".$sourceType." for ".$attribute." link!");
        }
        return $sourceObj->getObject($attribute,$uuid);
    }
}

sub getLinkedObjectArray {
    my ($self, $sourceType, $attribute, $array) = @_;
    my $list = [];
    foreach my $item (@{$array}) {
    	push(@{$list},$self->getLinkedObject($sourceType,$attribute,$item));
    }
    return $list;
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

sub fbaproblem {
    my ($self) = @_;
    my $parent = $self->parent();
    if (defined($parent) && ref($parent) eq "ModelSEED::MS::FBAProblem") {
        return $parent;
    } elsif (defined($parent)) {
        return $parent->fbaproblem();
    }
    ModelSEED::utilities::ERROR("Cannot find fbaproblem object in tree!");
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

sub __version__ { $VERSION }
sub __upgrade__ { return sub { return $_[0] } }

__PACKAGE__->meta->make_immutable;
1;
