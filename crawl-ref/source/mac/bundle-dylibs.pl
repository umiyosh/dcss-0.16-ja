#!/usr/bin/perl -w
#
# Make a macOS app bundle self-contained.
#
# Usage: bundle-dylibs.pl <executable> <frameworks-dir>
#
# Walks everything the executable links against, copies the non-system
# libraries into <frameworks-dir>, and rewrites the install names so they
# resolve relative to the executable instead of pointing at wherever the
# build machine happened to keep its Homebrew prefix.
#
# The copied libraries have to be re-signed: arm64 refuses to load a library
# whose signature does not match, and install_name_tool only regenerates the
# signature by itself for linker-signed binaries. Ours is one, Homebrew's
# libraries are not. The executable is left to the caller, which signs the
# whole bundle once it is assembled.

use strict;
use File::Basename;
use File::Copy;

my ($exe, $fwdir) = @ARGV;
die "Usage: $0 <executable> <frameworks-dir>\n" unless $exe && $fwdir;
die "No such executable: $exe\n" unless -f $exe;

# Libraries shipped with the OS; leave those alone.
sub is_system
{
    my ($path) = @_;
    return $path =~ m{^/usr/lib/} || $path =~ m{^/System/};
}

# Libraries a dependency pulls in with dlopen. Those are not load commands,
# so the walk below cannot discover them.
#
# Homebrew's sdl2 is sdl2-compat, a shim that resolves the real SDL3 in a
# library constructor. It looks for @loader_path/libSDL3.dylib first, so
# copying SDL3 next to it in Frameworks is enough; without it the shim wedges
# during startup instead of reporting anything useful.
my %DLOPENED = ("libSDL2-2.0.0.dylib" => ["libSDL3.dylib"]);

# The install name a library advertises for itself. It shows up in its own
# otool -L output and must not be treated as a dependency.
sub dylib_id
{
    my ($path) = @_;
    my @out = `otool -D '$path' 2>/dev/null`;
    return undef unless @out > 1;
    chomp $out[1];
    return $out[1];
}

sub otool_deps
{
    my ($path) = @_;
    my @out = `otool -L '$path' 2>/dev/null`;
    shift @out;                 # first line is the file name itself
    my @deps;
    for (@out)
    {
        push @deps, $1 if /^\s+(\S+)/;
    }
    return @deps;
}

sub rpaths_of
{
    my ($path) = @_;
    my @out = `otool -l '$path' 2>/dev/null`;
    my @rpaths;
    for (my $i = 0; $i < @out; $i++)
    {
        next unless $out[$i] =~ /^\s+cmd LC_RPATH/;
        for my $j ($i + 1 .. $i + 3)
        {
            next unless defined $out[$j];
            push @rpaths, $1 if $out[$j] =~ /^\s+path (\S+)/;
        }
    }
    return @rpaths;
}

# Turn a dependency string into a real file, resolving the @-prefixes
# relative to the binary that referred to it.
sub resolve
{
    my ($dep, $referrer) = @_;
    my $dir = dirname($referrer);

    # A bare leaf name comes from the dlopen table; look for it the same way
    # @rpath entries are looked up, and beside the library that asked for it.
    $dep = "\@rpath/$dep" if $dep !~ m{/};

    if ($dep =~ m{^\@rpath/(.*)})
    {
        my $rest = $1;
        return "$dir/$rest" if -f "$dir/$rest";
        for my $rp (rpaths_of($referrer))
        {
            (my $base = $rp) =~ s{^\@loader_path}{$dir};
            $base =~ s{^\@executable_path}{dirname($exe)}e;
            return "$base/$rest" if -f "$base/$rest";
        }
        return undef;
    }
    $dep =~ s{^\@loader_path}{$dir};
    $dep =~ s{^\@executable_path}{dirname($exe)}e;
    return -f $dep ? $dep : undef;
}

sub codesign
{
    my ($path) = @_;
    system("codesign", "--force", "--sign", "-", $path) == 0
        or die "codesign failed for $path\n";
}

# --------------------------------------------------------------------------
# Collect the transitive closure.
# --------------------------------------------------------------------------

my %bundled;        # basename => source path
my %unresolved;
my @queue = ($exe);
my %visited;

while (my $bin = shift @queue)
{
    next if $visited{$bin}++;
    my $id = $bin eq $exe ? undef : dylib_id($bin);

    # A dlopen entry is a guess about which library this is: plain SDL2 is
    # named like sdl2-compat but never asks for SDL3. Missing one is normal,
    # so those do not count as an unresolved dependency.
    my %deps = map { $_ => 0 } otool_deps($bin);
    $deps{$_} //= 1 for @{$DLOPENED{basename($bin)} || []};

    for my $dep (keys %deps)
    {
        next if is_system($dep);
        next if defined $id && $dep eq $id;
        my $base = basename($dep);
        next if $bundled{$base};

        my $src = resolve($dep, $bin);
        if (!defined $src)
        {
            $unresolved{$dep} = 1 unless $deps{$dep};
            next;
        }
        $bundled{$base} = $src;
        push @queue, $src;
    }
}

if (%unresolved)
{
    die "Could not resolve: " . join(", ", sort keys %unresolved) . "\n";
}

if (!%bundled)
{
    print "  nothing to bundle; the executable only uses system libraries\n";
    exit 0;
}

# --------------------------------------------------------------------------
# Copy, then rewrite the install names.
# --------------------------------------------------------------------------

mkdir $fwdir unless -d $fwdir;

for my $base (sort keys %bundled)
{
    my $dest = "$fwdir/$base";
    copy($bundled{$base}, $dest) or die "copy $bundled{$base}: $!\n";
    chmod 0755, $dest;
}

# Every reference to a library we bundled has to point into Frameworks. That
# includes references between the bundled libraries themselves.
for my $target ($exe, map { "$fwdir/$_" } sort keys %bundled)
{
    my $base = basename($target);
    my $is_lib = $target ne $exe;

    if ($is_lib)
    {
        system("install_name_tool", "-id",
               "\@executable_path/../Frameworks/$base", $target) == 0
            or die "install_name_tool -id failed for $target\n";
    }

    for my $dep (otool_deps($target))
    {
        next if is_system($dep);
        my $dbase = basename($dep);
        next unless $bundled{$dbase};
        next if $target ne $exe && $dbase eq $base;
        system("install_name_tool", "-change", $dep,
               "\@executable_path/../Frameworks/$dbase", $target) == 0
            or die "install_name_tool -change failed for $target\n";
    }
    codesign($target) if $is_lib;
}

printf "  bundled %d libraries into %s\n", scalar(keys %bundled), $fwdir;
