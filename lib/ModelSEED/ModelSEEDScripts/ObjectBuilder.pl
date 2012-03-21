use strict;
use ModelSEED::MS::MetaData::Definitions;
use ModelSEED::utilities;
use DateTime;

my $objects = ModelSEED::MS::DB::Definitions::objectDefinitions();

foreach my $name (keys(%{$objects})) {
	my $object = $objects->{$name};
	#Creating header
	my $output = [
		"########################################################################",
		"# ModelSEED::MS::DB::".$name." - This is the moose object corresponding to the ".$name." object",
		"# Authors: Christopher Henry, Scott Devoid, Paul Frybarger",
		"# Contact email: chenry\@mcs.anl.gov",
		"# Development location: Mathematics and Computer Science Division, Argonne National Lab",
		"# Date of module creation: ".DateTime->now()->datetime(),
		"########################################################################"
	];
	#Creating perl use statements
	my $baseObject = "BaseObject";
	if ($object->{class} eq "parent") {
		$baseObject = "IndexedObject";	
	}
	push(@{$output},(
		"use strict;",
		"use namespace::autoclean;",
		"use ModelSEED::MS::".$baseObject.";"
	));
	if (defined($object->{parents}->[0])) {
		push(@{$output},"use ModelSEED::MS::".$object->{parents}->[0].";");
	}
	foreach my $subobject (@{$object->{subobjects}}) {
		if ($subobject->{type} !~ /hasharray/) {
			push(@{$output},"use ModelSEED::MS::".$subobject->{class}.";");
		}
	}
	foreach my $subobject (@{$object->{links}}) {
		push(@{$output},"use ModelSEED::MS::".$subobject->{class}.";");
	}
	#Creating package statement
	push(@{$output},"package ModelSEED::MS::DB::".$name.";");
	push(@{$output},"use Moose;");
	#Determining and setting base class
	push(@{$output},("extends 'ModelSEED::MS::".$baseObject."';","",""));
	#Printing parent
	my $type = ", type => 'parent', metaclass => 'Typed'";
	if (defined($object->{parents}->[0])) {
		push(@{$output},("# PARENT:"));
		push(@{$output},"has parent => (is => 'rw',isa => 'ModelSEED::MS::".$object->{parents}->[0]."'".$type.",weak_ref => 1);");
		push(@{$output},("",""));
	}
	#Printing attributes
	push(@{$output},("# ATTRIBUTES:"));
	$type = ", type => 'attribute', metaclass => 'Typed'";
	my $uuid = 0;
	my $modDate = 0;
	foreach my $attribute (@{$object->{attributes}}) {
		my $suffix = "";
		if (defined($attribute->{req}) && $attribute->{req} == 1) {
			$suffix .= ", required => 1";
		}
		if (defined($attribute->{default})) {
			$suffix .= ", default => '".$attribute->{default}."'";
		}
		if ($attribute->{name} eq "uuid") {
			$suffix .= ", lazy => 1, builder => '_builduuid'";
			$uuid = 1;
		}
		if ($attribute->{name} eq "modDate") {
			$suffix .= ", lazy => 1, builder => '_buildmodDate'";
			$modDate = 1;
		}
		push(@{$output},"has ".$attribute->{name}." => ( is => '".$attribute->{perm}."', isa => '".$attribute->{type}."'".$type.$suffix." );");
	}
	push(@{$output},("",""));
	#Printing ancestor
	if ($uuid == 1) {
		push(@{$output},("# ANCESTOR:"));
		my $type = ", type => 'acestor', metaclass => 'Typed'";
		push(@{$output},"has ancestor_uuid => (is => 'rw',isa => 'uuid'".$type.");");
	}
	push(@{$output},("",""));
	#Printing subobjects
	my $typeToFunction;
	if (defined($object->{subobjects}) && defined($object->{subobjects}->[0])) {
		push(@{$output},("# SUBOBJECTS:"));
		foreach my $subobject (@{$object->{subobjects}}) {
			$typeToFunction->{$subobject->{class}} = $subobject->{name};
			$type = ", type => '".$subobject->{type}."(".$subobject->{class}.")', metaclass => 'Typed'";
			if ($subobject->{type} =~ m/hasharray\((.+)\)/) {
				$type = ", type => 'hasharray(".$subobject->{class}.",".$1.")', metaclass => 'Typed'";
				push(@{$output},"has ".$subobject->{name}." => (is => 'rw',default => sub{return {};},isa => 'HashRef[ArrayRef]'".$type.");");
			} elsif ($subobject->{type} =~ m/link/) {				
				$type = ", type => 'solink(".$subobject->{parent}.",".$subobject->{class}.",".$subobject->{query}.",".$subobject->{attribute}.")', metaclass => 'Typed'";
				push(@{$output},"has ".$subobject->{name}." => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::".$subobject->{class}."]'".$type.",weak_ref => 1);");
			} else {
				push(@{$output},"has ".$subobject->{name}." => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::".$subobject->{class}."]'".$type.");");
			}
		}
		push(@{$output},("",""));
	}
	#Printing object links
	if (defined($object->{links}) && defined($object->{links}->[0])) {
		push(@{$output},("# LINKS:"));
		foreach my $subobject (@{$object->{links}}) {
			$type = ", type => 'link(".$subobject->{parent}.",".$subobject->{class}.",".$subobject->{query}.",".$subobject->{attribute}.")', metaclass => 'Typed'";
			push(@{$output},"has ".$subobject->{name}." => (is => 'rw',lazy => 1,builder => '_build".$subobject->{name}."',isa => 'ModelSEED::MS::".$subobject->{class}."'".$type.",weak_ref => 1);");
		}
		push(@{$output},("",""));
	}
	#Printing builders
	push(@{$output},("# BUILDERS:"));
	if ($uuid == 1) {
		push(@{$output},"sub _builduuid { return Data::UUID->new()->create_str(); }");
	}
	if ($modDate == 1) {
		push(@{$output},"sub _buildmodDate { return DateTime->now()->datetime(); }");
	}
	foreach my $subobject (@{$object->{links}}) {
		push(@{$output},(
			"sub _build".$subobject->{name}." {",
				"\tmy (\$self) = \@_;",
				"\treturn \$self->getLinkedObject('".$subobject->{parent}."','".$subobject->{class}."','".$subobject->{query}."',\$self->".$subobject->{attribute}."());",
			"}"
		));
	}
	push(@{$output},("",""));
	#Printing constants
	push(@{$output},("# CONSTANTS:"));
	push(@{$output},"sub _type { return '".$name."'; }");
	if ($baseObject eq "IndexedObject") {
		push(@{$output},"sub _typeToFunction {");
		push(@{$output},"\treturn {");
		foreach my $key (keys(%{$typeToFunction})) {
			push(@{$output},"\t\t".$key." => '".$typeToFunction->{$key}."',");
		}
		push(@{$output},"\t};");
		push(@{$output},"}");
	}
	push(@{$output},("",""));
	#Finalizing
	push(@{$output},("__PACKAGE__->meta->make_immutable;","1;"));
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
			"use namespace::autoclean;",
			"use ModelSEED::MS::DB::".$name.";",
			"package ModelSEED::MS::".$name.";",
			"use Moose;",
			"extends 'ModelSEED::MS::DB::".$name."';",
			"# CONSTANTS:",
			"#TODO",
			"# FUNCTIONS:",
			"#TODO",
			"",
			"",
			"__PACKAGE__->meta->make_immutable;",
			"1;"
		];
		ModelSEED::utilities::PRINTFILE("../MS/".$name.".pm",$output);
	}
}
