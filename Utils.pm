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
            __trace("Looking at $path");

            my $dirname = dirname($path);
            $directory_contains->{$dirname} //= [];
            push $directory_contains->{$dirname}, $path;

            if (-d $path) {
                my @files = @{ delete $directory_contains->{$path} // [] };
                if (__only_ignored_files(\@files, \@ignore_patterns)) {
                    __log("Deleting empty $path");
                    remove_tree($path);
                } else {
                    __trace("$path is not deleted as it contains children");
                }
            }
        },
        no_chdir => 1
    }, $directory_path);
}

sub __only_ignored_files {
    my ( $file_paths, $ignore_patterns ) = @_;

    FILE: for my $existing_file_path (grep { -e $_ and -s $_ } @$file_paths) {
        return 0 if -d $existing_file_path;
        for my $pattern (@$ignore_patterns) {
            next FILE if $existing_file_path =~ m/$pattern/;
        }
        return 0;
    }

    __trace("Files @$file_paths do not match patterns @$ignore_patterns");
    return 1;
}

sub __trace {

}

sub __log {
    say @_;
}

1;