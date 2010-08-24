#! /usr/bin/perl
use uni::perl;

use URI;
use Web::Scraper;
use Data::Dump;
use Text::CSV_XS;
use autodie;

my $url = 'http://rnp.fas.gov.ru/';

my $malafides = scraper {
    # <thead> is skipped via XPath children axis magic
    process '//table[@class="data"]/tr[position() < last()]', 'rows[]' => scraper {
        process '//td', 'cells[]' => 'TEXT',
    },
};

my $res = $malafides->scrape(URI->new($url));

my $csv = Text::CSV_XS->new();
open my $file, '>:utf8', 'output.csv';

for my $row (@{$res->{rows}}) {
    $csv->print($file, $row->{cells});
    print $file "\n";
}
