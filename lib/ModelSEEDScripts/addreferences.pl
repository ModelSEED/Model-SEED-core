use strict;
$|=1;
 
use ModelSEED::utilities;
my $names = ["Table S1","Table S2","Table S3","Table S4","Table S5","Table S6","Table S7"];
my $links = {
	"Table S1" => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowDiagram&subsystem=Riboflavin%2C_FMN_and_FAD_biosynthesis_in_plants",
	"Table S2" => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowDiagram&subsystem=Thiamin_biosynthesis_in_plants",
	"Table S3" => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowDiagram&subsystem=Pyridoxine_(vitamin_B6)_biosynthesis_in_plants",
	"Table S4" => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowDiagram&subsystem=Niacin%2C_NAD_and_NADP_biosynthesis_in_plants",
	"Table S5" => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowDiagram&subsystem=Folate_biosynthesis_in_plants",
	"Table S6" => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowDiagram&subsystem=Biotin_biosynthesis_in_plants",
	"Table S7" => "http://pubseed.theseed.org/SubsysEditor.cgi?page=ShowDiagram&subsystem=Pantothenate_and_CoA_biosynthesis_in_plants",
};
my $notes = {
	"Table S1" => [
		'Enzyme abbreviations (column "Abbrev") correspond to those in the riboflavin pathway diagram (Fig. 1) and are defined in column "Functional role" ("Functional role"). Enzyme and transporter colour-coding is coordinated between the table and the pathway diagram and is explained at the top of the table (Legend).',
		'Arabidopsis gene IDs (column "AT gene ID") correspond to genome version AtGDB171/TAIR9 (www.plantgdb.org) (genome 3702 in the SEED database). Maize gene IDs (column "Maize ortholog") correspond to the Filtered Gene Set of the B73 cultivar genome sequence version AGPv2 (www.maizesequence.org) (genome 381124 in the SEED database). An attempt was made to establish orthology between Arabidopsis and maize genes, and the orthologous gene pairs are shown in the same rows. When one-on-one orthology could not be established, homologs appear in separate rows and are marked with an asterisk.',
		'Column "Curated localization" gives curated localizations (preceded by the # symbol) based on experimental and/or bioinformatics data for Arabidopsis, maize, or other plants; data are given specifically for Arabidopsis and maize in their respective columns. Abbreviations are: E - experimental evidence; P - predicted bioinformatically; PPDB - The Plant Proteome Database (ppdb.tc.cornell.edu). The column "Experimental data" briefly reviews experimental findings (other than enzyme localization) available for Arabidopsis, maize, or other plants. Publications are referenced by PubMed IDs (when available), which are linked to the PubMed database. The column "Problems, open questions, predictions" concerns gaps and inconsistencies in current knowledge.'
	],
	"Table S2" => [
		'Enzyme abbreviations (column "Abbrev") correspond to those in the thiamin pathway diagram (Fig. 2) and are defined in column "Functional role" ("Functional role"). Enzyme and transporter colour-coding is coordinated between the table and the pathway diagram and is explained at the top of the table (Legend).', 
		'Arabidopsis gene IDs (column "AT gene ID") correspond to genome version AtGDB171/TAIR9 (www.plantgdb.org) (genome 3702 in the SEED database). Maize gene IDs (column "Maize ortholog") correspond to the Filtered Gene Set of the B73 cultivar genome sequence version AGPv2 (www.maizesequence.org) (genome 381124 in the SEED database). An attempt was made to establish orthology between Arabidopsis and maize genes, and the orthologous gene pairs are shown in the same rows. When one-on-one orthology could not be established, homologs appear in separate rows and are marked with an asterisk.',
		'Column "Curated localization" gives curated localizations (preceded by the # symbol) based on experimental and/or bioinformatics data for Arabidopsis, maize, or other plants; data are given specifically for Arabidopsis and maize in their respective columns. Abbreviations are: E - experimental evidence; P - predicted bioinformatically; PPDB - The Plant Proteome Database (ppdb.tc.cornell.edu). The column "Experimental data" briefly reviews experimental findings (other than enzyme localization) available for Arabidopsis, maize, or other plants. Publications are referenced by PubMed IDs (when available), which are linked to the PubMed database. The column "Problems, open questions, predictions" concerns gaps and inconsistencies in current knowledge.'
	],
	"Table S3" => [
		'Enzyme abbreviations (column "Abbrev") correspond to those in the pyridoxine pathway diagram (Fig. 3) and are defined in column "Functional role" ("Functional role"). Enzyme and transporter colour-coding is coordinated between the table and the pathway diagram and is explained at the top of the table (Legend).',
		'Arabidopsis gene IDs (column "AT gene ID") correspond to genome version AtGDB171/TAIR9 (www.plantgdb.org) (genome 3702 in the SEED database). Maize gene IDs (column "Maize ortholog") correspond to the Filtered Gene Set of the B73 cultivar genome sequence version AGPv2 (www.maizesequence.org) (genome 381124 in the SEED database). An attempt was made to establish orthology between Arabidopsis and maize genes, and the orthologous gene pairs are shown in the same rows. When one-on-one orthology could not be established, homologs appear in separate rows and are marked with an asterisk.',
		'Column "Curated localization" gives curated localizations (preceded by the # symbol) based on experimental and/or bioinformatics data for Arabidopsis, maize, or other plants; data are given specifically for Arabidopsis and maize in their respective columns. Abbreviations are: E - experimental evidence; P - predicted bioinformatically; PPDB - The Plant Proteome Database (ppdb.tc.cornell.edu). The column "Experimental data" briefly reviews experimental findings (other than enzyme localization) available for Arabidopsis, maize, or other plants. Publications are referenced by PubMed IDs (when available), which are linked to the PubMed database. The column "Problems, open questions, predictions" concerns gaps and inconsistencies in current knowledge.'
	],
	"Table S4" => [
		'Enzyme abbreviations (column "Abbrev") correspond to those in the niacin pathway diagram (Fig. 4) and are defined in column "Functional role" ("Functional role"). Enzyme and transporter colour-coding is coordinated between the table and the pathway diagram and is explained at the top of the table (Legend).',
		'Arabidopsis gene IDs (column "AT gene ID") correspond to genome version AtGDB171/TAIR9 (www.plantgdb.org) (genome 3702 in the SEED database). Maize gene IDs (column "Maize ortholog") correspond to the Filtered Gene Set of the B73 cultivar genome sequence version AGPv2 (www.maizesequence.org) (genome 381124 in the SEED database). An attempt was made to establish orthology between Arabidopsis and maize genes, and the orthologous gene pairs are shown in the same rows. When one-on-one orthology could not be established, homologs appear in separate rows and are marked with an asterisk.',
		'Column "Curated localization" gives curated localizations (preceded by the # symbol) based on experimental and/or bioinformatics data for Arabidopsis, maize, or other plants; data are given specifically for Arabidopsis and maize in their respective columns. Abbreviations are: E - experimental evidence; P - predicted bioinformatically; PPDB - The Plant Proteome Database (ppdb.tc.cornell.edu). The column "Experimental data" briefly reviews experimental findings (other than enzyme localization) available for Arabidopsis, maize, or other plants. Publications are referenced by PubMed IDs (when available), which are linked to the PubMed database. The column "Problems, open questions, predictions" concerns gaps and inconsistencies in current knowledge.'
	],
	"Table S5" => [
		'Enzyme abbreviations (column "Abbrev") correspond to those in the folate pathway diagram (Fig. 5) and are defined in column "Functional role" ("Functional role"). Enzyme and transporter colour-coding is coordinated between the table and the pathway diagram and is explained at the top of the table (Legend).',
		'Arabidopsis gene IDs (column "AT gene ID") correspond to genome version AtGDB171/TAIR9 (www.plantgdb.org) (genome 3702 in the SEED database). Maize gene IDs (column "Maize ortholog") correspond to the Filtered Gene Set of the B73 cultivar genome sequence version AGPv2 (www.maizesequence.org) (genome 381124 in the SEED database). An attempt was made to establish orthology between Arabidopsis and maize genes, and the orthologous gene pairs are shown in the same rows. When one-on-one orthology could not be established, homologs appear in separate rows and are marked with an asterisk.',
		'Column "Curated localization" gives curated localizations (preceded by the # symbol) based on experimental and/or bioinformatics data for Arabidopsis, maize, or other plants; data are given specifically for Arabidopsis and maize in their respective columns. Abbreviations are: E - experimental evidence; P - predicted bioinformatically; PPDB - The Plant Proteome Database (ppdb.tc.cornell.edu). The column "Experimental data" briefly reviews experimental findings (other than enzyme localization) available for Arabidopsis, maize, or other plants. Publications are referenced by PubMed IDs (when available), which are linked to the PubMed database. The column "Problems, open questions, predictions" concerns gaps and inconsistencies in current knowledge.'
	],
	"Table S6" => [
		'Enzyme abbreviations (column "Abbrev") correspond to those in the biotin pathway diagram (Fig. 6) and are defined in column "Functional role" ("Functional role"). Enzyme and transporter colour-coding is coordinated between the table and the pathway diagram and is explained at the top of the table (Legend).',
		'Arabidopsis gene IDs (column "AT gene ID") correspond to genome version AtGDB171/TAIR9 (www.plantgdb.org) (genome 3702 in the SEED database). Maize gene IDs (column "Maize ortholog") correspond to the Filtered Gene Set of the B73 cultivar genome sequence version AGPv2 (www.maizesequence.org) (genome 381124 in the SEED database). An attempt was made to establish orthology between Arabidopsis and maize genes, and the orthologous gene pairs are shown in the same rows. When one-on-one orthology could not be established, homologs appear in separate rows and are marked with an asterisk.',
		'Column "Curated localization" gives curated localizations (preceded by the # symbol) based on experimental and/or bioinformatics data for Arabidopsis, maize, or other plants; data are given specifically for Arabidopsis and maize in their respective columns. Abbreviations are: E - experimental evidence; P - predicted bioinformatically; PPDB - The Plant Proteome Database (ppdb.tc.cornell.edu). The column "Experimental data" briefly reviews experimental findings (other than enzyme localization) available for Arabidopsis, maize, or other plants. Publications are referenced by PubMed IDs (when available), which are linked to the PubMed database. The column "Problems, open questions, predictions" concerns gaps and inconsistencies in current knowledge.'
	],
	"Table S7" => [
		'Enzyme abbreviations (column "Abbrev") correspond to those in the pantothenate pathway diagram (Fig. 7) and are defined in column "Functional role" ("Functional role"). Enzyme and transporter colour-coding is coordinated between the table and the pathway diagram and is explained at the top of the table (Legend).',
		'Arabidopsis gene IDs (column "AT gene ID") correspond to genome version AtGDB171/TAIR9 (www.plantgdb.org) (genome 3702 in the SEED database). Maize gene IDs (column "Maize ortholog") correspond to the Filtered Gene Set of the B73 cultivar genome sequence version AGPv2 (www.maizesequence.org) (genome 381124 in the SEED database). An attempt was made to establish orthology between Arabidopsis and maize genes, and the orthologous gene pairs are shown in the same rows. When one-on-one orthology could not be established, homologs appear in separate rows and are marked with an asterisk.',
		'Column "Curated localization" gives curated localizations (preceded by the # symbol) based on experimental and/or bioinformatics data for Arabidopsis, maize, or other plants; data are given specifically for Arabidopsis and maize in their respective columns. Abbreviations are: E - experimental evidence; P - predicted bioinformatically; PPDB - The Plant Proteome Database (ppdb.tc.cornell.edu). The column "Experimental data" briefly reviews experimental findings (other than enzyme localization) available for Arabidopsis, maize, or other plants. Publications are referenced by PubMed IDs (when available), which are linked to the PubMed database. The column "Problems, open questions, predictions" concerns gaps and inconsistencies in current knowledge.'	
	]
};
foreach my $name (@{$names}) {
	my $filename = "C:/Code/Model-SEED-core/data/bvitamins/".$name.".txt";
	my $newfilename = "C:/Code/Model-SEED-core/data/bvitamins/".$name.".html";
	
	my $data = ModelSEED::utilities::LOADFILE($filename);
	my $array = [split("\t",$data->[0])];
	my $title = $array->[0];
	my $output = [
		'<!doctype HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">',
		'<html><head>',
		'<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"></script>',
		'    <script type="text/javascript">',
		'        function UpdateTableHeaders() {',
		'            $("div.divTableWithFloatingHeader").each(function() {',
		'                var originalHeaderRow = $(".tableFloatingHeaderOriginal", this);',
		'                var floatingHeaderRow = $(".tableFloatingHeader", this);',
		'                var offset = $(this).offset();',
		'                var scrollTop = $(window).scrollTop();',
		'                if ((scrollTop > offset.top) && (scrollTop < offset.top + $(this).height())) {',
		'                    floatingHeaderRow.css("visibility", "visible");',
		'                    floatingHeaderRow.css("top", Math.min(scrollTop - offset.top, $(this).height() - floatingHeaderRow.height()) + "px");',
		'                    // Copy row width from whole table',
		'                    floatingHeaderRow.css(\'width\', "2000px");',
		'                    // Copy cell widths from original header',
		'                    $("th", floatingHeaderRow).each(function(index) {',
		'                        var cellWidth = $("th", originalHeaderRow).eq(index).css(\'width\');',
		'                        $(this).css(\'width\', cellWidth);',
		'                    });',
		'                }',
		'                else {',
		'                    floatingHeaderRow.css("visibility", "hidden");',
		'                    floatingHeaderRow.css("top", "0px");',
		'                }',
		'            });',
		'        }',
		'        $(document).ready(function() {',
		'            $("table.tableWithFloatingHeader").each(function() {',
		'                $(this).wrap("<div class=\"divTableWithFloatingHeader\" style=\"position:relative\"></div>");',
		'                var originalHeaderRow = $("tr:first", this)',
		'                originalHeaderRow.before(originalHeaderRow.clone());',
		'                var clonedHeaderRow = $("tr:first", this)',
		'                clonedHeaderRow.addClass("tableFloatingHeader");',
		'                clonedHeaderRow.css("position", "absolute");',
		'                clonedHeaderRow.css("top", "0px");',
		'                clonedHeaderRow.css("left", $(this).css("margin-left"));',
		'                clonedHeaderRow.css("visibility", "hidden");',
		'                originalHeaderRow.addClass("tableFloatingHeaderOriginal");',
		'            });',
		'            UpdateTableHeaders();',
		'            $(window).scroll(UpdateTableHeaders);',
		'            $(window).resize(UpdateTableHeaders);',
		'        });',
		'    </script>',
		'<style type="text/css">',
		'h1 {',
		'    font-size: 16px;',
		'}',
		'table.tableWithFloatingHeader {',
		'    font-size: 12px;',
		'    text-align: left;',
		'	 border: 0;',
		'	 width: 2000px;',
		'}',
		'th {',
		'    font-size: 14px;',
		'    background: #ddd;',
		'	 border: 1px solid black;',
		'    vertical-align: top;',
		'    padding: 5px 5px 5px 5px;',
		'}',
		'td {',
		'   font-size: 12px;',
	#	'	border: 1px solid black;',
		'	vertical-align: top;',
		'}',
		'</style></head>',
		'<h1>'.$title.'</h1>',
		'<p><a href="'.$links->{$name}.'" target="_blank">Link to pathway encoded in the SEED database</a></p>',
		'<table><tr>',
		'<td><b>Legend:</b></td>',
		'<td style="background-color:#FFFF11;">A yellow background indicates genes that are enigmatic in some way in plants</td>',
		'<td style="background-color:#FFBBDD;">A light pink background indicates genes that are unknown in plants</td>',
		'<td style="background-color:#FF0088;">A dark pink background indicates genes that are unknown in all organisms</td>',
		'<td style="background-color:#99FFEE;">A pale blue background indicates evidence that genes are not present in plants</td>',
		'<td style="background-color:#BBBBBB;">A dark gray background indicates probable pseudogenes</td>',
		'</tr></table>',
		'<table class="tableWithFloatingHeader">'
	];
	$array = [split("\t",$data->[2])];
	my $numcol = (@{$array}-1);
	my $line = "<tr style=\"width:2000px;\">";
	my $row = [];
	my $spaceLine = '<tr><td colspan="'.$numcol.'" style="border-top: 6px solid black;">&nbsp;</td></tr>';
	for (my $i=1; $i < @{$array}; $i++) {
		$line .= "<th>".$array->[$i]."</th>";
		push(@{$row},"&nbsp;");
	}
	$line .= "</tr>";
	my $current = 0;
	my $styles = [
		"style=\"background-color:#ebebeb;padding:2px;\"",
		"style=\"background-color:#ebebeb;padding-left:8px;\"",
		"style=\"background-color:#99FFEE;padding:2px;\"",#blue
		"style=\"background-color:#99FFEE;padding-left:8px;\"",#blue
		"style=\"background-color:#FFFF11;padding:2px;\"",#yellow
		"style=\"background-color:#FFFF11;padding-left:8px;\"",#yellow
		"style=\"background-color:#FFBBDD;padding:2px;\"",#pink
		"style=\"background-color:#FFBBDD;padding-left:8px;\"",#pink
		"style=\"background-color:#FF0088;padding:2px;\"",#red
		"style=\"background-color:#FF0088;padding-left:8px;\"",#red
		"style=\"background-color:#BBBBBB;padding:2px;\"",#gray
		"style=\"background-color:#BBBBBB;padding-left:8px;\""#gray
	];
	my $styleHash = {
		none => 0,
		blue => 1,
		yellow => 2,
		pink => 3,
		red => 4,
		gray => 5	
	};
	my $head = 0;
	push(@{$output},$line);
	for (my $i=3; $i < @{$data}; $i++) {
		if ($data->[$i] !~ m/^(\.\t)+\.$/) {
			my $array = [split("\t",$data->[$i])];
			$line = "";
			my $keep = 1;
			if (defined($array->[0]) && length($array->[0]) > 1 && !defined($styleHash->{$array->[0]})) {
				if ($i > 3) {
					push(@{$output},$spaceLine);	
				}
				$line = "<tr><th colspan=\"".$numcol."\">".$array->[0]."</th></tr>";
				$head = 1;
			} else {
				my $style = "none";
				if (defined($styleHash->{$array->[0]})) {
					$style = $array->[0];	
				}
				my $addSpace = 0;
				if ($array->[1] ne $row->[0] && length($array->[1]) ne 0 && $head == 0) {
					$addSpace = 1;
				}
				$head = 0;
				my $styleIndex = ((2*($styleHash->{$style})) + $current);
				for (my $j=1; $j < @{$array}; $j++) {
					if ($array->[$j] eq "." || $array->[$j] =~ m/^\s+$/) {
						$row->[$j-1] = "&nbsp;";
					} elsif (length($array->[$j]) > 0) {
						$row->[$j-1] = $array->[$j];
					}
					if ($row->[$j-1] =~ m/^(At\dg\d+)\s*$/) {
						$row->[$j-1] = "<a href=\"http://www.arabidopsis.org/servlets/TairObject?name=".$1."&type=locus\">".$1."</a>";
					} elsif ($row->[$j-1] =~ m/^(At\dg\d+)\*\s*$/) {
						$row->[$j-1] = "<a href=\"http://www.arabidopsis.org/servlets/TairObject?name=".$1."&type=locus\">".$1."</a>*";
					}
					if ($row->[$j-1] =~ m/^(GRMZM\dG\d+)\s*$/) {
						$row->[$j-1] = "<a href=\"http://www.maizesequence.org/Zea_mays/Gene?db=core;g=".$1."\">".$1."</a>";
					} elsif ($row->[$j-1] =~ m/^(GRMZM\dG\d+)\*\s*$/) {
						$row->[$j-1] = "<a href=\"http://www.maizesequence.org/Zea_mays/Gene?db=core;g=".$1."\">".$1."</a>*";
					}
					while ($row->[$j-1] =~ m/\[PMID:(\d+)\]/) {
						my $search = "\\[PMID:".$1."\\]";
						my $link = "[<a href=\"http://www.ncbi.nlm.nih.gov/pubmed?term=".$1."\">PMID:".$1."</a>]";
						$row->[$j-1] =~ s/$search/$link/;
					}
				}
				$keep = 0;
				for (my $j=1; $j < 6; $j++) {
					if ($row->[$j] ne "&nbsp;" && $row->[$j] ne "" && $row->[$j] !~ m/^[\s\t]+$/) {
						$keep = 1;
					}
				}
				if ($addSpace == 1 && $keep == 1) {
					push(@{$output},$spaceLine);
				}
				$line = "<tr><td ".$styles->[$styleIndex].">".join("</td><td ".$styles->[$styleIndex].">",@{$row})."</td></tr>";
			}
			if (defined($line) && length($line) > 0 && $keep == 1) {
				push(@{$output},$line);
			}
		} else {
			$row = [];
			for (my $j=1; $j < @{$row}; $j++) {
				push(@{$row},"&nbsp;");
			}
		}
	}
	push(@{$output},$spaceLine);
	push(@{$output},'<tr><th colspan="'.$numcol.'">Table Notes</th></tr>');
	for (my $i=0; $i < @{$notes->{$name}}; $i++) {
		push(@{$output},'<tr><td style="border: 1px solid black;" colspan="'.$numcol.'">'.$notes->{$name}->[$i].'</td></tr>');
	}
	push(@{$output},"</table></html>");
	ModelSEED::utilities::PRINTFILE($newfilename,$output);
}