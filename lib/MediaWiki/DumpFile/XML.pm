package MediaWiki::DumpFile::XML;

use strict;
use warnings;
use Data::Dumper;

use XML::LibXML::Reader;
use XML::CompactTree::XS;

sub new {
	my ($class, @args) = @_;
	my $self = {};
	my $reader;
	
	bless($self, $class);
	
	$reader = $self->{reader} = XML::LibXML::Reader->new(@args);
	$self->{elements} = [];
	$self->{config} = {};
	$self->{finished} = 0;
	
	die "could not construct libxml reader" unless defined $reader;
		
	die "libxml read error" unless $reader->read == 1;
	
	return $self;
	
}

sub config {
	my ($self, $path, $todo) = @_;
	
	$self->{config}->{$path} = $todo;
}

sub next {
	my ($self) = @_;
	my $reader = $self->{reader};
	my $elements = $self->{elements};
	my $config = $self->{config};
	
	return undef if $self->{finished};
	
	while(1) {
		my $type = $reader->nodeType;
		
		if ($type == XML_READER_TYPE_ELEMENT) {
			push(@$elements, $reader->name);
			my $is_empty = $reader->isEmptyElement;
			my $path = '/' . join('/', @$elements);
			my $todo = $config->{$path};
			my $did_something = 0;
			my $ret;
				
			if (defined($todo)) {	
				if ($todo eq 'subtree') {
					$ret = $self->do_subtree;
				} elsif ($todo eq 'element') {
					$ret = $self->read_element;
				} elsif (ref($todo) eq 'CODE') {
					$ret = $self->do_code($todo);
				} else {
					die "unexpected todo type";
				}
				
				$did_something = 1;
			}
			
			if ($is_empty) {
				pop(@$elements);
			}
			
			if ($did_something) {
				return $ret;
			}
		} elsif ($type == XML_READER_TYPE_END_ELEMENT) {
			pop(@$elements);
		}
		
		my $ret = $reader->read;
		
		if ($ret == 0) {
			$self->{finished} = 1;
			return undef;
		}
		
		die "libxml read error" if $ret == -1;
		die "expected 1" unless $ret == 1;
		
	}
	
}

sub do_code {
	my ($self, $ref) = @_;
	
	return &$ref($self->read_element);
}

sub do_subtree {
	my ($self) = @_;
	my $reader = $self->{reader};
	my $elements = $self->{elements};
	
	my $tree = MediaWiki::DumpFile::XML::Element->new(read_tree($reader));
	
	#CompactTree leaves us in an unknown spot after it's done
	#slurping up data - get ourselves back into sync with
	#the position of the reader
	my $depth = $reader->depth;
	splice(@$elements, $depth);
	
	if (! defined($tree)) {
		$self->{finished} = 1;
		return undef;
	}
	
	return $tree;
}

sub read_element {
	my ($self) = @_;
	my $reader = $self->{reader};
	my $new;
	my %attr;
	
	$new->[0] = 1;
	$new->[1] = $reader->name;
	$new->[2] = 0;
		
	if ($reader->hasAttributes && $reader->moveToFirstAttribute == 1) {
		do {
			my $name = $reader->name;
			my $val = $reader->value;
			
			$attr{$name} = $val;
		} while($reader->moveToNextAttribute == 1);
	}

	$new->[3] = \%attr;
	$new->[4] = undef;
	
	return MediaWiki::DumpFile::XML::Element->new($new);
}

sub read_tree {
	my ($r) = @_;
	
	return XML::CompactTree::XS::readSubtreeToPerl($r, 0);
}

package MediaWiki::DumpFile::XML::Element;

use strict;
use warnings;
use Carp qw(croak);

use XML::LibXML::Reader;

use Data::Dumper;

sub new {
	my ($class, $tree) = @_;
	
	if ($tree->[0] != XML_READER_TYPE_ELEMENT) {
		croak("must specify an element node");
	}
	
	bless($tree, $class);
	
	return $tree;
}

sub get_element {
	my ($tree, $path) = @_;
	my @path = split('/', $path);
	my $p = [ $tree ];
	my $target = pop(@path);	
	my $found;
	my @results;
	
	#remove empty data caused by leading /
	shift(@path);

	foreach (@path) {
		$found = 0;
	
		for(my $i = 0; $i < scalar(@$p); $i++) {
			my $one = $p->[$i];
			
			if ($one->[0] != XML_READER_TYPE_ELEMENT) {
				next;
			} elsif ($one->[1] eq $_) {
				$p = $one->[4];
				$found = 1;
				last;
			}		
		}
		
		return undef unless $found;
	}

	for(my $i = 0; $i < scalar(@$p); $i++) {
		next unless $p->[$i]->[0] == XML_READER_TYPE_ELEMENT;
		
		if ($p->[$i]->[1] eq $target) {
			push(@results, MediaWiki::DumpFile::XML::Element->new($p->[$i]));
		}
	}	
	
	if (! scalar(@results)) {
		return undef;
	} elsif (! wantarray()) {
		return pop(@results);
	} else {
		return (@results);
	}
}

sub name {
	my ($tree) = @_;
	
	return $tree->[1];
}

sub child_nodes {
	my ($tree) = @_;
	
	return $tree->[4];
}

sub text {
	my ($p) = @_;
	my @text;
	
	$p = $p->child_nodes;
	
	return undef unless defined $p;

	for(my $i = 0; $i < scalar(@$p); $i++) {
		if ($p->[$i]->[0] == XML_READER_TYPE_TEXT || $p->[$i]->[0] == XML_READER_TYPE_CDATA) {
			push(@text, $p->[$i]->[1]);
		}
	}	
	
	return join('', @text);
}

sub attributes {
	my ($tree) = @_;
	my $attr = $tree->[3];
	
	return {} unless defined $attr;
	return $attr;
}

1;