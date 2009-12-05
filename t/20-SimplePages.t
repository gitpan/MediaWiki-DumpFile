use strict;
use warnings;

use Test::Simple tests => 10;

use MediaWiki::DumpFile::SimplePages;

my $test_file = 't/testdata.xml';

my $p = MediaWiki::DumpFile::SimplePages->new($test_file);
test_suite($p);

die "could not open $test_file: $!" unless open(FILE, $test_file);
$p = MediaWiki::DumpFile::SimplePages->new(\*FILE);
test_suite($p);

sub test_suite {
	my ($p) = @_;
	my ($title, $text) = $p->next;
	
	ok($title eq 'Test 1');
	ok($text eq 'This is the text for test 1.');
	
	($title, $text) = $p->next;
	ok($title eq 'Test 2');
	ok($text eq 'The text does not look like the other test\'s text.');
	
	ok(! $p->next);
}