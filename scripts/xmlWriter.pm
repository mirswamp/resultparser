#!/usr/bin/perl -w

use strict;


sub XMLPrinter
{
    my $output_file_name = shift;
    my $output = new IO::File(">$output_file_name");

    ## ENCODING generates UTF-8 as outupt instead of ISO-8859 (US-ASCII)
    ## Yes, it is lower-case, and the following xmlDecl is upper case.
    my $writer = new XML::Writer(OUTPUT => $output, DATA_MODE => 'true',
	    DATA_INDENT => 2, ENCODING => 'utf-8');

    ## This adds an XML Declaration to say that the output is UTF-8
    ## compliant.    It's a different thing than generating UTF-8.
    ## W/out this there is no XML declaration in the output document.
    $writer->xmlDecl('UTF-8');

    $writer->startTag('AnalyzerReport', 'tool_name' => "$toolName",
	    'tool_version' => "$toolVersion", 'uuid'=> "$uuid");

    my $object;
    my $byte_count = 0;
    my $initial_byte_count = 0;
    my $final_byte_count = tell($output);
    foreach $object (sort{$a <=> $b} keys(%bugInstanceHash))  {
	$initial_byte_count = $final_byte_count;
	$bugInstanceHash{$object}->printXML($writer);
	$final_byte_count = tell($output);
	$byte_count = $final_byte_count - $initial_byte_count;
	my $code = $bugInstanceHash{$object}->getBugCode(); 
	my $group = $bugInstanceHash{$object}->getBugGroup();
	my $tag;
	if ($code ne "")  {
	    $tag = $code;
	}  else  {
	    $tag = "undefined";
	}

	if ($group ne "")  {
	    $tag = $tag."~#~".$group;
	}  else  {
	    $tag = $tag."~#~"."undefined";
	}

	if (!(defined $tag))  {
	    die ("bug group and bug code doesnot exist for grouping the bugs");
	}  else  {
	    if (exists $count_hash{$tag})  {
		$count_hash{$tag}++;
	    }  else  {
		$count_hash{$tag} = 1; 
	    }

	    if (exists $byteCountHash{$tag})  {
		$byteCountHash{$tag} = $byteCountHash{$tag} + $byte_count;
	    }  else  {
		$byteCountHash{$tag} = $byte_count;
	    }
	}
    }

    $writer->startTag('BugSummary') ;
    foreach my $object (keys(%count_hash))  {
	my ($code, $group) = split ('~#~', $object);
	$writer->emptyTag('BugCategory', 'group' => "$group", 'code' => "$code",
		'count' => $count_hash{$object}, 'bytes'=> $byteCountHash{$object});
    }

    $writer->endTag();
    $writer->endTag();
    $writer->end();
    $output->close();
}
