package MediaWiki::DumpFile::Pages;

our $VERSION = '0.0.7';

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
	
	return $self;
}

sub next {
	my ($self) = @_;
	my $version = $self->{version};
	my $new = $self->{xml}->next;
	
	return undef unless defined $new;
	
	return MediaWiki::DumpFile::Pages::Page->new($new);
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
		
		$namespaces{$id} = $name;
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

__END__

=head1 NAME

MediaWiki::DumpFile::Pages - Process an XML dump file of pages from a MediaWiki instance

=head1 SYNOPSIS

  use MediaWiki::DumpFile::Pages;
  
  $pages = MediaWiki::DumpFile::Pages->new($file);
  $pages = MediaWiki::DumpFile::Pages->new(\*FH);
  
  $version = $pages->version; 
  $sitename = $pages->sitename; 
  $base = $pages->base;
  $generator = $pages->generator;
  $case = $pages->case;
  %namespaces = $pages->namespaces;
  
  while(defined($page = $pages->next) {
    print 'Title: ', $page->title, "\n";
  }
  
  $title = $page->title; 
  $id = $page->id; 
  $revision = $page->revision; 
  @revision = $page->revision; 
  
  $text = $revision->text; 
  $id = $revision->id; 
  $timestamp = $revision->timestamp; 
  $comment = $revision->comment; 
  
=head1 METHODS

=head2 new

This is the constructor for this package. It is called with a single parameter: the location of
a MediaWiki pages dump file or a reference to an already open file handle. 

=head2 version

Returns the version of the dump file.

=head2 sitename

Returns the sitename from the MediaWiki instance.

=head2 base

Returns the URL used to access the MediaWiki instance.

=head2 generator

Returns the version of MediaWiki that generated the dump file.

=head2 case

Returns the case sensitivity configuration of the MediaWiki instance.

=head2 namespaces

Returns a hash where the key is the numerical namespace id and the value is
the plain text namespace name. The main namespace has an id of 0 and an empty 
string value. 

=head2 next

Returns an instance of MediaWiki::DumpFile::Pages::Page or undef if there is no more pages
available. 

=head1 MediaWiki::DumpFile::Pages::Page

This object represents a distinct Mediawiki page and is used to access the page data and metadata. The following
methods are available:

=over 4

=item title

Returns a string of the page title

=item id

Returns a numerical page identification

=item revision

In scalar context returns the last revision in the dump for this page; in array context returns a list of all
revisions made available for the page in the same order as the dump file. All returned data is an instance of
MediaWiki::DumpFile::Pages::Revision

=back

=head1 MediaWiki::DumpFile::Pages::Page::Revision

This object represents a distinct revision of a page from the Mediawiki dump file. The standard dump files contain only the most specific
revision of each page and the comprehensive dump files contain all revisions for each page. The following methods are available:

=over 4

=item text

Returns the page text for this specific revision of the page. 

=item id

Returns the numerical revision id for this specific revision - this is independent of the page id. 

=item timestamp 

Returns a string value representing the time the revision was created. The string is in the format of 
"2008-07-09T18:41:10Z".

=item comment

Returns the comment made about the revision when it was created. 

=back

=head1 AUTHOR

Tyler Riddle, C<< <triddle at gmail.com> >>

=head1 BUGS

Please see MediaWiki::DumpFile for information on how to report bugs in 
this software. 

=head1 COPYRIGHT & LICENSE

Copyright 2009 "Tyler Riddle".

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
