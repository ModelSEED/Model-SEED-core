package Diagram;

# Diagram - a package to display SEED diagrams

# $Id: Diagram.pm,v 1.19 2011-02-24 18:49:12 redwards Exp $

use strict;
use warnings;

use Carp qw( confess );

use GD;
use MIME::Base64;
use FIG_Config;
use Tracer;
use File::Temp qw( tempfile );
use CGI;

use constant ROLE => '';
use constant COMPOUND => 'http://www.genome.jp/dbget-bin/www_bget?cpd:<COMPOUND>';
my $SUBSYSTEM = "$FIG_Config::cgi_url/diagram.cgi?subsystem_name=<SUBSYSTEM>";
use constant MAX_WIDTH => 1000;
use constant MAX_HEIGHT => 2000;
use constant MIN_SCALE => 0.65;

1;


=pod

=head1 NAME

Diagram - a package to display SEED diagrams

=head1 METHODS

=over 4

=item * B<new> (I<subsystem_name>, I<path>)

Returns a new Diagram object. Mandatory parameters are the name of the 
subsystem in I<subsystem_name> and the path to the diagram I<path> with
a trailing slash.

=cut

sub new {
  my ($class, $subsystem_name, $path,$subsys,$rolehash) = @_;
  print STDERR "AAA: @_\n";
  
  unless ($subsystem_name) {
    confess 'No subsystem name given.';
  }
  
  my $imageFile; my $imageType;
  if (-f $path."diagram.png") {$imageFile = "diagram.png"; $imageType="png"}
  elsif (-f $path."diagram.jpg") {$imageFile = "diagram.jpg"; $imageType="jpg"}
  elsif (-f $path."diagram.jpeg") {$imageFile = "diagram.jpeg"; $imageType="jpg"}
  else {confess "The image file was not found in $path. We looked for .png, or .jpg, or .jpeg"}

  unless (-f $path.'diagram.html') {
    confess "The html map not found at '$path'.";
  }

  print STDERR "A: $imageType\n";
  
  my $self = { 'path'             => $path,
	       'items'            => {},
	       'subsystem_name'   => $subsystem_name,
	       'overlay'          => undef,
	       'image'            => undef,
	       'image_file_name'  => $imageFile,
	       'image_file_type'  => $imageType,
	       'width'            => undef,
	       'max_height'       => MAX_HEIGHT,
	       'max_width'        => MAX_WIDTH,
	       'min_scale'        => MIN_SCALE,
	       'need_js'          => 1,
	     };
  bless $self, $class;
  if (defined($subsys)) {
	$self->{_subsys} = $subsys;
  }
  if (defined($rolehash)) {
	$self->{_roles} = $rolehash;
  }
  
  # init WebGD::Image object for diagram image
  if ($self->{'image_file_type'} eq "png") {
  	#print STDERR "Calling newFromPng for ". $self->image_file. "\n";
  	$self->{'image'} = GD::Image->newFromPng($self->image_file, 1);
  }
  elsif ($self->{'image_file_type'} eq "jpg") {
  #print STDERR "B: $imageType ". $self->{'image_file_type'}. "\n";
  	print STDERR "Calling newFromJpeg for ". $self->image_file. "\n";
	  $self->{'image'} = GD::Image->newFromJpeg($self->image_file, 1);
  }
  else {
  #print STDERR "C:\n";
  	confess "No image type is defined";
  }

  my ($width, $height) = $self->{'image'}->getBounds();
  $self->{'width'} = $width;
  $self->{'height'} = $height;
  
  # load items from image map
  $self->parse_image_map();
  
  return $self;
}

=pod

=item * B<need_js> (boolean)

Getter / setter for whether the FIG.js need to be referenced by this script
Default: 1

=cut

sub need_js {
  my ($self, $need) = @_;

  if (defined($need)) {
    $self->{need_js} = $need;
  }

  return $self->{need_js};
}

=pod

=item * B<colors> ()

Returns a reference to a hash of acceptable color names.

=cut

sub colors {
  return { 'red'    => 1,
	   'green'  => 1,
	   'blue'   => 1,
	   'yellow' => 1,
	   'gray'   => 1,
	 };
}

=pod

=item * B<subsystem_name> ()

Returns the name of the subsystem.

=cut

sub subsystem_name {
  return $_[0]->{'subsystem_name'};
}


=pod

=item * B<image_map_file> ()

Returns the path to the image map file.

=cut

sub image_map_file {
  return $_[0]->{'path'}.'diagram.html';
}


=pod

=item * B<image_map> ()

Returns the html code of the image map. Currently the javascript needed for the 
hover tooltips to work is included here, too (FigCSS/FIG.js). I'd rather have this
module be self contained than relying on other shared files. 

=cut

sub image_map {
  my $self = shift;

  my $javascript = "";
  if ($self->need_js()) {
    $javascript = "\n<script type='text/javascript' src='$FIG_Config::cgi_url/Html/nmpdr.js'></script>\n\n";
  }

  my $image_map = '<map name="diagram">'."\n";
    
  foreach my $type (keys(%{$self->items})) {
    foreach my $id (keys(%{$self->items->{$type}})) {
      foreach my $item (@{$self->items->{$type}->{$id}}) {
	
	my $target = ''; 
	$target = 'target='.$item->{'link_target'}.'"' if ($item->{'link_target'}); 

	my $tooltip = '';
	if ($item->{'link_tooltip'}) {

	  # rewrite role names like 5'-methylthioadenosine nucleosidase
	  $item->{'link_tooltip'}->{'content'} =~ s/'/&rsquo;/g;
	  # Figure out the tooltip text and location.
	  my ($x, $y, $x2, $y2) = @{$item->{coords}};
	  my $tipText = CGI::strong($item->{link_tooltip}->{title}) .
			CGI::br() . $item->{link_tooltip}->{content};
	  $tooltip = qq~onMouseover="doTooltip2(this, '$tipText', $x2, $y2)"~;
	}
	
	
	my $href = $item->{'link'} || '';
	my $link = '';
	$link = 'href="'.$href.'" '.$target
	  if ($item->{'link'});
	
	$image_map .= '<area shape="'.$item->{'shape'}.'" '.
	  'coords="'.join(',',@{$item->{'coords'}}).'" '.$link.' '.$tooltip." >\n";
      }
    }
  }

  $image_map .= '</map>';

  return $javascript.$image_map;
}


=pod

=item * B<image_file> ()

Returns the path to the image file.

=cut

sub image_file {
  return $_[0]->{'path'}.$_[0]->{'image_file_name'};
}


=pod

=item * B<width> ()

Returns the width of the diagram image

=cut

sub width {
  return $_[0]->{'width'};
}


=pod

=item * B<height> ()

Returns the height of the diagram image

=cut

sub height {
  return $_[0]->{'height'};
}


=pod

=item * B<max_width> (I<max_width>)

Returns the maximal width of the resulting diagram image. Images will be rescaled to fit that size.
If the optional parameter I<max_width> is provided, the maximal width will be set. 

If the method is not called on a diagram, the default value MAX_WIDTH will be used.

=cut

sub max_width {
  if (defined $_[1]) {
    confess "Invalid value for maximal width." if (int($_[1]) <= 0);
    $_[0]->{'max_width'} = $_[1];
  }
  return $_[0]->{'max_width'};
}


=pod

=item * B<max_height> (I<max_height>)

Returns the maximal height of the resulting diagram image. Images will be rescaled to fit that size.
If the optional parameter I<max_height> is provided, the maximal height will be set. 

If the method is not called on a diagram, the default value MAX_HEIGHT will be used.

=cut

sub max_height {
  if (defined $_[1]) {
    confess "Invalid value for maximal height." if (int($_[1]) <= 0);
    $_[0]->{'max_height'} = $_[1];
  }
  return $_[0]->{'max_height'};
}


=pod

=item * B<min_scale> (I<min_scale>)

Returns the minimal scaling modifier allowed for the diagram as a float between 0 and 1. 
Example: scale not to less than 50%, I<min_scale> should be 0.5
If the optional parameter I<min_scale> is provided, the minimal scaling modifier will be set. 

If the method is not called on a diagram, the default value MIN_SCALE will be used.

Set to 1.0 if you like to turn off scaling.

=cut

sub min_scale {
  if (defined $_[1]) {
    confess "Invalid value for minimal scale." 
      if ($_[1] <= 0 or $_[1] > 1);
    warn "Scaling to $_[1] really doesn't make sense, but here you go." 
      if ($_[1] <= 0.25);
    $_[0]->{'min_scale'} = $_[1];
  }
  return $_[0]->{'min_scale'};
}

=pod

=item * B<items> ()

Returns a hash reference to the items.

=cut

sub items {
  return $_[0]->{'items'};
}


=pod

=item * B<image> ()

Returns the reference to the WebGD::Image instance of the diagram image file.
This is created during Diagram->new().

=cut

sub image {
  return $_[0]->{'image'};
}
    

=pod

=item * B<parse_image_map> ()

Reads the image map file and (1) populates the internal item hash and 
(2) prepares the final image map html where all the link stubs have been
replaced by fully functional links. 

=cut
sub parse_image_map {
    my $self = shift;
    $self->{_diagramcompartments} = [];
	my $compartmentHash;
    #my $filename = "/home/chenry/diagramtest/diagram.html";
    #open (MAP, $filename) or confess "Unable to open image map '".$filename."'.";
    open (MAP, $self->image_map_file) or confess "Unable to open image map '".$self->image_map_file."'.";
    while (defined (my $line = <MAP>)) {
	
      # drop starting body tag
      next if ($line =~ /<body/);

      # next if image map start
      next if ($line =~ /<map name=\"GraffleExport\">/);

      # parse items
      if ($line =~ /<area shape=(\w+) coords=\"([\d\,]+)\" href=\"(\w+)=(.+)\">/) {
		my $abrev = $4;
		my $compartment = "unspecified";
		my $array = [split(/;/,$abrev)];
		if (defined($array->[1])) {
			$compartmentHash->{$array->[1]} = 1;
			$compartment = $array->[1];
			$abrev = $array->[0];
		}
	
		# add to internal items
		unless (defined $self->{'items'}->{$3}) {
			$self->{'items'}->{$3} = {};
		}
	
		# init item type / id
		unless (defined $self->{'items'}->{$3}->{$abrev}) {
			$self->{'items'}->{$3}->{$abrev} = [];
		}

		my @coords = split(',',$2);
		my $item = { 'shape'  => $1,'compartment' => $compartment,'coords' => \@coords };
	
		# post-process links in the image map 
		# see internal function _process_link()
		if ($3 eq 'role' or $3 eq 'role_and' or $3 eq 'role_or') {
		  my $link = $self->_process_link(ROLE, { 'SUBSYSTEM' => $self->subsystem_name,'ROLE' => $abrev });
		  $item->{'link'} = $link if ($link);
		  my $rolename = $self->{_subsys}->get_role_from_abbr($abrev);
		  if (defined($rolename)) {
			  if ($item->{compartment} eq "unspecified" && defined($self->{_roles}->{$rolename})) {
				$item->{'pegs'} = $self->{_roles}->{$rolename}->{all};
				$item->{'link'} = "javascript:popUp('".$abrev."');";
			  } elsif (defined($self->{_roles}->{$rolename}->{unspecified}) || defined($self->{_roles}->{$rolename}->{$item->{compartment}})){
				if (defined($self->{_roles}->{$rolename}->{unspecified})) {
					push(@{$item->{'pegs'}},@{$self->{_roles}->{$rolename}->{unspecified}});
				}
				if (defined($self->{_roles}->{$rolename}->{$item->{compartment}})) {
					push(@{$item->{'pegs'}},@{$self->{_roles}->{$rolename}->{$item->{compartment}}});
				}
				$item->{'link'} = "javascript:popUp('".$abrev."_".$item->{compartment}."');";
			  }
		  } else {
		  	print STDERR "Found no role for ".$abrev."\n";
		  }
		  #print STDERR "TEST:".$item->{'link'}.":".$abrev.":".$rolename;
		  #$item->{'link_target'} = '_blank';
		} elsif ($3 eq 'compound') {
		  my $link = $self->_process_link(COMPOUND, { 'COMPOUND' => $abrev });
		  $item->{'link'} = $link if ($link);
		  $item->{'link_target'} = '_blank';
		} elsif ($3 eq 'subsystem') {
		  my $link = $self->_process_link($SUBSYSTEM, { 'SUBSYSTEM' => $abrev });
		  $item->{'link'} = $link if ($link) ;
		} else {
		  confess "Unknown item type '$3' in image map '".$self->image_map_file."'.";
		}

		push @{$self->{'items'}->{$3}->{$abrev}}, $item;

	  }
	
	  # stop parsing
	  if ($line =~ /<\/map>/) {
		  last;
	  }  
    }
    close (MAP);
	push(@{$self->{_diagramcompartments}},keys(%{$compartmentHash}));
    return $self;
}    


=pod

=item * B<has_item> (I<type>, I<id>)

Returns reference to self if the diagram has an item of I<type> with the id I<id>. 
Both I<type> and I<id> are mandatory. Returns undef else.

=cut

sub has_item {
  my ($self, $type, $id) = @_;

  return $self if (exists $self->items->{$type} and
		   exists $self->items->{$type}->{$id});
  return undef;
}


=pod

=item * B<item_ids_of_type> (I<type>)

Returns a reference to a list of ids of a given type I<type> contained in the
diagram. The parameter I<type> is mandaotry. Returns an empty list if the 
diagram doesnt contain any items of that type.

=cut

sub item_ids_of_type {
  my ($self, $type) = @_;
  
  if (exists($self->{'items'}->{$type})) {
    my @result = keys(%{$self->{'items'}->{$type}});
    return \@result;
  }
  else {
    return [];
  }
}

=pod

=item * B<color_item> (I<type>, I<id>, I<color_name>)

Colors the item specified by I<type> and I<id> with the color I<color_name>. 
All three parameters are mandatory. 

=cut

sub color_item {
  my ($self, $type, $id, $color) = @_;
  my $overlay = $self->image();

  if (exists $self->items->{$type} and
      exists $self->items->{$type}->{$id} and
      $self->colors->{$color} ) {
    
    foreach my $item (@{$self->items->{$type}->{$id}}) {
	  if ($color eq "green" && $type =~ m/^role/ && !defined($item->{pegs})) {
	  	next;
	  }
      my $blend_color = $overlay->colorAllocateAlpha(0,150,0,50);
      if ($item->{'shape'} eq 'rect') {
	$overlay->filledRectangle($item->{'coords'}->[0], $item->{'coords'}->[1], $item->{'coords'}->[2], $item->{'coords'}->[3], $blend_color);
      }
      elsif ($item->{'shape'} eq 'poly') {
	
	# draw compounds as circles although OmniGraffle exports them as polygon
	if ($type eq 'compound') {
	  my $center_x = ($item->{'coords'}->[0]+$item->{'coords'}->[4])/2;
	  my $center_y = ($item->{'coords'}->[1]+$item->{'coords'}->[3])/2;
	  my $radius = int(sqrt( ($item->{'coords'}->[0]-$center_x)*($item->{'coords'}->[0]-$center_x)+
				 ($item->{'coords'}->[1]-$center_y)*($item->{'coords'}->[1]-$center_y))
			  );
	  $overlay->filledEllipse($center_x,$center_y,$radius * 2,$radius * 2,$blend_color)
	}
	
	# for now let's assume everything else exported as polygon really is one
	else {
	  my $poly = new GD::Polygon;
	  for (my $i=0; $i<scalar(@{$item->{'coords'}}); $i=$i+2) {
	    $poly->addPt($item->{'coords'}->[$i],$item->{'coords'}->[$i+1]);
	  }
	  $overlay->filledPolygon($poly, $blend_color);
	}

      }
      else {
	confess "Unknown item shape in image map '".$self->image_map_file."'.";
      }
    }
  }
  else {
    confess 'No such item exists in this diagram.';
  }

  return $self;

}


=pod

=item * B<add_note> (I<type>, I<id>, I<note>)

Adds a tooltip note to the item specified by I<type> and I<id>. I<note> has to be
valid html. Tool tip notes are shown when hovering over the item.
All three parameters are mandatory.

=cut

sub add_note {
  my ($self, $type, $id, $note) = @_;
  
  if (exists $self->items->{$type} and
      exists $self->items->{$type}->{$id} and
      $note ) {
        
    my $tooltip = { 'title'   => "$type: $id",
		    'content' => $note,
		    'menu'    => '',
		  };

    foreach my $item (@{$self->items->{$type}->{$id}}) {
      $item->{'link_tooltip'} = $tooltip;
    }      

  }
  else {
    confess 'No such item exists in this diagram or empty note given.';
  }

  return $self;
}

=pod

=item * B<html> ()

Returns the diagram (together with it's image map) as html code. The image 
is printed inline (base64 encoded). The surrounding <div> as well as the <img> 
tag get the id='diagram' to be able to add CSS styles or javascript.

=cut

sub html {
  my $self = shift;

  my $image = $self->image;

  # resize if necessary
  $self->scale( $self->calculate_scale );

  return "\n<div id='diagram'>\n".$self->image_map.'<img style="border: none;" id="diagram" src="'.&image_src($self->image).'" usemap="#diagram"/>'."\n</div>";
}


=pod

=item * B<calculate_scale> ()

Returns the scaling factor based on the image size, the supposed maximal width
and height (rf. to B<max_width> and B<max_height>) and the minimal scaling 
allowed (rf. to B<min_scale>).

=cut

sub calculate_scale {
  my ($self) = @_;

  my $scale = 1; 
  if ($self->width > $self->max_width) {
    $scale = $self->max_width / $self->width;
  }
  if ($self->height > $self->max_height and 
      (($self->max_height / $self->height) < $scale) ) {
    $scale = $self->max_height / $self->height;
  }

  return $scale < $self->min_scale ? $self->min_scale : $scale ;

}


=pod

=item * B<scale> (I<scale>)

Scales the image and recalculates the internal item coordinates by the 
factor I<scale> given as parameter. 

=cut

sub scale {
  my ($self, $scale) = @_;

  return if ($scale == 1);

  my $scaled_width = $self->width * $scale;
  my $scaled_height = $self->height * $scale;
  my $scaled_image = GD::Image->new( $scaled_width, $scaled_height, 1 );
  $scaled_image->copyResampled( $self->image, 0, 0, 0, 0, $scaled_width, $scaled_height, $self->width, $self->height );
  $self->{image} = $scaled_image;
  
  # recalculate item coordinates
  foreach my $type (keys(%{$self->items})) {
    foreach my $id (keys(%{$self->items->{$type}})) {
      for (my $i=0; $i<scalar(@{$self->items->{$type}->{$id}}); $i++) {
	my $coords = [];
	foreach my $c (@{$self->items->{$type}->{$id}->[$i]->{'coords'}}) {
	  push @$coords, int($c*$scale);
	}
	$self->items->{$type}->{$id}->[$i]->{'coords'} = $coords;
      }
    }
  }    

}


=pod

=back

=head1 INTERNAL METHODS

Internal or overwritten default perl methods. Do not use from outside!

=over 4

=item * B<_process_link> (I<link>, I<values>)

Helper method which takes the link fragments from the html image map and 
returns complete links for them according to the constants defined at the 
top of the module. 

The method recognises three placeholders: ROLE, COMPOUND, SUBSYSTEM. If any
of those is supplied in the I<values> parameter, it will be replaced.

=cut

sub _process_link {
  my ($self, $link, $values) = @_;

  while (my ($k, $v) = each(%$values)) {
    
    if ($k eq 'ROLE') {
      $link =~ s/<ROLE>/$v/;
    }

    if ($k eq 'COMPOUND') {
      $link =~ s/<COMPOUND>/$v/;
    }

    if ($k eq 'SUBSYSTEM') {
      $link =~ s/<SUBSYSTEM>/$v/;
    }
  }

  return $link;
}
 
# copy from WebApplication::WebComponent::WebGD to make this module independant of WebApplication   
sub image_src {
  my ($image) = @_;

  my $image_link = "";
  my $user_agent = $ENV{HTTP_USER_AGENT};
  if ($user_agent =~ /MSIE/) {
    $user_agent = 'IE';
  }
  if ($user_agent eq 'IE' || $FIG_Config::file_images_only) {
    my ($fh, $filename) = tempfile( TEMPLATE => 'webimageXXXXX', DIR => $FIG_Config::temp, SUFFIX => '.png' );
    print $fh $image->png();
    close $fh;
    $filename =~ s/.*\/(\w+\.png)$/$1/;
    $image_link = $FIG_Config::temp_url."/".$filename;
  } else {
    my $mime = MIME::Base64::encode($image->png(), "");
    $image_link = "data:image/gif;base64,$mime";
  }

  return $image_link;
}
