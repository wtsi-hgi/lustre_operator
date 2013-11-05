#!/usr/bin/perl -w
#
# split-by-cols.pl: splits a tabular file (such as comma-delimited CSV or 
# tab-delimited TSV) into multiple files each containing unique combinations 
# of values for one or more specified columns.
#
# Copyright 2010 Joshua Randall
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Author:
#    This software was written by Joshua C. Randall <jcrandall@alum.mit.edu>
#

use strict;

use IO::File;
use IO::Uncompress::Gunzip;
use IO::Compress::Gzip;

use Getopt::Long;

my $scriptcentral_path = "/home/jrandall/scriptcentral";
if(exists($ENV{SCRIPTCENTRAL})) {
    $scriptcentral_path = $ENV{SCRIPTCENTRAL};
}
require "$scriptcentral_path/fzinout.pl";

my $DEBUG=1;

my $infile;
my $outbase;
my $outsuffix;

my $insep="\t"; 
my $outsep="\t"; 

my $header=1;
my $outheader=1;
my $keepcols=0;
my $missing="";

my $toplines=0; # number lines at the top of file before beader (to skip or keep)
my $keeptoplines=0;

my @cols;

my @transforms;

my $result = GetOptions( "in=s" => \$infile,
			 "outbase=s" => \$outbase,
			 "outsuffix=s" => \$outsuffix,
			 "insep=s" => \$insep,
			 "outsep=s" => \$outsep,
			 "header=i" => \$header,
			 "outheader=i" => \$outheader,
			 "keepcols=i" => \$keepcols,
			 "cols=s{1,}" => \@cols,
			 "transforms=s{0,}" => \@transforms, # matchpat/substexpr
			 "missing=s" => \$missing,
			 "toplines=i" => \$toplines,
			 "keeptoplines=i" => \$keeptoplines,
			 );

print STDERR "have transforms [@transforms]\n" if($DEBUG>0);

# open input file
my $infh = fzinopen($infile);

# suck top lines
my $toplinesdata="";
if($toplines > 0) {
    for(my $n=0; $n<$toplines; $n++) {
	my $topline = <$infh>;
	$toplinesdata .= $topline;
    }
}

# process headers
my $headerline = <$infh>;
chomp $headerline;
my @headers = split /$insep/,$headerline,-1;
my %header2colnum;
my $colnum = 0;
foreach my $header (@headers) {
    $header2colnum{$header} = $colnum;
    $colnum++;
}
my $numcols = $colnum;


# get column indices from @cols, which could have headers or colnums
my @colnums;
my %colnum2names;
if($header < 1) {
    # don't have a header, so we must have colnums already
    @colnums = @cols;
    foreach my $col (@cols) {
	$colnum2names{$col} = $col;
    }
} else {
    # have a header, might have a mix of colnums and colheaders
    foreach my $col (@cols) {
	if(defined($header2colnum{$col})) {
	    print STDERR "Found colnum $header2colnum{$col} for $col\n" if($DEBUG>0);
	    push @colnums, $header2colnum{$col};
	    $colnum2names{$header2colnum{$col}} = $col;
	} else {
	    push @colnums, $col;
	    $colnum2names{$col} = $col;
	}
    }
}

print STDERR "Splitting on colnums [".join(' ',@colnums)."]\n" if($DEBUG>0);
print STDERR "Using column names [".join(' ',map {$colnum2names{$_}} @colnums)."]\n" if($DEBUG>0);

# suck input file into memory, and build enumeration of values for each of the selection columns (as hash keys)
my %data; # HoA (strathashkey --> rowdata)
while(my $line = <$infh>) {
    chomp $line;
    my @rowdata = recode_missing(split /$insep/,$line,-1);
    my $strathashkey;
    foreach my $colnum (@colnums) {
	my $name = $colnum2names{$colnum};
	my $value = $rowdata[$colnum];
	foreach my $transform (@transforms) {
	    $value = transform($transform,$value);
	}
#	$strathashkey .= ".".$name."_".$value;
	$strathashkey .= $value.".";
    }
    
    push @{$data{$strathashkey}},[keepcols(@rowdata)];
}

$infh->close();

# eliminate unwanted cols from headers
@headers = keepcols(@headers);

# output a file for each hash key
foreach my $strathashkey (keys %data) {
    my $outfile = $outbase.$strathashkey.$outsuffix;
    print STDERR "Outputting [$outfile]... " if($DEBUG>0);
    my $outfh = fzoutopen($outfile);
    if($keeptoplines > 0) {
	print $outfh $toplinesdata;
    }
    if($outheader > 0) {
	print $outfh join($outsep,@headers)."\n";
    }
    foreach my $rowdataref (@{$data{$strathashkey}}) {
	print $outfh join($outsep,@{$rowdataref})."\n";
    }
    print STDERR "done!\n" if($DEBUG>0);
    $outfh->close();
}


sub transform {
    my $transform = shift;
    my $value = shift;

    if($transform =~ m/\//) {
	my ($matchpat, $substpat) = split /\//,$transform,2;
	$value =~ s/$matchpat/$substpat/g;
    } elsif($transform =~ m/\:/) {
	my ($matchpat, $substexpr) = split /\:/,$transform,2;
	$value =~ s/$matchpat/$substexpr/gee;
    } else {
	print STDERR "could not parse transform [$transform]\n" if($DEBUG>0);
    }
    return($value);
}

sub keepcols {
    my @rowdata = @_;
    my @keptrowdata;
    if($keepcols < 1) {
        # remove strat columns from row data 
	my $col = 0;
	foreach my $data (@rowdata) {
	    if(defined($colnum2names{$col})) {
		# this is a strat column
	    } else {
		# this is not a strat column, keep it
		push @keptrowdata, $data;
	    }
	    $col++;
	}
    } else {
	# keep all columns
	@keptrowdata = @rowdata;
    }
    return(@keptrowdata);
}

sub recode_missing {
    my @indata = @_;
    my @outdata; 
    foreach my $data (@indata) {
	if($data eq "") {
	    push @outdata,$missing;
	} else {
	    push @outdata,$data;
	}
    }
    return @outdata;
}
