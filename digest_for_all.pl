#!/usr/bin/env perl

use 5.016;
use strict;
use warnings;
use autodie;

use PhotoMoveManager;
use File::Find;

finddepth( {
    wanted => sub {
        my $file_path = $File::Find::name;
        return if -d $file_path or not -s $file_path;

        my $digest = PhotoMoveManager::__get_file_digest($file_path);
        print "$digest $file_path\n"
    },
    no_chdir => 1
}, @ARGV);