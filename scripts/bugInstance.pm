#!/usr/bin/perl
package bugInstance;

#use strict;

use bugLocation;
use bugMethod;

sub new
{
		my $class=shift;
		my $self= {
						_bugId=>shift
				  };
        #my %_bugLocationHash;
        bless $self,$class;
        return $self;
}

sub setBugMessage
{
		my ($self,$bugMessage)=@_;
		$self->{_bugMessage}=$bugMessage if defined ($bugMessage);
        return $self->{_bugMessage};
}


sub setBugLocation_old
{
	my ($self,$bugLocation)=@_;
	$self->{_bugLocation}=$bugLocation if defined ($bugLocation);
        return $self->{_bugLocation};
}

sub setBugLocation
{
		my ($self,$bugLocationId,$bugClassname,$SourceFile,$startLineNo,$endLineNo,$beginColumn,$endColumn,$bugMessage,$primary,$resolvedFlag)=@_;
		my $locationObject;
		if ( $resolvedFlag eq 'true' or (defined ($startLineNo) && $startLineNo ne ""))
		{
				$locationObject = new bugLocation($bugLocationId,$bugClassname,$SourceFile,$startLineNo,$endLineNo,$beginColumn,$endColumn,$bugMessage,$primary);
		}
		else
		{       
				$locationObject = new bugLocation($bugLocationId,$bugClassname,$self->{_classSourceFile},$self->{_classStartLine},$self->{_classEndLine},$beginColumn,$endColumn,$self->{_classMessage},$primary);
		}		
		$self->{_bugLocationHash}{$bugLocationId}=$locationObject;
}

sub setBugColumn
{
	my ($self, $start_column, $end_column, $bugLocationId) = @_;
	my $locationObject = $self->{_bugLocationHash}{$bugLocationId}->setBugColumn($start_column, $end_column);
}

sub setBugMethod
{
		my ($self,$methodId,$className,$methodName,$primary)=@_;
        my $methodObject = new bugMethod($methodId,$methodName,$className,$primary);
        $self->{_bugMethodHash}{$methodId}=$methodObject;
        #print $self->{_bugMethodHash}{$methodId}, "\n";
}

sub setSourceFile
{
        my ($self,$sourceFile)=@_;
        $self->{_sourceFile}=$sourceFile if defined ($sourceFile);
        return $self->{_sourceFile};
}

sub setClassName
{
        my ($self,$className)=@_;
        $self->{_className}=$className if defined ($className);
        return $self->{_className};
}

sub setClassAttribs
{
		my($self,$classname,$sourcefile,$start,$end,$classMessage) = @_;
		#print $sourcefile, "\n";
        $self->{_classSourceFile}=$sourcefile if defined ($sourcefile);
        $self->{_className}=$classname if defined ($classname);
        $self->{_classStartLine}=$start if defined ($start);
        $self->{_classEndLine}=$end if defined ($end);
		$self->{_classMessage}=$classMessage if defined ($classMessage);
}

sub setBugSeverity
{
        my ($self,$bugSeverity)=@_;
        $self->{_bugSeverity}=$bugSeverity if defined ($bugSeverity);
        return $self->{_bugSeverity};
}

sub setBugRank
{
        my ($self,$bugRank)=@_;
        $self->{_bugRank}=$bugRank if defined ($bugRank);
        return $self->{_bugRank};
}

sub setCweId
{
        my ($self,$cweId)=@_;
        push(@{$self->{_cweId}},$cweId) if defined ($cweId);
        return $self->{_cweId};
}

sub setBugGroup
{
       my($self,$group)=@_;
       $self->{_bugGroup}=$group if defined ($group);
       return $self->{_bugGroup};
}

sub getBugGroup
{
		my ($self)=@_;
		return $self->{_bugGroup} if defined ($self->{_bugGroup});
}

sub setBugCode
{
       my($self,$code)=@_;
       $self->{_bugCode}=$code if defined ($code);
       return $self->{_bugCode};
}

sub getBugCode
{
		my($self)=@_;
		return $self->{_bugCode} if defined ($self->{_bugCode});
}

sub setBugSuggestion
{
       my($self,$suggestion)=@_;
       $self->{_bugSuggestion}=$suggestion if defined ($suggestion);
       return $self->{_bugSuggestion};
}

sub setBugPath
{
        my ($self,$bugPath)=@_;
        $self->{_bugPath}=$bugPath if defined ($bugPath);
        return $self->{_bugPath};
}



sub setBugLine
{
        my ($self,$bugLineStart,$bugLineEnd)=@_;
        $self->{_bugLineStart}=$bugLineStart if defined ($bugLineStart);
        $self->{_bugLineEnd}=$bugLineEnd if defined ($bugLineEnd);
}

sub setBugReportPath
{
		my ($self, $reportPath) = @_;
		$self->{_reportPath} = $reportPath if defined ($reportPath);
		return $self->{_reportPath};
}

sub getBugReportPath
{
		my ($self)=@_;
		return $self->{_reportPath} if defined ($self->{_reportPath});	
}

sub setBugBuildId
{
		my ($self, $buildId) = @_;
		$self->{_buildId} = $buildId if defined ($buildId);
		return $self->{_buildId};
}

sub getBugBuildId
{
		my ($self)=@_;
		return $self->{_buildId} if defined ($self->{_buildId});		
}

sub setURLText
{
        my ($self, $url_txt)=@_;
        $self->{_url}=$url_txt if defined ($url_txt);
}

sub getURLText
{
	my ($self) = @_;
	return $self->{_url} if defined ($self->{_url});
}

sub setBugPackage
{
        my ($self,$bugPackage)=@_;
        $self->{_package}=$bugPackage if defined ($bugPackage);
        return $self->{_package};
}

sub getBugPackage
{
	my ($self) = @_;
	return $self->{_package} if defined ($self->{_package});
}

sub setBugPathLength
{
        my ($self,$bugPathLength)=@_;
        $self->{_bugPathLength}=$bugPathLength if defined ($bugPathLength);
        return $self->{_bugPathLength};
}

sub getBugPathLength
{
    my ($self) = @_;
    return $self->{_bugPathLength} if defined ($self->{_bugPathLength});
}

sub setCWEInfo
{
    my ($self, $info) = @_;
    $self->{_cwe}=$info if defined ($info);
    return $self->{_cwe};
}

sub getCWEInfo
{
    my ($self) = @_;
    return $self->{_cwe} if defined ($self->{_cwe});
}

sub setCWEArray
{
    my $self = shift; 
    if (length @_!=0){
    	$self->{_cwe_array} = [];
    	@{$self->{_cwe_array}} = @_;
    }
    return @{$self->{_cwe_array}};
}

sub getCWEArray
{
    my ($self) = @_;
    return @{$self->{_cwe_array}} if defined ($self->{_cwe_array});
}

sub setBugPosition
{
    my ($self, $info) = @_;
    $self->{_position}=$info if defined ($info);
    return $self->{_position};
}

sub getBugPosition
{
    my ($self) = @_;
    return $self->{_position} if defined ($self->{_position});
}

sub setBugWarningCode
{
    my ($self, $info) = @_;
    $self->{_warningCode}=$info if defined ($info);
    return $self->{_warningCode};
}

sub getBugWarningCode
{
    my ($self) = @_;
    return $self->{_warningCode} if defined ($self->{_warningCode});
}

sub setBugToolSpecificCode
{
    my ($self, $info) = @_;
    $self->{_toolSpecificCode}=$info if defined ($info);
    return $self->{_toolSpecificCode};
}

sub getBugToolSpecificCode
{
    my ($self) = @_;
    return $self->{_toolSpecificCode} if defined ($self->{_toolSpecificCode});
}

sub setBugLongMessage
{
        my ($self, $info)=@_;
        $self->{_long_message}=$info if defined ($info);
}

sub getBugLongMessage
{
    my ($self) = @_;
    return $self->{_long_message} if defined ($self->{_long_message});
}

sub setBugShortMessage
{
	my ( $self, $info ) = @_;
	$self->{_short_message} = $info if defined ($info);
}

sub getBugShortMessage
{
	my ($self) = @_;
	return $self->{_short_message} if defined ($self->{_short_message});
}

sub setBugInconclusive
{
        my ($self, $info) = @_;
        $self->{_inconclusive} = $info if defined ($info);
        return $self->{_inconclusive};
}

sub getBugInconclusive
{
        my ($self)=@_;
        return $self->{_inconclusive} if defined ($self->{_inconclusive});        
}

sub printBugId
{
		my($self)=@_;
		return $self->{_bugId} if defined ($self->{_bugId});
}

sub printBugInstance
{
      my ($self)=@_;
      my $locn;
      foreach $locn (keys %{$self->{_bugLocationHash}})
      {
          print "Location : ";
          print $self->{_bugLocationHash}{$locn}->printBugLocation(), "\n";
      }
      my $method;
      #print $self->{_bugMethodHash}{1}->printBugMethod(),"\n";
      foreach $method (keys %{$self->{_bugMethodHash}})
      {
          print "Method : ";
          print $self->{_bugMethodHash}{$method}->printBugMethod(), "\n";
      }
      return $self->{_bugId} . " :: ". $self->{_bugMessage} . " :: " . $self->{_bugSeverity} . " :: " . $self->{_bugRank} . " :: " . $self->{_bugPath} . " :: " . $self->{_cweId} . " :: " . $self->{_bugSuggestion} . " :: " . $self->{_bugGroup};
}

sub printXML_sate
{
		my($self,$writer)=@_;
#  if(keys %{$self->{_bugLocationHash}} > 0)
#  {
        $writer->startTag('weakness', 'id'=>$self->{_bugId});
        if (defined $self->{_cweId})
        {
          $writer->startTag('name', 'cweid'=>$self->{_cweId});
        } else {
          $writer->startTag('name');
		}
        $writer->characters($self->{_bugGroup});
        $writer->endTag();  #name end tag
        my $locn;
        foreach $locn (sort{$a <=> $b} keys %{$self->{_bugLocationHash}})
        {
#                print $self->{_classStartLine},$self->{_classEndLine},"\n";
				$self->{_bugLocationHash}{$locn}->printXML($writer,$self->{_classStartLine},$self->{_classEndLine});
        }
        $writer->emptyTag('grade', 'severity' => $self->{_bugSeverity});
#        $writer->endTag(); #grade end tag
        $writer->startTag('output');
        $writer->startTag('textoutput');
        $writer->characters($self->{_bugMessage});
        $writer->endTag(); #textoutput end tag
        $writer->endTag(); #output end tag
        $writer->endTag(); #weakness end tag
#   }
}

sub printXML
{
	my($self,$writer)=@_;
        $writer->startTag('BugInstance', 'id'=>$self->{_bugId});
        
        if (defined $self->{_className})
		{
			$writer->startTag('ClassName');
			$writer->characters($self->{_className});
			$writer->endTag();
		}
          
        $writer->startTag('Methods');
		my $method;
		foreach $method (sort{$a <=> $b} keys %{$self->{_bugMethodHash}})
		{
			$self->{_bugMethodHash}{$method}->printXML($writer);
		}
        $writer->endTag();
			  
        $writer->startTag('BugLocations');
        my $locn;
        foreach $locn (sort{$a <=> $b} keys %{$self->{_bugLocationHash}})
        {
			$self->{_bugLocationHash}{$locn}->printXML($writer,$self->{_classStartLine},$self->{_classEndLine});
        }
        $writer->endTag();
        if (defined $self->{_cweId})
        {
		foreach my $cwe (@{$self->{_cweId}})
		{
			$writer->startTag('CweId');
			$writer->characters($cwe);
			$writer->endTag();
		}
	}
		
        if (defined $self->{_bugGroup})
        {
          $writer->startTag('BugGroup');
		  $writer->characters($self->{_bugGroup});
		  $writer->endTag();
		}
        
        if (defined $self->{_bugCode})
        {
          $writer->startTag('BugCode');
          $writer->characters($self->{_bugCode});
		  $writer->endTag();
		}

		if (defined $self->{_bugRank})
        {
          $writer->startTag('BugRank');
          $writer->characters($self->{_bugRank});
		  $writer->endTag();
		}

		if (defined $self->{_bugSeverity})
        {
          $writer->startTag('BugSeverity');
          $writer->characters($self->{_bugSeverity});
		  $writer->endTag();
		}

		
		if (defined $self->{_bugMessage})
        {
          $writer->startTag('BugMessage');
          $writer->characters($self->{_bugMessage});
		  $writer->endTag();
		}

		if (defined $self->{_bugSuggestion})
        	{
          	  $writer->startTag('ResolutionSuggestion');
          	  $writer->characters($self->{_bugSuggestion});
		  $writer->endTag();
		}

		$writer->startTag('BugTrace');
		if (defined $self->{_buildId})
		{
			$writer->startTag('BuildId');
			$writer->characters($self->{_buildId});
			$writer->endTag();
		}
	
		if (defined $self->{_reportPath})
		{
			$writer->startTag('AssessmentReportFile');
			$writer->characters($self->{_reportPath});
			$writer->endTag();
		}
		        
		if (defined $self->{_bugPath})
		{
				$writer->startTag('InstanceLocation');
				$writer->startTag('Xpath');
				$writer->characters($self->{_bugPath});
				$writer->endTag();
				$writer->endTag();
		}
        if (defined $self->{_bugLineStart} and defined $self->{_bugLineEnd})
		{
				$writer->startTag('InstanceLocation');
				$writer->startTag('LineNum');
				$writer->startTag('Start');
				$writer->characters($self->{_bugLineStart});
				$writer->endTag();
				$writer->startTag('End');
				$writer->characters($self->{_bugLineEnd});
				$writer->endTag();
				$writer->endTag();
				$writer->endTag();
		}
		$writer->endTag();
        
		
        $writer->endTag(); 
}

1;
