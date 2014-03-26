package Utils;

use 5.016;
use strict;
use warnings;
use autodie;

use File::Path qw/remove_tree/;
use File::Find qw/finddepth/;
use File::Basename qw/dirname/;

sub clean_directory {
    my ( $class, $directory_path, @ignore_patterns ) = @_;

    my $directory_contains = { };

    finddepth( {
        wanted => sub {
            my $path = $File::Find::name;
            __log("Looking at $path");

            if (-d $path) {
                my @files = @{ delete $directory_contains->{$path} // [] };
                unless (__only_ignored_files_or_directories(\@files, \@ignore_patterns)) {
                    __log("Deleting empty $path");
                    remove_tree($path);
                } else {
                    __log("$path is not deleted as it contains children");
                }
            } else {
                my $dirname = dirname($path);
                $directory_contains->{$dirname} //= [];
                push $directory_contains->{$dirname}, $path;
            }
        },
        no_chdir => 1
    }, $directory_path);
}

sub __only_ignored_files_or_directories {
    my ( $file_paths, $ignore_patterns ) = @_;

    FILE: for my $existing_file_path (grep { -e $_ } @$file_paths) {
        unless (-d $existing_file_path) {
            for my $pattern (@$ignore_patterns) {
                next FILE if $existing_file_path =~ m/$pattern/;
            }
        }
        return 1;
    }
    return 0;
}

sub __log {
    #say @_;
}

1;