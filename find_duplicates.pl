#!/usr/bin/env perl

use 5.016;
use strict;
use warnings;
use autodie;

use PhotoMoveManager;
use File::Find;
use Data::Dumper;

my $digest_to_files = {};

finddepth( {
    wanted => sub {
        my $file_path = $File::Find::name;
        return if -d $file_path or not -s $file_path;

        my $digest = PhotoMoveManager::__get_file_digest($file_path);
        $digest_to_files->{$digest}->{$file_path} = 1;
    },
    no_chdir => 1
}, '/Volumes/Media/SkyDrive/Music');

for my $digest (keys $digest_to_files) {
    my @file_paths = keys $digest_to_files->{$digest};
    if (scalar @file_paths > 1) {
        say "Duplicates found:\n" . (join "\n", @file_paths);
    }
}

#finddepth(sub { rmdir $_ if -d }, $move_manager->target_directory);