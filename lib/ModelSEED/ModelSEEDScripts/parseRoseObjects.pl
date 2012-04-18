########################################################################
# Script that parses the RoseDB object files and outputs moose object definitions
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 3/12/2012
########################################################################
use strict;
use ModelSEED::utilities;
use Try::Tiny;
use File::Temp;
use Cwd;

my $directory = "../DB/";

my $objects = [ qw(
	Biochemistry
	Compartment
	Compound
	CompoundStructure
	CompoundPk
	Reaction
	Reagent
	ReagentTransport
	DefaultTransportedReagent
	Media
	MediaCompound
	Compoundset
	Reactionset
	Model
	Biomass
	BiomassCompound
	ModelCompartment
	ModelReaction
	ModelReactionRawGPR
	ModelTransportedReagent
	Modelfba
	ModelfbaCompound
	ModelfbaReaction
	ModelessFeature
	Annotation
	Genome
	Feature
	Mapping
	Role
	RoleSet
	ReactionRule
	ReactionRuleTransport
	Complex
	ComplexRole
	ComplexReactionRule
) ];

my $translation = {
	character => "Str",
	datetime => "Str",
	integer => "Int",
	varchar => "Str",
	text => "Str",
	"scalar" => "Num",
	"float" => "Num"
};

my $output = [];
foreach my $key (@{$objects}) {
	if (-e $directory.$key.".pm") {
		my $data = ModelSEED::utilities::LOADFILE($directory.$key.".pm");
		my $atts = 0;
		my $object;
		for (my $i=0; $i < @{$data}; $i++) {
			if ($atts == 0 && $data->[$i] =~ m/^__PACKAGE__/ && defined($data->[$i+1])) {
				$i++;
				if ($data->[$i] =~ m/table\s*\=\>\s*\'(\w)\',/) {
					$object->{table} = $1;
				}
			} elsif ($atts == 0 && $data->[$i] =~ m/^\s*columns\s*\=\>\s*\[/) {
				$atts = 1;
			} elsif ($atts == 1 && $data->[$i] =~ m/^\s*(\w+)\s*\=\>\s*{\s*type\s*=>\s*\'(\w+)\'.+\}/) {
				my $type = $2;
				if (defined($translation->{$type})) {
					$type = $translation->{$type};
				} else {
					print "Unrecognized type: ".$type."\n";	
				}
				my $attribute = {perm => "rw",name => $1,type => $type,req => 0};
				if ($data->[$i] =~ m/^\s*\w+\s*\=\>\s*{.+,\s*length\s*=>\s*(\d+)/) {
					$attribute->{len} = $1;
				}
				if ($data->[$i] =~ m/^\s*\w+\s*\=\>\s*{.+,\s*not_null\s*=>\s*(\d+)/) {
					$attribute->{req} = $1;
				}
				push(@{$object->{attributes}},$attribute);
			} elsif ($atts == 1 && $data->[$i] =~ m/^\s*\],/) {
				$atts = 0;
			} elsif ($atts == 0 && $data->[$i] =~ m/^\s*primary_key_columns\s*=>\s*\[(.+)\],/) {
				my $data = $1;
				$data =~ s/[\s\']//g;
				$object->{primarykeys} = [split(/,/,$data)];
			}
		}
		push(@{$output},"\$objectDefinitions->{".$key."} = {");
		push(@{$output},"\ttable => '".$object->{table}."',");
		push(@{$output},"\tparents => ['biochemistry'],");
		push(@{$output},"\tclass => 'tracked',");
		push(@{$output},"\tattributes => [");
		foreach my $attribute (@{$object->{attributes}}) {
			if (defined($attribute->{len})) {
				push(@{$output},"\t\t{name => '".$attribute->{name}."',perm => '".$attribute->{perm}."',type => '".$attribute->{type}."',len => ".$attribute->{len}.",req => ".$attribute->{req}."},");
			} else {
				push(@{$output},"\t\t{name => '".$attribute->{name}."',perm => '".$attribute->{perm}."',type => '".$attribute->{type}."',req => ".$attribute->{req}."},");	
			}
		}
		push(@{$output},"\t],");
		push(@{$output},"\tsubobjects => [");
		push(@{$output},"\t],");
		if (defined($object->{primarykeys})) {
			push(@{$output},"\tprimarykeys => [ qw(".join(" ",@{$object->{primarykeys}}).") ],");
		}
		push(@{$output},"\tlinks => [");
		push(@{$output},"\t]");
		push(@{$output},"};");
		push(@{$output},"");
	}
}
ModelSEED::utilities::PRINTFILE("../MS/objectData.txt",$output);
