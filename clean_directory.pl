#!/usr/bin/env perl

use 5.016;
use strict;
use warnings;
use autodie;

use Utils;

my $dir_to_clean = $ARGV[0];
die "No parameter" unless $dir_to_clean;
die "Dir $dir_to_clean does not exists" unless -d $dir_to_clean;

Utils->clean_directory($dir_to_clean, qr/\.DS_store/i);

__END__
mkdir test
mkdir test/test-inner
touch test/file
touch test/test-inner/.DS_Store
mkdir test/test-inner2
touch test/test-inner2/.DS_Store
mkdir test/test-inner3
touch test/test-inner3/inner-file
./clean_directory.pl test
