package ModelSEED::generatePriceData;
#===============================================================================
#
#         FILE: generatePriceData.pm
#
#  DESCRIPTION: 
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Scott Devoid, devoid@ci.uchicago.edu
#      COMPANY: University of Chicago / Argonne Nat. Lab.
#      VERSION: 1.0
#      CREATED: 03/07/2012 11:24:04
#     REVISION: ---
#===============================================================================
use Moose;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Model;
use ModelSEED::CoreApi;
use XML::LibXML;
use Data::Dumper;
with 'MooseX::Getopt';

# Basic arugments ( command line too )
has likelihood => (
    is            => 'rw',
    isa           => 'Str',
    required      => 1,
    documentation => "Output likelihoods file name (required)"
);
has input => (
    is            => 'rw',
    isa           => 'Str',
    required      => 1,
    documentation => "Output model file name (required)"
);
has model => (
    is            => 'rw',
    isa           => 'Str',
    required      => 1,
    documentation => "Id of model (required)"
);
has biomass => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    lazy    => 1,
    builder => '_buildBiomass',
    documentation => "Id of a biomass objective function (required)",
);
has media => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    lazy    => 1,
    builder => '_buildMedia',
    documentation => "Name of a media condition (required)",
);

# --likelihood filename --input filename --model id --biomass bio-id --biomass bio-id --media meida-id

## Internal data objects
has _bio => (
    is       => 'rw',
    isa      => 'ModelSEED::MS::Biochemistry',
    builder  => '_buildBiochemistry',
    lazy     => 1,
    accessor => 'bioObject',

);
has _model => (
    is       => 'rw',
    isa      => 'ModelSEED::MS::Model',
    builder  => '_buildModel',
    lazy     => 1,
    accessor => 'modelObject',
);
has _coreApi => (
    is      => 'rw',
    isa     => 'ModelSEED::CoreApi',
    builder => '_buildCoreApi',
    lazy    => 1,
    accessor => 'coreApi',
);

has _conversionData => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { return {}; },
    accessor => 'conversionData',
);

has _conversionIndexes => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { return {}; },
    accessor => 'conversionIndexes',
);

## Database Configuration Options
has DBdatabase => (
    is      => 'ro',
    isa     => 'Str',
    default => $ENV{MODEL_SEED_CORE} . "/data/ModelDB.db"
);
has DBdriver => (is => 'ro', isa => 'Str', default => 'SQLite');
has DBdsn      => (is => 'ro', isa => 'Str');
has DBusername => (is => 'ro', isa => 'Str');
has DBpassword => (is => 'ro', isa => 'Str');


# Run() - this is called when this is run as a command line script.
# Generate the input.xml and the likelihood.xml files.
sub run {
    my ($self) = @_;
    # print the input.xml file
    my $inputXML = XML::LibXML->createDocument;
    my $data = XML::LibXML::Element->new("data");
    $inputXML->addChild($data);
    my $growths = [];
    foreach my $biomass (@{$self->biomass}) {
        foreach my $media (@{$self->media}) {
            push(@$growths, { biomass => $biomass, media => $media });
        }
    }
    foreach my $growth (@$growths) {
        my $growthXML = XML::LibXML::Element->new("growth");
        $data->addChild($growthXML);
        my $mediaName = $growth->{media};
        my $biomassId = $growth->{biomass};
        $growthXML->addChild($self->createMediaNameNode($mediaName));
        $growthXML->addChild($self->createMediaNode($mediaName));
        # drain fluxes are <byproducts> TODO
        $data->addChild($self->createBiomassNode($biomassId));
    }
    $inputXML->toFile($self->input, 1);
    # print the likelihood.xml file
    my $likelihoodXML = XML::LibXML->createDocument;
    my $model = XML::LibXML::Element->new("model");
    $likelihoodXML->addChild($model);
    foreach my $compound (@{$self->modelObject->biochemistry->compounds}) {
        $model->addChild($self->createMetaboliteNode($compound));
    }
    my $reactions = [ map { $_->reaction } @{$self->modelObject->model_reactions} ];
    foreach my $reaction (@$reactions) {
        $model->addChild($self->createReactionNode($reaction));
    }
    $likelihoodXML->toFile($self->likelihood, 1);
}

sub createMediaNameNode {
    my ($self, $mediaName) = @_;
    my $el = XML::LibXML::Element->new("mediaName");
    $el->appendTextNode($mediaName);
    return $el;
}

sub createMediaNode {
    my ($self, $mediaName) = @_;

    # get the media object from the biochemistry
    my $mediaObject = $self->bioObject->getMedia({name => $mediaName});
    die "Unknown media with name: $mediaName\n" unless(defined($mediaObject));
    my $mediaEl = XML::LibXML::Element->new("media");

    # foreach element, convert the compound uuid => id
    foreach my $media_cpd (@{$mediaObject->media_compounds}) {
        my $name = _convertName($media_cpd->compound->name);
        my $id   = $self->convertCompound($media_cpd->compound);
        my $rate = $media_cpd->maxflux;    # FIXME what's the real rate?
        my $el = XML::LibXML::Element->new("metab");
        $el->addChild($self->_createElWithText("met_id", $id));
        $el->addChild($self->_createElWithText("name",   $name));
        $el->addChild($self->_createElWithText("rate",   $rate));
        $mediaEl->addChild($el);
    }
    return $mediaEl;
}

sub createBiomassNode {
    my ($self, $biomassId) = @_;
    # get the biomass object from the model
    my $biomassObject = $self->modelObject->getBiomass( { id => $biomassId } );
    die "Unknown biomass with id: $biomassId\n" unless(defined($biomassObject));
    my $biomassEl = XML::LibXML::Element->new("biomass");
    foreach my $bio_cpd (@{$biomassObject->biomass_compounds}) {
        my $name = _convertName($bio_cpd->compound->name);
        my $id   = $self->convertCompound($bio_cpd->compound);
        my $stoich = $bio_cpd->coefficient;
        my $el = XML::LibXML::Element->new("s");
        $el->addChild($self->_createElWithText("met_id", $id));
        $el->addChild($self->_createElWithText("name", $name));
        $el->addChild($self->_createElWithText("stoich", $stoich));
        $biomassEl->addChild($el); 
    }
    return $biomassEl;
}

sub createMetaboliteNode {
    my ($self, $compound) = @_;
    my $name = _convertName($compound->name);
    my $id   = $self->convertCompound($compound);
    my $el = XML::LibXML::Element->new("metabolite");
    $el->addChild($self->_createElWithText("met_id", $id));
    $el->addChild($self->_createElWithText("name", $name));
    return $el;
}

sub createReactionNode {
    my ($self, $reaction) = @_;
    my $el = XML::LibXML::Element->new("reaction");
    my $id = $self->convertReaction($reaction);
    my $name = _convertName($reaction->name);
    my $transport = $reaction->isTransport;
    $el->addChild($self->_createElWithText("id", $id));
    $el->addChild($self->_createElWithText("name", $name));
    $el->addChild($self->_createElWithText("transport", $transport));
    foreach my $reagent (@{$reaction->reagents}) {
        my $s = XML::LibXML::Element->new("s");
        $el->addChild($s);
        my $met_id = $self->convertCompound($reagent->{compound});
        $s->addChild($self->_createElWithText("met_id", $met_id));
        $s->addChild($self->_createElWithText("stoich", $reagent->{coefficient}));

    }
    return $el;
}

sub _createElWithText {
    my ($self, $elName, $text) = @_;
    my $el = XML::LibXML::Element->new($elName);
    $el->appendTextNode($text);
    return $el;
}

sub convertCompound {
    my ($self, $compoundObject) = @_;
    return $self->_internalConvert("compound", $compoundObject->uuid);
}

sub convertReaction {
    my ($self, $reactionObject) = @_;
    return $self->_internalConvert("reaction", $reactionObject->uuid);
}

sub _internalConvert {
    my ($self, $type, $str) = @_;

    # initialize the conversion data structure if not defined
    unless (defined($self->conversionData->{$type})) {
        $self->conversionData->{$type}    = {};
        $self->conversionIndexes->{$type} = 0;
    }
    my $c   = $self->conversionData->{$type};
    my $idx = $self->conversionIndexes->{$type};
    if (!defined($c->{$str})) {

        # set and increment the index if we haven't
        # already added that object to the set
        $c->{$str} = $idx;
        $self->conversionIndexes->{$type} += 1;
    }
    return $c->{$str};
}

sub printIdConversionData {
    # TODO - impelement
}


# Builders for modelObject, bioObject, coreApi
sub _buildModel {
    my ($self) = @_;
    my $modelId = $self->model;
    my $data = $self->coreApi->getModel({id => $modelId, with_all => 1});
    my $object = ModelSEED::MS::Model->new($data);
    $self->modelObject($object);
}

sub _buildBiochemistry {
    my ($self) = @_;
    my $model = $self->modelObject;
    my $object = $model->biochemistry;
    return $self->bioObject($object);
}

sub _buildCoreApi {
    my ($self) = @_;
    my $options;
    if(defined($self->DBdsn)) {
        $options = {
            dsn => $self->DBdsn,
            username => $self->DBusername,
            password => $self->DBpassword,
        };
    } else {
        $options = { 
            database => $self->DBdatabase,
            driver   => $self->DBdriver,
        };
    }
    return $self->coreApi(ModelSEED::CoreApi->new($options));
}

sub _buildBiomass {
    my ($self) = @_;
    my $model = $self->modelObject;
    my $biomassNames = [ map { $_->id } @{$model->biomasses} ];
    return $self->biomass($biomassNames);
}

sub _buildMedia {
    my ($self) = @_;
    my $bio = $self->bioObject;
    my $mediaNames = [ map { _convertName($_->name) } @{$bio->media} ];
    return $self->media($mediaNames);
}

sub _convertName {
    return $_[0];
}

1;

# Main package - called if this is a command line script
# this is the basic modulino pattern.
package main;
use strict;
use warnings;
sub run
{
    my $module = ModelSEED::generatePriceData->new_with_options();
        $module->run();
}
# run unless we are being called by
# another perl script / package
run() unless caller();
