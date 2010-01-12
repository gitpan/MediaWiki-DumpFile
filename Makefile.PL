use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'MediaWiki::DumpFile',
    AUTHOR              => q{"Tyler Riddle <triddle@gmail.com>"},
    VERSION_FROM        => 'lib/MediaWiki/DumpFile.pm',
    ABSTRACT_FROM       => 'lib/MediaWiki/DumpFile.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => '0.94',
        'Test::Simple' => '0.94',
        'Scalar::Util' => '1.21',
        'XML::LibXML' => '1.70',
        'XML::CompactTree::XS' => '0.02',
        'Data::Compare' => '1.2101',
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'MediaWiki-DumpFile-*' },
);
