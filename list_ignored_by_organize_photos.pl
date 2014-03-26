#!/usr/bin/env perl

use 5.016;
use strict;
use warnings;
use autodie;

use File::Find;

my $ignored_files = {};
finddepth( {
    wanted => sub {
        my $file_path = $File::Find::name;
        return if -d $file_path;
        say $file_path if $file_path eq '/Volumes/Media/Photos/2013-06-14/WP_20130609_025.mp4';
    },
    no_chdir => 1
}, '/Volumes/Media/Photos');