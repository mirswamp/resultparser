#!/usr/bin/perl
use strict;
use Getopt::Long;
use IO;
use XML::Twig;

my ($summary_file);

GetOptions(
		   "summary_file=s" => \$summary_file
		  ) or die("Error parsing command line arguments\n");
my $twig = XML::Twig->new();
$twig->parsefile($summary_file);


my $root=$twig->root;
my @uuids = $twig->get_xpath('/assessment-summary/assessment-summary-uuid');
my $uuid = $uuids[0]->text;

my @pkg_dirs = $twig->get_xpath('/assessment-summary/package-root-dir');
my $package_name = $pkg_dirs[0]->text;
$package_name =~ s/\/[^\/]*$//;

my @tool_names = $twig->get_xpath('/assessment-summary/tool-type');
my $tool_name = $tool_names[0]->text;

my @tool_versions = $twig->get_xpath('/assessment-summary/tool-version');
my $tool_version = $tool_versions[0]->text;
$tool_version =~ s/\n/ /g;

my @assessment_root_dir =  $twig->get_xpath('/assessment-summary/assessment-root-dir');
my $size =  @assessment_root_dir;
if ($size > 0)
{
    $package_name = $assessment_root_dir[0]->text;
} 



my @assessments = $twig->get_xpath('/assessment-summary/assessment-artifacts/assessment');

foreach my $i (@assessments)
{
		my @report=$i->get_xpath('report');
		my @target = $i->get_xpath('replace-path/target') if (defined $i->get_xpath('replace-path/target'));
		my @srcdir = $i->get_xpath('replace-path/srcdir') if (defined $i->get_xpath('replace-path/srcdir'));
		my $srcdir_path = " ";
		if (@srcdir)
		{
			$srcdir_path = $target[0]->text;	
			foreach my $elem (@srcdir)
			{
				$srcdir_path = $srcdir_path."::".$elem->text;
			}
		}
		my @build_art_id = $i->get_xpath('build-artifact-id');
		my $build_artifact_id = 0;
        my @cwd=$i->get_xpath('command/cwd');
		$build_artifact_id = $build_art_id[0]->text if defined ($build_art_id[0]);
		print $uuid,"~:~",$package_name,"~:~", $tool_name, "~:~" , $tool_version, "~:~" ,$build_artifact_id,"~:~",$report[0]->text,"~:~",$cwd[0]->text,"~:~",$srcdir_path,"\n" if defined($report[0]);
}
