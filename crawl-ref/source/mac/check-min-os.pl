#!/usr/bin/perl -w
#
# Fail if anything in an app bundle needs a newer macOS than we promise.
#
# Usage: check-min-os.pl <max-version> <app-bundle>
#
# Every Mach-O carries the OS version it was built to require. Nothing sets
# that here: the Apple block that would pass -mmacosx-version-min is skipped
# (#8), so clang falls back to the version of the machine doing the build, and
# the Homebrew libraries copied into the bundle carry whatever their bottles
# were built for. A build host newer than the target audience therefore
# produces a bundle that Finder refuses with "you can't use this version of
# the application with this version of macOS" — and every other check still
# passes, because the bundle is perfectly valid, just for a newer OS.

use strict;
use File::Basename;

my ($max, $bundle) = @ARGV;
die "Usage: $0 <max-version> <app-bundle>\n" unless $max && $bundle;
die "No such bundle: $bundle\n" unless -d $bundle;

# "15.4" => 15.004000, so versions compare numerically rather than as strings.
sub numify
{
    my ($v) = @_;
    my @p = (split(/\./, $v), 0, 0);
    return $p[0] + $p[1] / 1000 + $p[2] / 1000000;
}

sub min_os
{
    my ($path) = @_;
    my @out = `otool -l '$path' 2>/dev/null`;
    for (my $i = 0; $i < @out; $i++)
    {
        # LC_VERSION_MIN_MACOSX is what older binaries use instead.
        next unless $out[$i] =~ /^\s+cmd LC_(BUILD_VERSION|VERSION_MIN_MACOSX)/;
        for my $j ($i + 1 .. $i + 6)
        {
            next unless defined $out[$j];
            return $1 if $out[$j] =~ /^\s+(?:minos|version) (\S+)/;
        }
    }
    return undef;
}

my @machos = grep { min_os($_) }
             split /\n/, `find '$bundle' -type f \\( -perm +111 -o -name '*.dylib' \\)`;

die "Found no Mach-O files in $bundle; the check would pass vacuously.\n"
    unless @machos;

my $limit = numify($max);
my (%seen, @bad);
for my $f (@machos)
{
    my $v = min_os($f);
    $seen{$v}++;
    push @bad, "  $v\t" . basename($f) if numify($v) > $limit;
}

printf "  checked %d Mach-O files, minimum macOS: %s\n",
       scalar(@machos), join(", ", sort keys %seen);

if (@bad)
{
    print STDERR "error: these need a newer macOS than the promised $max:\n";
    print STDERR "$_\n" for @bad;
    print STDERR "Build on a runner matching the oldest macOS to support.\n";
    exit 1;
}

print "  ok: runs on macOS $max and later\n";
