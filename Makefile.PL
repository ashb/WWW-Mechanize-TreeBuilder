use inc::Module::Install;

perl_version    '5.008001';
name            'WWW-Mechanize-TreeBuilder';
all_from        'lib/WWW/Mechanize/TreeBuilder.pm';
license         'perl';

requires        'Moose'                          => '0.69';
requires        'HTML::TreeBuilder';

build_requires  'Test::More';
build:requires  'Test::WWW::Mechanize';

no_index        directory => 't/lib';

WriteAll;
