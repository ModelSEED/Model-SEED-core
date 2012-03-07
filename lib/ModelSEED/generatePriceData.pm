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
with 'MooseX::Getopt';

# Basic arugments ( command line too )
has likelihood => (is => 'rw', isa => 'Str', required => 1);
has input      => (is => 'rw', isa => 'Str', required => 1);
has model      => (is => 'rw', isa => 'Str', required => 1);
has biomass => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    lazy    => 1,
    builder => '_buildBiomass'
);
has media => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    lazy    => 1,
    builder => '_buildMedia',
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
has DBhostname => (is => 'ro', isa => 'Str');
has DBusername => (is => 'ro', isa => 'Str');
has DBpassword => (is => 'ro', isa => 'Str');
has DBsock     => (is => 'ro', isa => 'Str');


# Run() - this is called when this is run as a command line script.
# Generate the input.xml and the likelihood.xml files.
sub run {
    my ($self) = @_;
    # print the input.xml file
    my $inputXML = XML::LibXML->createDocument;
    my $data = $inputXML->createElement("data");
    my $growths = [];
    foreach my $biomass (@{$self->biomass}) {
        foreach my $media (@{$self->media}) {
            push(@$growths, {biomass => $biomass, media => $media});
        }
    }
    foreach my $growth (@$growths) {
        my $growth = $data->createElement("growth");
        my $mediaName = $growth->{media};
        my $biomassId = $growth->{biomass};
        $growth->appendChild($self->createMediaNameNode($mediaName));
        $growth->appendChild($self->createMediaNode($mediaName));
        # drain fluxes are <byproducts> TODO
        $data->appendChiled($self->createBiomass($biomassId));
    }
    # print the likelihood.xml file
    my $likelihoodXML = XML::LibXML->createDocument;
     
    $likelihoodXML->toFile($self->likelihood);
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
    die "Unknown media with name: $mediaName\n";
    my $mediaEl = XML::LibXML::Element->new("media");

    # foreach element, convert the compound uuid => id
    foreach my $media_cpd (@{$mediaObject->media_compounds}) {
        my $name = $media_cpd->compound->name;
        my $id   = $self->convertCompound($media_cpd->compound);
        my $rate = $media_cpd->maxFlux;    # FIXME what's the real rate?
        my $el = XML::LibXML::Element->new("metab");
        $el->appendChild($self->_createElWithText("met_id", $id));
        $el->appendChild($self->_createElWithText("name",   $name));
        $el->appendChild($self->_createElWithText("rate",   $rate));
        $mediaEl->appendChild($el);
    }
    return $mediaEl;
}

sub createBiomassNode {
    my ($self, $biomassId) = @_;
    # get the biomass object from the model
    my $biomassObject = $self->modelObject->getBiomass( { id => $biomassId } );
    die "Unknown biomass with id: $biomassId\n";
    my $biomassEl = XML::LibXML::Element->new("biomass");
    foreach my $bio_cpd (@{$biomassObject->biomass_compounds}) {
        my $name = $bio_cpd->compound->name;
        my $id   = $self->convertCompound($bio_cpd->compound);
        my $stoich = $bio_cpd->coefficient;
        my $el = XML::LibXML::Element->new("s");
        $el->appendChild($self->_createElWithText("met_id", $id));
        $el->appendChild($self->_createElWithText("name", $name));
        $el->appendChild($self->_createElWithText("stoich", $stoich));
        $biomassEl->appendChild($el); 
    }
    return $biomassEl;
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
    my $data = $self->coreApi->getModel({id => $modelId});
    my $object = ModelSEED::MS::Model->new($data);
    $self->modelObject($object);
}

sub _buildBiochemistry {
    my ($self) = @_;
    my $model = $self->modelObject;
    my $uuid = $model->biochemistry_uuid;
    my $data = $self->coreApi->getBiochemistry({uuid => $uuid});
    my $object = ModelSEEED::MS::Biochemistry->new($data);
    return $self->bioObject($object);
}

sub _buildCoreApi {
    my ($self) = @_;
    my $options = { 
        database => $self->DBdatabase,
        driver   => $self->DBdriver,
    };
    $options->{hostname} = $self->DBhostname if defined($self->DBhostname);
    $options->{username} = $self->DBusername if defined($self->DBusername);
    $options->{password} = $self->DBpassword if defined($self->DBpassword);
    $options->{sock} = $self->DBsock if defined($self->DBsock);
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
    my $mediaNames = [ map { $_->name } @{$bio->media} ];
    return $self->media($mediaNames);
}

1;

# Main package - called if this is a command line script
# this is the basic modulino pattern.
package main;
use strict;
use warnings;
sub run
{
    my $module = MyApp::Module::Foo->new_with_options();
        $module->run();
}
# run unless we are being called by
# another perl script / package
run() unless caller();
