#!/usr/bin/env perl

use 5.016;
use strict;
use warnings;
use autodie;
use utf8;

use PhotoMoveManager;
use Utils;

use File::Find;
use Data::Dumper;
use File::Copy;
use Term::ANSIColor;
use List::Util qw(max);

use Getopt::Long;

my $target_directory;
my $trash_directory = '';
my $trash = 0;
GetOptions(
    'target=s' => \$target_directory,
    'trash_dir=s'  => \$trash_directory,
    'trash'  => \$trash,
);

$trash_directory ||= $target_directory . '.trash';

say "Trash directory is '$trash_directory'";

my $move_manager = PhotoMoveManager->new($target_directory, $trash_directory);
my $files_to_handle = {};
say "Searching for movable files in $target_directory...";
finddepth( {
    wanted => sub {
        my $file_path = $File::Find::name;
        return if $file_path !~ m/\/.+\.(jpg|jpeg|mov|avi|mp4|m4v|png|orf|wmv)$/i
            or -d $file_path;
        $files_to_handle->{$file_path} = 1;
    },
    no_chdir => 1
}, $target_directory);

my @files_to_move = sort { $a cmp $b } keys $files_to_handle;

say "Planning the move...";
local $| = 1;
my $counter;
my $last_print_length = 0;
for my $path (@files_to_move) {
    my $target_path = $move_manager->plan_move($path);

    if ($counter++ % 42 == 0) {

        my $color = '';
        if ($target_path) {
            if ($target_path eq $path) {
                $color = 'green';
            } elsif (substr($target_path, 0, length $trash_directory) eq $trash_directory) {
                $color = 'red';
            } else {
                $color = 'yellow';
            }
        }

        print "\b" x $last_print_length;
        my $status = "\r" .$path . ' => ' . ($target_path  || 'unknown');
        print colored($status, $color);
        my $status_length = length $status;
        print ' ' x ($last_print_length - $status_length);
        $last_print_length = max($status_length, $last_print_length);
    }
}

print "\n";

$move_manager->execute();

Utils->clean_directory($_, qr/\.DS_store/i) for ($target_directory, $trash_directory);

`trash '$trash_directory'` if $trash;