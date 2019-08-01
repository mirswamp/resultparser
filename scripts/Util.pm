#!/usr/bin/perl -w
package Util;
use strict;
use XML::Twig;
use IO qw(File);
use Cwd qw();
use File::Basename;

my $current_dir = Cwd::cwd();
my $script_dir = dirname(Cwd::abs_path($0)) ;


sub UrlEncodePath
{
    my ($s) = @_;

    $s =~ s/([%?#])/sprintf("%%%02x", ord($1))/eg;
    if ($s =~ /^([^\/]*:[^\/]*)(\/.*)?$/)  {
        my ($seg1, $rest) = ($1, $2);
        $seg1 =~ s/(:)/sprintf("%%%02x", ord($1))/eg;
        $s = "$seg1";
        $s .= $rest if defined $rest;
    }

    return $s;
}


# NormalizePath - take a path and remove empty and '.' directory components
#                 empty directories become '.'
#
sub NormalizePath
{
    my ($p, $isWin) = @_;

    $p =~ s/\\/\//g if $isWin; 		# if windows: \ -> /
    my $isUnc = $isWin && $p =~ /^\/\//;
    $p =~ s/\/\/+/\//g;       		# collapse consecutive /'s to one /
    $p =~ s/\/(\.\/)+/\//g;   		# change /./'s to one /
    $p =~ s/^\.\///;          		# remove initial ./
    $p = '.' if $p eq '';     		# change empty dirs to .
    $p =~ s/\/\.$/\//;        		# remove trailing . directory names
    $p =~ s/\/$// unless $p eq '/';	# remove trailing /

    $p = "/$p" if $isUnc;		# restore UNC if necessary

    return $p;
}


# IsAbsolutePath - on POSIX it starts with a /
#                  on Windows starts with / or [A-Z]:/
sub IsAbsolutePath
{
    my ($p, $isWin) = @_;

    if (!$isWin)  {
	return $p =~ /^\//;
    }  else  {
	return $p =~ /^(?:[a-z]:)?[\/\\]/i;
    }
}


# AdjustPath - take a path that is relative to curDir and make it relative
#              to baseDir.  If the path is not in baseDir, do not modify.
#
#       baseDir    - the directory to make paths relative to
#       curDir     - the directory paths are currently relative to
#       path       - the path to change
#
sub AdjustPath
{
    my ($baseDir, $curDir, $path, $isWin) = @_;

    $curDir  = NormalizePath($curDir, $isWin);
    $path    = NormalizePath($path, $isWin);

    # if path is relative, prefix with current dir
    if ($path eq '.')  {
        $path = $curDir;
    }  elsif ($curDir ne '.' && !IsAbsolutePath($path, $isWin))  {
        $path = "$curDir/$path";
    }

    # remove initial baseDir from path if baseDir is defined
    if (defined $baseDir)  {
	$baseDir = NormalizePath($baseDir, $isWin);
	$path =~ s/^\Q$baseDir\E\/// if $baseDir ne '.';
    }

    return $path;
}


sub UnescapeCEscape
{
    my $s = shift;
    my %m = (a => "\a", b => "\b", t => "\t", n => "\n", v => chr(11), f => "\f", r => "\r",
            '"' => '"', "'" => "'", "?" => "?", "\\" => "\\");

    if (exists $m{$s})  {
        return $m{$s};
    }  elsif ($s =~ /^[0-7]{1,3}$/)  {
	my $v = oct($s) & 0xFF;
	return chr($v);
    }  elsif ($s =~ /^x([0-9a-fA-F]+)$/)  {
	my $v = hex($s) & 0xFF;
	return chr($v);
    }  else  {
	die "unknown C escape sequence $s";
    }
}


sub UnescapeCString
{
    my $s = shift;

    $s =~ s/\\([abtnrvf?\\"']|[0-7]{1,3}|x[0-9a-fA-F]+)/UnescapeCEscape($1)/ge;
    return $s;
}


sub ReadFile
{
    my $filename = shift;

    open F, $filename or die "open $filename: $!";
    local $/;
    my $s = <F>;
    close F or die "close $filename: $!";

    return $s;
}


sub ReadJsonFile
{
    my ($filename) = @_;

    my $contents;

    {
        use PerlIO::encoding;
        use Encode qw/:fallbacks/;
        local $PerlIO::encoding::fallback = Encode::WARN_ON_ERR;
        open F, "< :encoding(UTF-8)", $filename or die "open $filename: $!";
        local $/;
        $contents = <F>;
        close F or die "close $filename";
    }

    use JSON;
    my $jsonObject = JSON->new->decode($contents);

    return $jsonObject;
}


sub ConvertBadXmlChar
{
    my ($c) = @_;

    my $fixedChar = sprintf("\\u%04X",ord($c));

    print STDERR "WARNING: bad XML char in input converting to '$fixedChar'\n";

    return $fixedChar;
}


# return a file handle where the input if filtered to remove invalid
# XML 1.0 characters
#
sub OpenFilteredXmlInputFile
{
    my ($filename) = @_;

    # open file to filter
    open INFILE, "<:raw", $filename or die "open <$filename: $!";

    # fork child filter process
    my $pid = open my $filteredFile, "-|";

    if (!defined $pid)  {
	die "Failed to exec FilteredXmlInput child process: $!";
    }

    if ($pid != 0)  {
	# in parent
	close INFILE;
	return $filteredFile;
    }

    binmode STDOUT;

    my $sigPipe;
    $SIG{PIPE} = sub {$sigPipe = 1;};

    my $badXmlCharRe = qr/([\x00-\x08\x0b\x0c\x0e-\x1f])/;

    while (1)  {
	my $nRead = sysread INFILE, my $data, 16384;
	die "sysread on file $filename failed: $!" unless defined $nRead;
	last if $nRead == 0;

	$data =~ s/$badXmlCharRe/ConvertBadXmlChar($1)/eg;

	my $r = print $data;

	# exit if there is an error printing or it generated a SIGPIPE
	last if !$r || $sigPipe;
    }

    close INFILE or die "close $filename: $!";
    exit 0;
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
    my $toolVersion;
    if (@toolVersions)  {
	$toolVersion  = $toolVersions[0]->text;
	$toolVersion =~ s/\n/ /g;
    }  else  {
	$toolVersion = '';
    }

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


sub GetToolName {
    my $assessment_summary_file = shift;
    my $toolName                = "";
    my $twig                    = XML::Twig->new(
                                    twig_roots    => {'assessment-summary' => 1},
                                    twig_handlers => {
                                            'assessment-summary/tool-type' => sub {
                                                    my ($tree, $elem) = @_;
                                                    $toolName = $elem->text;
						    $tree->finish_now();
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

    if (@parsedSummary)  {
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
    }  else  {
	#FIXME:  set to uuid an toolVersion to remove warnings.
	#FIXME:  assessment_summary.xml processing code needs to be written
	#FIXME:  to not process file multiple times, not combine multiple
	#FIXME:  pieces of data into a string, and return fixed values
	#FIXME:  separate from per assessment values
	$uuid = '';
	$toolVersion = '';
	print "NO ASSESSMENTS FOUND\n";
    }

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
    my ($weaknessCountFile, $weaknessCount, $status, $longMsg) = @_;

    if (defined $weaknessCountFile)  {
        open WFILE, ">", $weaknessCountFile or die "open $weaknessCountFile: $!";
        print WFILE "weaknesses: $weaknessCount\n";
	if (defined $status)  {
	    die "unknown status type '$status'"
		    unless $status =~ /^(PASS|FAIL|SKIP|NOTE)$/;
	    print WFILE "$status\n";
	}
	if (defined $longMsg && $longMsg !~ /^\s*$/)  {
	    $longMsg =~ s/\n*$//;
	    print WFILE "-----\n$longMsg\n";
	}
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
