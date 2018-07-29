#!/usr/bin/perl

# outputs names of all Perl Modules installed on localhost

use ExtUtils::Installed;
my $instmod = ExtUtils::Installed->new();
foreach my $module ($instmod->modules()) {
    my $version = $instmod->version($module) || "???";
    print "$module -- $version\n";
}
