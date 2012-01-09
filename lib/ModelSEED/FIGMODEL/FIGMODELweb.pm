use strict;
package ModelSEED::FIGMODEL::FIGMODELweb;
#use WebComponent::WebGD;
#use WebColors;
use Scalar::Util qw(weaken);
use Carp qw(cluck);

=head1

=head2 Introduction
Module for generating of the model-associated webpages

=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELweb = FIGMODELweb->new();
Description:
	This is the constructor for the FIGMODELweb object.
=cut

sub new {
	my ($class,$figmodel) = @_;
	my $self;
	$self->{"_figmodel"}->[0] = $figmodel;
    weaken($self->{"_figmodel"}->[0]);
	bless $self;

	return $self;
}

=head3 error_message
Definition:
	string:message text = FIGMODELweb->error_message(string::message);
Description:
=cut
sub error_message {
	my ($self,$args) = @_;
	$args->{"package"} = "FIGMODELweb";
    return $self->figmodel()->new_error_message($args);
}

=head3 figmodel
Definition:
	FIGMODEL = FIGMODELweb->figmodel();
Description:
	Returns a FIGMODEL object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{"_figmodel"}->[0];
}

=head3 cgi
Definition:
	FIGMODEL = FIGMODELweb->cgi();
Description:
	Returns a cgi object
=cut
sub cgi {
	my ($self,$cgi) = @_;
	if (defined($cgi)) {
		$self->{"_cgi"}->[0] = $cgi;
	}
	return $self->{"_cgi"}->[0];
}

=head3 config
Definition:
	ref::key value = FIGMODELweb->config(string::key);
Description:
	Trying to avoid using calls that assume configuration data is stored in a particular manner.
	Call this function to get file paths etc.
=cut
sub config {
	my ($self,$key) = @_;
	return $self->figmodel()->config($key);
}

=head3 get_model_overview_tbl()
Definition:
	string = FIGMODELweb->get_model_overview_tbl();
Description:
=cut
sub get_model_overview_tbl {
	my ($self,$model_ids,$mgrast) = @_;
    my $colors = WebColors::get_palette( 'varied' );
    my $download_link = "http://bioseed.mcs.anl.gov/~chenry/SBMLModels/";
    #Getting the user name
    my $username = "";
    my $userid = "NONE";
    if ($self->figmodel()->user() ne "PUBLIC") {
		$userid = $self->figmodel()->user();
		$username = "&username=".$self->figmodel()->user();
    }
	#Getting all models and determining if the upload column should appear
    my $rows = '';
    my $modelList;
    for (my $i=0; $i < @$model_ids; $i++) {
        my $model = $self->figmodel()->get_model($model_ids->[$i]);
		if (defined($model)) {
			push(@{$modelList},$model);
		}
    }
    if (!defined($modelList)) {
    	return "";
    }
    #Creating the header for the overview table
    my $header = "<tr><th style='width: 100px;'>Model ID</th>";
	if (defined($mgrast) && $mgrast == 1) {
		$header .= "<th style='width: 150px;'>Metagenome/organism</th>";
	} else {
		$header .= "<th style='width: 150px;'>Organism</th>";
	}
	$header .= "<th style='width: 80px;' >Version</th><th style='width: 80px;' >Source</th>";
	if (!defined($mgrast) || $mgrast != 1) {
		$header .= "<th style='width: 80px;'>Class</th>";
	}
	$header .= "<th style='width: 80px;' >Genome size</th><th style='width: 80px;' >Model genes</th><th style='width: 80px;' >Reactions with genes </th><th style='width: 80px;' >Gapfilling Reactions</th>".
	"<th style='width: 80px;' >Gapfilling Media</th><th style='width: 80px;' >Compounds</th><th style='width: 80px;' >Download</th>";
    if( @$modelList > 1 ) {
        $header .= "<td style='width: 80px; padding-top:5px'><small>(<a href=\"javascript:removeAllModels();\">clear all</a>)</small></td></tr>";
    } else {
        $header .= "<td style='width: 80px; padding-top:5px'></td></tr>";
    }
    #Filling in the rows of the model overview table
    for (my $i=0; $i < @$modelList; $i++) {
	    # Generate a color key for the rest of the page
	    my $box = new WebGD( 12, 12 );
	    $box->colorResolve( @{$colors->[$i]} );
	    #Loading summary data for the models
	    my $model = $modelList->[$i];
	    my $row = "<tr><td><img src='".$box->image_src()."'>&nbsp;".$model->id()."</td>";
	    my $genomelink = '<a style="text-decoration:none" href="?page=Organism&organism='.$model->genome().'" target="_blank">'.$model->genome()."</a>";
	    if ($model->source() =~ m/RAST/) {
	    	$genomelink = '<a href="http://rast.nmpdr.org/seedviewer.cgi?page=Organism&organism='.$model->genome().'" target="_blank">'.$model->genome()."</a>";
	    }
	    $row .= "<td> ".$model->name()."<br>(".$genomelink.")</td>";
	    if ($model->status() < 0) {
	    	$row .= "<td>Model under construction</td>";
	    	$row .= "<td>".$self->create_model_source_link($model)."</td>";
	    	$row .= '<td title="Will be calculated when model is constructed">--</td><td title="Will be calculated when model is constructed">--</td><td title="Will be calculated when model is constructed">--</td><td title="Will be calculated when model is constructed">--</td><td title="Will be calculated when model is constructed">--</td><td title="Will be calculated when model is constructed">--</td><td title="Will be calculated when model is constructed">--</td>';
			$row .= '<td>Unavailable</td>';
	    } else {
	    	$row .= "<td>".$model->version()."</td>";
	    	$row .= "<td>".$self->create_model_source_link($model)."</td>";
	    	my $total_genes = $model->genome_genes();
		    my $genes_with_rxn = $model->model_genes();
		    my $total_rxn = $model->total_reactions();
		    my $gapfilling = $model->gapfilling_reactions();
		    my $rxn_with_genes = $model->gene_reactions();
		    my $cpds = $model->total_compounds();
		    my $size = $model->genome_size();
		    my $gapfillingmedia = $model->ppo()->autoCompleteMedia();
		    my $mediacompounds = "All transportable nutrients available";
		    #Adding commas to the large numbers to make them more readable
		    while($genes_with_rxn =~ s/(\d+)(\d{3})+/$1,$2/){};
		    while($total_genes =~ s/(\d+)(\d{3})+/$1,$2/){};
		    while($rxn_with_genes =~ s/(\d+)(\d{3})+/$1,$2/){};
		    while($total_rxn =~ s/(\d+)(\d{3})+/$1,$2/){};
		    while($cpds =~ s/(\d+)(\d{3})+/$1,$2/){};
		    while($size =~ s/(\d+)(\d{3})+/$1,$2/){};
			if (!defined($mgrast) || $mgrast != 1) {
				$row .= "<td>".$model->class()."</td>";
			}
			$row .= "<td>".substr($size,0,length($size)-4)." KB</td><td title='Model genes/Total genes'>" . $genes_with_rxn. "<br>/".$total_genes. "</td>" .
			"<td title='Reactions with genes/Total reactions'>" .  $rxn_with_genes ."<br>/".$total_rxn . "</td><td title='Gap filling reactions/Total reactions'>" . $gapfilling ."/".$total_rxn. "</td>" .
			"<td title='".$mediacompounds."'>".$gapfillingmedia."</td><td>" .$cpds . "</td><td><small>".$self->create_model_download_link($model->id())."</small></td>"; 
	    }
	    $row .= "<td style='padding-top:5px;'><small>(<a href='javascript:removeModelParam(\"".$model->id()."\")'>remove</a>)</small></td></tr>";
    	$rows .= $row;
    }
    #Returning the completed table
    my $model_overview = "<div><table>" . $header . $rows . "</table></div>";
    return $model_overview;
}

=head3 display_reaction_roles()
Definition:
	string = FIGMODELweb->display_reaction_roles(string:reaction ID);
Description:
=cut
sub display_reaction_roles {
	my ($self,$rxn) = @_;
	my $roleHash = $self->figmodel()->mapping()->get_role_rxn_hash();
	if (!defined($roleHash->{$rxn})) {
		return "None";
	}
	my $list;
	foreach my $role (keys(%{$roleHash->{$rxn}})) {
		push(@{$list},$roleHash->{$rxn}->{$role}->name());
	}
	return join("<br><br>",@{$list});
}

=head3 display_reaction_subsystems()
Definition:
	string = FIGMODELweb->display_reaction_subsystems(string:reaction ID);
Description:
=cut
sub display_reaction_subsystems {
	my ($self,$rxn) = @_;
	my $subsysHash = $self->figmodel()->mapping()->get_subsy_rxn_hash();
	if (!defined($subsysHash->{$rxn})) {
		return "None";
	}
	my $list;
	foreach my $subsys (keys(%{$subsysHash->{$rxn}})) {
		push(@{$list},$subsysHash->{$rxn}->{$subsys}->name());
	}
	if (defined($list)) {
		return join("|",@{$list});
	}
	return "";
}

=head3 display_keggmaps()
Definition:
	string = FIGMODELweb->display_keggmaps({type => string:entity type,
											data => entity id});
Description:
=cut
sub display_keggmaps {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["type","data"]);
	if (defined($args->{error})) {
		return "Error";	
	}
	my $mapHash = $self->figmodel()->get_map_hash($args);
	if (!defined($mapHash->{$args->{data}})) {
		return "None";
	}
	my $list;
	foreach my $diagram (keys(%{$mapHash->{$args->{data}}})) {
		my $modelString = "";
		if (defined($self->cgi()->param('model'))) {
			$modelString = "&model=".$self->cgi()->param('model');
		}
		push(@{$list},'<a href=\'javascript:addTab("'.$mapHash->{$args->{data}}->{$diagram}->altid().'","'.$mapHash->{$args->{data}}->{$diagram}->name().'","keggMapTabs","build_map","pathway='.$mapHash->{$args->{data}}->{$diagram}->altid().$modelString.'&component=ModelMap|viewmap&mapInNewTab=keggMapTabs");tab_view_select(4,0)\'>'.$mapHash->{$args->{data}}->{$diagram}->name().'</a>');
	}
	return join("<br><br>",@{$list});
}

=head3 display_alias()
Definition:
	string = FIGMODELweb->display_alias({object => string:PPOobject,
										 function => string:PPOobject function,
										 type => string:alias type,
										 -delimiter => string:delimiter for output});
Description:
=cut
sub display_alias {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["data","object","function","type"],{
		-delimiter => ",<br>"
	});
	return $self->error_message({function => "display_alias",args=>$args}) if (defined($args->{error}));
	if (!defined($self->{_aliashash}->{$args->{object}}->{$args->{type}})) {
		my $objs = $self->figmodel()->database()->get_objects($args->{object},{type=>$args->{type}});
		for (my $i=0; $i < @{$objs}; $i++) {
			my $function = $args->{function};
			push(@{$self->{_aliashash}->{$args->{object}}->{$args->{type}}->{$objs->[$i]->$function()}},$objs->[$i]->alias());
		}
	}
	if (!defined($self->{_aliashash}->{$args->{object}}->{$args->{type}}->{$args->{data}}->[0])) {
		return "None";	
	}
	return join($args->{-delimiter},@{$self->{_aliashash}->{$args->{object}}->{$args->{type}}->{$args->{data}}});
}

=head3 display_reaction_notes()
Definition:
	string = FIGMODELweb->display_reaction_notes({
		data => string:reaction id,
		rxnDataHash => ?:{string:reaction ids => PPO:rxnmdl}
	});
Description:
=cut
sub display_reaction_notes {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["data","dataHash","model"],{});
	if (!defined($args->{"dataHash"}->{$args->{data}->{_rtid}}->{models}->{$args->{model}})) {
		return "Not in model";
	}
	return $args->{"dataHash"}->{$args->{data}->{_rtid}}->{models}->{$args->{model}}->notes();
}

=head3 display_reaction_equation()
Definition:
	string = FIGMODELweb->display_reaction_equation(PPOreaction:reaction object);
Description:
=cut
sub display_reaction_equation {
	my ($self,$args) = @_;
	$args = ModelSEED::globals::ARGS($args,["cpdHash","data"],{dataHash => undef});
	my $direction = "=>";
	#Determining reaction direction
	if ($args->{data}->id() !~ m/bio/) {
		if (defined($args->{dataHash}->{$args->{data}->{_rtid}}->{models})) {
			my $list = [keys(%{$args->{dataHash}->{$args->{data}->{_rtid}}->{models}})];
			$direction =  $args->{dataHash}->{$args->{data}->{_rtid}}->{models}->{$list->[0]}->directionality();
			if ($direction ne "<=>") {
				for (my $i=1; $i < @{$list};$i++) {
					if ($args->{dataHash}->{$args->{data}->{_rtid}}->{models}->{$list->[$i]}->directionality() ne $direction) {
						$direction = "<=>";
						last;
					}
				}
			}
		} else {
			$direction = $args->{data}->thermoReversibility();
		}
	}
	#Substituting direction in equation
	my $Equation = $args->{data}->equation();
	$Equation =~ s/<*=>*/$direction/;
	#Replacing compound IDs with compound names
	$_ = $Equation;
	my @OriginalArray = /(cpd\d\d\d\d\d)/g;
	my %VisitedLinks;
	for (my $i=0; $i < @OriginalArray; $i++) {
	  if (!defined($VisitedLinks{$OriginalArray[$i]})) {
		$VisitedLinks{$OriginalArray[$i]} = 1;
		my $Link = "|ERROR";
		if (defined($args->{cpdHash}->{$OriginalArray[$i]})) {
			$Link = "|".$args->{cpdHash}->{$OriginalArray[$i]}->name();
		}
		my $Find = $OriginalArray[$i];
		$Equation =~ s/$Find(\[\D\])/$Link$1|/g;
		$Equation =~ s/$Find/$Link|/g;
	  }
	}
	return $Equation;
}

=head3 display_reaction_enzymes()
Definition:
	string = FIGMODELweb->display_reaction_enzymes(string:enzyme list);
Description:
=cut
sub display_reaction_enzymes {
	my ($self,$rxnObj) = @_;
	if ($rxnObj->id() !~ /rxn\d\d\d\d\d/ || !defined($rxnObj->enzyme()) || length($rxnObj->enzyme()) == 0) {
		return "Undetermined";	
	}
	my $enzymes = $rxnObj->enzyme();
	$enzymes =~ s/\|/, /g;
	$enzymes =~ s/^,//g;
	$enzymes =~ s/,$//g;
	return $enzymes;
}

=head3 display_reaction_flux()
Definition:
	string = FIGMODELweb->display_reaction_flux({string:flux ID,string:rxn ID});
Description:
=cut
sub display_reaction_flux {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["fluxid","data"],{});
	if (defined($args->{error})) {
		return "Error";	
	}
	if (!defined($self->{_fluxes}->{$args->{fluxid}})) {
		my @tempArray = split(/_/,$args->{fluxid});
		my $obj = $self->figmodel()->database()->get_object("fbaresult",{_id => $tempArray[1]});
		if (defined($obj)) {
			$self->{_fluxes}->{$args->{fluxid}}->{object} = $obj;
			$self->{_fluxes}->{$args->{fluxid}}->{model} = $self->figmodel()->get_model($obj->model());	
		} else {
			print STDERR "Flux ID not found: ".$tempArray[1]."\n";
		}
		if (!defined($self->{_fluxes}->{$args->{fluxid}}->{model})) {
			$self->{_fluxes}->{$args->{fluxid}} = {};
			print STDERR "Flux ID model not found: ".$tempArray[1]."\n";
		}
	}
	if (defined($self->{_fluxes}->{$args->{fluxid}}->{model})) {
		return $self->{_fluxes}->{$args->{fluxid}}->{model}->get_reaction_flux({fluxobj => $self->{_fluxes}->{$args->{fluxid}}->{object}, id => $args->{data}});
	}
	return "None"
}

=head3 compound_model_column()
Definition:
	string = FIGMODELweb->compound_model_column({
		data => string:object id,
		model => FIGMODELmodel:model
	});
Description:
=cut
sub compound_model_column {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["model","data"],{});
	my $output = "";
	my $cpd = $args->{model}->get_compound_data($args->{data});
	if (!defined($cpd)) {
		return "Not in model";
	}
	if (defined($cpd->{COMPARTMENTS})) {
		for (my $i=0; $i < @{$cpd->{COMPARTMENTS}}; $i++) {
			if (length($output) > 0) {
				$output .= "<br>";
			}
			if (defined($self->figmodel()->config("compartments")->{$cpd->{COMPARTMENTS}->[$i]}->[0])) {
				$output .= $self->figmodel()->config("compartments")->{$cpd->{COMPARTMENTS}->[$i]}->[0];
			} else {
				$output .= $cpd->{COMPARTMENTS}->[$i];
			}
		}
	} else {
		$output = "Cytosol";
	}
	if (defined($cpd->{BIOMASS})) {
		$output .= "<br>Biomass";
	}
	return $output;
}

=head3 reaction_model_column()
Definition:
	string = FIGMODELweb->reaction_model_column({
		data => {},
		rxnclasses => {},
		dataHash => {},
		modelid => string
	});
Description:
=cut
sub reaction_model_column {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["data","rxnclasses","dataHash","modelid","featuretbl"],{});
	if (!defined($args->{dataHash}->{$args->{data}->{_rtid}}->{models}->{$args->{modelid}})) {
		return "Not in model";
	}	
	my $rxnMdlData = $args->{dataHash}->{$args->{data}->{_rtid}}->{models}->{$args->{modelid}};
	#Getting the reaction class
	my $output;
	my $rxnclass = $self->reactionClassHtml({
		classtbl => $args->{rxnclasses},
		data => $rxnMdlData->REACTION()
	});
	if (defined($rxnclass)) {
		$output = $rxnclass."<br>";
	}
	#Handling genes
    if (!defined($rxnMdlData->pegs()) || length($rxnMdlData->pegs()) == 0) {
		$output .= "UNKNOWN";
		return $output;
	}
	#Handling normal genomes
	my $PegString = $rxnMdlData->pegs();
	if ($PegString !~ m/\d/ && $PegString !~ m/SPONT/) {
		return "Gap filling";
	}
	$PegString =~ s/\sor\s/|/g;
	$PegString =~ s/\sand\s/+/g;
	my @PegList = split(/[\+\|\s\(\)]/,$PegString);
	my $PegHash;
	for (my $n=0; $n < @PegList; $n++) {
	  if (length($PegList[$n]) > 0) {
	  	$PegHash->{$PegList[$n]} = 1;
	  }
	}
	$PegString = join(", <br>",keys(%{$PegHash}));
	$_ = $PegString;
	my @OriginalArray = /(peg\.\d+)/g;
	my $visited;
	for (my $i=0; $i < @OriginalArray; $i++) {
		if (!defined($visited->{$OriginalArray[$i]})) {
			$visited->{$OriginalArray[$i]} = 1;
			my $row = $args->{featuretbl}->get_row_by_key("fig|".$args->{featuretbl}->{_genome}.".".$OriginalArray[$i],"ID");
			if (defined($row)) {
				my $Link = $self->create_feature_link($row);
				my $Find = $OriginalArray[$i];
				$PegString =~ s/$Find(\D)/$Link$1/g;
				$PegString =~ s/$Find$/$Link/g;
			}
		}
	}
	$output .= $PegString;
	$output =~ s/\(\s/(/g;
	$output =~ s/\s\)/)/g;
	return $output;
}

=head3 reactionClassHtml
Definition:
	string = FIGMODELweb->reactionClassHtml({
		classtbl => FIGMODELtable
		data => string:reaction ID
	});
Description:
	Returns reaction class in html form
=cut
sub reactionClassHtml {
	my ($self,$args) = @_;
	$args = ModelSEED::globals::ARGS($args,["classtbl","data"],{showflux => 0});
	my $output = "";
	my $rows = [$args->{classtbl}->get_rows_by_key($args->{data},"REACTION")];
	my $classHash = {
		Positive => "Essential =>",
		Negative => "Essential <=",
		"Positive variable" => "Active =>",
		"Negative variable" => "Active <=",
		Variable => "Active <=>",
		Blocked => "Inactive",
		Dead => "Disconnected"
	};
	if (defined($rows)) {
		for (my $i=0; $i < @{$rows}; $i++) {
			my $row = $rows->[$i];
			if (defined($classHash->{$row->{CLASS}->[0]})) {
				if (length($output) > 0) {
					$output .= "<br>";
				}
				$output = $row->{MEDIA}->[0].":".$classHash->{$row->{CLASS}->[0]};
				if ($args->{showflux} == 1 && $row->{CLASS}->[0] ne "Blocked" && $row->{CLASS}->[0] ne "Dead") {
					$output .= "<br>[Flux: ".sprintf("%.3g",$row->{MAX}->[0])." to ".sprintf("%.3g",$row->{MIN}->[0])."]<br>";
				}
				#$NewClass = "<span title=\"Flux:".$min." to ".$max."\">".$NewClass."</span>";
			} else {
				print STDERR $row->{CLASS}->[0]."\n";
			}
		}
	}
	return $output;
}

=head3 ModelSelectTable()
Definition:
	[[string]]::table data = FIGMODELweb->ModelSelectTable([string]::columns,string::user id);
Description:
	Returns a two dimensional array with the contents for a model select table with the input columns and the specified user ID
=cut
sub ModelSelectTable {
	my ($self,$columns,$userid) = @_;

	#If the user ID is not defined, we assume it is master
	my $modelList;
	if (!defined($userid)) {
		$modelList = $self->figmodel()->get_user_models("master");
	} else {
		for (my $i=0; $i < @{$userid}; $i++) {
			my $templist = $self->figmodel()->get_user_models($userid->[$i]);
			if (defined($templist)) {
				push(@{$modelList},@{$templist});
			}
		}
	}

	#Getting the table row associated with each user model
	my $allrows;
	if (defined($modelList)) {
		for (my $i=0; $i < @{$modelList}; $i++) {
			if ($modelList->[$i]->source() !~ /MGRAST/) {
				push(@{$allrows},$self->ModelSelectTableRow($columns,$modelList->[$i]));
			}
		}
	}
	return $allrows;
}

=head3 ModelSelectTableRow()
Definition:
	[string]::table row = FIGMODELweb->ModelSelectTableRow([string]::columns,FIGMODELmodel::model);
Description:
	Returns the one dimensional row for the model select table for the input model object
=cut
sub ModelSelectTableRow {
	my ($self,$columns,$model) = @_;

	my $output;
	for (my $i=0; $i < @{$columns}; $i++) {
		$output->[$i] = "";
		if ($columns->[$i] eq "id") {
			$output->[$i] = $self->create_model_id_link($model->id());
		} elsif ($columns->[$i] eq "genome") {
			$output->[$i] = $self->create_genome_link($model->genome());
		} elsif ($columns->[$i] eq "message") {
			$output->[$i] = $model->message();
		} elsif ($columns->[$i] eq "sbml") {
			$output->[$i] = $self->create_sbml_link($model);
		} elsif ($columns->[$i] eq "version") {
			$output->[$i] = $model->version();
		} elsif ($columns->[$i] eq "moddata") {
			$output->[$i] = $self->figmodel()->date($model->modification_time());
		} elsif ($columns->[$i] eq "name") {
			$output->[$i] = $model->name();
		} elsif ($columns->[$i] eq "class") {
			$output->[$i] = $model->class();
		} elsif ($columns->[$i] eq "genes") {
			$output->[$i] = $model->model_genes()."/".$self->figmodel()->get_genome_stats($model->genome())->genes();
		} elsif ($columns->[$i] eq "reactions") {
			$output->[$i] = $model->total_reactions();
		} elsif ($columns->[$i] eq "gapfilling") {
			$output->[$i] = $model->gapfilling_reactions();
		} elsif ($columns->[$i] eq "compounds") {
			$output->[$i] = $model->total_compounds();
		} elsif ($columns->[$i] eq "source") {
			if ($model->source() =~ m/PMID\d\d\d\d\d\d\d\d/) {
				$output->[$i] = '<a style="text-decoration:none" href="http://www.ncbi.nlm.nih.gov/pubmed/'.substr($model->source(),4).'" target="_blank">'.$model->source()."</a>";
			} else {
				$output->[$i] = $model->source();
			}
		}

	}
	return $output;
}

=head3 media_table
Definition:
	[[string]]::table columns and rows = FIGMODELweb->media_table([string]::columns,string::user id);
Description:
	Returns a two dimensional array of the data that should be displayed in the media table columns and rows
=cut
sub media_table {
	my ($self,$columns,$tabletype) = @_;

	#First use the table type to determine what media formulations should appear in the table
	my $medialist;
	if ($tabletype eq "ALL") {
		push(@{$medialist},{NAME => ["Complete"], NAMES => ["All compounds"],COMPOUNDS => ["All compounds"]});
		for (my $i=0; $i < $self->figmodel()->database()->get_media_number(); $i++) {
			push(@{$medialist},$self->figmodel()->database()->get_media($i));
		}
	}

	#Now creating the table matrix
	my $rows;
	for (my $j=0; $j < @{$medialist}; $j++) {
		my $output;
		my $media = $medialist->[$j];
		for (my $i=0; $i < @{$columns}; $i++) {
			$output->[$i] = "";
			if ($columns->[$i] eq "id") {
				$output->[$i] = $media->{NAME}->[0];
			} elsif ($columns->[$i] eq "cpdname") {
				if (defined($media->{NAMES})) {
					$output->[$i] = join(", ",$self->create_compound_link(@{$media->{NAMES}}));
				}
			} elsif ($columns->[$i] eq "cpdid") {
				if (defined($media->{COMPOUNDS})) {
					$output->[$i] = join(", ",$self->create_compound_link(@{$media->{COMPOUNDS}}));
				}
			} elsif ($columns->[$i] eq "acselect") {
				$output->[$i] = '<input type="button" value="Select" onClick="select_ac_media('.$media.');">';
			}
		}
		push(@{$rows},$output);
	}

	return $rows;
}

=head3 create_compound_link
Definition:
	(string)::array of links = FIGMODELweb->create_compound_link((string)::list of compounds);
Description:
	Returns an html encoded list of compound links
=cut
sub create_compound_link {
	my ($self,@Compounds) = @_;

	my @Output;
	my $modelString = "";
	if (defined($self->cgi()->param('model'))) {
		$modelString = "&model=".$self->cgi()->param('model');
	}
	for (my $i=0; $i < @Compounds; $i++) {	
		push(@Output,'<a href="?page=CompoundViewer&compound='.$Compounds[$i].$modelString.'" target="_blank">'.$Compounds[$i]."</a>");
	}

	return @Output;
}

=head3 CpdLinks
Definition:
	my ($Link) = $model->CpdLinks($CpdID,$SelectedModel,$Label);
Description:
	This function returns the link for the compound viewer page given a compound ID.
Example:
	my ($Link) = $model->CpdLinks($CpdID,$SelectedModel,$Label);
=cut
sub CpdLinks {
	my ($self,$CpdID,$Label) = @_;
	my $cpdObj;
	my $modelString = "";
	if (defined($self->cgi()->param('model'))) {
		$modelString = "&model=".$self->cgi()->param('model');
	}
	if ($Label ne "IDONLY") {
		$cpdObj = $self->figmodel()->database()->get_object("compound",{id=>$CpdID});	
	}
	if ($Label eq "IDONLY" || !defined($cpdObj)) {
		return '<a href="?page=CompoundViewer&compound='.$CpdID.$modelString.'" target="_blank">'.$CpdID."</a>";
	}
	if ($Label eq "NAME") {
		return '<a style="text-decoration:none" href="?page=CompoundViewer&compound='.$CpdID.$modelString.'" title="'.$CpdID.'" target="_blank">'.$cpdObj->name()."</a>";
	} else {
		return '<a style="text-decoration:none" href="?page=CompoundViewer&compound='.$CpdID.$modelString.'" title="'.$cpdObj->name().'" target="_blank">'.$CpdID."</a>";
	}
}

=head3 get_selected_models
Definition:
	[FIGMODELmodel]:models = FIGMODELweb->get_selected_models();
Description:
	Returns a list of the currently selected models
=cut
sub get_selected_models {
	my ($self) = @_;
	my $models;
	if (defined($self->cgi()->param('model'))) {
		my @array = split(/,/,$self->cgi()->param('model'));
		for (my $i=0; $i < @array; $i++) {
			my $mdlObj = $self->figmodel()->get_model($array[$i]);
			push(@{$models},$mdlObj);	
		}
	}
	return $models;	
}

=head3 create_model_source_link
Definition:
	string:link = FIGMODELweb->create_model_source_link(FIGMODELmodel:model);
Description:
	Returns an html encoded link of model source
=cut
sub create_model_source_link {
	my ($self,$model) = @_;
	my $source = $model->source();
	if ($source =~ m/PMID(\d+)/) {
		$source = "<a href=http://www.ncbi.nlm.nih.gov/pubmed/".$1.">".$model->source()."</a>";
	}
	return $source;
}

=head3 create_kegg_link
Definition:
	(string)::array of links = FIGMODELweb->create_kegg_link((string)::list of compounds);
Description:
	Returns an html encoded list of compound link
=cut
sub create_kegg_link {
	my ($self,$compounds) = @_;

	return '<a href="http://www.genome.jp/dbget-bin/www_bget?cpd:'.$compounds.'" target="_blank">'.$compounds."</a>";
}

=head3 create_reaction_link
Definition:
	string:link = FIGMODELweb->create_reaction_link(string:reaction ID,string:tooltip);
Description:
	Returns the link for the input reaction ID
=cut
sub create_reaction_link {
	my ($self,$reaction,$tooltip,$models) = @_;
	if (!defined($tooltip)) {
		$tooltip = "";
	}
	return '<a style="text-decoration:none" href="seedviewer.cgi?page=ReactionViewer&model='.$models.'&reaction='.$reaction.'" title="'.$tooltip.'" target="_blank">'.$reaction."</a>";
}

=head3 create_feature_link
Definition:
	string:link = FIGMODELweb->create_feature_link(string:feature ID);
Description:
	Returns an html encoded link to the feature
=cut
sub create_feature_link {
	my ($self,$feature) = @_;
	my $genome;
	my $id = $feature->{ID}->[0];
	if ($feature->{ID}->[0] =~ m/fig\|(\d+\.\d+)\.(\D+\.\d+)/) {
		$genome = $1;
		$id = $2;
	}
	my $genomeObj = $self->figmodel()->get_genome($genome);
	if (defined($genomeObj) && $genomeObj->source() =~ m/RAST/) {
		return '<a href="http://rast.nmpdr.org/seedviewer.cgi?page=Annotation&feature='.$feature->{ID}->[0].'" title="'.join("<br>",@{$feature->{ROLES}}).'" target="_blank">'.$id."</a>";
	}
	my $roles = "No roles";
	if (defined($feature->{ROLES})) {
		$roles = join("<br>",@{$feature->{ROLES}});
	}
	return '<a href="http://www.theseed.org/linkin.cgi?id='.$feature->{ID}->[0].'" title="'.$roles.'" target="_blank">'.$id."</a>";
}

sub gene_link {
	my ($self,$GeneID,$SelectedModel) = @_;
	my $model = $self->figmodel()->get_model($SelectedModel);
	my $featureTbl = $model->feature_table();
	my $row = $featureTbl->get_row_by_key("fig|".$model->ppo()->genome().".".$GeneID,"ID");
	return $self->create_feature_link($row);
}

=head3 create_sbml_link
Definition:
	string::link to SBML file = FIGMODELweb->create_sbml_link(FIGMODELmodel::model);
Description:
	Returns a string with the link to the SBML file for the input model object
=cut
sub create_sbml_link {
	my ($self,$id,$type,$title,$name) = @_;
	if (!defined($type)) {
		$type = "SBML";
	}
	if (!defined($title)) {
		$title = "This is the SBML file for the model, useful for running the model in the COBRA toolkit.";
	}
	if (!defined($name)) {
		$name = "SBML format";
	}
	my $Link = '<a  href="ModelSEEDdownload.cgi?model='.$id.'&file='.$type.'" title="'.$title.'">'.$name.'</a>';
	return $Link;
}

=head3 create_model_download_link
Definition:
	string::links to downloadable files = FIGMODELweb->create_model_download_link(string::model ID);
Description:
	Returns a string with the link to the downloadable files for the input model object
=cut
sub create_model_download_link {
	my ($self,$id) = @_;
	my $downloadLinks = "<small>".$self->create_sbml_link($id,"SBML")."<br>";
    $downloadLinks .= $self->create_sbml_link($id, "XLS", "Excel format", "Excel format") . "<br>";
	$downloadLinks .= $self->create_sbml_link($id,"LP","This file can be used directly with any linear optimization software (e.g. GLPK-gnu linear programming kit) to run flux balance analysis on the models.","LP format")."<br></small>";
	return $downloadLinks;
}

=head3 create_genome_link
Definition:
	string::html for link to genome = FIGMODELweb->create_genome_link(string:genome ID);
Description:
	Given a genome ID, this function returns a link to the genome page and includes the genome name
	Used by the GeneTable component.
=cut
sub create_genome_link {
	my ($self,$genome) = @_;
	my $genomeObj = $self->figmodel()->get_genome($genome);
	if (defined($genomeObj) && defined($genomeObj->job())) {
		return '<a href="http://rast.nmpdr.org/seedviewer.cgi?page=Organism&organism='.$genome.'" target="_blank">'.$genome."</a>";
	}
	return '<a style="text-decoration:none" href="?page=Organism&organism='.$genome.'" target="_blank">'.$genome."</a>";
}

=head3 create_model_id_link
Definition:
	string::link to model viewer = FIGMODELweb->create_model_id_link(string::id);
Description:
	Returns a string with the link to the genome page
=cut
sub create_model_id_link {
	my ($self,$id) = @_;

	return '<a href="javascript:select_model('."'".$id."'".');">'.$id.'</a>';
}

=head3 joboutput
Definition:
	string::links to job output = FIGMODELweb->joboutput(object:job object);
Description:
	Given a job object, this function returns links to the job output and error files.
	Used by the QueueManager webpage.
=cut
sub joboutput {
	my ($self,$object) = @_;
	
	my $output = "";
	if (-e "/vol/model-prod/FIGdisk/log/QSubOutput/ModelDriver.sh.o".$object->PROCESSID()) {
		$output =  "<a href=\"?page=QueueManager&file=o".$object->PROCESSID()."\">Output</a>";
	}
	if (-e "/vol/model-prod/FIGdisk/log/QSubError/ModelDriver.sh.e".$object->PROCESSID()) {
		if (length($output) > 0) {
			$output .= "<br>";
		}
		$output .= "<a href=\"?page=QueueManager&file=e".$object->PROCESSID()."\">Errors</a>";
	}
	return $output;
}

=head3 jobcontrols
Definition:
	string::html for ajax controls = FIGMODELweb->jobcontrols(object:job object);
Description:
	Given a job object, this function returns the html for the ajax controls associated with that job.
	Used by the QueueManager webpage.
=cut
sub jobcontrols {
	my ($self,$object) = @_;
	
	if ($object->STATE() == 1) {
		return "<a href=\"javascript:execute_ajax('print_running_tab','0_content_1','job=".$object->ID()."','Loading...','0','post_hook','')\">Kill job</a>";
	} elsif ($object->STATE() == 0) {
		return "<a href=\"javascript:execute_ajax('print_queue_tab','0_content_0','job=".$object->ID()."','Loading...','0','post_hook','')\">Remove job</a><br><a href=\"javascript:execute_ajax('print_queue_tab','0_content_0','top=".$object->ID()."','Loading...','0','post_hook','')\">Move to top</a>";
	}
}

=head3 format_essentiality
Definition:
	string::html for essentiality data = FIGMODELweb->format_essentiality(object:feature object);
Description:
	Given a feature object, this function returns the html for the feature essentiality data.
=cut
sub format_essentiality {
	my ($self,$feature) = @_;
	my $output;
	if (defined($feature->{ESSENTIALITY})) {
		my $essentialityData;
		for (my $i=0; $i < @{$feature->{ESSENTIALITY}};$i++) {
			my @temp = split(/:/,$feature->{ESSENTIALITY}->[$i]);
			push(@{$essentialityData->{$temp[1]}},$temp[0]);
		}
		foreach my $key (keys(%{$essentialityData})) {
			my $string = $key;
			$string = ucfirst($string); 
			push(@{$output},'<span title="'.join(", ",@{$essentialityData->{$key}}).'">'.$string.'</span>');
		}
		return join("<br>",@{$output});
	}
	return "Unknown";
}

sub model_source {
	my ($self,$source) = @_;
	if ($source =~ m/PMID\d\d\d\d\d\d\d\d/) {
		return '<a style="text-decoration:none" href="http://www.ncbi.nlm.nih.gov/pubmed/'.substr($source,4).'" target="_blank">'.$source."</a>";
	}
	return $source;
}

sub model_genes {
	my ($self,$id) = @_;
	my $model = $self->figmodel()->get_model($id);
	if (defined($model)) {
		return $model->model_genes()."/".$self->figmodel()->get_genome_stats($model->genome())->genes();
	}
	return "";
}

sub model_version {
	my ($self,$object) = @_;
	my $model = $self->figmodel()->get_model($object->{id}->[0]);
	if (defined($model)) {
		return $model->version();
	}
	return "";
}

sub print_reaction_equation {
	my ($self,$equation) = @_;
    return $self->figmodel()->EquationLinks($equation,"=>");
}

sub print_biomass_models {
	my ($self,$args) = @_;
	$args = ModelSEED::globals::ARGS($args,["bofModelHash","data"],{});
	if (defined($args->{bofModelHash}->{$args->{data}})) {
		return join(", ",@{$args->{bofModelHash}->{$args->{data}}});
	}
}

sub call_model_function {
	my ($self,$id,@args) = @_;
	my $function = $args[0];
	my $model = $self->figmodel()->get_model($id);
	if (!defined($model)) {
		return "";
	}
	return $model->$function();
}

sub model_modification_time {
	my ($self,$time) = @_;
	#my $model = $self->figmodel()->get_model($id);
	#if (!defined($model)) {
	#	return "unknown";
	#}
	return $self->figmodel()->date($time);
}

sub load_html_from_file {
	my ($self,$filename,$altmessage) = @_;
	my $html = $self->figmodel()->database()->load_single_column_file($filename);
	if (defined($html->[0])) {
		return join("\n",@{$html});
	}
	return "<p>".$altmessage."</p>";
}

sub print_compound_biomass_coef {
	my ($self,$id,@args) = @_;
	my $cpd = $self->figmodel()->database()->get_object("cpdbof",{COMPOUND=>$id,BIOMASS=>$args[0]});
	if (defined($cpd)) {
		my $coef = $cpd->coefficient();
		if ($coef < 0) {
			$coef = -1*$coef;
		}
		return $self->figmodel()->convert_number_for_viewing($coef);
	}
	return "NOT FOUND";
}

sub print_compound_kegg_ids {
	my ($self,$id) = @_;
	my $objs = $self->figmodel()->database()->get_objects("cpdals",{COMPOUND=>$id,type=>"KEGG"});
	my $result = "";
	for (my $i=0; $i < @{$objs}; $i++) {
		if (length($result) > 0) {
			$result .= "<br>";	
		}
		$result .= $self->create_kegg_link($objs->[$i]->alias());
	}
	return $result;
}

sub print_compound_names {
	my ($self,$id) = @_;
	
	my $objs = $self->figmodel()->database()->get_objects("cpdals",{COMPOUND=>$id,type=>"name"});
	my $result = "";
	for (my $i=0; $i < @{$objs}; $i++) {
		if (length($result) > 0) {
			$result .= "<br>";	
		}
		$result .= $objs->[$i]->alias();
	}
	return $result;
}

sub print_compound_group {
	my ($self,$id,@args) = @_;
	return $id;
}

sub build_control {
	my ($self,$id) = @_;
	my $mdl = $self->figmodel()->get_model($id);
	my $html = '<select id="'.$id."_cellWallSelect".'" name="'.$id."_cellWallSelect".'">';
    my @class = ("Gram positive","Gram negative","Unknown");
    for (my $i=0; $i < @class; $i++) {
    	if ($class[$i] eq $mdl->cellwalltype()) {
    		$html .= '<option selected="true">'.$class[$i].'</option>';
    	} else {
    		$html .= '<option>'.$class[$i].'</option>';
    	}	
    }
    $html .= '</select><br><input type="button" onclick="submit_build_control('.$id.');" value="Build/Rebuild Model">';
    return $html;
}

sub gapfill_control {
	my ($self,$id) = @_;
	my $mdl = $self->figmodel()->get_model($id);
	my $html = '<select id="'.$id."_acMediaSelect".'" name="'.$id."_acMediaSelect".'">';
	if (!defined($self->figmodel()->cache("media_objects"))) {
   		$self->figmodel()->set_cache("media_objects",$self->figmodel()->database()->get_objects("media"));
	}
    my $media = $self->figmodel()->cache("media_objects");
    for (my $i=0; $i < @{$media}; $i++) {
    	if ($media->[$i]->id() eq $mdl->autoCompleteMedia()) {
    		$html .= '<option selected="true">'.$media->[$i]->id().'</option>';
    	} else {
    		$html .= '<option>'.$media->[$i]->id().'</option>';
    	}	
    }
    $html .= '</select><br><input type="button" onclick="submit_autocompletion_control('.$id.');" value="Rerun autocomplete">';
    return $html;
}

sub printMediaCompounds {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["data","mediaCpdHash","compoundHash"],{type => "id"});
	my $argTwo = "IDONLY";
	my $mediaHash = $args->{mediaCpdHash};
	my $cpdHash = $args->{compoundHash};
	if ($args->{type} eq "name") {
		$argTwo = "NAME";
	}
	if (!defined($mediaHash->{$args->{data}})) {
		return "Not found";
	}
	my $output;
    for (my $i=0; $i < @{$mediaHash->{$args->{data}}}; $i++) {
    	if ($mediaHash->{$args->{data}}->[$i]->maxFlux() > 0 && $mediaHash->{$args->{data}}->[$i]->entity() =~ m/cpd\d+/) {
    		push(@{$output},$self->CpdLinks($mediaHash->{$args->{data}}->[$i]->entity(),$argTwo));
    	}
    }
    return join(", ",@{$output});
}

sub display_hash_data {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["hash","data","key"],{seckey => undef,tertkey => undef});
	if (!defined($args->{hash}->{$args->{data}})) {
		return "NA";
	}
	my $output = $args->{hash}->{$args->{data}}->{$args->{key}};
	if (defined($args->{tertkey})) {
		$output .= "/".$args->{hash}->{$args->{data}}->{$args->{seckey}}."/".$args->{hash}->{$args->{data}}->{$args->{tertkey}};
	} elsif (defined($args->{seckey})) {
		$output .= " (".$args->{hash}->{$args->{data}}->{$args->{seckey}}.")";
	}
	return $output;
}

1;
