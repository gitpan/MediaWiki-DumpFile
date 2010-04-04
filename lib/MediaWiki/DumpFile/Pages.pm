package MediaWiki::DumpFile::Pages;

our $VERSION = '0.1.2';

use strict;
use warnings;
use Scalar::Util qw(reftype);
use Carp qw(croak);
use Data::Dumper;

use XML::TreePuller;

sub new {
	my ($class, $input) = @_;
	my $self = {};
	my $reftype = reftype($input);
	my $xml;
	
	if (! defined($input)) {
		croak "must specify a file path or open file handle object";
	} elsif (! defined($reftype)) {
		if (! -e $input) {
			croak("$input is not a file");
		}
		
		$xml = XML::TreePuller->new(location => $input);
	} elsif ($reftype eq 'GLOB') {
		$xml = XML::TreePuller->new(IO => $input);
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
	
	return MediaWiki::DumpFile::Pages::Page->new($new, $version);
}

sub version {
	return $_[0]->{version};
}

#private methods

sub _init {
	my ($self) = @_;
	my $xml = $self->{xml};
	my $version;
	
	$xml->config('/mediawiki', 'short');
	$xml->config('/mediawiki/siteinfo', 'subtree');
	$xml->config('/mediawiki/page', 'subtree');
	
	$version = $self->{version} = $xml->next->attribute('version');
	
	if ($version > 0.2) {
		$self->{siteinfo} = $xml->next;
		
		bless($self, 'MediaWiki::DumpFile::PagesSiteinfo');
	} elsif ($version > 0.4) {
		die "version $version dump file is not supported";
	}
		
	return undef;
}

package MediaWiki::DumpFile::PagesSiteinfo;

use base qw(MediaWiki::DumpFile::Pages);

use MediaWiki::DumpFile::Pages::Lib qw(_safe_text); 

sub _site_info {
	my ($self, $name) = @_;
	my $siteinfo = $self->{siteinfo};
	
	return _safe_text($siteinfo, $name);
}

sub sitename {
	return $_[0]->_site_info('sitename');
}

sub base {
	return $_[0]->_site_info('base');
}

sub generator {
	return $_[0]->_site_info('generator');
}

sub case {
	return $_[0]->_site_info('case');
}

sub namespaces {
	my %namespaces;

	foreach ($_[0]->{siteinfo}->get_elements('namespaces/namespace')) {
		my ($name, $id);
		
		$name = $_->text;
		$id = $_->attribute('key');
		
		$namespaces{$id} = $name;
	}

	return %namespaces;
}

package MediaWiki::DumpFile::Pages::Page;

use strict;
use warnings;
use Data::Dumper;

use MediaWiki::DumpFile::Pages::Lib qw(_safe_text); 

sub new {
	my ($class, $element, $version) = @_;
	my $self = { tree => $element };
	
	bless($self, $class);
	
	if ($version >= 0.4) {
		bless ($self, 'MediaWiki::DumpFile::Pages::Page000004000');
	}
	
	return $self;
}

sub title {
	return _safe_text($_[0]->{tree}, 'title');
}

sub id {
	return _safe_text($_[0]->{tree}, 'id');
}

sub revision {
	my ($self) = @_;
	my @revisions;
	
	foreach ($self->{tree}->get_elements('revision')) {
		push(@revisions, MediaWiki::DumpFile::Pages::Page::Revision->new($_));
	}
	
	if (wantarray()) {
		return (@revisions);
	}
	
	return pop(@revisions);
}

package MediaWiki::DumpFile::Pages::Page000004000;

use base qw(MediaWiki::DumpFile::Pages::Page);

use strict;
use warnings;

sub redirect {
	return 1 if defined $_[0]->{tree}->get_elements('redirect');
	return 0;
}


package MediaWiki::DumpFile::Pages::Page::Revision;

use strict;
use warnings;

use MediaWiki::DumpFile::Pages::Lib qw(_safe_text); 

sub new {
	my ($class, $tree) = @_;
	my $self = { tree => $tree };
	
	return bless($self, $class);
}

sub text {
	return _safe_text($_[0]->{tree}, 'text');
}

sub id {
	return _safe_text($_[0]->{tree}, 'id');
}

sub timestamp {
	return _safe_text($_[0]->{tree}, 'timestamp');
}

sub comment {
	return _safe_text($_[0]->{tree}, 'comment');
} 

sub minor {
	return 1 if defined $_[0]->{tree}->get_elements('minor');
	return 0;
}

sub contributor {
	return MediaWiki::DumpFile::Pages::Page::Revision::Contributor->new(
		$_[0]->{tree}->get_elements('contributor') );
}

package MediaWiki::DumpFile::Pages::Page::Revision::Contributor;

use strict;
use warnings;

use Carp qw(croak);

use overload 
	'""' => 'astext',
	fallback => 'TRUE';

sub new {
	my ($class, $tree) = @_;
	my $self = { tree => $tree };
	
	return bless($self, $class);
}

sub astext {
	my ($self) = @_;
	
	if (defined($self->ip)) {
		return $self->ip;
	} 	
	
	return $self->username;
}

sub username {
	my $user = $_[0]->{tree}->get_elements('username');
	
	return undef unless defined $user;
	
	return $user->text;
}

sub id {
	my $id = $_[0]->{tree}->get_elements('id');
	
	return undef unless defined $id;
	
	return $id->text;
}

sub ip {
	my $ip = $_[0]->{tree}->get_elements('ip');
	
	return undef unless defined $ip;
	
	return $ip->text;
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
  
  #version 0.3 and later dump files only
  $sitename = $pages->sitename; 
  $base = $pages->base;
  $generator = $pages->generator;
  $case = $pages->case;
  %namespaces = $pages->namespaces;
  
  #all versions
  while(defined($page = $pages->next) {
    print 'Title: ', $page->title, "\n";
  }
  
  $title = $page->title; 
  $id = $page->id; 
  $revision = $page->revision; 
  @revisions = $page->revision; 
  
  $text = $revision->text; 
  $id = $revision->id; 
  $timestamp = $revision->timestamp; 
  $comment = $revision->comment; 
  $contributor = $revision->contributor;
  #version 0.4 and later dump files only
  $bool = $revision->redirect;
  
  $username = $contributor->username;
  $id = $contributor->id;
  $ip = $contributor->ip;
  $username_or_ip = $contributor->astext;
  $username_or_ip = "$contributor";
  
=head1 METHODS

=head2 new

This is the constructor for this package. It is called with a single parameter: the location of
a MediaWiki pages dump file or a reference to an already open file handle. 

=head2 version

Returns the version of the dump file.

=head2 sitename

Returns the sitename from the MediaWiki instance. Requires a dump file of at least version 0.3.

=head2 base

Returns the URL used to access the MediaWiki instance. Requires a dump file of at least version 0.3.

=head2 generator

Returns the version of MediaWiki that generated the dump file. Requires a dump file of at least version 0.3.

=head2 case

Returns the case sensitivity configuration of the MediaWiki instance. Requires a dump file of at least version 0.3.

=head2 namespaces

Returns a hash where the key is the numerical namespace id and the value is
the plain text namespace name. The main namespace has an id of 0 and an empty 
string value. Requires a dump file of at least version 0.3.

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

=item contributor

Returns an instance of MediaWiki::DumpFile::Pages::Page::Revision::Contributor

=item minor

Returns true if the edit was marked as being minor or false otherwise

=item redirect

Returns true if the page is a redirect to another page or false otherwise. Requires a dump file of at least version 0.4.

=back

=head1 MediaWiki::DumpFile::Pages::Page::Revision::Contributor

This object provides access to the contributor of a specific revision of a page. When used in a scalar
context it will return the username of the editor if the editor was logged in or the IP address of
the editor if the edit was anonymous.

=over 4

=item username

Returns the username of the editor if the editor was logged in when the edit was made or undef otherwise.

=item id

Returns the numerical id of the editor if the editor was logged in or undef otherwise.

=item ip

Returns the IP address of the editor if the editor was anonymous or undef otherwise. 

=item astext

Returns the username of the editor if they were logged in or the IP address if the editor
was anonymous. 

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
