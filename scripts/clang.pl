#!/usr/bin/perl -w

#use strict;
use Getopt::Long;
use bugInstance;
use xmlWriterObject;
use Util;

my (
	$input_file,   $output_file, $tool_name, $tool_version, $uuid,
	$package_name, $build_id,    $cwd,       $replace_dir,  $file_path
);
my $violationId = 0;
my $bugId       = 0;
my $file_Id     = 0;

GetOptions(
	"input_file=s"     => \$input_file,
	"output_file=s"    => \$output_file,
	"tool_name=s"      => \$tool_name,
	"tool_version=s"   => \$tool_version,
	"package_name=s"   => \$package_name,
	"uuid=s"           => \$uuid,
	"build_id=s"       => \$build_id,
	"cwd=s"            => \$cwd,
	"replace_dir=s"    => \$replace_dir,
	"input_file_arr=s" => \@input_file_arr
) or die("Error");

my $xmlWriterObj = new xmlWriterObject($output_file);
$xmlWriterObj->addStartTag( $tool_name, $tool_version, $uuid );

foreach my $input_file (@input_file_arr) {
	my $index_check_flag = 1;
	if ( !-e "$input_file/index.html" ) {
		$index_check_flag = 0;
	}
	opendir( DIR, $input_file );
	my @filelist =
	  grep { -f "$input_file/$_" && $_ ne "index.html" && $_ =~ m/\.html$/ }
	  readdir(DIR);

	close(DIR);
	my $file_count = scalar(@filelist);
	die
"ERROR!! Clang assessment run did not complete. index.html file is missing. \n"
	  if ( $file_count > 0 and $index_check_flag eq 0 );
	foreach my $file (@filelist) {
		my $in_file1 = new IO::File("<$input_file/$file");
		my @lines = grep /<!--.*BUG.*-->/, <$in_file1>;
		close($in_file1);
		my $in_file2 = new IO::File("<$input_file/$file");
		my @column = grep /class=\"rowname\".*Location.*line/, <$in_file2>;
		close($in_file2);

		my ( $BUGFILE, $BUGDESC, $BUGTYPE, $BUGCATEGORY, $BUGLINE, $BUGCOLUMN );
		foreach my $line (@lines) {
			if ( $line =~ m/.*BUGFILE/ ) {
				$BUGFILE =
				  Util::AdjustPath( $package_name, $cwd, bugLine($line) );
			}
			elsif ( $line =~ m/.*BUGDESC/ ) { $BUGDESC = bugLine($line); }
			elsif ( $line =~ m/.*BUGTYPE/ ) { $BUGTYPE = bugLine($line); }
			elsif ( $line =~ m/.*BUGCATEGORY/ ) {
				$BUGCATEGORY = bugLine($line);
			}
			elsif ( $line =~ m/.*BUGLINE/ ) { $BUGLINE = bugLine($line); }
		}
		foreach my $line (@column) {
			if ( $line =~ m/.*line.*column *\d.*/ ) {
				$BUGCOLUMN = &bugColumn($line);
			}
		}
		$bugId++;
		my $bugObject = new bugInstance($bugId);
		$bugObject->setBugMessage($BUGDESC);
		$bugObject->setBugCode($BUGTYPE);
		$bugObject->setBugGroup($BUGCATEGORY);
		$bugObject->setBugLocation(
			1,   "", $BUGFILE, $BUGLINE, $BUGLINE, $BUGCOLUMN,
			"0", "", "true",   "true"
		);
		$bugObject->setBugBuildId($build_id);
		$bugObject->setBugReportPath($input_file);
		$xmlWriterObj->writeBugObject($bugObject);
	}
}
$xmlWriterObj->writeSummary();
$xmlWriterObj->addEndTag();

sub bugLine
{
	my ($line) = @_;
	$line =~ s/(<!--)//;
	$line =~ s/-->//;
	$line =~ s/^ *//;
	my ( $val1, $val2 ) = split /\s *\s*/, $line, 2;
	$val2 =~ s/(\n|\r)$//;
	$val2 =~ s/ *$//;
	return ($val2);
}

sub bugColumn {
	my ($line) = @_;
	$line =~ s/^.*> *line *(\d)* *, *column *//;
	$line =~ s/<.*>$//;
	$line =~ s/(\n|\r)$//;
	$line =~ s/ *$//;
	return ($line);
}
1

