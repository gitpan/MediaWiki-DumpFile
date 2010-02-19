package MediaWiki::DumpFile;

our $VERSION = '0.0.12';

use warnings;
use strict;
use Carp qw(croak);

sub new {
	my ($class, %files) = @_;
	my $self = {};
	
	bless($self, $class);
	
	return $self;
}

sub sql {
	if (! defined($_[1])) {
		croak "must specify a filename or open filehandle";
	}
	
	require MediaWiki::DumpFile::SQL;
	
	return MediaWiki::DumpFile::SQL->new($_[1]);
}

sub pages {
	if (! defined($_[1])) {
		croak "must specify a filename or open filehandle";
	}
	
	require MediaWiki::DumpFile::Pages;
	
	return MediaWiki::DumpFile::Pages->new($_[1]);
}

sub fastpages {
	if (! defined($_[1])) {
		croak "must specify a filename or open filehandle";
	}
	
	require MediaWiki::DumpFile::FastPages;
	
	return MediaWiki::DumpFile::FastPages->new($_[1]);
}

1;

__END__

=head1 NAME

MediaWiki::DumpFile - Process various dump files from a MediaWiki instance

=head1 SYNOPSIS

  use MediaWiki::DumpFile;

  $mw = MediaWiki::DumpFile->new;
  
  $sql = $mw->sql($filename);
  $sql = $mw->sql(\*FH);
  
  $pages = $mw->pages($filename);
  $pages = $mw->pages(\*FH);
  
  $fastpages = $mw->fastpages($filename);
  $fastpages = $mw->fastpages(\*FH);
  
=head1 ABOUT

This module is used to parse various dump files from a MediaWiki instance. The most
likely case is that you will want to be parsing content at http://download.wikimedia.org/backup-index.html 
provided by WikiMedia which includes the English and all other language Wikipedias. 

This module could also be considered Parse::MediaWikiDump version 2. It has been created
as a seperate distribution to improve the API with out breaking existing code that is using
Parse::MediaWikiDump. 

=head1 STATUS

This is currently bleeding edge software. API changes may happen in the future (but will try
to be avoided), there may be bugs, it might not work at all, etc. If you need something well tested
and stable use Parse::MediaWikiDump instead. If you do encounter issues with this software please
open a bug report according to the documentation below. See the LIMITATIONS section below for
what is left to be supported. 

=head1 FUNCTIONS

=head2 sql

Return an instance of MediaWiki::DumpFile::SQL. This object can be used to parse
any arbitrary SQL dump file used to recreate a single table in the MediaWiki instance. 

=head2 pages

Return an instance of MediaWiki::DumpFile::Pages. This object parses the contents of the
page dump file and supports both single and multiple revisions per article as well as
associated metadata.

=head2 fastpages

Return an instance of MediaWiki::DumpFile::FastPages. This object parses the contents
of the page dump file but only supports fetching the article titles and text and will
only return the text for the first revision of the article if the page dump includes
multiple revisions. The trade off for the lack of features is drastically increased
processing speed.

=head1 SPEED

These benchmarks will give you a rough idea of how fast you can expect the XML dump
files to be processed. The benchmark is to print all of the article titles and text
to STDOUT and was executed on a 2.66 GHz Intel Core Duo Macintosh running
Snow Leopard. The test data is a dump file of the Simple English Wikipedia from
October 21, 2009.

=over 4

=item MediaWiki-DumpFile-FastPages: 26.4 MiB/sec

=item MediaWiki-DumpFile-Pages: 10.6 MiB/sec

=item Parse-MediaWikiDump: 3.2 MiB/sec

=back

=head1 LIMITATIONS

This software is not completed yet; specifically the object for parsing the pages dump file
does not support all of the data made available in the dump file. The most commonly used
information should already be supported and patches are always welcome to add support
before I can get around to it. See the documentation for MediaWiki::DumpFile::Pages
for up to date information on what is and what is not supported at this time. 

=head1 AUTHOR

Tyler Riddle, C<< <triddle at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mediawiki-dumpfile at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MediaWiki-DumpFile>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MediaWiki::DumpFile


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=MediaWiki-DumpFile>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/MediaWiki-DumpFile>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/MediaWiki-DumpFile>

=item * Search CPAN

L<http://search.cpan.org/dist/MediaWiki-DumpFile/>

=back


=head1 ACKNOWLEDGEMENTS

All of the people who reported bugs or feature requests for Parse::MediaWikiDump. 

=head1 COPYRIGHT & LICENSE

Copyright 2009 "Tyler Riddle".

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
