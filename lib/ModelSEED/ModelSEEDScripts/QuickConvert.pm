#!/usr/bin/env perl
package QuickConvert;
use strict;
use warnings;
use IO::Prompt;
use Encode::Detect::Detector; # Detect encoding
use Text::Iconv;        # Conversion from non-standard encodings to utf-8
use Text::Unidecode;    # Converts non-standard encodings to ascii (agresssive)
use ModelSEED::FIGMODEL;
use Moose;
use Data::Dumper;
with 'MooseX::Getopt';

has auto => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => "If set, do not prompt the user for each conversion",
);

has default => (
    is => 'rw',
    isa => 'Str',
    default => 'utf-8',
    documentation => "Set the default encoding to present, convert to.",
);

has query => (
    is => 'rw',
    isa => 'Str',
    default => "{}",
    documentation => "JSON stirng for query"
);

has type => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    documentation => "Type of objects to validate"
);

has save => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
    documentation => "If set, save, otherwise don't.",
);

has IdAttribute => (
    is => 'rw',
    isa => 'Str',
    documentation => "Attribute on type to use in object description",
);

has summary => (
    is => 'rw',
    isa => 'Bool',
    documentation => "Just print summary of non-ASCII encodings",
);

has ignore => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    default => sub { return []; },
    documentation => "Don't even prompt for an encoding",
);

has useModelDatabase => (
    is => 'rw',
    isa => 'Str',
    documentation => "Supply a model id to use that model's provenance database",
);

has username => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    documentation => "FIGMODEL authentication",
);

has password => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    documentation => "FIGMODEL authentication",
);

sub run {
    my ($self) = @_;
    my $fm = ModelSEED::FIGMODEL->new();
    $fm->authenticate({ username => $self->username, password => $self->password});
    if($self->useModelDatabase) {
        my $mdl = $fm->get_model($self->useModelDatabase);
        $fm = $mdl->figmodel();
    } 
    my $query = JSON::Any->new->jsonToObj($self->query);
    my $objects = $fm->database->get_objects($self->type, $query);
    my $idAttr = $self->IdAttribute;
    print "Found ".scalar(@$objects)." objects of type ".$self->type."\n";
    my $summary = {};
    my $ignoreEncodings = { map { $_ => 1 } @{$self->ignore} };
    foreach my $object (@$objects) {
        foreach my $attr (keys %{$object->attributes()}) {
            my $str = $object->$attr();
            next unless(defined($str));
            if($self->summary) {
                my $isString = $self->_getAttrType($object, $attr);
                my $encoding = $self->_getEncoding($str);
                if($isString && defined($encoding)) {
                    $summary->{$attr}->{$encoding} = 0
                    unless(defined($summary->{$attr}->{$encoding}));
                    $summary->{$attr}->{$encoding} += 1;
                }
            } else {
                my $isString = $self->_getAttrType($object, $attr);
                my $encoding = $self->_getEncoding($str);
                if($isString && defined($encoding)) {
                    if(defined($idAttr)) {
                        print "Found $encoding on ".$object->$idAttr." $attr\n";
                        if(defined($ignoreEncodings->{$encoding})) {
                            print "Skipping\n";
                            next;
                        }
                        my $newStr = $self->_change($str, $encoding);
                        next unless(defined($newStr));
                        if($self->save) {
                            $object->$attr($newStr);
                        }
                    }
                }
            }
        }
    }
    if($self->summary) {
        print Dumper $summary;
    }
}

sub _getAttrType {
    my ($self, $object, $attribute) = @_;
    return 1;
}

sub _getEncoding {
    my ($self, $str) = @_;
    return Encode::Detect::Detector::detect($str);
}

sub _change {
    my ($self, $str, $fromEnc) = @_;
    my $startStr = $str;
    my $startEnc = $fromEnc;
    my $newStr = $str;
    my $notDone = 1;
    my $toEnc = $self->default;
    while ( $notDone ) {
        print "Converting $fromEnc to $toEnc\n";
        my $conv = $self->_convert($str, $fromEnc, $toEnc);
        print "Old: $str\n";
        print "New: $conv\n";
        prompt "[reset|skip|set|accept|try \$enc] : ";
        chomp $_;
        if($_ eq 'accept') {
            $newStr = $conv;
            $notDone = 0;
        } elsif ($_  eq 'set') {
            $str = $conv;
            $fromEnc = $toEnc;
        } elsif ($_ =~ /^try (.*)$/) {
            $toEnc = $1;
        } elsif ($_ eq "skip") {
            return undef;
        } elsif ($_ eq "reset") {
            $newStr = $str = $startStr;
            $fromEnc = $startEnc;
            $toEnc = $self->default;
        }
    }
    return $newStr;
}

sub _convert {
    my ($self, $str, $from, $to) = @_;
    if ($to eq 'manual') {
        print "Old: $str\n";
        prompt "New: ";
        chomp $_;
        return $_;
    } elsif ($to eq 'smart-ASCII') {
        return unidecode($str);
    } else {
        my $converter = Text::Iconv->new($from, $to);
        return $converter->convert($str);
    }
}

1;

# Main package - called if this is a command line script
# this is the basic modulino pattern.
package main;
use strict;
use warnings;
sub run {
    my $module = QuickConvert->new_with_options();
    $module->run();
}
# run unless we are being called by
# another perl script / package
run() unless caller();

1;
