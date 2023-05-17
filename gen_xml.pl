#-*- mode: perl; tab-size: 4 -*-
use strict;
use Cwd 'abs_path';
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Find::Rule;
use File::Basename;
use Config::Tiny;
use XML::Writer;
use File::stat;
use Time::localtime;
use File::Copy "cp";

use constant AUTORE => 'Giovanni Zezza';
use constant HOMEPAGE => 'http://verde06';
use constant HOST => 'http://verde06';

my $rule = File::Find::Rule->new;

my $dirname = dirname(__FILE__);

my $root = basename(abs_path($dirname));

$rule->name('*.zip');

my $file;
my $member;

$rule->start($dirname);

sub leggi_zip;

use IO::File;

my $output = IO::File->new(">qgis-repo.xml");

my $writer = XML::Writer->new(OUTPUT => $output, DATA_MODE => 1, DATA_INDENT => 3);

$writer->xmlDecl();
$writer->pi('xml-stylesheet', 'type="text/xsl" href="qgis_plugins/plugins.xsl"');

$writer->startTag('plugins');

while (defined($file = $rule->match())) {
	print $file, "\n";
	leggi_zip $file, $writer, $root;
}

$writer->endTag('plugins');
$writer->end();
$output->close();

cp 'qgis-repo.xml', 'plugins.xml';

sub leggi_zip {
	my ($file, $writer, $root) = @_;
	my $zipFile = Archive::Zip->new();
	my $status = $zipFile->read($file);
	my $contenuto;
	my @metadata;
	my $config = Config::Tiny->new();
	my $data_creazione;
	my $data_modifica;
	
	if ($status != AZ_OK) {
		print STDERR "File ", $file, " non trovato\n";
		return;
	}

	@metadata = $zipFile->membersMatching('.*\metadata.txt');
	
	if (!scalar(@metadata)) {
		print STDERR "Non trovato metadata.txt\n";
		return;
	}

	$data_creazione = localtime(stat($file)->ctime);
	
	$data_creazione = localtime(stat($file)->mtime);

	$data_creazione = sprintf("%04s-%02s-%02s",
					$data_creazione->year + 1900,
					$data_creazione->mon + 1,
					$data_creazione->mday);
	
	$data_modifica = localtime(stat($file)->mtime);

	$data_modifica = sprintf("%04s-%02s-%02s",
					$data_modifica->year + 1900,
					$data_modifica->mon + 1,
					$data_modifica->mday);
	
	for my $elemento (@metadata) {
		($contenuto, $status) = $elemento->contents();
        print $contenuto, "---\n";
        print $status, "---\n";
		if ($status != AZ_OK) {
			return;
		}
		
		my $ini;
		eval {$ini = $config->read_string($contenuto)};
		print $ini, "\n";
		if ($ini) {
			my $plg_nome = $ini->{'general'}{'name'};
			my $plg_versione = $ini->{'general'}{'version'};
			my $plg_descrizione = $ini->{'general'}{'description'};
			my $plg_qgis_min_version = $ini->{'general'}{'qgisMinimumVersion'};
			my $plg_qgis_max_version = $ini->{'general'}{'qgisMaximumVersion'};
			
			my $plg_author = $ini->{'general'}{'author'};
			
			if (!defined($plg_author)) {
				$plg_author = AUTORE;
			}

			my $plg_homepage = $ini->{'general'}{'homepage'};
			if (!defined($plg_homepage)) {
				$plg_homepage = HOMEPAGE;
			}
			
			$writer->startTag("pyqgis_plugin",
					  'name' => $plg_nome,
					  'version' => $plg_versione);
			
			$writer->dataElement('description', $plg_descrizione);
			$writer->dataElement('version', $plg_versione);
			$writer->dataElement('qgis_minimum_version', $plg_qgis_min_version);
			$writer->dataElement('homepage', $plg_homepage);
			$writer->dataElement('file_name', $file);
			$writer->dataElement('author_name', $plg_author);
			$writer->dataElement('download_url', HOST . '/' . $root . '/' . $file);
			$writer->dataElement('create_date', $data_creazione);
			$writer->dataElement('update_date', $data_modifica);

			$writer->endTag("pyqgis_plugin");

		} else {
			print STDERR 'no ini';
		}
		
	}
}
