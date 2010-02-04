package MediaWiki::DumpFile::XML;

use strict;
use warnings;
use Data::Dumper;
use Scalar::Util qw(reftype);

use XML::LibXML::Reader; 
use XML::CompactTree::XS;

#this only works well enough to be used
#in MediaWiki::DumpFile - it's not
#general purpose yet

sub new {
	my ($class, @args) = @_;
	my $self = {};
	my $reader;
	
	#die "obsoleted by XML::TreePuller";
	
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
	
	return () if $self->{finished};
	
	while(1) {
		my $type = $reader->nodeType;
		
		if ($type == XML_READER_TYPE_ELEMENT) {
			push(@$elements, $reader->name);
			my $is_empty = $reader->isEmptyElement;
			my $path = '/' . join('/', @$elements);
			my $todo = $config->{$path};
			my $did_something = 0;
			my $ignore_empty = 0;
			my $ret;
				
			if (defined($todo)) {	
				if ($todo eq 'subtree') {
					$ret = $self->_do_subtree;
					$self->sync;
					$ignore_empty = 1;
				} elsif ($todo eq 'element') {
					$ret = $self->_read_element;
				} else {
					die "unexpected todo type: $todo";
				}
				
				$did_something = 1;
			}
			
			if ($is_empty && ! $ignore_empty) {
				pop(@$elements);
			}
			
			if ($did_something) {
				if (wantarray()) {
					return ($path, $ret);
				}
				
				return $ret;
			}
		} elsif ($type == XML_READER_TYPE_END_ELEMENT) {
			pop(@$elements);
		}
		
		my $ret = $reader->read;
		
		if ($ret == 0) {
			$self->{finished} = 1;
			return ();
		}
		
		die "libxml read error" if $ret == -1;
		die "expected 1" unless $ret == 1;
		
	}
	
}

sub reader {
	return $_[0]->{reader};
}

sub sync {
	my ($self) = @_;
	my $depth = $self->{reader}->depth;

	splice(@{$self->{elements}}, $depth);
}


#private methods
sub _do_subtree {
	my ($self) = @_;
	my $reader = $self->{reader};
	my $elements = $self->{elements};
	
	my $tree = MediaWiki::DumpFile::XML::Element->new(_read_tree($reader));
	
	if (! defined($tree)) {
		$self->{finished} = 1;
		return undef;
	}
	
	return $tree;
}

sub _read_element {
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

sub _read_tree {
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

sub get_elements {
	my ($self, $path) = @_;
	my @results;

	$path = '' unless defined $path;

	@results = $self->_recursive_get_child_elements(split('/', $path));
	
	if (wantarray()) {
		return @results;
	}
	
	return shift(@results);
}

sub name {
	my ($tree) = @_;
	
	return $tree->[1];
}

sub child_nodes {
	my ($tree) = @_;
	
	if (wantarray()) {
		if (! defined($tree->[4])) {
			return ();
		}
		
		return @{$tree->[4]};
	}
	
	return $tree->[4];
}

sub text {
	my ($tree) = @_;
	my $p = $tree->[4]; 
	my @text;
		
	return '' unless defined $p;

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
	
	$attr = {} unless defined $attr;

	if (wantarray()) {
		return %$attr;
	}
	
	return $attr;
}

sub attribute {
	return $_[0]->attributes->{$_[1]};
}

#private methods
sub _extract_elements {
	return grep { $_->[0] == XML_READER_TYPE_ELEMENT} @_;	
}

sub _recursive_get_child_elements {
	my ($tree, @path) = @_;
	my $child_nodes = $tree->[4];
	my @results;
	my $target;
	
	if (! scalar(@path)) {
		return MediaWiki::DumpFile::XML::Element->new($tree);
	}
	
	$target = shift(@path);
	
	return () unless defined $child_nodes;
	
	foreach (_extract_elements(@$child_nodes)) {
		next unless $_->[1] eq $target;
		
		push(@results, _recursive_get_child_elements($_, @path));
	}
	
	return @results;
}


1;