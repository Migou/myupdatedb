#!/usr/bin/perl
# liste les disques qui seront visités par updatedb

use strict;

# arguments :
# - fs : {'dev'=> le device , 'fs' => le fstype, 'mp' => point de montage }
sub report($$)
{
    my $fs = shift;
    my $rapport= shift;

    my $mp = $fs->{mp};
    my $fstype = $fs->{fs};
    my $dev = $fs->{dev};
    
    print("$mp ($dev), type $fstype : $rapport\n");
}


my $conf='/etc/updatedb.conf'; # contient prunefs et prunepath

my $memoryfile="$0.sav"; # liste des résultats connus

my @fs=();

# obtention de la liste des fs montés
open(MONTAGES,'mount|');
while(<MONTAGES>)
{
    m|^([^ ]*) on (/[^ ]*) type ([^ ]+)| || next;
    my $device=$1;
    my $mountpoint = $2;
    my $filesystem = $3;
    if($device ne 'none')
    {
	push @fs, {'dev'=>$device,'mp'=>$mountpoint,'fs'=>$filesystem};
    }
}

#obtention fe prunpath
my %prunepath=();
my %prunefs=();
open(CONF,$conf) || die "$!";
while(<CONF>)
{
    if( /^\s*PRUNEPATHS\s*=\s*"([^"]*)/ )
    {
	my @prunepaths=split(/\s+/,$1);
	foreach my $pp (@prunepaths)
	{
	    $prunepath{$pp} = 1;
	}
    }
    if( /^\s*PRUNEFS\s*=\s*"([^"]*)/ )
    {
	my @prunefstype=split(/\s+/,$1);
	foreach my $pfst (@prunefstype)
	{
	    $prunefs{$pfst} = 1;
	}
    }
}

#obtention de la mémoire du programme
my $memory=read_memory($memoryfile);

# rapport de l'élagage
my %rapport = ();

foreach my $fs (@fs)
{
    my $keyfs = $fs->{mp};
    if( ! exists($memory->{$keyfs}) )
    {
	$memory->{$keyfs}={%$fs};
    }
    $memory->{$keyfs}{present}++;
    $memory->{$keyfs}{seen}=1;
    


    # est-il dans prunepath ?
    my $indic;
    if( $prunefs{$fs->{fs}} )
    {
	# report($fs,"Ignorer : fstype=$fs->{fs}");
    }
    if( est_completement_elague($fs->{mp}) )
    {
	report($fs,"Ignorer");
    }
    elsif( defined($indic=est_partiellement_elague($fs->{mp})) )
    {
	report($fs,"Indexer, sauf ".join(', ',@$indic));
    }
    else
    {
	report($fs,"Indexer");
    }
}



# Ajout d'un warning sur les disques durs manquants
# & mise à jour de la mémoire : fichiers manquants
foreach my $mp (keys %$memory)
{
    if( ! $memory->{$mp}{seen} )
    {
	$memory->{$mp}{missing}++;

	report($memory->{$mp},"Absent : ce système de fichiers n'est pas monté actuellement (taux de présence : ".int(100*$memory->{$mp}{present}/($memory->{$mp}{missing}+$memory->{$mp}{present}))."%)\n");
    }
}

write_memory($memoryfile,$memory);



sub est_completement_elague($)
{
    my $path = shift;
    foreach my $prunepath (keys(%prunepath))
    {
	if( $path =~ m[^$prunepath($|/)] )
	{
	    # lors il est complétement élagué
	    return 1;
	}
    }
    return undef;
}

# retourne la liste des sous dossiers élagués
sub est_partiellement_elague($)
{
    my $path = shift;
    my @indic=();
    foreach my $prunepath ( keys(%prunepath) )
    {
	if( $prunepath =~ m[^$path($|/)] )
	{
	    # lors, il existe un sous ficher de $path qui est élagué
	    push @indic, $prunepath;
	}
    }

    if(@indic)
    {
	return [@indic];
    }
    else
    {
	return undef;
    }
}


# dev path type nbpresent nbmissing
# nppresent-nbmissing : nombre d'expériences positives ou négatives permet de détecter les fs rarement montés
sub read_memory($)
{
    my $memoryfile= shift;
    my $res={};
    if( open(MEM,$memoryfile) )
    {    
	while(<MEM>){
	    chop;
	    my ($dev, $mp, $type, $nbpresent, $nbmissing) = split("\t",$_);
	    if($type)
	    {
		$res->{$mp} = {'dev'=>$dev,'mp'=> $mp, 'fs'=>$type, 'present'=>$nbpresent,'missing'=> $nbmissing};
	    }
	}
	
	close(MEM) || die "close file failed";
    }
    else
    {
	print("WARNING : no history file detected, creating one.\n");       
    }
    
    return $res;
}

sub write_memory($$)
{
    my $memoryfile = shift;
    my $memory = shift;
    open(OUT,'>',$memoryfile) || die "dommage, impossible de mettre à jour l'historique : $!";
    foreach my $mp (sort keys %$memory) 
    {
	my $fsm = $memory->{$mp};
	print OUT join("\t", $fsm->{dev}, $fsm->{mp}, $fsm->{fs}, $fsm->{present}, $fsm->{missing}||0)."\n";
	
    }

}
