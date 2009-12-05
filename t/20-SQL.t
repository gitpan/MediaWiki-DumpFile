use strict;
use warnings;

use Data::Dumper;
use Data::Compare; 

use Storable qw(nstore retrieve);

use Test::Simple tests => 104;

use MediaWiki::DumpFile::SQL;

my $test_file = 't/specieswiki-20091204-user_groups.sql';

my $p = MediaWiki::DumpFile::SQL->new($test_file);
test_suite($p);

die "could not open $test_file: $!" unless open(FILE, $test_file);
$p = MediaWiki::DumpFile::SQL->new(\*FILE);
test_suite($p);

sub test_suite {
	my ($p) = @_;
	my $data = retrieve('t/specieswiki-20091204-user_groups.data');
	my @schema = $p->schema;

	ok($p->table_name eq 'user_groups');
	
	ok($schema[0][0] eq 'ug_user');
	ok($schema[0][1] eq 'int');
	
	ok($schema[1][0] eq 'ug_group');
	ok($schema[1][1] eq 'varchar');
	
	ok(! defined($schema[2]));

	while(defined(my $row = $p->next)) {
		my $test_against = shift(@$data);
		ok(Compare($test_against, $row));
	}
	
}