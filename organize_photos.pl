#!/usr/bin/env perl

use 5.016;
use strict;
use warnings;
use autodie;

use PhotoMoveManager;
use File::Find;
use Data::Dumper;
use File::Copy;

my $move_manager = PhotoMoveManager->new('/Volumes/Media/Photos', '/Volumes/Media/Photos.back');
my $files_to_handle = {};
finddepth( {
    wanted => sub {
        my $file_path = $File::Find::name;
        return if $file_path !~ m/\/.+\.(jpg|jpeg|mov|avi|mp4|m4v|png|orf|wmv)$/i
            or -d $file_path;
        $files_to_handle->{$file_path} = 1;
    },
    no_chdir => 1
}, $move_manager->target_directory);

$move_manager->plan_move($_) for keys $files_to_handle;

$move_manager->execute();