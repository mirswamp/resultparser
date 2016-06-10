#!/usr/bin/perl -w
package Util;
use strict;
use XML::Twig;
use IO qw(File);
use Cwd qw();
use File::Basename;

my $current_dir = Cwd::cwd();
my $script_dir = dirname(Cwd::abs_path($0)) ;


# NormalizePath - take a path and remove empty and '.' directory components
#                 empty directories become '.'
#
sub NormalizePath {
    my $p = shift;

    $p =~ s/\/\/+/\//g;        # collapse consecutive /'s to one /
    $p =~ s/\/(\.\/)+/\//g;    # change /./'s to one /
    $p =~ s/^\.\///;           # remove initial ./
    $p = '.' if $p eq '';      # change empty dirs to .
    $p =~ s/\/\.$/\//;                 # remove trailing . directory names
    $p =~ s/\/$// unless $p eq '/';    # remove trailing /

    return $p;
}


# AdjustPath - take a path that is relative to curDir and make it relative
#              to baseDir.  If the path is not in baseDir, do not modify.
#
#       baseDir    - the directory to make paths relative to
#       curDir     - the directory paths are currently relative to
#       path       - the path to change
#
sub AdjustPath {
    my ($baseDir, $curDir, $path) = @_;

    $baseDir = NormalizePath($baseDir);
    $curDir  = NormalizePath($curDir);
    $path    = NormalizePath($path);

    # if path is relative, prefix with current dir
    if ($path eq '.')  {
        $path = $curDir;
    }  elsif ($curDir ne '.' && $path !~ /^\//)  {
        $path = "$curDir/$path";
    }

    # remove initial baseDir from path if baseDir is not empty
    $path =~ s/^\Q$baseDir\E\///;

    return $path;
}


sub SplitString {
    my ($str) = @_;
    $str =~ s/::+/~#~/g;
    $str =~ /(‘[^:]+:+[^:]+’)/;
    my $temp = $1;
    $str =~ s/‘[^:]+:+[^:]+’/~~&&~~/;
    if (defined $temp)  {
        $temp =~ s/:/~%%~/;
    }
    $str =~ s/~~&&~~/$temp/;
    my @tokens = split(':', $str);
    my @ret;
    foreach $a (@tokens)  {
        $a =~ s/~#~/::/g;
        $a =~ s/~%%~/:/g;
        push(@ret, $a);
    }
    return (@ret);
}


sub Trim {
    my ($string) = @_;
    $string =~ s/^ *//;
    $string =~ s/ *$//;
    return "$string";
}


sub ParseSummaryFile {
    my $summaryFile = shift;
    my $twig         = XML::Twig->new();
    $twig->parsefile($summaryFile);
    my @parsedSummary;

    my $root  = $twig->root;
    my @uuids = $twig->get_xpath('/assessment-summary/assessment-summary-uuid');
    my $uuid  = $uuids[0]->text;

    my @pkg_dirs = $twig->get_xpath('/assessment-summary/package-root-dir');
    my $packageName = $pkg_dirs[0]->text;
    $packageName =~ s/\/[^\/]*$//;

    my @toolVersions = $twig->get_xpath('/assessment-summary/tool-version');
    my $toolVersion  = $toolVersions[0]->text;
    $toolVersion =~ s/\n/ /g;

    my @assessmentRootDir = $twig->get_xpath('/assessment-summary/assessment-root-dir');
    my $size = @assessmentRootDir;
    if ($size > 0)  {
        $packageName = $assessmentRootDir[0]->text;
    }
    my @assessments = $twig->get_xpath('/assessment-summary/assessment-artifacts/assessment');

    foreach my $i (@assessments)  {
        my @report = $i->get_xpath('report');
        my @target = $i->get_xpath('replace-path/target')
        if (defined $i->get_xpath('replace-path/target'));
            my @srcdir = $i->get_xpath('replace-path/srcdir')
                    if (defined $i->get_xpath('replace-path/srcdir'));
            my $srcdir_path = " ";
            if (@srcdir)  {
                $srcdir_path = $target[0]->text;
                foreach my $elem (@srcdir)  {
                    $srcdir_path = $srcdir_path . "::" . $elem->text;
                }
            }
            my @build_art_id      = $i->get_xpath('build-artifact-id');
            my $buildArtifactId = 0;
            my @cwd               = $i->get_xpath('command/cwd');
            $buildArtifactId = $build_art_id[0]->text if defined $build_art_id[0];
            push(@parsedSummary,
                    join("~:~",
                        $uuid, $packageName, $toolVersion,
                        $buildArtifactId, $report[0]->text, $cwd[0]->text,
                        $srcdir_path)
            ) if defined $report[0];
    }

    return @parsedSummary;
}


sub GetFileList {
    my @parsedSummary = @_;
    my $print_flag     = 1;
    my @inputFiles;
    my ($uuid, $packageName, $toolVersion, $buildArtifactId, $input, $cwd, $replaceDir);
    foreach my $line (@parsedSummary)  {
        chomp $line;
        ($uuid, $packageName, $toolVersion, $buildArtifactId, $input, $cwd, $replaceDir)
                = split('~:~', $line);
        print $input . "\n";
        push @inputFiles, "$input";
    }
    return @inputFiles;
}


#Not used anywhere. Remove
sub BuildParserHash {
    my ($hash, $file) = @_;
    open(IN, "<$file") or die("Failed to open $file for reading");
    for my $line (<IN>)  {
        chomp($line);
        my ($tool, $parser_function) = split /#/, $line, 2;
        $hash->{$tool} = $parser_function;
    }
    close(IN);
    return $hash;
}


sub IsAbsolutePath {
    my ($path) = @_;
    if ($path =~ m/^\/.*/g)  {
        return 1;
    }
    return 0;
}


sub TestPath {
    my ($path, $mode) = @_;
    my $fh;
    if ($mode eq "W")  {
        open $fh, ">>", $path or die "Cannot open file $path !!";
    }  elsif ($mode eq "R")  {
        open $fh, "<", $path or die "Cannot open file $path !!";
    }
    close($fh);
}


sub GetToolName {
    my $assessment_summary_file = shift;
    my $toolName                = "";
    my $twig                    = XML::Twig->new(
                                    twig_roots    => {'assessment-summary' => 1},
                                    twig_handlers => {
                                            'assessment-summary/tool-type' => sub {
                                                    my ($tree, $elem) = @_;
                                                    $toolName = $elem->text;
                                              }
                                    }
                                );
    $twig->parsefile($assessment_summary_file);
    if ($toolName eq "")  {
        die("Error: Could not extract tool name from the summary file ");
    }
    return $toolName;
}


sub ToolNameHandler {
    my ($tree, $elem) = @_;
    return $elem->text;
}


sub InitializeParser {
    my @parsedSummary = @_;
    my @inputFiles = GetFileList(@parsedSummary);
    my ($uuid, $packageName, $toolVersion, $buildArtifactId, $input, $cwd, $replaceDir);

    chomp($parsedSummary[0]);
    (
        $uuid, $packageName, $toolVersion, $buildArtifactId, $input, $cwd,
        $replaceDir
    ) = split('~:~', $parsedSummary[0]);

    print '-' x 86, "\n";
    print "UUID: $uuid\n";
    print "PACKAGE_NAME: $packageName\n";
    print "TOOL_VERSION: $toolVersion\n";
    print "BUILD_ARTIFACT_ID: $buildArtifactId\n";
    print "REPLACE_DIR: $replaceDir\n";
    print "CWD: $cwd\n";
    print "\n";
    return ($uuid, $packageName, $buildArtifactId, $input, $cwd,
            $replaceDir, $toolVersion, @inputFiles);
}


sub GetBuildIds {
    my @parsedSummary = @_;
    my @buildIds;
    my ($uuid, $packageName, $toolVersion, $buildArtifactId, $input, $cwd, $replaceDir);
    foreach my $line (@parsedSummary)  {
        chomp($line);
        ($uuid, $packageName, $toolVersion, $buildArtifactId, $input, $cwd, $replaceDir)
                = split('~:~', $line);
        push @buildIds, "$buildArtifactId";
    }
    return @buildIds;
}


sub PrintWeaknessCountFile {
    my ($weaknessCountFile, $weaknessCount) = @_;

    if (defined $weaknessCountFile)  {
        open WFILE, ">", $weaknessCountFile or die "open $weaknessCountFile: $!";
        print WFILE "weaknesses: $weaknessCount\n";
        close WFILE or die "close $weaknessCountFile: $!";
    }
}


sub Version
{
    system ("cat $script_dir/version.txt");
    exit 0;
}


sub Usage
{
print <<EOF;
Usage: resultParser.pl [-h] [-v]
          [--summary_file=<PATH_TO_SUMMARY_FILE>]
          [--input_dir=<PATH_TO_RESULTS_DIR>]
          [--output_dir=<PATH_TO_OUTPUT_DIR>]
          [--output_file=<OUTPUT_FILENAME>]
          [--weakness_count_file=<WEAKNESS_COUNT_FILENAME>]
          [--merge/nomerge]
          [--log_file=<LOGFILE>]
          [--report_summary_file=<REPORT_SUMMARY_FILE>]

Arguments
    -h, --help                          show this help message and exit
    -v, --version                       show the version number
    --summary_file=[SUMMARY_FILE]       Path to the Assessment Summary File
    --input_dir=[INPUT_DIR]             Path to the raw assessment result directory
    --output_dir=[OUTPUT_DIR]           Path to the output directory
    --output_file=[OUTPUT_FILE]         Output File name in merged case 
                                            (relative to the output_dir)
    --merge                             Merges the parsed result in a single file (Default option)
    --nomerge                           Do not merge the parsed results
    --weakness_count_file               Name of the weakness count file
                                            (relative to the output_dir)
    --log_file                          Name of the log file
EOF
    exit 0;
}


1;
