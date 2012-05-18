package NCBI_taxonomy;

#
# This is a SAS Component
#

#===============================================================================
#  Get information from the NCBI taxonomy database.
#
#      \%data = taxonomy( $taxid, { hash =>  1     } )
#
#       @data = taxonomy( $taxid, { key  =>  $key  } )
#      \@data = taxonomy( $taxid, { key  =>  $key  } )
#
#       @data = taxonomy( $taxid, { path => \@path } )
#      \@data = taxonomy( $taxid, { path => \@path } )
#
#      \@xml  = taxonomy( $taxid, { xml  =>  1     } )
#
#  Keys:
#
#      CommonName                 # Common name (might be a list)
#      Division                   # GenBank division (not 3-letter abbrev)
#      GeneticCode                # Genetic code number
#      Lineage                    # Full lineage text, semicolon separated
#      LineageAbbrev              # Abbreviated lineage text, semicolon sep.
#      LineageAbbrevIds           # List of abbreviated lineage ids
#      LineageAbbrevNames         # List of abbreviated lineage names
#      LineageAbbrevPlus          # Abbreviated lineage with full lineage suffix
#      LineageAbbrevPlusIds       # List of LineageAbbrevPlus ids
#      LineageAbbrevPlusNames     # List of LineageAbbrevPlus names
#      LineageExIds               # See LineageIds
#      LineageIds                 # List of full lineage taxids
#      LineageExNames             # List of full lineage names
#      LineageNames               # See LineageNames
#      MitochondrialGeneticCode   # Mitochondrial genetic code number
#      Parent                     # Parent node taxid
#      Rank                       # Rank
#      ScientificName             # Scientific name (binomial for species)
#
#  In the first form, a hash reference is returned with the keys listed above.
#  Each associated value is a reference to a list, which usually only includes
#  one item.  The LineageEx... keys are lists of the complete lineage.
#
#  The second form returns the data associated with a given key from the above
#  list.
#
#  The third form allows access to an anrbrary datum in the XML heirarchy.
#  The following 2 requests are equivalent:
#
#      taxonomy( $taxid, { key  => 'GeneticCode' } )
#      taxonomy( $taxid, { path => [ qw( Taxon GeneticCode GCId ) ] } )
#
#  The last form returns the XML hierarchy in perl lists of the form:
#
#      [ tag, [ enclosed_items, ... ] ]
#
#-------------------------------------------------------------------------------
#  It does not seem to be possible to get the short lineage without loading
#  the taxonmy browser page.  Oh bother.
#
#    $lineage = lineage_abbreviated( $taxid );
#
#-------------------------------------------------------------------------------
#  Functions for doing the major steps:
#-------------------------------------------------------------------------------
#  Get and parse the XML for an NCBI taxonomy entry:
#
#      $xml = taxonomy_xml( $taxid )
#
#  The XML is composed of items of the form:
#
#      [ tag, [ content, ... ] ]
#
#-------------------------------------------------------------------------------
#  Extract specific items from the NCBI taxonomy by keyword:
#
#      @key_valuelist = taxonomy_data( $xml, @data_keys );
#
#-------------------------------------------------------------------------------
#  Extract a specific item from the NCBI taxonomy by complete path through
#  XML tags.
#
#      @values = taxonomy_datum( $xml, @path );
#
#-------------------------------------------------------------------------------

use strict;
use SeedAware;
use Data::Dumper;

#
#  This hash is used to store paths to specific data.
#
my %path = (
             CommonName      => [ qw( Taxon OtherNames CommonName ) ],
             Division        => [ qw( Taxon Division ) ],
             GCId            => [ qw( Taxon GeneticCode GCId ) ],
             GeneticCode     => [ qw( Taxon GeneticCode GCId ) ],
             Lineage         => [ qw( Taxon Lineage ) ],
             LineageIds      => [ qw( Taxon LineageEx Taxon TaxId ) ],
             LineageNames    => [ qw( Taxon LineageEx Taxon ScientificName ) ],
             MGCId           => [ qw( Taxon MitoGeneticCode MGCId ) ],
             MitoGeneticCode => [ qw( Taxon MitoGeneticCode MGCId ) ],
             Parent          => [ qw( Taxon ParentTaxId ) ],
             ParentTaxId     => [ qw( Taxon ParentTaxId ) ],
             Rank            => [ qw( Taxon Rank ) ],
             ScientificName  => [ qw( Taxon ScientificName ) ],
             TaxId           => [ qw( Taxon TaxId ) ],
             Taxonomy        => [ qw( Taxon Lineage ) ],
           );


sub taxonomy
{
    my $taxid = shift;
    return undef unless defined $taxid && $taxid =~ s/^(\d+)/$1/;

    my $options = ( ! @_ || ! $_[0] )           ? { key => 'Lineage'  }
                : ( ! ref( $_[0] ) )            ? { key => $_[0]      }
                : (   ref( $_[0] ) eq 'ARRAY' ) ? { key => $_[0]->[0] }
                : (   ref( $_[0] ) ne 'HASH' )  ? { key => 'Lineage'  }
                :                                 $_[0];

    #  This is the only instance in which we do not need the XML:

    my $ps_key = pseudo_key( $options->{ key } );
    if ( $ps_key eq 'LineageAbbrev' )
    {
        my $datum = lineage_abbreviated( $taxid );
        return wantarray ? ( $datum ) : [ $datum ];
    }

    my $taxon_xml = taxonomy_xml( $taxid );
    return () unless $taxon_xml && ref( $taxon_xml ) eq 'ARRAY' &&  @$taxon_xml;

    #  XML

    return $taxon_xml  if $options->{ xml };

    #  Hash of keys and values, or an type that we need to derive

    if ( $options->{ hash } || $ps_key )
    {
        my %results = ();

        #  These are the keys for deriving lineages:

        foreach my $key ( qw( Lineage LineageNames LineageIds ) )
        {
            my @values = taxonomy_datum( $taxon_xml, @{ $path{ $key } } );
            $results{ $key } = \@values if @values;
        }

        #  These will probably never happen, but it could be useful:

        my $Lineage = $results{ Lineage } && @{ $results{ Lineage } } ? $results{ Lineage }->[0] : '';
        if ( ! $results{ LineageNames } && $Lineage )
        {
            $results{ LineageNames } = text2list( $Lineage );
        }

        if ( ! $Lineage && $results{ LineageNames } && @{ $results{ LineageNames } } )
        {
            $results{ Lineage } = list2text( $results{ LineageNames } );
            $Lineage = $results{ Lineage }->[0]
        }

        #  Get the abbreviated lineage:

        my $LineageAbbrev = lineage_abbreviated( $taxid );
        $results{ LineageAbbrev } = [ $LineageAbbrev ];

        if ( $LineageAbbrev )
        {
            my $AbbrevNames = text2list( $LineageAbbrev );
            return wantarray ? @$AbbrevNames : $AbbrevNames if $ps_key eq 'LineageAbbrevNames';

            my %id;
            my $LineageIds   = $results{ LineageIds };
            my $LineageNames = $results{ LineageNames };
            if ( $LineageIds && $LineageNames && @$LineageIds == @$LineageNames )
            {
                for ( my $i = 0; $i < @$LineageIds; $i++ )
                {
                    $id{ $LineageNames->[ $i ] } = $LineageIds->[ $i ];
                }

                my $AbbrevIds = [ map { $id{ $_ } } @$AbbrevNames ];
                return wantarray ? @$AbbrevIds : $AbbrevIds if $ps_key eq 'LineageAbbrevIds';

                $results{ LineageAbbrevIds } = $AbbrevIds;
            }

            $results{ LineageAbbrevNames } = $AbbrevNames;

            #  There is a peculiarity of the abbreviated lineage that it does not
            #  include the species binomial.  We will add LineageAbbrevPlus, which
            #  adds a suffix of categories at the end of the full lineage, but not
            #  in the abbreviated lineage.

            if ( $LineageNames && @$LineageNames )
            {
                my @suffix = ();
                foreach ( reverse @$LineageNames )
                {
                    last if $_ eq $AbbrevNames->[-1];
                    push @suffix, $_;
                }
                # die "NCBI_taxonomy::taxonomy: Terminal taxon in abbreviated lineage not found in full lineage.\n    $LineageAbbrev\n    $Lineage\n" if @suffix == @$LineageNames;

                @suffix = () if @suffix == @$LineageNames;
                my $AbbrevPlusNames = [ @$AbbrevNames, @suffix ];

                return wantarray ? @$AbbrevPlusNames : $AbbrevPlusNames if $ps_key eq 'LineageAbbrevPlusNames';

                my $AbbrevPlusIds = keys %id ? [ map { $id{ $_ } } @$AbbrevPlusNames ] : undef;

                return wantarray ? @$AbbrevPlusIds : $AbbrevPlusIds if $ps_key eq 'LineageAbbrevPlusIds';

                my $AbbrevPlus = list2text( $AbbrevPlusNames );
                return wantarray ? @$AbbrevPlus : $AbbrevPlus if $ps_key eq 'LineageAbbrevPlus';

                $results{ LineageAbbrevPlusNames } = $AbbrevPlusNames;
                $results{ LineageAbbrevPlusIds   } = $AbbrevPlusIds  if $AbbrevPlusIds;
                $results{ LineageAbbrevPlus      } = $AbbrevPlus;
            }
        }

        #  These are other keys that we can get from the XML:

        my @keys = qw( CommonName
                       Division
                       GeneticCode
                       MitochondrialGeneticCode
                       Parent
                       Rank
                       ScientificName
                     );
        foreach my $key ( @keys )
        {
            my @values = taxonomy_datum( $taxon_xml, @{ $path{ $key } } );
            $results{ $key } = \@values if @values;
        }

        return \%results;
    }

    my $path = $options->{ path };
    if ( ! ( $path && ( ref( $path ) eq 'ARRAY' ) && @$path ) )
    {
        my $key = cannonical_key( $options->{ key } );
        $path = $path{ $key };
    }

    my @data = taxonomy_datum( $taxon_xml, @$path );

    wantarray ? @data : \@data;
}


sub text2list { [ split /; +/, $_[0] ] }


sub list2text { [ join '; ', @{ $_[0] } ] }


#  These are not in the XML, but we can build them:

sub pseudo_key
{
    local $_ = shift || '';
    return  m/Abb.*Pl.*Nam/i ? 'LineageAbbrevPlusNames' :
            m/Abb.*Pl.*Id/i  ? 'LineageAbbrevPlusIds'   :
            m/Abb.*Pl/i      ? 'LineageAbbrevPlus'      :
            m/Abb.*Nam/i     ? 'LineageAbbrevNames'     :
            m/Abb.*Id/i      ? 'LineageAbbrevIds'       :
            m/Abb/i          ? 'LineageAbbrev'          :
            m/^Lin.*Sh/i     ? 'LineageAbbrev'          :  # LineageShort
                               '';
}


sub cannonical_key
{
    local $_ = shift || '';
    return  ( ! $_ )          ? 'Lineage'                  :
            m/^Cod/i          ? 'GeneticCode'              :
            m/^Com/i          ? 'CommonName'               :
            m/^Div/i          ? 'Division'                 :
            m/^Gen/i          ? 'GeneticCode'              :
            m/^Lin.*Id/i      ? 'LineageIds'               :
            m/^Lin.*Nam/i     ? 'LineageNames'             :
            m/^Lin/i          ? 'Lineage'                  :
            m/^Mit/i          ? 'MitochondrialGeneticCode' :
            m/^Par/i          ? 'Parent'                   :
            m/^Ran/i          ? 'Rank'                     :
            m/^Sci/i          ? 'ScientificName'           :
            m/^Tax/i          ? 'Lineage'                  :
                                'Lineage';
}


#-------------------------------------------------------------------------------
#  Get and parse the NCBI XML for a taxonomy entry:
#
#    $xml = taxonomy_xml( $taxid );
#
#  The XML is composed of items of the form:
#
#      [ tag, [ content, ... ] ]
#
#-------------------------------------------------------------------------------

sub taxonomy_xml
{
    my $curl = SeedAware::executable_for( 'curl' )
        or die "Could not find executable for 'curl'.\n";

    my $url = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi';
    my $id = shift;

    my %request = ( db     => 'taxonomy',
                    id     => $id,
                    report => 'xml',
                  );
    my $request = join( '&', map { "$_=" . url_encode( $request{$_}||'' ) } qw( db id report ) );

    my $pass = 0;
    my @return = #  Remove XML header
                 grep { /./ && ! /^<[?!]/ && ! /^<\/?pre>/ }
                 grep { if ( /^<pre>/ ) { $pass = 1 } elsif ( /^<\/pre>/ ) { $pass = 0 }; $pass }
                 map  { xml_unescape( $_ ) }         # Decode HTML body content
                 map  { chomp; s/^\s+//; s/\s+$//; $_ }
                 SeedAware::run_gathering_output( $curl, '-s', "$url?$request" );
    ( xml_items( \@return, undef ) )[0];
}


#  This is a very crude parser that handles NCBI XML:

sub xml_items
{
    my ( $list, $close ) = @_;
    my @items = defined $close ? ( $close ) : ();
    while ( my $item = xml_item( $list, $close ) ) { push @items, $item }
    @items;
}


sub xml_item
{
    my ( $list, $close ) = @_;
    local $_ = shift @$list;
    return undef if ! $_ || defined $close && /^<\/$close>/;
    die "Bad closing tag '$_'." if /^<\//;
    return( [ $1, xml_unescape($2) ] ) if /^<(\S+)>(.*)<\/(\S+)>$/ && $1 eq $3;
    return( [ $1, $1 ] ) if /^<(\S+)\s*\/>$/;
    die "Bad line '$_'." if ! /^<(\S+)>$/;
    [ xml_items( $list, $1 ) ];
}


#-------------------------------------------------------------------------------
#  Extract items from the taxonomy:
#-------------------------------------------------------------------------------

#
#  @key_valuelist = taxonomy_data( $xml, @data_keys );
#
sub taxonomy_data
{
    my $xml = shift;
    return () unless $xml && ref $xml eq 'ARRAY' && @$xml > 1;
    map { [ $_, [ taxonomy_datum( $xml, @{$path{$_}} ) ] ] } grep { $path{$_} } @_;
}


#
#  @values = taxonomy_datum( $xml, @path );
#
sub taxonomy_datum
{
    my ( $xml, @path ) = @_;

    return () unless $xml && ref $xml eq 'ARRAY' && @$xml > 1 && @path;

    my $match = $xml->[0] eq $path[0];
    return () unless $match || ( $xml->[0] eq 'TaxaSet' );

    shift @path if $match;

    @path ? map  { taxonomy_datum( $_, @path ) } @$xml[ 1 .. (@$xml-1) ]
          : grep { defined() && ! ref() }        @$xml[ 1 .. (@$xml-1) ];
}


#-------------------------------------------------------------------------------
#  It does not seem to be possible to get the short lineage without loading
#  the taxonmy browser page.  Oh bother.
#
#    $lineage = lineage_abbreviated( $taxid );
#
#-------------------------------------------------------------------------------
sub lineage_abbreviated
{
    my $curl = SeedAware::executable_for( 'curl' )
        or die "Could not find executable for 'curl'.\n";

    my $id = shift;
    defined $id or return undef;

    my $url = 'http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi';
    my %request = ( id => $id, lin => 's', lvl => 1 );
    my $request = join( '&', map { "$_=" . url_encode( $request{$_}||'' ) } qw( id lin lvl ) );

    chomp( my @html = SeedAware::run_gathering_output( $curl, '-s', "$url?$request" ) );

    local $_;
    while ( defined( $_ = shift @html ) && ! s/^.*Lineage.*abbreviated\s*// ) {}
    return undef if ! defined $_;

    my @part = m/<A [^>]*TITLE=[^>]*>([^<]*)<\/A>/gi;
    if ( ! @part )
    {
        $_ = shift @html;
        @part = m/<A [^>]*TITLE=[^>]*>([^<]*)<\/A>/gi  if defined $_;
        return undef if ! @part;
    }

    join( '; ', grep { $_ ne 'root' }
                map  { s/\s+/ /g; s/^ //; s/ $//; xml_unescape( $_ ) }
                @part
        );
}



#-------------------------------------------------------------------------------
#  Auxiliary functions:
#-------------------------------------------------------------------------------
#
#  Function to escape the called URL:

my %url_esc = (  ( ' ' => '%20',
                   '"' => '%22',
                   '#' => '%23',
                   '$' => '%24',
                   ',' => '%2C' ),
               qw(  !      %21
                    %      %25
                    +      %2B
                    &      %2D
                    /      %2F
                    :      %3A
                    ;      %3B
                    <      %3C
                    =      %3D
                    >      %3E
                    ?      %3F
                    @      %40
                    [      %5B
                    \      %5C
                    ]      %5D
                    `      %60
                    {      %7B
                    |      %7C
                    }      %7D
                    ~      %7E
                 )
              );

sub url_encode { join( '', map { $url_esc{$_}||$_ } split //, $_[0] ) }


#  http://en.wikipedia.org/wiki/List_of_XML_and_HTML_character_entity_references

my %predef_ent;
BEGIN {
%predef_ent =
    ( # XML predefined entities:
      amp    => '&',
      apos   => "'",
      gt     => '>',
      lt     => '<',
      quot   => '"',

      # HTML predefined entities:
      nbsp   => ' ',
      iexcl  => '¡',
      cent    => '¢',
      pound   => '£',
      curren  => '¤',
      yen     => '¥',
      brvbar  => '¦',
      sect    => '§',
      uml     => '¨',
      copy    => '©',
      ordf    => 'ª',
      laquo   => '«',
      not     => '¬',
      shy     => ' ',
      reg     => '®',
      macr    => '¯',
      deg     => '°',
      plusmn  => '±',
      sup2    => '²',
      sup3    => '³',
      acute   => '´',
      micro   => 'µ',
      para    => '¶',
      middot  => '·',
      cedil   => '¸',
      sup1    => '¹',
      ordm    => 'º',
      raquo   => '»',
      frac14  => '¼',
      frac12  => '½',
      frac34  => '¾',
      iquest  => '¿',
      Agrave  => 'À',
      Aacute  => 'Á',
      Acirc   => 'Â',
      Atilde  => 'Ã',
      Auml    => 'Ä',
      Aring   => 'Å',
      AElig   => 'Æ',
      Ccedil  => 'Ç',
      Egrave  => 'È',
      Eacute  => 'É',
      Ecirc   => 'Ê',
      Euml    => 'Ë',
      Igrave  => 'Ì',
      Iacute  => 'Í',
      Icirc   => 'Î',
      Iuml    => 'Ï',
      ETH     => 'Ð',
      Ntilde  => 'Ñ',
      Ograve  => 'Ò',
      Oacute  => 'Ó',
      Ocirc   => 'Ô',
      Otilde  => 'Õ',
      Ouml    => 'Ö',
      times   => '×',
      Oslash  => 'Ø',
      Ugrave  => 'Ù',
      Uacute  => 'Ú',
      Ucirc   => 'Û',
      Uuml    => 'Ü',
      Yacute  => 'Ý',
      THORN   => 'Þ',
      szlig   => 'ß',
      agrave  => 'à',
      aacute  => 'á',
      acirc   => 'â',
      atilde  => 'ã',
      auml    => 'ä',
      aring   => 'å',
      aelig   => 'æ',
      ccedil  => 'ç',
      egrave  => 'è',
      eacute  => 'é',
      ecirc   => 'ê',
      euml    => 'ë',
      igrave  => 'ì',
      iacute  => 'í',
      icirc   => 'î',
      iuml    => 'ï',
      eth     => 'ð',
      ntilde  => 'ñ',
      ograve  => 'ò',
      oacute  => 'ó',
      ocirc   => 'ô',
      otilde  => 'õ',
      ouml    => 'ö',
      divide  => '÷',
      oslash  => 'ø',
      ugrave  => 'ù',
      uacute  => 'ú',
      ucirc   => 'û',
      uuml    => 'ü',
      yacute  => 'ý',
      thorn   => 'þ',
      yuml    => 'ÿ',
      OElig   => 'Œ',
      oelig   => 'œ',
      Scaron  => 'Š',
      scaron  => 'š',
      Yuml    => 'Ÿ',
      fnof    => 'ƒ',
      circ    => 'ˆ',
      tilde   => '˜',
      Alpha   => 'Α',
      Beta    => 'Β',
      Gamma   => 'Γ',
      Delta   => 'Δ',
      Epsilon => 'Ε',
      Zeta    => 'Ζ',
      Eta     => 'Η',
      Theta   => 'Θ',
      Iota    => 'Ι',
      Kappa   => 'Κ',
      Lambda  => 'Λ',
      Mu      => 'Μ',
      Nu      => 'Ν',
      Xi      => 'Ξ',
      Omicron => 'Ο',
      Pi      => 'Π',
      Rho     => 'Ρ',
      Sigma   => 'Σ',
      Tau     => 'Τ',
      Upsilon => 'Υ',
      Phi     => 'Φ',
      Chi     => 'Χ',
      Psi     => 'Ψ',
      Omega   => 'Ω',
      alpha   => 'α',
      beta    => 'β',
      gamma   => 'γ',
      delta   => 'δ',
      epsilon => 'ε',
      zeta    => 'ζ',
      eta     => 'η',
      theta   => 'θ',
      iota    => 'ι',
      kappa   => 'κ',
      lambda  => 'λ',
      mu      => 'μ',
      nu      => 'ν',
      xi      => 'ξ',
      omicron => 'ο',
      pi      => 'π',
      rho     => 'ρ',
      sigmaf  => 'ς',
      sigma   => 'σ',
      tau     => 'τ',
      upsilon => 'υ',
      phi     => 'φ',
      chi     => 'χ',
      psi     => 'ψ',
      omega   => 'ω',
      thetasym => 'ϑ',
      upsih   => 'ϒ',
      piv     => 'ϖ',
      ensp    => ' ',
      emsp    => ' ',
      thinsp  => ' ',
      zwnj    => ' ',
      zwj     => ' ',
      lrm     => ' ',
      rlm     => ' ',
      ndash   => '–',
      mdash   => '—',
      lsquo   => '‘',
      rsquo   => '’',
      sbquo   => '‚',
      ldquo   => '“',
      rdquo   => '”',
      bdquo   => '„',
      dagger  => '†',
      Dagger  => '‡',
      bull    => '•',
      hellip  => '…',
      permil  => '‰',
      prime   => '′',
      Prime   => '″',
      lsaquo  => '‹',
      rsaquo  => '›',
      oline   => '‾',
      frasl   => '⁄',
      euro    => '€',
      image   => 'ℑ',
      weierp  => '℘',
      real    => 'ℜ',
      trade   => '™',
      alefsym => 'ℵ',
      larr    => '←',
      uarr    => '↑',
      rarr    => '→',
      darr    => '↓',
      harr    => '↔',
      crarr   => '↵',
      lArr    => '⇐',
      uArr    => '⇑',
      rArr    => '⇒',
      dArr    => '⇓',
      hArr    => '⇔',
      forall  => '∀',
      part    => '∂',
      exist   => '∃',
      empty   => '∅',
      nabla   => '∇',
      isin    => '∈',
      notin   => '∉',
      ni      => '∋',
      prod    => '∏',
      sum     => '∑',
      minus   => '−',
      lowast  => '∗',
      radic   => '√',
      prop    => '∝',
      infin   => '∞',
      ang     => '∠',
      and     => '∧',
      or      => '∨',
      cap     => '∩',
      cup     => '∪',
      int     => '∫',
      there4  => '∴',
      sim     => '∼',
      cong    => '≅',
      asymp   => '≈',
      ne      => '≠',
      equiv   => '≡',
      le      => '≤',
      ge      => '≥',
      sub     => '⊂',
      sup     => '⊃',
      nsub    => '⊄',
      sube    => '⊆',
      supe    => '⊇',
      oplus   => '⊕',
      otimes  => '⊗',
      perp    => '⊥',
      sdot    => '⋅',
      lceil   => '⌈',
      rceil   => '⌉',
      lfloor  => '⌊',
      rfloor  => '⌋',
      lang    => '〈',
      rang    => '〉',
      loz     => '◊',
      spades  => '♠',
      clubs   => '♣',
      hearts  => '♥',
      diams   => '♦',
    );
}


sub xml_unescape
{
    local $_ = shift;
    s/&#(\d+);/chr($1)/eg;                 #  Numeric character (html)
    s/&#x([\dA-Fa-f]+);/chr(hex($1))/eg;   #  Numeric character (xml)
    s/&(\w+);/$predef_ent{$1}||"&$1;"/eg;  #  Predefined entity
    $_;
}


1;

