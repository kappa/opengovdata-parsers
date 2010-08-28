#! /usr/bin/perl
use strict;
use warnings;

use Encode;
use Web::Scraper;
use Text::CSV_XS;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::Form;
use Encode;

my $DEBUG = 0;

sub get_page {
    my $req = shift;
    my $delay = 1;
    our $ua;
    unless (defined $ua) {
        $ua = LWP::UserAgent->new();
        $ua->show_progress(1) if $DEBUG;
    }

    my ($resp, $data);
    until (($resp = $ua->request($req))->is_success
        && ($data = decode('cp1251', $resp->content)) !~ /возникли технические неполадки/) {

        warn "error fetching [@{[$req->uri]}], delaying for $delay\n";
        sleep($delay *= 2);
    }

    return $data;
}

my $url = 'http://rnp.fas.gov.ru/';

my $unfair_list_scraper = scraper {
    # <thead> is skipped via XPath children axis magic
    process '//table[@class="data"]/tr[position() < last()]/td[1]/input[1]', 'ids[]' => sub { $_[0]->attr('onclick') =~ /id=([^"]+)"/ ? $1 : undef },
};

my $unfair_scraper = scraper {
    process '//table[@class="form"]/tr/td[2]', 'values[]' => 'TEXT',
};

my $unfair_headers_scraper = scraper {
    process '//table[@class="form"]/tr/td[1][not(@colspan="2")]', 'values[]' => 'TEXT',
};

my @ids = ();
my $page = get_page(GET $url);
my ($total) = ($page =~ m{<span id="ctl00_phWorkZone_rnpList_datapgr_lblRecNumAll">(\d+)</span>});
my $from = 0;
my $form = HTML::Form->parse($page, $url);

$|++;
while ($total - $from > 500) {
    @ids and $form->param('ctl00$phWorkZone$rnpList$datapgr$tbRecNumFrom', $from = scalar @ids + 1);
    $form->param('ctl00$phWorkZone$rnpList$datapgr$ddlVolume', 500);

    $page = get_page($form->click);
    push @ids, @{$unfair_list_scraper->scrape($page)->{ids}};

    $form = HTML::Form->parse($page, $url);
    print ".";
}

print "we have " . scalar @ids . " entries\n";

my $csv = Text::CSV_XS->new({ binary => 1 });
open my $file, '>:utf8', 'rnpfas_output.csv';

my $have_headers;

for my $id (@ids) {
    unless ($have_headers) {
        my @headers = @{$unfair_headers_scraper->scrape(get_page(GET "${url}RNPCard.aspx?id=$id"))->{values}};
        $csv->print($file, \@headers);
        print $file "\n";
        $have_headers++;
    }

    my @fields = @{$unfair_scraper->scrape(get_page(GET "${url}RNPCard.aspx?id=$id"))->{values}};
    $csv->print($file, \@fields);
    print $file "\n";
    print ".";
}
print "\n";

close $file;
