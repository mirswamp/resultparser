#!/usr/bin/perl -w

#use strict;
use Getopt::Long;
use bugInstance;
use XML::Twig;
use xmlWriterObject;
use Util;

my (
    $input_dir,  $output_file,  $tool_name, $summary_file, $weakness_count_file, $help, $version
);

GetOptions(
    "input_dir=s"   => \$input_dir,
    "output_file=s"  => \$output_file,
    "tool_name=s"    => \$tool_name,
    "summary_file=s" => \$summary_file,
    "weakness_count_file=s" => \$$weakness_count_file,
    "help" => \$help,
    "version" => \$version
) or die("Error");

Util::Usage() if defined ( $help );
Util::Version() if defined ( $version );

if( !$tool_name ) {
    $tool_name = Util::GetToolName($summary_file);
}

my ($uuid, $package_name, $build_id, $input, $cwd, $replace_dir, $tool_version, @input_file_arr) = Util::InitializeParser($summary_file);


my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );
my %h;

foreach my $input_file (@input_file_arr) {
    open my $file, "$input_dir/$input_file" or die ("Unable to open file!");
    my @f;
    my $counter = 0;
    my $state = '0';
    my $sourcefile = "";
    my $fn_name = "";
    my $l1 = <$file>;
    my $l2 = <$file>;
    my $l3 = <$file>;
    if ($l1 =~ /=*/ && $state eq '0') {
        #Check Line-1
        $state = '1';
    }
    if ($l2 =~ /^\s+NLOC*/ && $state eq '1') {
        #Check Line-2
        #@f = split /\s+/, $l2, 7;
        $state = '2';
    }
    if ($l3 =~ /-*/ && $state eq '2') {
        #Check Line-3
        $state = '3';
    }
    if ($state ne '3') {
        print "Invalid file! \n";
        exit;
    }
    while (my $line = <$file>) {
        if ($line =~ /^-+/) {
            last;
        }
        my @v = split /\s+/, $line, 7;
        my $loc = $v[6];
        my @l = split /@/, $loc, 3;
        my @fm = split /-/, $l[1];
        chomp $l[2];
        $fn_name = $l[0];
        my $class = "";
        my $fn = "";
        my @cl_fn = split /::/, $fn_name;
        my $fnl = scalar @cl_fn;
        if ($fnl > 1) {
            #$class = $cl_fn[0];
            #$fn = $cl_fn[1];
            my $rind = rindex($fn_name, '::');
            $class = substr($fn_name, 0, $rind);
            $fn = substr($fn_name, $rind+2);
        }
        my $nloc = $v[1];
        my $ccn = $v[2];
        my $token = $v[3];
        my $param = $v[4];
        my $length = $fm[1] - $fm[0] + 1;
        $sourcefile = $l[2];
        my @keys = keys %h;
        if (exists $h{ $fn_name }) {
            # Update uniquifier
        }
        $h{ $sourcefile }{'file-stat'} = "";
        $h{ $sourcefile }{'func-stat'}{$fn_name}{'class'} = $class;
        if ($fn eq '') {
            $h{ $sourcefile }{'func-stat'}{$fn_name}{'function'} = $fn_name;
        }
        else {
            $h{ $sourcefile }{'func-stat'}{$fn_name}{'function'} = $fn;
        }
        $h{ $sourcefile }{'func-stat'}{$fn_name}{'file'} = $sourcefile;
        $h{ $sourcefile }{'func-stat'}{$fn_name}{'metrics'}{'token'} = $token;
        $h{ $sourcefile }{'func-stat'}{$fn_name}{'metrics'}{'ccn'} = $ccn;
        $h{ $sourcefile }{'func-stat'}{$fn_name}{'metrics'}{'params'} = $param;
        $h{ $sourcefile }{'func-stat'}{$fn_name}{'metrics'}{'code-lines'} = $nloc;
        $h{ $sourcefile }{'func-stat'}{$fn_name}{'metrics'}{'total-lines'} = $length;
        $h{ $sourcefile }{'func-stat'}{$fn_name}{'location'}{'startline'} = $fm[0];
        $h{ $sourcefile }{'func-stat'}{$fn_name}{'location'}{'endline'} = $fm[1];
    }
}
$xmlWriterObj->writeMetricObjectUtil(%h);
undef %h;
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

if(defined $weakness_count_file){
    Util::PrintWeaknessCountFile($weakness_count_file,$xmlWriterObj->getBugId()-1);
}