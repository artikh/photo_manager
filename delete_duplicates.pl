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
    my $value = $digest_to_paths->{$digest};
    if (not $value or scalar(keys($value)) < 2) {
        delete $digest_to_paths->{$digest};
    } else {
        my ($path_to_keep, @paths_to_delete) =
            sort { $a cmp $b }
            keys $digest_to_paths->{$digest};
        die "No '$path_to_keep' found" unless (-f $path_to_keep);

        print "Keeping\n$path_to_keep\nDeleting\n" . (join "\n", @paths_to_delete) . "\n\n";
        for (@paths_to_delete) {
            if (-f $_) {
                `rm -f "$_"`;
            }
        }
    }
}
