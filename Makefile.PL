
use strict;
use warnings;

BEGIN { require 5.010; }

use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'Helper module for generating class definitions',
  'AUTHOR' => 'Tom Molesworth <cpan@entitymodel.com>',
  'BUILD_REQUIRES' => {
    'Test::Deep' => '0',
    'Test::More' => '0'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.31'
  },
  'DISTNAME' => 'EntityModel-Class',
  'EXE_FILES' => [],
  'LICENSE' => 'perl',
  'NAME' => 'EntityModel::Class',
  'PREREQ_PM' => {
    'DateTime' => '0',
    'DateTime::Format::Strptime' => '0',
    'EntityModel::Log' => '0.001',
    'Exporter' => '0',
    'IO::Handle' => '0',
    'List::Util' => '0',
    'Tie::Cache::LRU' => '0',
    'Time::HiRes' => '0',
    'Try::Tiny' => '0',
    'parent' => '0'
  },
  'VERSION' => '0.006',
  'test' => {
    'TESTS' => 't/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



