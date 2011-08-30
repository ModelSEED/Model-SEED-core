package SeedHTML;

use strict;

# This is a SAS component.

########################### HTML Utilities ###########################


=head1 make_table

The main method to convert an array into a table.

The col_hdrs are set to the <th> headers, the $tab is an array of
arrays. The first is the rows, and the second is the columns. The
title is the title of the table.

The options define the settings for the table such as border, width,
and class for css formatting. 

=cut

sub make_table {
    my($col_hdrs,$tab,$title, %options ) = @_;
    my(@tab);

    my $border = defined $options{border} ? "border=\"$options{border}\"" : "border";
    my $width = defined $options{width} ? "width=\"$options{width}\"" : "";
    my $class = defined $options{class} ? "class=\"$options{class}\"" : "";
    push( @tab, "\n<table $border $width $class>\n",
                "\t<caption><b>$title</b></caption>\n",
                "\t<tr>\n\t\t"
              . join( "\n", map { &expand($_, "th") } @$col_hdrs )
              . "\n\t</tr>\n"
        );
    my($i);

    my $row;
    foreach $row (@$tab)
    {
        push( @tab, "\t<tr>\n"
                  . join( "\n", map { &expand($_) } @$row )
                  . "\n\t</tr>\n"
            );
    }
    push(@tab,"</table>\n");
    return join("",@tab);
}

sub expand {
    shift if UNIVERSAL::isa($_[0],__PACKAGE__);
    my( $x, $tag ) = @_;

    $tag = "td" unless $tag;
    my $endtag = $tag;

    # RAE modified this so that you can pass in a reference to an array where
    # the first element is the data to display and the second element is optional
    # things like colspan and align. Note that in this case you need to include the td
    # use something like ["some data to appear", "td colspan=4 bgcolor=gray"]

    # per GJO's request modified this line so it can take any tag.
    if ( ref($x) eq "ARRAY" ) { ($x, $tag) = @$x; $tag =~ /^(\S+)/; $endtag = $1 }

    if ( $x =~ /^\@([^:]+)\:(.*)$/ )
    {
        return "\t\t<$tag $1>$2</$endtag>";
    }
    else
    {
        return "\t\t<$tag>$x</$endtag>";
    }
}

sub show_page {
    shift if UNIVERSAL::isa($_[0],__PACKAGE__);
    my($cgi,$html) = @_;

    # ARGUMENTS:
    #     $cgi is the CGI method
    #     $html is an array with all the html in it. It is just joined by "\n" (and not <br> or <p>

    print $cgi->header();
    print "<html>\n";
    print qq(<script src="http://theseed.uchicago.edu/FIG/Html/css/FIG.js" type="text/javascript"></script>\n);
    print $_ for @$html;
    print "</html>\n";
}


#
# This was copied from FIGjs.pm
#

=head2 mouseover()

Generate a mouseover for your code.

You can use it like this: 
push @$html, "<a " . FIGjs::mouseover("Title", "Body Text", "Menu", $parent, $title_bg_color, $text_bg_color) . " href='link.cgi'>a link</a>";

and the appropriate javascript will be added for you.

Title: The title of the popup that appears in bold
Body Text: The text to appear in the box.
Menu: This is probably the alternate menu that appears on the pinned regions page??

Please note these should be HTML code so <b>text</b> will appear as bold. Also, please don't put linebreaks in the text since that breaks everything.
The text strings supplied must already be HTML escaped (< or & will be treated as HTML, not text). 

$parent is whether to place the box under the cursor or elsewhere on the page (e.g. top right corner)
Please note that there is an error at the moment and the value of parent doesn't affect anything. 
Note also that I (RAE) didn't add this, but I have left it here for compatability with mouseover calls that expect it to be here.

$title_bg_color is the color of the background for the title. The default blue color is #333399. Please include the # in describing the color
$text_bg_color is the color of the body of the text. The default body color is #CCCCFF. Please include the # in describing the color

You don't need to supply the default colors, but can make the box red or green if you like.

=cut


sub mouseover {
    my ($title, $text, $menu, $parent, $hc, $bc) = @_;

    defined( $title ) or $title = '';
    $title =~ s/'/\\'/g;    # escape '
    $title =~ s/"/&quot;/g; # escape "

    #  Fixed incorrect quoting of $text (reversed single and double quote)
    #  -- GJO

    defined( $text ) or $text = '';
    $text =~ s/'/\\'/g;    # escape '
    $text =~ s/"/&quot;/g; # escape "

    defined( $menu ) or $menu = '';
    $menu =~ s/'/\\'/g;    # escape '
    $menu =~ s/"/&quot;/g; # escape "

    qq( onMouseover="javascript:if(!this.tooltip) this.tooltip=new Popup_Tooltip(this,'$title','$text','$menu','$parent','$hc','$bc');this.tooltip.addHandler(); return false;" );
}

1;
