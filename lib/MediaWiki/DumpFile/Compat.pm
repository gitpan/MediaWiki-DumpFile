#!/usr/bin/env perl

#Parse::MediaWikiDump compatibility

package MediaWiki::DumpFile::Compat;

our $VERSION = '0.1.7';

package #go away indexer! 
	Parse::MediaWikiDump;

use strict;
use warnings;

sub new {
	my ($class) = @_;
	return bless({}, $class);
}

sub pages {
	shift(@_);
	return Parse::MediaWikiDump::Pages->new(@_);
}

sub revisions {
	shift(@_);
	return Parse::MediaWikiDump::Revisions->new(@_);
}

sub links {
	shift(@_);
	return Parse::MediaWikiDump::Links->new(@_);
}

package #go away indexer! 
	Parse::MediaWikiDump::Links;

use strict; 
use warnings;

use MediaWiki::DumpFile::SQL;

sub new {
	my ($class, $source) = @_;
	my $self = {};
	my $sql;
	
	$Carp::CarpLevel++;
	$sql = MediaWiki::DumpFile::SQL->new($source);
	$Carp::CarpLevel--;
	
	if (! defined($sql)) {
		die "could not create SQL parser";
	}
	
	$self->{sql} = $sql;
	
	return bless($self, $class);
}

sub next {
	my ($self) = @_;
	my $next = $self->{sql}->next;
	
	unless(defined($next)) {
		return undef;
	}
	
	return Parse::MediaWikiDump::link->new($next);
}

package #go away indexer! 
	Parse::MediaWikiDump::link;

use strict; 
use warnings;

use Data::Dumper;

sub new {
	my ($class, $self) = @_;
	
	bless($self, $class);
}

sub from {
	return $_[0]->{pl_from};
}

sub namespace {
	return $_[0]->{pl_namespace};
}

sub to {
	return $_[0]->{pl_title};
}

package #go away indexer! 
	Parse::MediaWikiDump::Revisions;

use strict;
use warnings;
use Data::Dumper;

use MediaWiki::DumpFile::Pages;

sub new {
	my ($class, $source) = @_;
	my $self = { queue => [] };
	my $mediawiki;
	
	$Carp::CarpLevel++;
	$mediawiki = MediaWiki::DumpFile::Pages->new($source);
	$Carp::CarpLevel--;
	
	$self->{mediawiki} = $mediawiki;
	$self->{source} = $source;
	
	return bless($self, $class);
}

sub version {
	return $_[0]->{mediawiki}->version;
}

sub sitename {
	return $_[0]->{mediawiki}->sitename;
}

sub base {
	return $_[0]->{mediawiki}->base;
}

sub generator {
	return $_[0]->{mediawiki}->generator;
}

sub case {
	return $_[0]->{mediawiki}->case;
}

sub namespaces {
	my $cache = $_[0]->{cache}->{namespaces};
	
	if(defined($cache)) {
		return $cache;
	}
	
	my %namespaces = $_[0]->{mediawiki}->namespaces;
	my @temp;
	
	while(my ($key, $val) = each(%namespaces)) {
		push(@temp, [$key, $val]);
	}
	
	@temp = sort({$a->[0] <=> $b->[0]} @temp);
	
	$_[0]->{cache}->{namespaces} = \@temp;
	
	return \@temp;
}

sub namespaces_names {
	my @result;
	
	foreach (@{ $_[0]->namespaces }) {
		push(@result, $_->[1]);
	}
	
	return \@result;
}

sub current_byte {
	return $_[0]->{mediawiki}->current_byte;
}

sub size {
	return $_[0]->{mediawiki}->size;
}

sub get_category_anchor {
	my ($self) = @_;
	my $namespaces = $self->namespaces;

	foreach (@$namespaces) {
		my ($id, $name) = @$_;
		if ($id == 14) {
			return $name;
		}
	}	
	
	return undef;
}

sub next {
	my $self = $_[0];
	my $queue = $_[0]->{queue};
	my $next = shift(@$queue);
	my @results;

	return $next if defined $next;
	
	$next = $self->{mediawiki}->next;
	
	return undef unless defined $next;

	foreach ($next->revision) {
		push(@$queue, Parse::MediaWikiDump::page->new($next, $self->namespaces, $self->get_category_anchor, $_));
	}
	
	return shift(@$queue);
}

package #go away indexer! 
	Parse::MediaWikiDump::Pages;

use strict;
use warnings;

our @ISA = qw(Parse::MediaWikiDump::Revisions);

sub next {
	my $self = $_[0];
	my $next = $self->{mediawiki}->next;
	my $revision_count;
	
	return undef unless defined $next;
	
	$revision_count = scalar(@{[$next->revision]});
						#^^^^^ because scalar($next->revision) doesn't work
	
	if ($revision_count > 1) {
		die "only one revision per page is allowed\n";
	}

	return Parse::MediaWikiDump::page->new($next, $self->namespaces, $self->get_category_anchor);
}


package #go away indexer! 
	Parse::MediaWikiDump::page;

use strict;
use warnings;

sub new {
	my ($class, $page, $namespaces, $category_anchor, $revision) = @_;
	my $self = {page => $page, namespaces => $namespaces, category_anchor => $category_anchor};
	
	$self->{revision} = $revision;
	
	return bless($self, $class);
}

sub _revision {
	if (defined($_[0]->{revision})) { return $_[0]->{revision}};
	
	return $_[0]->{page}->revision;
}

sub text {
	my $text = $_[0]->_revision->text;
	return \$text;
}

sub title {
	return $_[0]->{page}->title;
}

sub id {
	return $_[0]->{page}->id;
}

sub revision_id {
	return $_[0]->_revision->id;
}

sub username {
	return $_[0]->_revision->contributor->username;
}

sub userid {
	return $_[0]->_revision->contributor->id;
}

sub userip {
	return $_[0]->_revision->contributor->ip;
}

sub timestamp {
	return $_[0]->_revision->timestamp;
}

sub minor {
	return $_[0]->_revision->minor;
}

sub namespace {
	my ($self) = @_;
	my $title = $self->title;
	my $namespace = '';
	
	if ($title =~ m/^([^:]+):(.*)/) {
		foreach (@{ $self->{namespaces} } ) {
			my ($num, $name) = @$_;
			if ($1 eq $name) {
				$namespace = $1;
				last;
			}
		}
	}

	return $namespace;
}

sub redirect {
	my ($self) = @_;
	my $text = $self->text;

	if ($$text =~ m/^#redirect\s*:?\s*\[\[([^\]]*)\]\]/i) {
		return $1;
	} else {
		return undef;
	}
}

sub categories {
	my ($self) = @_;
	my $anchor = $$self{category_anchor};
	my $text = $self->text;
	my @cats;
	
	while($text =~ m/\[\[$anchor:\s*([^\]]+)\]\]/gi) {
		my $buf = $1;

		#deal with the pipe trick
		$buf =~ s/\|.*$//;
		push(@cats, $buf);
	}

	return undef if scalar(@cats) == 0;

	return \@cats;
}


1;

__END__

=head1 NAME

MediaWiki::DumpFile::Compat - Compatibility with Parse::MediaWikiDump

=head1 SYNOPSIS

  use MediaWiki::DumpFile::Compat;

  $pmwd = Parse::MediaWikiDump->new;
  
=head1 ABOUT

This is a compatibility layer with Parse::MediaWikiDump; instead of "use Parse::MediaWikiDump;" 
you "use MediaWiki::DumpFile::Compat;". The Parse::MediaWikiDump module itself is well documented
so it will not be reproduced here. The benefit of using the new compatibility module is an increased
processing speed - see the MediaWiki::DumpFile main documentation for benchmark results. 

Compatibility is verified by using the existing Parse::MediaWikiDump test suite with the 
following adjustments:

=head2 Parse::MediaWikiDump::Pages

=over 4

=item

Parse::MediaWikiDump did not need to load all revisions of an article into memory when processing
dump files that contain more than one revision but this compatibility module does. The API does not
change but the memory requirements for parsing those dump files certainly do. It is, however, highly
unlikely that you will notice this as most of the documents with many revisions per article are so large
that Parse::MediaWikiDump would not have been able to parse them in any reasonable timeframe. 

=item 

The order of the results from namespaces() is now sorted by the namespace ID instead of being in document order

=back

=head2 Parse::MediaWikiDump::Links

=over 4

=item 

Order of values from next() is now in identical order as SQL file.

=back

=head1 BUGS

=over 4

=item

The value of current_byte() wraps at around 2 gigabytes of input XML; see http://rt.cpan.org/Public/Bug/Display.html?id=56843

=back

=head1 LIMITATIONS

=over 4

=item 

This compatibility layer is not yet well tested.

=back