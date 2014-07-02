use strict;
use warnings;
use RDF::Query::Client;
use LWP::Simple;

my $namedgSPARQL = 'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

SELECT distinct ?graph 

WHERE {
  graph ?graph {?a ?b ?c}

}';


#http://bio2rdf.org/bio2rdf.dataset:bio2rdf-affymetrix-20131220
#http://bio2rdf.org/bio2rdf.dataset:bio2rdf-hgnc-20131212
#my $RAWsubjecttypesSPARQL = 'SELECT distinct(?stype)
#FROM <NAMED_GRAPH_HERE>
#WHERE {
# ?s a ?stype .
# FILTER (!regex(?stype, "owl#")) .
# FILTER (!regex(?stype, "dc/terms/Dataset")) .
# FILTER (!regex(?stype, "w3.org")) .
# FILTER (!regex(?stype, ":Resource")) 
#}';

my $RAWsubjecttypesSPARQL = 'SELECT distinct(?stype)
FROM <NAMED_GRAPH_HERE>
WHERE {
 ?s a ?stype .
}
';



#my $RAWpredicatetypesSPARQL = 'SELECT distinct(?p)
#FROM <NAMED_GRAPH_HERE>
#WHERE {
# ?s a <SUBJECT_TYPE_HERE> .
#?s ?p ?o .   
#FILTER (!regex(?p, "w3.org"))
#FILTER (?p != <http://rdfs.org/ns/void#inDataset>)
#}
#';

my $RAWpredicatetypesSPARQL = 'SELECT distinct(?p)
FROM <NAMED_GRAPH_HERE>
WHERE {
 ?s a <SUBJECT_TYPE_HERE> .
?s ?p ?o .   
}
';


#my $RAWobjecttypesSPARQL = 'SELECT distinct(?otype)
#FROM <NAMED_GRAPH_HERE>
#WHERE {
# ?s a <SUBJECT_TYPE_HERE> .
#?s <PREDICATE_TYPE_HERE> ?o .   
#?o a ?otype
# FILTER (!regex(?otype, "owl#")) .
# FILTER (!regex(?stype, "w3.org")) .
#
#}';

my $RAWobjecttypesSPARQL = 'SELECT distinct(?otype)
FROM <NAMED_GRAPH_HERE>
WHERE {
 ?s a <SUBJECT_TYPE_HERE> .
?s <PREDICATE_TYPE_HERE> ?o .   
?o a ?otype
}';


#my $RAWspecificobjecttypesSPARQL = 'SELECT distinct(?o)
#WHERE { 
#
#    SERVICE <LOCALENDPOINT>  
#         
#      {SELECT ?s { ?s a <OTYPE> } LIMIT 200 }
#  
#
#   SERVICE <REMOTEENDPOINT>
#        
#       { ?s a ?o .
#         FILTER (?o != <OTYPE>)
#         FILTER (!regex(?o, "w3.org" ))
#       }
#  
#}
#';

my $RAWspecificobjecttypesSPARQL = 'SELECT distinct(?o)
WHERE { 

    SERVICE <LOCALENDPOINT>  
         
      {SELECT ?s { ?s a <OTYPE> } LIMIT 200 }
  

   SERVICE <REMOTEENDPOINT>
        
       { ?s a ?o .
       }
  
}
';

        

my $RAWobjectdatatypesSPARQL = 'SELECT distinct(datatype(?o)) as ?datatype
FROM <NAMED_GRAPH_HERE>
WHERE {
 ?s a <SUBJECT_TYPE_HERE> .
?s <PREDICATE_TYPE_HERE> ?o .   
 FILTER isLiteral(?o)
}
group by ?o
';



my %dataset_endpoints;

open(OUT, ">endpoint_datatypes.list") || die "can't open output file for writing $!\n";


#my $bio2rdfendpoints = get('http://s4.semanticscience.org/bio2rdf/3/');
my $bio2rdfendpoints = get('http://openlifedata.org/');
$bio2rdfendpoints =~ s/content\-type.*//gs;
my @namespaces = ($bio2rdfendpoints =~ m'<td>([a-z]+)</td>'gs);
foreach my $namespace(@namespaces){
        next if $namespace eq "ndc";
        next if $namespace eq "lsr";
        next if $namespace eq "bioportal";
        next if $namespace eq "clinicaltrials";
        
        next if $namespace eq "mesh";
        next if $namespace eq "pharmgkb";

        next if $namespace eq "drugbank";  # wait until Michel finishes reparsing the data

        
        ##### my $page = get("http://s4.semanticscience.org/bio2rdf/3/$namespace.html");
        ##### $page =~ m|(http://s4.semanticscience.org:14\d\d\d/sparql)|s;
        my $endpoint = "http://openlifedata.org/$namespace/sparql/";
        die "not found $namespace\n\n" unless $endpoint;

        my $graphquery = RDF::Query::Client->new($namedgSPARQL);
        my $iterator = $graphquery->execute($endpoint,  {Parameters => {timeout => 380000, format => 'application/sparql-results+json'}});
        next unless $iterator;  # in case endpoint is down
        my $namedgraph;
        my $highest=0;
        while (my $row = $iterator->next){
                next if $row->{graph}->[1] =~ /statistics/;
                next unless ($row->{graph}->[1] =~ /openlifedata\.dataset/);
                $namedgraph = $row->{graph}->[1];
                #### my $this = $1;
                ##### ($namedgraph = $row->{graph}->[1]) if ($this > $highest);
                print "$namespace, $namedgraph, $endpoint\n";
        }

        $dataset_endpoints{$namespace} = [$endpoint, $namedgraph];
        
}
#die;

#while (($bio2rdfendpoints =~ /\[(\w+)\].*?(http:\/\/s4.semanticscience.org:\d+\/sparql)/sg) ) {
#        my ($namespace, $endpoint) = ($1, $2);
#        next if $namespace eq "ndc";
#        next if $namespace eq "lsr";
#        next if $namespace eq "bioportal";
#        
#        my $graphquery = RDF::Query::Client->new($namedgSPARQL);
#        my $iterator = $graphquery->execute($endpoint,  {Parameters => {timeout => 380000, format => 'application/sparql-results+json'}});
#        next unless $iterator;  # in case endpoint is down
#        my $namedgraph;
#        my $highest=0;
#        while (my $row = $iterator->next){
#                next unless ($row->{graph}->[1] =~ /bio2rdf.dataset.*?(\d+)$/);
#                my $this = $1;
#                ($namedgraph = $row->{graph}->[1]) if ($this > $highest);
#                print "$namespace, $namedgraph, $endpoint\n";
#        }
#
#        $dataset_endpoints{$namespace} = [$endpoint, $namedgraph];
#}

foreach my $namespace(sort(keys %dataset_endpoints)){
        my ($endpoint, $namedgraph) = @{$dataset_endpoints{$namespace}};
        print "\n\n\nMoving On to $namespace\n\n\n";
        my $subjecttypesSPARQL = $RAWsubjecttypesSPARQL;
        $subjecttypesSPARQL =~ s/NAMED_GRAPH_HERE/$namedgraph/;
        
        my $typequery = RDF::Query::Client->new($subjecttypesSPARQL); # query for all output types of the form xxx_vocabulary:Resource
        my $siterator = $typequery->execute($endpoint,  {Parameters => {timeout => 380000, format => 'application/sparql-results+json'}});
        unless ($siterator){print "          ---------no subject types found -----------\n"; next;}

        while (my $row = $siterator->next){
                my $stype = $row->{stype}->[1];
#FILTER (!regex(?stype, "owl#")) .
#FILTER (!regex(?stype, "dc/terms/Dataset")) .
#FILTER (!regex(?stype, "w3.org")) .
#FILTER (!regex(?stype, ":Resource")) 
                next if $stype =~ 'owl#';
                next if $stype =~ 'dc/terms/Dataset';
                next if $stype =~ 'w3.org';
                next if $stype =~ ':Resource';
                
                my $base_input_type = "";
                print STDERR "\n\nno match $stype\n\n" unless $stype =~ m|(http://\S+\..*):\S+$|;  #(something-something.something:something:something):Geneotype
                $base_input_type = "$1:Resource" if $1;  # because Bio2RDF doesn't know what type something is, it always outputs :Resource, which means we need services that will consume these weakly-typed data
                
                my $predicatetypesSPARQL = $RAWpredicatetypesSPARQL;
                $predicatetypesSPARQL =~ s/NAMED_GRAPH_HERE/$namedgraph/;
                $predicatetypesSPARQL =~ s/SUBJECT_TYPE_HERE/$stype/;
                
                my $ptypequery = RDF::Query::Client->new($predicatetypesSPARQL); # query for all output types of the form xxx_vocabulary:Resource
                my $piterator = $ptypequery->execute($endpoint,  {Parameters => {timeout => 380000, format => 'application/sparql-results+json'}});
                unless ($piterator){print "          ---------no predicate types found for $stype -----------\n"; next;}
        
                while (my $row = $piterator->next){
                        my $ptype = $row->{p}->[1];
#FILTER (!regex(?p, "w3.org"))
#FILTER (?p != <http://rdfs.org/ns/void#inDataset>)

                        next if $ptype =~ 'w3.org';
                        next if $ptype =~ 'void#inDataset';
                        
                        my $objecttypesSPARQL = $RAWobjecttypesSPARQL;
                        $objecttypesSPARQL =~ s/NAMED_GRAPH_HERE/$namedgraph/;
                        $objecttypesSPARQL =~ s/SUBJECT_TYPE_HERE/$stype/;
                        $objecttypesSPARQL =~ s/PREDICATE_TYPE_HERE/$ptype/;
                        
                        my $otypequery = RDF::Query::Client->new($objecttypesSPARQL); # query for all output types of the form xxx_vocabulary:Resource
                        my $oiterator = $otypequery->execute($endpoint,  {Parameters => {timeout => 380000, format => 'application/sparql-results+json'}});
                        #unless ($oiterator){print "          ---------no object types found for $stype $ptype -----------\n";}
                        my $FLAG = 0;   # this is a flag that is up when it is a resource object, and down when it is a datatype object
                        if ($oiterator){
                                while (my $row = $oiterator->next){
                                        $FLAG=1;   # an object type was found - set flag so that we don't do the datatype query!
                                        my $otype = $row->{otype}->[1];
                                        
                                        next if $otype =~ 'owl#';
                                        next if $otype =~ 'w3.org';
#FILTER (!regex(?otype, "owl#")) .
#FILTER (!regex(?stype, "w3.org")) .


                                        unless ($otype =~ /:Resource/){  # it is already a specific type
                                                print "           Found Triple Pattern:     $stype $ptype $otype\n";
                                                print OUT "$namespace\t$stype\t$ptype\t$otype\n";
                                                print OUT "$namespace\t$base_input_type\t$ptype\t$otype\n" if $base_input_type;
                                        } else {  # this is one of those generic bio2rdf REsource types, so try to figure out a more specific type with a federated query
#                                                die "can't match $otype to determine Bio2RDF namespace" unless ($otype =~ m|bio2rdf\.org/([^_]+)_|);  # match everything after the / and up to the next '_'
                                                die "can't match $otype to determine Bio2RDF namespace" unless ($otype =~ m|openlifedata\.org/([^_]+)_|);  # match everything after the / and up to the next '_'
                                                my $remotenamespace = $1;
                                                print "checking $remotenamespace\n";   # is this a namespace that we have heard of before?
                
                                                unless ($dataset_endpoints{$remotenamespace}){  # if the remote dataset isn't alive, then just print the triple pattern in its generic form
                                                        print "$remotenamespace not found in our index, writing generic triple pattern and moving on...\n" ;
                                                        print "           Found Triple Pattern:     $stype $ptype $otype\n";
                                                        print OUT "$namespace\t$stype\t$ptype\t$otype\n";
                                                        print OUT "$namespace\t$base_input_type\t$ptype\t$otype\n" if $base_input_type;
                                                        next;  # move on to the next ojbect type
                                                }
                                                
                                                # if we get here, then we have a :Resource that is pointing to a remote dataset that is alive.  So do the federated query
                                                my ($remoteendpoint, $namedgraph) = @{$dataset_endpoints{$remotenamespace}};
                                                die "can't find remote endpoint for $remotenamespace" unless $remoteendpoint;  # this should never happen, but just in case
                                                my @specificotypes = &getSpecificObjectTypes($otype, $endpoint, $remoteendpoint);  # this subroutine does the federated query
                                                unless ($specificotypes[0]){ # if there was no more specific type found, then the list returned from the subroutine is empty, so just write the generic type
                                                        unless ($namespace eq $remotenamespace){                                                
                                                                open(FAILED, ">>NoSpecificTypeFound.txt") || die "can't open the file for Michel of non-specific types $!\n";
                                                                print FAILED "data in $namespace exists in $remotenamespace but has no more specific type than $otype\n\n";
                                                                close FAILED;
                                                        }
        
                                                        print "           Failed to find anything more specific than $otype\n";
                                                        print "           Found Triple Pattern:     $stype $ptype $otype\n";
                                                        print OUT "$namespace\t$stype\t$ptype\t$otype\n";
                                                        print OUT "$namespace\t$base_input_type\t$ptype\t$otype\n" if $base_input_type;
                                                        
                                                } else {
                                                        foreach my $specificotype(@specificotypes){
                                                                print "           Found Triple Pattern:     $stype $ptype $specificotype\n";
                                                                print OUT "$namespace\t$stype\t$ptype\t$specificotype\n";
                                                                print OUT "$namespace\t$base_input_type\t$ptype\t$specificotype\n" if $base_input_type;
                                                        }                                                
                                                }                                       
                                        }
                                }
                                
                        }
                        next if ($FLAG);  # if the flag is up, then don't test the datatype                        

                        my $datatypesSPARQL = $RAWobjectdatatypesSPARQL;
                        $datatypesSPARQL =~ s/NAMED_GRAPH_HERE/$namedgraph/;
                        $datatypesSPARQL =~ s/SUBJECT_TYPE_HERE/$stype/;
                        $datatypesSPARQL =~ s/PREDICATE_TYPE_HERE/$ptype/;
                        
                        my $diterator;
                        #my $dtypequery = RDF::Query::Client->new($datatypesSPARQL); # query for all output types of the form xxx_vocabulary:Resource
                        #$dtypequery->useragent->default_headers->header(Accept => "text/plain");
                        #$diterator = $dtypequery->execute($endpoint,  {Parameters => {timeout => 380000, format => 'text/plain'}});
                        unless ($diterator){print "          ---------no data types found for $stype $ptype defaulting to STRING-----------\n";
                                my $otype = "http://www.w3.org/2001/XMLSchema#string";
                                print "           Found Triple Pattern:     $stype $ptype $otype\n";
                                print OUT "$namespace\t$stype\t$ptype\t$otype\n";
                                print OUT "$namespace\t$base_input_type\t$ptype\t$otype\n" if $base_input_type;
                                next;
                        }
                        
                        #while (my $row = $diterator->next){
                        #        my $otype = $row->{datatype}->[0];  # oddly, if you don't group-by it is ->[1], but the query often crashes!
                        #        $otype = $row->{datatype}->[1] unless $otype;  # this is a bug in virtuoso!
                        #        unless ($otype){
                        #                print "\n\nwtf?   no result in a returned result???  \n\n";
                        #                next;
                        #        }
                        #        print "           Found Triple Pattern:     $stype $ptype $otype\n";
                        #        print OUT "$namespace\t$stype\t$ptype\t$otype\n";
                        #        print OUT "$namespace\t$base_input_type\t$ptype\t$otype\n" if $base_input_type;
                        #}
                }
        }
        # exit 1;
}
exit 1;


sub getSpecificObjectTypes {  # there should never be more than one specific type, given the query, but... lets assume it returns a list just in case
        my ($otype, $endpoint, $remoteendpoint) = @_;
        my $sparql = $RAWspecificobjecttypesSPARQL;
        $sparql =~ s/LOCALENDPOINT/$endpoint/g;
        $sparql =~ s/OTYPE/$otype/g;
        $sparql =~ s/REMOTEENDPOINT/$remoteendpoint/g;
        print "executing query $sparql\n\n";
        my $otypequery = RDF::Query::Client->new($sparql); # query for all output types of the form xxx_vocabulary:Resource
        my $oiterator = $otypequery->execute($endpoint,  {Parameters => {timeout => 380000, format => 'application/sparql-results+json'}});
        unless ($oiterator){
                print "          ---------no SPECIFIC object types found for $otype -----------\n";
                return undef;
        }
        my @otypes;
        while (my $row = $oiterator->next){
                my $objecttype = $row->{o}->[1];
                next if $objecttype =~ /$otype/;
                next if $objecttype =~ 'w3.org';
#FILTER (?o != <OTYPE>)
#FILTER (!regex(?o, "w3.org" ))

                push @otypes, $objecttype;
        }
        return @otypes;              
}