#!/usr/bin/perl

use strict;
use warnings;

package monitor;

use Template ();

use JSON::XS ( '&decode_json', '&encode_json' );

use CGI ();
use CGI::Carp 'fatalsToBrowser';

use constant
{
	PATH => '/path/where/your/stuff/lies/',
	CONFIG => 'conf',
	LAST_STATE => 'last'
};

our %REPLACES = ();

{
	my $cgi = CGI -> new();

	my $action = $cgi -> param( 'please' );

	if( $action eq 'fix' )
	{
		if( my $service = $cgi -> param( 'service' ) )
		{
			&fix( $service );
		}

	} elsif( $action eq 'check' )
	{
		&update_state();
		&get_state();

	} else
	{
		&main();
	}
}

exit 0;

sub load_json
{
	my $file = PATH . shift;

	if( ( -e $file ) and open( my $fh, '<', $file ) )
	{
		my $json = join( '', <$fh> );

		close( $fh );

		return &decode_json( $json ) if $json;
	}

	return undef;
}

sub save_json
{
	my $file = PATH . shift;
	my $data = shift;

	if( open( my $fh, '>', $file ) )
	{
		if( flock( $fh, 2 ) )
		{
			print $fh &encode_json( $data );

			flock( $fh, 8 );
		}

		close( $fh );

		return 1;
	}

	return undef;
}

sub load_config
{
	return &load_json( CONFIG );
}

sub load_state
{
	return &load_json( LAST_STATE );
}

sub save_state
{
	return &save_json( LAST_STATE, shift );
}

sub get_state
{
	print "Content-type: text/plain;charset=utf-8\n\n" . &encode_json( &load_state() );
}

sub fix
{
	my $service = shift;

	my %broken = ( map{ ( $_ )x2 } @{ ( &load_state() or [] ) } );

	delete $broken{ $service };

	&save_state( [ keys %broken ] );

	print "Content-type: text/plain;charset=utf-8\n\n1";
}

sub update_state
{
	if( defined( my $cfg = &load_config() ) )
	{
		if( ( my $num_to_break = ( ( ( 1 + int( rand( 100 ) ) ) >= 90 ) ? ( 1 + int( rand( 3 ) ) ) : 0 ) ) > 0 )
		{
			my %broken = ( map{ ( $_ )x2 } @{ ( &load_state() or [] ) } );

			my @services = ( sort{ rand() <=> rand() } @$cfg );
			my $cnt = scalar( @services );

			if( scalar( keys %broken ) < $cnt )
			{
				my @breakable = ( grep{ not exists $broken{ $_ -> { 'name' } } } @services );
				my $breakable_cnt = scalar( @breakable );

				if( $num_to_break > $breakable_cnt )
				{
					$num_to_break = $breakable_cnt;
				}

				if( $num_to_break > 0 )
				{
					for( my $i = 0; $i < $num_to_break; ++$i )
					{
						my $service = $breakable[ $i ] -> { 'name' };

						$broken{ $service } = $service;
					}

					&save_state( [ keys %broken ] );
				}
			}
		}

		return 1;
	}

	return undef;
}

sub main
{
	if( defined( my $cfg = &load_config() ) )
	{
		&ar( CFG => $cfg );
	}

	print "Content-type: text/html;charset=utf-8\n\n" . &tt( \&pt( 'index' ) );
}

sub pt
{
	my ( $tplname, $output ) = ( shift, '' );

	if( open( my $fh, '<', PATH . $tplname . '.tt' ) )
	{
		$output = join( '', <$fh> );
		close( $fh );
	}

	return $output;
}

sub tt
{
	my $tplname = shift;

	my $config = { POST_CHOMP => 1 };

	my ( $template, $output ) = ( Template -> new( $config ), '' );

	unless( $template -> process( $tplname, \%REPLACES, \$output ) )
	{
		$output = $template -> error();
	}

	if( $output =~ m/\[%\s.+?\s%\]/g )
	{
		$output = &tt( \$output );
	}

	return $output;
}

sub ar
{
	my %args = @_;

	foreach my $macros ( keys %args )
	{
		$REPLACES{ $macros } = $args{ $macros };
	}

	return scalar keys %args;
}

sub gr
{
	return $REPLACES{ $_[ 0 ] };
}

