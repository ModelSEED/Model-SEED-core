package SubsystemEditor::WebPage::ShowDiagram;

use strict;
use warnings;
use URI::Escape;
use HTML;
use Data::Dumper;

use Diagram;

use FIG;

use base qw( WebPage );

my $translation = {
	"cytosolic" => "cyt",
	"plastidial" => "plast",
	"mitochondrial" => "mit",
	"peroxisomal" => "per",
	"lysosomal" => "lys",
	"vacuolar" => "vac",
	"nuclear" => "nuc",
	"plasma membrane" => "pm",
	"cell wall" => "cw",
	"Golgi apparatus" => "ga",
	"endoplasmic reticulum" => "er"
};

my $revtranslation = {
	cyt => "cytosolic",
	plast => "plastidial",
	mit => "mitochondrial",
	per => "peroxisomal",
	lys => "lysosomal",
	vac => "vacuolar",
	nuc => "nuclear",
	pm => "plasma membrane",
	cw => "cell wall",
	ga => "Golgi apparatus",
	er => "endoplasmic reticulum"
};

1;

##################################################
# Method for registering components etc. for the #
# application                                    #
##################################################
sub init {
  my ( $self ) = @_;

  $self->application->register_component(  'Table', 'sstable'  );
}

sub require_javascript {
  return [ './Html/showfunctionalroles.js',"./Html/PopUp.js" ];
}

##############################################
# Website content is returned by this method #
##############################################
sub output {
  my ( $self ) = @_;
  my $fig = new FIG;
  my $cgi = $self->application->cgi;
  my $genome = $cgi->param('genome_id');
  if (defined($genome)) {
    my $features = $fig->all_features_detailed_fast($genome); 
	my $complist = [keys(%{$translation})];
	foreach my $row (@{$features}) {
		#if ($row->[0] eq "fig|349163.4.peg.1074") {
		#	$row->[6] .= " #mitochondrial";
		#}
		my $compartments;
		for (my $j=0; $j < @{$complist}; $j++) {
			my $query = "\\#.*".$complist->[$j];
			$query =~ s/\s/\\s/g;
			if ($row->[6] =~ m/$query/) {
				push(@{$compartments},$translation->{$complist->[$j]});
			}
		}
		if (!defined($compartments)) {
			$compartments = ["unspecified"];
		}
		my $roles = [$fig->roles_of_function($row->[6])];
		for (my $i=0; $i < @{$roles};$i++) {
			push(@{$self->{_data}->{_roles}->{$roles->[$i]}->{all}},$row->[0]);
			for (my $j=0; $j < @{$compartments}; $j++) {
				push(@{$self->{_data}->{_roles}->{$roles->[$i]}->{$compartments->[$j]}},$row->[0]);
			}
		}
	}
  }
  my $name = $cgi->param( 'subsystem' );
  my $ssname = $name;
  $ssname =~ s/\_/ /g;

  my $esc_name = uri_escape($name);

  my $subsystem = new Subsystem( $name, $fig, 0 );
  
  # look if someone is logged in and can write the subsystem #
  my $can_alter = 0;
  my $user = $self->application->session->user;
  #if ( $user && $user->has_right( $self->application, 'edit', 'subsystem', $name ) ) {
    $can_alter = 1;
  #}

  ######################
  # Construct the menu #
  ######################

  my $menu = $self->application->menu();

  # Build nice tab menu here
  $menu->add_category( 'Subsystem Info', "SubsysEditor.cgi?page=ShowSubsystem&subsystem=$esc_name" );
  $menu->add_category( 'Functional Roles', "SubsysEditor.cgi?page=ShowFunctionalRoles&subsystem=$esc_name" );
  $menu->add_category( 'Subsets', "SubsysEditor.cgi?page=ShowSubsets&subsystem=$esc_name" );
  $menu->add_category( 'Diagrams and Illustrations' );
  $menu->add_entry( 'Diagrams and Illustrations', 'Diagram', "SubsysEditor.cgi?page=ShowDiagram&subsystem=$esc_name" );
  $menu->add_entry( 'Diagrams and Illustrations', 'Illustrations', "SubsysEditor.cgi?page=ShowIllustrations&subsystem=$esc_name" );
  $menu->add_category( 'Spreadsheet', "SubsysEditor.cgi?page=ShowSpreadsheet&subsystem=$esc_name" );
  $menu->add_category( 'Show Check', "SubsysEditor.cgi?page=ShowCheck&subsystem=$esc_name" );
  $menu->add_category( 'Show Connections', "SubsysEditor.cgi?page=ShowTree&subsystem=$esc_name" );

  my $error = '';
  my $comment = '';

  #########
  # TASKS #
  #########

  if ( defined( $cgi->param( 'DELETEBUTTONPRESSED' ) ) && $cgi->param( 'DELETEBUTTONPRESSED' ) == 1 ) {
    my $diagramid = $cgi->param( 'DIAGRAMID' );
    &delete_diagram( $subsystem, $diagramid );
    $cgi->delete( 'diagram' );
    $cgi->delete( 'DIAGRAMID' );
    $cgi->delete( 'diagram_selectbox' );
  }

  ##############################
  # Construct the page content #
  ##############################

  my $content = "<H1>Subsystem Diagram:  $ssname</H1>";

  if ( defined( $cgi->param( 'UploadDiagram' ) ) ) {
    $comment .= "Your Diagram should now be uploaded, don\'t know how yet :) \n";
  }

  my $diagram = $self->get_Diagram( $fig, $cgi, $can_alter );

  $content .= $diagram;
  if (defined($self->{_genomeroles})) {
	  for (my $i=0; $i < @{$self->{_genomeroles}}; $i++) {
	    my $allgenes;
		foreach my $comp (keys(%{$self->{_data}->{_roles}->{$self->{_genomeroles}->[$i]}})) {
			push(@{$allgenes},@{$self->{_data}->{_roles}->{$self->{_genomeroles}->[$i]}->{$comp}});
		}
		$content .= $self->print_gene_popup($subsystem,$self->{_genomeroles}->[$i],$allgenes);
		for (my $j=0; $j < @{$self->{_diagramcompartments}}; $j++) {
			my $genes;
			if (defined($self->{_data}->{_roles}->{$self->{_genomeroles}->[$i]}->{$self->{_diagramcompartments}->[$j]})) {
				push(@{$genes},@{$self->{_data}->{_roles}->{$self->{_genomeroles}->[$i]}->{$self->{_diagramcompartments}->[$j]}});
			}
			if (defined($self->{_data}->{_roles}->{$self->{_genomeroles}->[$i]}->{unspecified})) {
				push(@{$genes},@{$self->{_data}->{_roles}->{$self->{_genomeroles}->[$i]}->{unspecified}});
			}
			if (defined($genes)) {
				$content .= $self->print_gene_popup($subsystem,$self->{_genomeroles}->[$i],$genes,$self->{_diagramcompartments}->[$j]);
			}
		}
	  }
  }

  ###############################
  # Display errors and comments #
  ###############################
 
  if ( defined( $error ) && $error ne '' ) {
    $self->application->add_message( 'warning', $error );
  }
  if ( defined( $comment ) && $comment ne '' ) {
    $self->application->add_message( 'info', $comment );
  }

  return $content;
}


sub get_data {

  my ( $fig, $subsystem_name ) = @_;
  my $subsystem = $fig->get_subsystem( $subsystem_name );

  my $default_diagram;
  my $newDiagrams;

  foreach my $d ($subsystem->get_diagrams) {
    my ( $id, $name ) = @$d;
    if ( $subsystem->is_new_diagram( $id ) ) {
      $newDiagrams->{ $id }->{ 'name' } = $name;
      if ( !defined( $default_diagram ) ) {
	$default_diagram = $id;
      }
    }
  }
  
  return ( $subsystem, $newDiagrams, $default_diagram );
}

sub get_Diagram {
    my ( $self, $fig, $cgi, $can_alter ) = @_;

    # get the subsystem
    unless ( $cgi->param( 'subsystem' ) ) {
	return '<p>CGI Parameter missing.</p>';
    }
    my $subsystem_name = $cgi->param( 'subsystem' ) || '';
    my $subsystem_pretty = $subsystem_name;
    $subsystem_pretty =~ s/_/ /g;
    my ( $subsystem, $newDiagrams, $defaultDiagram ) = get_data( $fig, $subsystem_name );
	
    my $esc_name = uri_escape($subsystem_name);

    # check subsystem
    unless ( $subsystem ) {
	return "<p>Unable to find a subsystem called '$subsystem_name'.</p>";
    }
	$self->{_data}->{_subsystem} = $subsystem;

    #####################################
    # get values for attribute coloring #
    #####################################

    my $color_by_attribute = 0;
    my $attribute = $cgi->param( 'attribute_selectbox' );
  

    # if diagram.cgi is called without the CGI param diagram (the diagram id)
    # it will try to load the first 'new' diagram from the subsystem and
    # print out an error message if there is no 'new' diagram
    my $diagram_id  = $cgi->param( 'diagram' ) || $cgi->param( 'diagram_selectbox' ) || '';

    if ( defined( $cgi->param( 'Show this diagram' ) ) ) {
      $diagram_id = $cgi->param( 'diagram_selectbox' );
    }

    unless ( $diagram_id ) {
      $diagram_id = $defaultDiagram;
    }

    # check diagram id
    my $errortext = '';

    if ( !( $diagram_id ) ) {
      $errortext .= "<p><em>Unable to find a diagram for this subsystem.</em><p>";
    }
    else {
      unless ( $subsystem->is_new_diagram( $diagram_id ) ) {
	$errortext .= "<p><em>Diagram '$diagram_id' is not a new diagram.</em><p>";
      }
    }

    my $colordiagram = "";
    my $attribute_panel = "";
    my @genomes;
    my $genome = $cgi->param( 'genome_id' );
    my $lookup = {};
    my $d;

    if ( $diagram_id ) {
      # find out about sort order
      my $sort_by = $cgi->param( 'sort_by' ) || 'name';
      
      # get the genomes from the subsystem 
      if ($sort_by eq 'variant_code') {
 	@genomes = sort { ($subsystem->get_variant_code( $subsystem->get_genome_index($a) ) cmp
 			   $subsystem->get_variant_code( $subsystem->get_genome_index($b) )) or
			     ( $fig->genus_species($a) cmp $fig->genus_species($b) )
			   } $subsystem->get_genomes()
			 }
      else { 
	@genomes = sort { $fig->genus_species($a) cmp $fig->genus_species($b) } $subsystem->get_genomes();
      }
      
      # show only genomes with zero or positive variant codes
      # unless user switched that off
      unless ($cgi->param('show_negative')) {
	my @temp;
	foreach (@genomes) {
	  my $vcode = $subsystem->get_variant_code( $subsystem->get_genome_index( $_ ) );
	  push @temp, $_ if ($vcode ne "0");
	}
	@genomes = @temp;
      }
      
      my %genome_labels = map { $_ => $fig->genus_species($_)." ( $_ ) [".
				  $subsystem->get_variant_code( $subsystem->get_genome_index( $_ ) )."]"
				} @genomes;
      
      @genomes = ('0', @genomes);
      $genome_labels{'0'} = 'please select a genome to color the diagram with' ;
      
      # color diagram div
      $colordiagram = build_color_diagram ( $self, $fig, $cgi, \@genomes, $genome, \%genome_labels, $diagram_id, $sort_by );

    }
    # initialise a status string (log)
    my $status = '';
    
    # generate the content
    my $content = $errortext;

    # start form #
    $content .= $self->start_form( 'diagram_select_genome' ); 

    $content .= "<TABLE><TR><TD>";
    
    if ( $diagram_id ) {
      $content .= "$colordiagram $attribute_panel</TD></TR>";
      
      # fetch the diagram
      my $diagram_dir = $subsystem->{dir}."/diagrams/$diagram_id/";
      $d = Diagram->new($subsystem_name, $diagram_dir, $subsystem,$self->{_data}->{_roles});
      $self->{_diagramcompartments} = $d->{_diagramcompartments};
      # turn off scaling?
      $d->min_scale(1) if ($cgi->param('dont_scale'));
      
      # DEBUG: test all items of the diagram against the subsystem
    # (for debug purposes during introduction of new diagrams)
      # (remove when no longer needed)
      # (1) roles
      my $types = [ 'role', 'role_and', 'role_or' ];
      foreach my $t (@$types) {
	foreach my $id (@{$d->item_ids_of_type($t)}) {
	  unless ($subsystem->get_role_from_abbr($id) or
		  scalar($subsystem->get_subsetC_roles($id))) {
	    $status .= "Diagram item '$t' = '$id' not found in the subsystem.\n";
	  }
	}
      }
      # (2) subsystem
      foreach my $s (@{$d->item_ids_of_type('subsystem')}) {
	unless ($fig->subsystem_version($s)) {
	  $status .= "Diagram item 'subsystem' = '$s' is not a subsystem.\n";
	}
      }
      # END 
      
      
      # add notes to roles
      # to reduce the total number of loos role_or, role_and get their notes 
      # attached in the loops further down
      foreach my $id (@{$d->item_ids_of_type('role')}) {
	my $role = $subsystem->get_role_from_abbr($id);
	if ($role) {
	  $d->add_note('role', $id, $role);
	}
      }
      
      
      # build a lookup hash, make one entry for each role_and and role_or item
      # the index references to the inner hash of the role_and/role_or hash
      # to set a value there use $lookup->{role_abbr}->{role_abbr} = 1;
      # declared outside if to be available for debug output
      
      # find out about role_and
      my $role_and = {};
      if (scalar(@{$d->item_ids_of_type('role_and')})) {
	foreach my $subset (@{$d->item_ids_of_type('role_and')}) {
	  
	  $role_and->{$subset} = {};
	  
	  my $note = '';
	  foreach my $r ($subsystem->get_subsetC_roles($subset)) {
	    my $r_abbr = $subsystem->get_abbr_for_role($r);
	    unless ($r_abbr) {
	      die "Unable to get the abbreviation for role '$r'.";
	    }
	    
	    $note .= "<li>$r</li>";
	    $lookup->{$r_abbr} = $role_and->{$subset};
	    $role_and->{$subset}->{$r_abbr} = 0;
	  }
	  $d->add_note('role_and', $subset, "<h4>Requires all of:</h4><ul>$note</ul>");
	}
      }
      
      # find out about role_or
      my $role_or = {};
      if (scalar(@{$d->item_ids_of_type('role_or')})) {
	foreach my $subset (@{$d->item_ids_of_type('role_or')}) {
	  
	  $role_or->{$subset} = {};
	  
	    my $note = '';
	  foreach my $r ($subsystem->get_subsetC_roles($subset)) {
	    my $r_abbr = $subsystem->get_abbr_for_role($r);
	    
	    unless ($r_abbr) {
	      die "Unable to get the abbreviation for role '$r'.";
	    }
	    
	    $note .= "<li>$r</li>";
	    $lookup->{$r_abbr} = $role_or->{$subset};
	    $role_or->{$subset}->{$r_abbr} = 0;
	  }
	    $d->add_note('role_or', $subset, "<h4>Requires any of:</h4><ul>$note</ul>");
	}
      }
      
      
      my $color_diagram_info = "";
      
      if ($genome) {
	
	#EDIT HERE TO GET PEGS FOR EACH ROLE TODO
	my @roles = $subsystem->get_roles_for_genome( $genome );
	$self->{_genomeroles} = [@roles];
	my $roleatts;
	
	# if color by attributes, get the roles to color here
	if ( defined( $attribute ) && $attribute ne '' ) {
	  $roleatts = find_roles_to_color( $fig, $cgi, $genome, $attribute );
	}

	# check if genome is present in subsystem
	# genomes not present, unfortunately return @roles = ( undef )
	if (scalar(@roles) == 0 or 
	    (scalar(@roles) and !defined($roles[0]))) {
	  $color_diagram_info .= "<p><em>Genome '$genome' is not present in this subsystem.</em><p>";
	  shift(@roles);
	}
	else {
	  $color_diagram_info .= "<p><em>Showing colors for genome: ".
	    $fig->genus_species($genome)." ( $genome ), variant code ".
	      $subsystem->get_variant_code($subsystem->get_genome_index($genome)) ."</em><p>";
	}
	
	
	# iterate over all roles present in a subsystem:
	# -> map roles to abbr in the foreach loop
	# -> color simple roles present
	# -> tag roles being part of a logical operator in $lookup
	foreach ( map { $subsystem->get_abbr_for_role($_) } @roles ) {
	  
	  # color normal roles
	  if ($d->has_item( 'role', $_ ) ) {
		$d->color_item( 'role',$_,'green' );
		
	    # if color by attribute, color items here
	    if ( $attribute ) {
	      if ( $roleatts->{ $_ } ) {
		my $color = get_color_for_value( $roleatts->{ $_ } );
		$d->color_item( 'role', $_, $color ) ;
	      }
	      else {
		$d->color_item( 'role', $_, 'gray' ) ;
	      }
	    }
	    next;
	  }
	  
	  # try to find role_and / role_or
	  if (exists($lookup->{$_})) {
	    $lookup->{$_}->{$_} = 1;
	    next;
	  }
	  
	  $status .= "Role '$_' not found in the diagram.\n";
	}
	
	# check if to color any role_and
	foreach my $id_role_and (keys(%$role_and)) {
	  my $result = 1;
	  foreach (keys(%{$role_and->{$id_role_and}})) {
	    $result = 0 unless ($role_and->{$id_role_and}->{$_});
	  }
	  $d->color_item('role_and', $id_role_and, 'green') if ($result);
	}
	
	# check if to color any role_or
	foreach my $id_role_or (keys(%$role_or)) {
	  foreach ( keys( %{ $role_or->{ $id_role_or } } ) ) {
	    if ($role_or->{$id_role_or}->{$_}) {
	      $d->color_item('role_or', $id_role_or, 'green');
	      last;
	    }
	  }
	}
	
      }
      else {
	$color_diagram_info .= '<p><em>You have not provided a genome id to color the diagram with.</em><p>';
      }
      
      # add an info line about diagram scaling
      my $scaling_info;
      my $scale = $d->calculate_scale * 100;
      if ( $scale == 100 ) {
	$scaling_info .= '<p><em>This diagram is not scaled.</em></p>';
      }
      else {
	$scaling_info .= '<p><b><em>This diagram has been scaled to '.sprintf("%.2f", $scale).'%. ';
	$scaling_info .= "(<a href='".$self->application->url()."?page=ShowDiagram&subsystem=$esc_name&diagram=$diagram_id&dont_scale=1'>".
	  "view in original size</a>)";
	$scaling_info .= '</em></b></p>';
      }
      if ( $cgi->param( 'dont_scale' ) ) {
	$scaling_info .= '<p><em>You have switched off scaling this diagram down. ';
	$scaling_info .= "(<a href='".$self->application->url()."?page=ShowDiagram&subsystem=$esc_name&diagram=$diagram_id'>".
	  "Allow scaling</a>)";
	$scaling_info .= '</em></p>';
      }	
      
      $content .= "<TR><TD>$color_diagram_info</TD></TR>";
      
      $content .= "<TR><TD>$scaling_info</TD></TR>";
      $content .= "<TR><TD><DIV STYLE='padding: 10px;'>\n";
      
      # print diagram
      $content .= $d->html;
      
      $content .= "</DIV></TD></TR>";
      $content .= "<TR><TD>Key intermediates are shown in circles with Roman numerals. They are explained in the inset and hyperlinked to the KEGG Compound<BR>\ndatabase. Enzymes are shown by rectangular boxes, multi-subunit complexes - by octagons; alternative (nonorthologous) enzymes<BR>\ncatalyzing the same reaction appear as squares. Hover over these objects to see protein annotations in full. Enzymes not encoded in<BR>\nthis Subsystem are shaded gray. They are included merely for functional context, and do not respond to interactive diagram coloring.<BR>\nneighboring Subsystems or general areas of metabolism are shown in ovals.</TD></TR>";
    # print status 
    $content .= '<TR><TD><em>Below follows a status message to help test the new diagrams:</em></TD></TR>'. "<TR><TD><pre>$status</pre></TD></TR>" if ($status);
    }

    my $choose = build_show_other_diagram( $fig, $cgi, $subsystem, $newDiagrams, $diagram_id );

    $content .= "<TR><TD><DIV id='controlpanel'>$choose";

    # upload diagram only if can_alter #
    if ( $can_alter ) {
      my $upload = $self->build_upload_diagram( $fig, $esc_name );
      $content .= "$upload";
      
      my $delete = '';
      if ( defined( $diagram_id ) ) {
	$delete = $self->build_delete_diagram( $fig, $esc_name, $diagram_id );
	$content .= "$delete";
      }
    }

    $content .= "</DIV></TD><TR></TABLE>";

    if ( $diagram_id ) {
      # print status 
#      $content .= '<hr/><p><em>Below follows a status message to help test the new diagrams:</em><p>'.
#	"<pre>$status</pre>" if ($status);
      
      # print debug
      if ($cgi->param('debug')) {
	require Data::Dumper;
	$content .= '<hr/>';
	$content .= "<h2>Diagram dump:</h2><pre>".Data::Dumper->Dump([ $d ])."</pre>";
	$content .= "<h2>Lookup dump:</h2><pre>".Data::Dumper->Dump([ $lookup ])."</pre>";
      }
    }
    $content .= $self->end_form();

    return $content;
  }

sub build_color_diagram {
  my ( $self, $fig, $cgi, $genomesarr, $genome, $genome_labels, $diagram_id, $sort_by ) = @_;
  
  my $subsystem_name = $cgi->param( 'subsystem' );

  my $esc_name = uri_escape($subsystem_name);

  my $colordiagram = "<DIV id='controlpanel'>";
  # header #
  $colordiagram .= "<H2>Color Diagram</H2>";
  
  # hiddens for subsystem, diagram, scale, negative variants #
  $colordiagram .= $cgi->hidden( -name  => 'subsystem',
				 -value => $esc_name );	
  $colordiagram .= $cgi->hidden( -name  => 'diagram',
				 -value => $diagram_id );
  
  $colordiagram .= $cgi->hidden( -name  => 'dont_scale', -value => 1 ) 
    if ( $cgi->param( 'dont_scale' ) );
  
  $colordiagram .= $cgi->hidden( -name  => 'show_negative', -value => 1 ) 
    if ( $cgi->param( 'show_negative' ) );
  
  $colordiagram .= $cgi->hidden( -name  => 'debug', -value => 1 )
    if ( $cgi->param( 'debug' ) );
  
  $colordiagram .= "<B>Pick a genome to color diagram:</B><BR><BR>";
  
  $colordiagram .= $cgi->popup_menu( -name    => 'genome_id',
				     -values  => $genomesarr,
				     -default => $genome,
				     -labels  => $genome_labels,
				   );
  
  $colordiagram .= '<p>Sort by: '.
    $cgi->radio_group( -name    => 'sort_by',
		       -values  => ['name', 'variant_code'],
		       -default => $sort_by,
		       -labels  => { 'name' => 'Genome name',
				     'variant_code' => 'Variant code, then genome name' },
		       -onChange => 'document.getElementById("diagram_select_genome").submit();',
		     ).'</p>';
  $colordiagram .= '<p>Show: '.$cgi->checkbox( -name  => 'show_negative',
					       -value => 1,
					       -label => 'genomes with negative variant codes',
					       -onChange => 'document.getElementById("diagram_select_genome").submit();',
					     ).'</p>';
  
  $colordiagram .= get_attributes_popup( $fig, $cgi );

  $colordiagram .= $cgi->submit( -name => 'Color diagram' );
  $colordiagram .= "</DIV>";

  return $colordiagram;
}

###################################
# get colors for attribute values #
###################################
sub get_color_for_value {

  my ( $val ) = @_;
  my $color = 'gray';
  if ( $val eq 'essential' ) {
    $color = 'red';
  }
  if ( $val eq 'nonessential' ) {
    $color = 'blue';
  }

  return $color;
}

###################################
# build the little upload diagram #
###################################
sub build_upload_diagram {

  my ( $self, $fig, $subsystem_name ) = @_;
  
  my $diagramupload = "<H2>Upload new diagram</H2>\n";
  $diagramupload .= "<A HREF='".$self->application->url()."?page=UploadDiagram&subsystem=$subsystem_name'>Upload a new diagram or change an existing one for this subsystem</A>";

}

#######################################
# build the little show other diagram #
#######################################
sub build_show_other_diagram {

  my ( $fig, $cgi, $subsystem, $diagrams, $default ) = @_;
  
  my $default_num;

  my @ids = sort keys %$diagrams;
  my %names;
  my $counter = 0;
  foreach ( @ids ) {
    if ( $_ eq $default ) {
      $default_num = $counter;
    }
    $names{ $_ } = $diagrams->{ $_ }->{ 'name' };
    $counter++;
  }

  my $diagramchoose = "<H2>Choose other diagram</H2>\n";
  $diagramchoose .= $cgi->popup_menu( -name    => 'diagram_selectbox',
 				      -values  => \@ids,
 				      -default => $default_num,
 				      -labels  => \%names,
				      -maxlength  => 150,
 				    );

  $diagramchoose .= $cgi->submit( -name => 'Show this diagram' );

  return $diagramchoose;
}

#########################################
# build the little get attributes popup #
#########################################
sub get_attributes_popup {

  my ( $fig, $cgi, $genome ) = @_;

  my $colorattribute .= "<B>Color diagram by attribute</B><P>";
  
  my @attributes = ( undef, sort { uc($a) cmp uc($b) }
		      grep { /(Essential|fitness)/i }
		      $fig->get_peg_keys()
		    );


  $colorattribute .= $cgi->popup_menu( -name    => 'attribute_selectbox',
 				      -values  => \@attributes,
				      -maxlength  => 150,
 				    );

  $colorattribute .= "</P>\n";

  return $colorattribute;

}


#####################################################
# get the roles that should be colored by attribute #
#####################################################
sub find_roles_to_color {

    my ( $fig, $cgi, $genome_id, $attributekey ) = @_;

    my @results;
    
    my ( @pegs, %roles, %p2v );
    foreach my $result (@results){
      my ( $p, $a, $v, $l ) = @$result;
      if ( $p =~ /$genome_id/ ) {
	push( @pegs, $p );
	$p2v{ $p } = $v;
      }
    }
    
    foreach my $peg (@pegs){
        my $value = $p2v{ $peg };     
        my $function = $fig->function_of($peg);
        my @function_roles = $fig->roles_of_function($function);
	foreach my $fr ( @function_roles ) {
	  $roles{ $fr } = $value;
	}
    }

    return \%roles;  
}


###################################
# build the little delete diagram #
###################################
sub build_delete_diagram {

  my ( $self, $fig, $subsystem, $diagramid ) = @_;
  
  my $diagramdelete = "<H2>Delete currently shown diagrams</H2>\n";

  my $deletebutton = "<INPUT TYPE=HIDDEN NAME='DIAGRAMID' ID='DIAGRAMID' VALUE='$diagramid'><INPUT TYPE=HIDDEN NAME='DELETEBUTTONPRESSED' ID='DELETEBUTTONPRESSED' VALUE=0><INPUT TYPE=BUTTON VALUE='Delete Diagram' NAME='DELETEDIAGRAMBUTTON' ID='DELETEDIAGRAMBUTTON' ONCLICK='if ( confirm( \"Do you really want to delete the diagram $diagramid?\" ) ) { 
 document.getElementById( \"DELETEBUTTONPRESSED\" ).value = 1;
 document.getElementById( \"diagram_select_genome\" ).submit(); }'>";
  
  $diagramdelete .= $deletebutton;

}

sub delete_diagram {

  my ( $subsystem, $id ) = @_;
  
  $subsystem->delete_diagram( $id );
}

sub print_gene_popup {
    my ($self,$subsystem,$role,$genes,$compartment) = @_;
    my $peg_link = "http://seed-viewer.theseed.org/seedviewer.cgi?page=Annotation&feature=";
    # open divs
	my $id = $subsystem->get_abbr_for_role($role);
	my $compartmentNote = "";
	if (defined($compartment)) {
		$compartmentNote = " (".$revtranslation->{$compartment}.")";
		$id = $id .= "_".$compartment;
	}
	my $pop_up_html = "<div id=\"$id\" style=\"padding:5px;display:none;\">";
	$pop_up_html .= "<b>".$role." pegs".$compartmentNote.":</b><br>";
    for (my $i = 0; $i < @{$genes}; $i++) {
		$pop_up_html .= "<a href=\"".$peg_link.$genes->[$i]."\" target=\"_blank\">".$genes->[$i]."</a><br>"
	}
    $pop_up_html .= "</div>";
    return $pop_up_html;
}
