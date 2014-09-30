#!/usr/bin/env perl

use 5.016;
use strict;
use warnings;
use autodie;
no autovivification;

use Math::Round;
use File::Find;
use List::Util qw(max);
use List::MoreUtils qw(any);

use Getopt::Long;

use constant DISTANCE => 1024*2;

my $dir_path;
my @extensions;
GetOptions(
    'path=s' => \$dir_path,
    'ext=s'  => \@extensions,
);

@extensions = map { $_ =~ s'^\.''r } map { split ',', $_ } @extensions;

die 'No extensions to search for' unless @extensions;

printf "Searching for movable files (%s) in %s...\n", (join ', ', @extensions), $dir_path;

my $extensions = join '|', @extensions;
my $regex = qr/\.($extensions)$/;

my $found_files_to_sizes = {};
finddepth( {
    wanted => sub {
        my $file_path = $File::Find::name;
        return if $file_path !~ m/$regex/i
            or -d $file_path;
        $found_files_to_sizes->{$file_path} = -s $file_path;
    },
    no_chdir => 1
}, $dir_path);

my @files =
    sort { $a->{size} <=> $b->{size} }
    map {{ path => $_, size => $found_files_to_sizes->{$_} }}
    keys $found_files_to_sizes;

my @groups;
my $current_group;
my $size = -1 * (DISTANCE + 1);

for my $file (@files) {
    if ($file->{size} - $size > DISTANCE) {
        $current_group = [ $file ];
        push @groups, $current_group;
    } else {
        push $current_group, $file;
    }
    $size = $file->{size};
}
@groups = sort { -(@$a <=> @$b) } grep { @$_ > 1 } @groups;

print ( (scalar @groups) . " potential duplicate groups found\n" );

for my $group (@groups) {
    my @group = sort {$a cmp $b} @$group;
    my $n = scalar @group;
    say "$n files of same size found";

    my @sets = map {{$_->{path} => 1}} @group;

    for (my $i = 0; $i < $n; $i++) {
        for (my $j = $i; $j < $n; $j++) {
            my $a = $group[$i];
            my $b = $group[$j];
            next if in_same_set(\@sets, $a, $b);
            printf "Comparing '%s' and '%s' ...\n",
                remove_common_path($a->{path}),
                remove_common_path($b->{path});
            play_video($a, 1);
            print "Press any key to continue";
            $| = 1;
            $_ = <STDIN>;
            play_video($b);
            if (ask_if_same()) {
                merge_sets(\@sets, $a, $b);
            }
        }
    }

    for my $duplicate_set (grep { keys $_ > 1 } @sets) {
        print "\n";

        my @duplicate_paths = sort { $a cmp $b } keys $duplicate_set;
        for (my $i = 0; $i < @duplicate_paths; $i++) {
            my $path = $duplicate_paths[$i];
            printf "%s. %s [%.2f %s]\n", $i, remove_common_path($path), format_size($found_files_to_sizes->{$path});
        }
        print "\tare duplicates. Witch one shall stay [0]?\n# ";
        $| = 1;
        my $index;
        while(1) {
            $index = <STDIN>;
            $index =~ s~[\0|\n]~~;
            $index ||= 0;
            last if defined $index and $index =~ /^-?[0-9]+$/ and $index >= -1 and $index < @duplicate_paths;
            print "Invalid input '$index'. Again...\n# ";
        }
        for (my $i = 0; $i < @duplicate_paths; $i++) {
            my $path = $duplicate_paths[$i];
            if ($i != $index) {
                say "Deleting " . remove_common_path($path) . "...";
                `trash '$path'`;
            } else {
                say remove_common_path($path) . " is staying";
            }
        }
    }
}

sub play_video {
    my ($file, $wait) = shift;
    my $file_path = $file->{path};
    print "\nOpening '". remove_common_path($file_path) . "'...\n";
    system 'killall', '-9', 'VLC';
    system("open -F -g '$file_path'");
}

sub ask_if_same {
    while(1) {
        print "Are those files look the same [Y]? ";
        $| = 1;
        $_ = <STDIN>;
        chomp;

        next unless length $_ == 0 or /^(yes|y|no|n)$/i;

        return 0 if /^(no|n)$/i;
        return 1;
    }
}

sub merge_sets {
    my ( $sets, $a, $b ) = @_;
    
    my ($set_to_merge, $set_to_merge_to);
    for my $set (@$sets) {
        if (exists $set->{$a->{path}}) {
            die if $set_to_merge;
            $set_to_merge = $set;
        }
        if (exists $set->{$b->{path}}) {
            die if $set_to_merge_to;
            $set_to_merge_to = $set;
        }
    }
    die if not $set_to_merge;
    die if not $set_to_merge_to;
    die if not $set_to_merge ne $set_to_merge_to;

    for my $key (keys $set_to_merge) {
        $set_to_merge_to->{$key} = delete $set_to_merge->{$key};
    }
}

sub in_same_set {
    my ( $sets, $a, $b ) = @_;
    
    for my $set (@$sets) {
        if (exists $set->{$a->{path}} and exists $set->{$b->{path}}) {
            return 1;
        }
    }
    return 0;
}

sub remove_common_path {
    $_[0] =~ s/^\Q$dir_path\E\///r;
}

sub format_size {
    my $size = shift;
    my $exp = 0;
    state $units = [qw(B KB MB GB TB PB)];
    for (@$units) {
        last if $size < 1024;
        $size /= 1024;
        $exp++;
    }
    return ($size, $units->[$exp]);
}

1;