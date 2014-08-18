#!/usr/bin/env perl

use 5.016;
use strict;
use warnings;
use autodie;

use PhotoMoveManager;
use File::Find;

my $digest_to_paths = {};
while (<>) {
    chomp;
    /^([0-9a-f]+) (.*)$/;
    if (not $1 or not $2 or length($1) != 32) {
        die "Incorrect line:\n$_\n";
    }
    my ($digest, $path) = ($1, $2);
    $digest_to_paths->{$digest}{$path} = 1;
}

for my $digest (keys $digest_to_paths) {
    my @file_paths = sort { $a cmp $b }  keys $digest_to_paths->{$digest};
    next if @file_paths <= 1;

    my $file_to_leave_path = shift @file_paths;
    print "Leaving $file_to_leave_path\n";
    print "Deleting:\n" . (join "\n", @file_paths) . "\n\n";
    for (@file_paths) {
        if (-f $_) {
            `rm -f "$_"`;
        }
    }
}