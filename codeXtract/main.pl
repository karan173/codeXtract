#use strict;
#use warnings;
use LWP::UserAgent;
use Data::Dumper;
use JSON;
use Text::Balanced qw(extract_codeblock);
##Note dereferencing is equivalent to making a copy

#take input from user
print "Enter search keyword\n";
my $input = <STDIN>;
#print "Enter no. of search results(maximum = 50)\n";
#my $cnt = <STDIN>;

#access bing using bing search api
#https://skydrive.live.com/view.aspx?resid=9C9479871FBFA822!111&app=Word&wdo=2&authkey=!AGIw0_5GJbU2Wqo
##### constants #####
my $accnt_key = 'hO+FNgghOI5lq3i5TILA4TFVKHBdtLsXZBFj67UaeMw';
my $root      = 'https://api.datamarket.azure.com/Bing/Search/v1/Web';
my $query     = $input;
#my $count  = $cnt;         #maximum limit = 50
my $offset = 0;
my $format = 'JSON';    #ATOM==xml or use JSON
##### end_constants ####

my $url = $root . build_args( $query, 50, $offset, $format );

my $ua  = LWP::UserAgent->new;
my $req = HTTP::Request->new( GET => $url );
$req->authorization_basic( '', $accnt_key );
my $response = $ua->request($req);
if ( !$response->is_success ) {
	die 'Error connecting to BING API';
}
my $json = $response->content;

#print $json;
#print Dumper($response);
my $perl     = from_json($json);                 #reference to anon hash
my $next_url = $perl->{'d'}->{'__next'};         #dereferncing through pointers
my @results  = @{ $perl->{'d'}->{'results'} };

#html page
open( my $FH, '>', "output.html" ) or die 'Cannot open output file output.html';
print $FH <<ENDHTML;
<HTML>
<HEAD>
<TITLE>CodeXtract</TITLE>
</HEAD>
<BODY>
<H1 align = "center">RESULTS</H2>
ENDHTML
#open(TRIAL, "trial.html") or die "Trial.html can't be opened";
#my $webpage = '';
#while(<TRIAL>)
#{
#	$webpage = $webpage.$_;
#}
#codeXtract($webpage);
#exit(1);
foreach my $result (@results) {
	
	
	codeXtract($result);
}
print $FH <<ENDHTML;
</body>
</html>
ENDHTML
close($FH);

sub build_args
{
	my $q = '?Query=%27' . shift(@_) . '%27';    #always first
	my $c = '$top=' . shift(@_);
	my $o = '$skip=' . shift(@_);
	my $f = '$format=' . shift(@_);
	return join( '&', $q, $c, $o, $f );
}

##8 control structures ->
#	1.if(){} 	2.switch(){}  3.for(){}   4.while(){}   5.do{}while()  6.struct ..{}..;  7.class ..{}..;   8. int func(){}

#issues ->handling else ifs??  --> code outside{}

sub codeXtract 
{
	$result = shift(@_);
	my $url2        = $result->{'Url'};
	print $url2."\n";
	if($url2 =~ /\.(pdf|ppt|doc|docx)$/)
	{
		print "skipped\n";
		next;
	}
	my $disp_url    = $result->{'DisplayUrl'};
	my $description = $result->{'Description'};
	my $title       = $result->{'Title'};
	my $req2        = HTTP::Request->new( GET => $url2 );
	my $resp        = $ua->request($req2);
	if ( !$resp->is_success ) 
	{
		print( <STDERR>, 'Error connecting to url - ' . $url2 . "\n" );
	}
	my $page = $resp->content;
	
	
	my $first = 0;
	#reg1 ws (...  ...) ws {
	my $reg1 = '\s*?\(.*?\)\s*?';

	#func word[int double myStruct] ws funcname
	my $func = '(?:int|long|double|float|void|long\ long|long\ double)\s?\*?\s+?\w{1,30}';
	my $grp1 = '(?:if|else\ if|switch|for|while)'; 
	#?: is used to make it a non capturing group
	
	#class/struct keyword ws name ws {
	my $grp2  = '(?:class|struct|typedef\ struct)\s*?\w{1,30}\s*?';
	my $delim = '{}';
	#else with 0 or more whitespace different group since has no (...)
	my $grp3 = 'else\s*?';
	#remove javascript to avoid conflicts
	#g = global		i=ignore case	s=. also includes \n
	while ( $page =~ s/<script.*?>.*?<\/script>//gsi ) { }
	
	pos($page) = 0;
	my $regex1 = $grp1.$reg1;
	my $regex2 = $grp2;
	my $regex3 = $func.$reg1;
	my $regex4 = $grp3;
	
	my $regex = join('|', $regex1, $regex2, $regex3, $regex4);
	while ($page =~ /(($regex)(?=\{))/)  
	{
		if($first == 0)
		{
			$first = 1;
			print( $FH '<font size = 6><b><a href = "' . $url2 . '">' . $title . '</a></font></b><br>' );
			print( $FH '<i>' . $disp_url . '</i><br>' );
			print( $FH $description . '</p>' );
			
		}	
		$page = $';
		my $code = $1.extract_codeblock($page, $delim );	
		print( $FH '<pre>'.$code.'<br></pre>' );
	}
	if($first)
	{
		print($FH '<br><br><hr size = 4 color = "red">');	
	}
}


#ISSUES
#1) Else will never be done.
#2) Comments surrounding code
#3) do while
