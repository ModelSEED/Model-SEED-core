# try to do away with typeToFunction and functionToType.
# call around methods via $orig, and store class name in info hash

use strict;
use ModelSEED::MS::Metadata::Definitions;
use ModelSEED::utilities;
use DateTime;
use Data::Dumper;

my $objects = ModelSEED::MS::Metadata::Definitions::objectDefinitions();
my $tab = " ";

foreach my $name (keys(%{$objects})) {
    my $object = $objects->{$name};
    #Creating header
    my $output = [
        "########################################################################",
        "# ModelSEED::MS::DB::".$name." - This is the moose object corresponding to the ".$name." object",
        "# Authors: Christopher Henry, Scott Devoid, Paul Frybarger",
        "# Contact email: chenry\@mcs.anl.gov",
        "# Development location: Mathematics and Computer Science Division, Argonne National Lab",
        "########################################################################"
    ];

    #Creating package statement
    push(@$output, "package ModelSEED::MS::DB::" . $name . ";");

    #Creating perl use statements
    my $baseObject = "BaseObject";
    if ($object->{class} eq "indexed") {
        $baseObject = "IndexedObject";
    }
    push(@$output, "use ModelSEED::MS::" . $baseObject . ";");

    foreach my $subobject (@{$object->{subobjects}}) {
        if ($subobject->{type} !~ /hasharray/) {
            push(@$output, "use ModelSEED::MS::" . $subobject->{class} . ";");
        }
    }

    push(@$output,
         "use Moose;",
         "use namespace::autoclean;"
    );

    #Determining and setting base class
    push(@$output, "extends 'ModelSEED::MS::" . $baseObject . "';", "", "");

    #Printing parent
    my $type = ", type => 'parent', metaclass => 'Typed'";
    if (defined($object->{parents}->[0])) {
        my $parent = $object->{parents}->[0];
        push(@$output, "# PARENT:");

        my $props = ["is => 'rw'"];
        if ($parent =~ /ModelSEED::/) {
            push(@$props, "isa => '$parent'");
        } elsif ($parent eq "Ref") {
        	push(@$props, "isa => 'Ref'", "weak_ref => 1");
    	} else {
            push(@$props, "isa => 'ModelSEED::MS::$parent'", "weak_ref => 1");
        }
        push(@$props, "type => 'parent'", "metaclass => 'Typed'");

        push(@$output, "has parent => (" . join(", ", @$props) . ");");
        push(@$output, "", "");
    }

    #Printing attributes
    push(@$output, "# ATTRIBUTES:");
    $type = ", type => 'attribute', metaclass => 'Typed'";
    my $uuid = 0;
    my $modDate = 0;
    my $attrs = [];
    foreach my $attribute (@{$object->{attributes}}) {
        if (!defined($attribute->{printOrder})) {
        	$attribute->{printOrder} = -1;	
        }
        my $props = [
            "is => '" . $attribute->{perm} . "'",
            "isa => '" . $attribute->{type} . "'",
            "printOrder => '". $attribute->{printOrder} ."'"
        ];
        if (defined($attribute->{req}) && $attribute->{req} == 1) {
            push(@$props, "required => 1");
        }
        if (defined($attribute->{default})) {
            if ($attribute->{default} =~ /sub\s*\{/) {
				push(@$props, "default => " . $attribute->{default} );
			} else {
				push(@$props, "default => '" . $attribute->{default} . "'");
			}
        }
        if ($attribute->{name} eq "uuid") {
            push(@$props, "lazy => 1", "builder => '_build_uuid'");
            $uuid = 1;
        }
        if ($attribute->{name} eq "modDate") {
            push(@$props, "lazy => 1", "builder => '_build_modDate'");
            $modDate = 1;
        }
        push(@$props, "type => 'attribute'", "metaclass => 'Typed'");

        push(@$output, "has " . $attribute->{name} . " => (" . join(", ", @$props) . ");");
        push(@$attrs, "'" . $attribute->{name} . "'");
    }
    push(@$output, "", "");

    #Printing ancestor
    if ($uuid == 1) {
        push(@$output, "# ANCESTOR:");
        my $type = ", type => 'ancestor', metaclass => 'Typed'";
        push(@$output, "has ancestor_uuid => (is => 'rw', isa => 'uuid', type => 'ancestor', metaclass => 'Typed');");
        push(@$output, "", "");
    }

    #Printing subobjects
    my $typeToFunction;
    my $functionToType;
	if (defined($object->{subobjects}) && defined($object->{subobjects}->[0])) {
        push(@$output, "# SUBOBJECTS:");
        foreach my $subobject (@{$object->{subobjects}}) {
            if (!defined($subobject->{printOrder})) {
	        	$subobject->{printOrder} = -1;	
	        }
            $typeToFunction->{$subobject->{class}} = $subobject->{name};
            $functionToType->{$subobject->{name}} = $subobject->{class};

            my $soname = $subobject->{name};
            my $class = $subobject->{class};

            my $props = [ "is => 'rw'" ];
            my $type = $subobject->{type};

            push(@$props,
                 "isa => 'ArrayRef[HashRef]'",
                 "default => sub { return []; }",
                 "type => '$type($class)'",
                 "metaclass => 'Typed'",
                 "reader => '_$soname'",
                 "printOrder => '". $subobject->{printOrder} ."'"
            );

            push(@$output, "has $soname => (" . join(", ", @$props) . ");");
        }
        push(@$output, "", "");
    }

    #Printing object links
    if (defined($object->{links})) {
        push(@$output, "# LINKS:");
        foreach my $subobject (@{$object->{links}}) {
            my $soname = $subobject->{name};
            my $parent = $subobject->{parent};
            my $method = $subobject->{method};
            my $attr = $subobject->{attribute};
            my $weak = (defined($subobject->{weak})) ? $subobject->{weak} : 1;
            warn "$name $soname is notweak" if(!$weak);
            # find link class
            my $class;
            foreach my $parent_so (@{$objects->{$parent}->{subobjects}}) {
                if ($parent_so->{name} eq $method) {
                    $class = $parent_so->{class};
                    last;
                }
            }
            if (!defined($class)) {
                $class = $method;
            }
            my $type = 'ModelSEED::MS::'.$class;
            if (defined($subobject->{array}) && $subobject->{array} == 1) {
            	$weak = 0;
            	$type = "ArrayRef[".$type."]";
            }
            my $props = [
                "is => 'rw'",
                "isa => '".$type."'",
                "type => 'link($parent,$method,$attr)'",
                "metaclass => 'Typed'",
                "lazy => 1",
                "builder => '_build_$soname'",
            ];
            push(@$props, "weak_ref => 1") if($weak);
            push(@$output, "has $soname => (" . join(", ", @$props) . ");");
        }
    }
    if (defined($object->{alias})) {
        push(@$output,"has id => (is => 'rw', lazy => 1, builder => '_build_id', isa => 'Str', type => 'id', metaclass => 'Typed');");
    }
    push(@$output, "", "");

    #Printing builders
    push(@$output,("# BUILDERS:"));
    if ($uuid == 1) {
        push(@$output, "sub _build_uuid { return Data::UUID->new()->create_str(); }");
    }
    if ($modDate == 1) {
        push(@$output, "sub _build_modDate { return DateTime->now()->datetime(); }");
    }
    foreach my $subobject (@{$object->{links}}) {
        if (defined($subobject->{array}) && $subobject->{array} == 1) {
	        push(@$output,
	            "sub _build_".$subobject->{name}." {",
	            "$tab my (\$self) = \@_;",
	            "$tab return \$self->getLinkedObjectArray('" . $subobject->{parent} . "','" . $subobject->{method} . "',\$self->" . $subobject->{attribute} . "());",
	            "}"
	        );
        } else {
        	push(@$output,
	            "sub _build_".$subobject->{name}." {",
	            "$tab my (\$self) = \@_;",
	            "$tab return \$self->getLinkedObject('" . $subobject->{parent} . "','" . $subobject->{method} . "',\$self->" . $subobject->{attribute} . "());",
	            "}"
	        );
        }
    }
    push(@$output, "", "");

    #Printing constants
    push(@$output, "# CONSTANTS:");
    push(@$output, "sub _type { return '" . $name . "'; }");


=head1

if (defined($typeToFunction)) {
push(@$output, "", "my \$typeToFunction = {");
foreach my $key (keys(%{$typeToFunction})) {
push(@$output, "$tab $key => '".$typeToFunction->{$key}."',");
}
push(@$output, "};");
push(@$output,
"sub _typeToFunction {",
"$tab my (\$self, \$key) = \@_;",
"$tab if (defined(\$key)) {",
"$tab $tab return \$typeToFunction->{\$key};",
"$tab } else {",
"$tab $tab return \$typeToFunction;",
"$tab }",
"}"
);
}
if (defined($functionToType)) {
push(@$output, "", "my \$functionToType = {");
foreach my $key (keys %$functionToType) {
push(@$output, "$tab $key => '" . $functionToType->{$key} . "',");
}
push(@$output, "};");
push(@$output,
"sub _functionToType {",
"$tab my (\$self, \$key) = \@_;",
"$tab if (defined(\$key)) {",
"$tab $tab return \$functionToType->{\$key};",
"$tab } else {",
"$tab $tab return \$functionToType;",
"$tab }",
"}"
);
}

=cut

    # add _attributes and _subobjects

    my $attr_map = [];
    my $num = 0;
    map {push(@$attr_map, $_->{name} . " => " . $num++)} @{$object->{attributes}};

    my $attributes = Dumper($object->{attributes});
    $attributes =~ s/\$VAR1/my \$attributes/;

    push(@$output, "",
         $attributes,
         "my \$attribute_map = {" . join(", ", @$attr_map) . "};",
         "sub _attributes {",
         "$tab my (\$self, \$key) = \@_;",
         "$tab if (defined(\$key)) {",
         "$tab $tab my \$ind = \$attribute_map->{\$key};",
         "$tab $tab if (defined(\$ind)) {",
         "$tab $tab $tab return \$attributes->[\$ind];",
         "$tab $tab } else {",
         "$tab $tab $tab return undef;",
         "$tab $tab }",
         "$tab } else {",
         "$tab $tab return \$attributes;",
         "$tab }",
         "}"
    );


    my $so_map = [];
    $num = 0;
    map {push(@$so_map, $_->{name} . " => " . $num++)} @{$object->{subobjects}};

    my $subobjects = Dumper($object->{subobjects});
    $subobjects =~ s/\$VAR1/my \$subobjects/;

    push(@$output, "",
         $subobjects,
         "my \$subobject_map = {" . join(", ", @$so_map) . "};",
         "sub _subobjects {",
         "$tab my (\$self, \$key) = \@_;",
         "$tab if (defined(\$key)) {",
         "$tab $tab my \$ind = \$subobject_map->{\$key};",
         "$tab $tab if (defined(\$ind)) {",
         "$tab $tab $tab return \$subobjects->[\$ind];",
         "$tab $tab } else {",
         "$tab $tab $tab return undef;",
         "$tab $tab }",
         "$tab } else {",
         "$tab $tab return \$subobjects;",
         "$tab }",
         "}"
    );

    if (defined($object->{alias})) {
        push(@$output, "sub _aliasowner { return '".$object->{alias}."'; }");
    }

    push(@$output, "", "");

    # print subobject readers
    if (defined($object->{subobjects}) && defined($object->{subobjects}->[0])) {
        push(@$output, "# SUBOBJECT READERS:");
        foreach my $subobject (@{$object->{subobjects}}) {
            push(@$output,
                 "around '" . $subobject->{name} . "' => sub {",
                 "$tab my (\$orig, \$self) = \@_;",
                 "$tab return \$self->_build_all_objects('" . $subobject->{name} . "');",
                 "};"
            );
        }
        push(@$output, "", "");
    }

    #Finalizing
    push(@$output, "__PACKAGE__->meta->make_immutable;", "1;");
    ModelSEED::utilities::PRINTFILE("../MS/DB/".$name.".pm",$output);
    if (!-e "../MS/".$name.".pm") {
        $output = [
            "########################################################################",
            "# ModelSEED::MS::".$name." - This is the moose object corresponding to the ".$name." object",
            "# Authors: Christopher Henry, Scott Devoid, Paul Frybarger",
            "# Contact email: chenry\@mcs.anl.gov",
            "# Development location: Mathematics and Computer Science Division, Argonne National Lab",
            "# Date of module creation: ".DateTime->now()->datetime(),
            "########################################################################",
            "use strict;",
            "use ModelSEED::MS::DB::".$name.";",
            "package ModelSEED::MS::".$name.";",
            "use Moose;",
            "use namespace::autoclean;",
            "extends 'ModelSEED::MS::DB::".$name."';",
            "#***********************************************************************************************************",
            "# ADDITIONAL ATTRIBUTES:",
            "#***********************************************************************************************************",
            "",
            "",
            "#***********************************************************************************************************",
            "# BUILDERS:",
            "#***********************************************************************************************************",
            "",
            "",
            "",
            "#***********************************************************************************************************",
            "# CONSTANTS:",
            "#***********************************************************************************************************",
            "",
            "#***********************************************************************************************************",
            "# FUNCTIONS:",
            "#***********************************************************************************************************",
            "",
            "",
            "__PACKAGE__->meta->make_immutable;",
            "1;"
      ];
        ModelSEED::utilities::PRINTFILE("../MS/".$name.".pm",$output);
    }
}
