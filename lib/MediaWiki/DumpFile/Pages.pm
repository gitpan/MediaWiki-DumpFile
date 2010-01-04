package MediaWiki::DumpFile::Pages;

our $VERSION = '0.0.0';

use strict;
use warnings;
use Scalar::Util qw(reftype);
use Carp qw(croak);
use Data::Dumper;

use MediaWiki::DumpFile::XML;
use XML::LibXML::Reader;

sub new {
	my ($class, $input) = @_;
	my $self = {};
	my $reftype = reftype($input);
	my $xml;
	
	if (! defined($input)) {
		croak "must specify a file path or open file handle object";
	} elsif (! defined($reftype)) {
		$xml = MediaWiki::DumpFile::XML->new(location => $input);
	} elsif ($reftype eq 'GLOB') {
		$xml = MediaWiki::DumpFile::XML->new(IO => $input);
	} else {
		croak "must specify a file path or open file handle object";
	}
	
	$self->{xml} = $xml;
	$self->{siteinfo} = undef;
	$self->{version} = undef;
	
	bless($self, $class);
	
	$self->_init;
	
	if ($self->{version} ne '0.3' && $self->{version} ne '0.4') {
		die "only version 0.3 and 0.4 version dump files are supported";
	}
	
	return $self;
}

sub next {
	my ($self) = @_;
	my $version = $self->{version};
	my $new = $self->{xml}->next;
	
	return undef unless defined $new;
	
	if ($version eq '0.4') {
		return MediaWiki::DumpFile::Pages::Page->new($new);
	} else {
		die "unexpected dump version";
	}
}

sub version {
	return $_[0]->{version};
}

sub sitename {
	return $_[0]->_siteinfo('sitename');
}

sub base {
	return $_[0]->_siteinfo('base');
}

sub generator {
	return $_[0]->_siteinfo('generator');
}

sub case {
	return $_[0]->_siteinfo('case');
}

sub namespaces {
	my $namespaces = $_[0]->{siteinfo}->get_element('/siteinfo/namespaces')->child_nodes;
	my %namespaces;

	foreach (@$namespaces) {
		my ($name, $id);
		
		next unless $_->[0] == XML_READER_TYPE_ELEMENT;
		bless($_, 'MediaWiki::DumpFile::XML::Element');		
		next unless $_->name eq 'namespace';
		
		$name = $_->text;
		$id = $_->attributes->{key};
		
		$name = '' unless defined $name;
		
		$namespaces{$name} = $id;
	}

	return %namespaces;
}

#private methods

sub _init {
	my ($self) = @_;
	my $xml = $self->{xml};
	
	$xml->config('/mediawiki', 'element');
	$xml->config('/mediawiki/siteinfo', 'subtree');
	$xml->config('/mediawiki/page', 'subtree');
	
	$self->{version} = $xml->next->attributes->{version};
	$self->{siteinfo} = $xml->next;
	
	return undef;
}

sub _siteinfo {
	my ($self, $name) = @_;
	my $siteinfo = $self->{siteinfo};
	
	return $siteinfo->get_element("/siteinfo/$name")->text;
}

package MediaWiki::DumpFile::Pages::Page;

use strict;
use warnings;
use Data::Dumper;

sub new {
	my ($class, $element) = @_;
	my $self = { tree => $element };
	
	bless($self, $class);
	
	return $self;
}

sub title {
	return $_[0]->{tree}->get_element('/page/title')->text;
}

sub id {
	return $_[0]->{tree}->get_element('/page/id')->text;
}

sub revision {
	my ($self) = @_;
	my @revisions;
	
	foreach ($self->{tree}->get_element('/page/revision')) {
		push(@revisions, MediaWiki::DumpFile::Pages::Page::Revision->new($_));
	}
	
	if (wantarray()) {
		return (@revisions);
	}
	
	return pop(@revisions);
}

package MediaWiki::DumpFile::Pages::Page::Revision;

use strict;
use warnings;

sub new {
	my ($class, $tree) = @_;
	my $self = { tree => $tree };
	
	return bless($self, $class);
}

sub text {
	return $_[0]->{tree}->get_element('/revision/text')->text;
}

sub id {
	return $_[0]->{tree}->get_element('/revision/id')->text;
}

sub timestamp {
	return $_[0]->{tree}->get_element('/revision/timestamp')->text;
}

sub comment {
	return $_[0]->{tree}->get_element('/revision/comment')->text;
} 

1;
