#!/usr/bin/perl
package util;

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
	my ( $baseDir, $curDir, $path ) = @_;

	#print "\nBaseDir ".$baseDir;
	#print "\nCurDir ".$curDir;
	#print "\npath ".$path;

	$baseDir = NormalizePath($baseDir);
	$curDir  = NormalizePath($curDir);
	$path    = NormalizePath($path);

	# if path is relative, prefix with current dir
	if ( $path eq '.' ) {
		$path = $curDir;
	}
	elsif ( $curDir ne '.' && $path !~ /^\// ) {
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
	if ( defined($temp) ) {
		$temp =~ s/:/~%%~/;
	}
	$str =~ s/~~&&~~/$temp/;
	my @tokens = split( ':', $str );
	my @ret;
	foreach $a (@tokens) {
		$a =~ s/~#~/::/g;
		$a =~ s/~%%~/:/g;
		push( @ret, $a );
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
	my $summary_file = shift;
	my $twig         = XML::Twig->new();
	$twig->parsefile($summary_file);
	my @parsed_summary;

	my $root  = $twig->root;
	my @uuids = $twig->get_xpath('/assessment-summary/assessment-summary-uuid');
	my $uuid  = $uuids[0]->text;

	my @pkg_dirs     = $twig->get_xpath('/assessment-summary/package-root-dir');
	my $package_name = $pkg_dirs[0]->text;
	$package_name =~ s/\/[^\/]*$//;

	my @tool_names = $twig->get_xpath('/assessment-summary/tool-type');
	my $tool_name  = $tool_names[0]->text;

	my @tool_versions = $twig->get_xpath('/assessment-summary/tool-version');
	my $tool_version  = $tool_versions[0]->text;
	$tool_version =~ s/\n/ /g;

	my @assessment_root_dir =
	  $twig->get_xpath('/assessment-summary/assessment-root-dir');
	my $size = @assessment_root_dir;
	if ( $size > 0 ) {
		$package_name = $assessment_root_dir[0]->text;
	}
	my @assessments =
	  $twig->get_xpath('/assessment-summary/assessment-artifacts/assessment');

	foreach my $i (@assessments) {
		my @report = $i->get_xpath('report');
		my @target = $i->get_xpath('replace-path/target')
		  if ( defined $i->get_xpath('replace-path/target') );
		my @srcdir = $i->get_xpath('replace-path/srcdir')
		  if ( defined $i->get_xpath('replace-path/srcdir') );
		my $srcdir_path = " ";
		if (@srcdir) {
			$srcdir_path = $target[0]->text;
			foreach my $elem (@srcdir) {
				$srcdir_path = $srcdir_path . "::" . $elem->text;
			}
		}
		my @build_art_id      = $i->get_xpath('build-artifact-id');
		my $build_artifact_id = 0;
		my @cwd               = $i->get_xpath('command/cwd');
		$build_artifact_id = $build_art_id[0]->text
		  if defined( $build_art_id[0] );
		push(
			@parsed_summary,
			join( "~:~",
				$uuid,         $package_name,      $tool_name,
				$tool_version, $build_artifact_id, $report[0]->text,
				$cwd[0]->text, $srcdir_path )
		) if defined( $report[0] );
	}

	return @parsed_summary;
}

sub GetFileList {
	my @parsed_summary = shift;
	foreach my $line (@parsed_summary) {
		chomp($line);
		(
			$uuid, $package_name, $tool_name, $tool_version, $build_artifact_id,
			$input, $cwd, $replace_dir
		) = split( '~:~', $line );
		if ( $print_flag == 1 ) {
			print "--------------------------------------------------------------------------------------\n";
			print "UUID: $uuid\n";
			print "PACKAGE_NAME: $package_name\n";
			print "TOOL_NAME: $tool_name\n";
			print "TOOL_VERSION: $tool_version\n";
			print "BUILD_ARTIFACT_ID: $build_artifact_id\n";
			print "REPLACE_DIR: $replace_dir\n";
			print "CWD: $cwd\n";
			print "INPUT_FILES:";
			$print_flag = 0;
		}
		print " " . $input;
		push @input_file_arr, "$input";
	}
	return @input_file_arr;
}

1;
