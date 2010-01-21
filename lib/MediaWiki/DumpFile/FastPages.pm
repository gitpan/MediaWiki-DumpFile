#!/usr/bin/env perl

package MediaWiki::DumpFile::FastPages;

our $VERSION = '0.0.7';

use strict;
use warnings;

use XML::LibXML::Reader;
use Scalar::Util qw(reftype);
use Carp qw(croak);

sub new {
	my ($class, $input) = @_;
	my $self = {};
	my $reftype = reftype($input);
	my $reader;
	
	if (! defined($input)) {
		croak "must specify a file path or open file handle object";
	} elsif (! defined($reftype)) {
		$reader = XML::LibXML::Reader->new(location => $input);
	} elsif ($reftype eq 'GLOB') {
		$reader = XML::LibXML::Reader->new(IO => $input);
	} else {
		croak "must specify a file path or open file handle object";
	}
	
	$self->{reader} = $reader;
	$self->{finished} = 0;
	
	bless($self, $class);
	
	return $self;
	
}

sub next {
	my ($self) = @_;
	my $reader = $self->{reader};
	my ($title, $text);
	
	return () if $self->{finished};
	
	while(1) {
		my $type = $reader->nodeType;
		 
		if ($type == XML_READER_TYPE_ELEMENT) {
			if ($reader->name eq 'title') {
				$title = get_text($reader);
				last unless $reader->nextElement('text') == 1;
				next;
			} elsif ($reader->name eq 'text') {
				$text = get_text($reader);
				$reader->nextElement('title');
				last;
			}		
		} 
		
		last unless $reader->nextElement == 1;
	}
	
	if (! defined($title) || ! defined($text)) {
		$self->{finished} = 1;
		return ();
	}
	
	return ($title, $text);
}

sub get_text {
	my ($r) = @_;
	my @buffer;
	my $type;

	while($r->nodeType != XML_READER_TYPE_TEXT && $r->nodeType != XML_READER_TYPE_END_ELEMENT) {
		$r->read or die "could not read";
	}

	while($r->nodeType != XML_READER_TYPE_END_ELEMENT) {
		if ($r->nodeType == XML_READER_TYPE_TEXT) {
			push(@buffer, $r->value);
		}
		
		$r->read or die "could not read";
	}

	return join('', @buffer);	
}

1;

__END__

=head1 NAME

MediaWiki::DumpFile::FastPages - Access the title and text of pages from a dump file

=head1 SYNOPSIS

  use MediaWiki::DumpFile::FastPages;
  
  $pages = MediaWiki::DumpFile::FastPages->new($file);
  $pages = MediaWiki::DumpFile::FastPages->new(\*FH);
  
  while(($title, $text) = $pages->next) {
    print "Title: $title\n";
    print "Text: $text\n";
  }
  
=head1 METHODS

=head2 new

This is the constructor for this package. It is called with a single parameter: the location of
a MediaWiki pages dump file or a reference to an already open file handle. 

=head2 next

Returns a two element list where the first element is the article title and the second element
is the article text. Returns an empty list when there are no more pages available.

=head1 LIMITATIONS

This object is only capable of handling page titles and text contents; as well only the text
of the first revision of an article will be returned. If you need to access the other data
associated with a page or you need support for more than one revision per page use 
MediaWiki::DumpFile::Pages instead. 

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
