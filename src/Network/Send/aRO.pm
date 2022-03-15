#################################################################################################
#  OpenKore - Network subsystem									#
#  This module contains functions for sending messages to the server.				#
#												#
#  This software is open source, licensed under the GNU General Public				#
#  License, version 2.										#
#  Basically, this means that you're allowed to modify and distribute				#
#  this software. However, if you distribute modified versions, you MUST			#
#  also distribute the source code.								#
#  See http://www.gnu.org/licenses/gpl.html for the full license.				#
#################################################################################################
# tRO (Thai)
package Network::Send::aRO;
use strict;
use base qw(Network::Send::ServerType0);
use Globals qw($masterServer %config);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'098F' => ['char_delete2_accept', 'v a4 a*', [qw(length charID code)]],
		'0437' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0436' => ['map_login', 'a4 a4 a4 V V C', [qw(accountID charID sessionID none tick sex)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		master_login 0A76
		game_login 0275
		buy_bulk_vender 0801
		actor_action 0437
		skill_use 0438
		character_move 035F
		sync 0360
		actor_look_at 0361
		item_take 0362
		item_drop 0363
		storage_item_add 0364
		storage_item_remove 0365
		skill_use_location 0366
		actor_info_request 0368
		actor_name_request 0369
		buy_bulk_buyer 0819
		buy_bulk_request 0817
		buy_bulk_closeShop 0815
		buy_bulk_openShop 0811
		item_list_window_selected 07E4
		map_login 0436
		party_join_request_by_name 02C4
		friend_request 0202
		homunculus_command 022D
		storage_password 023B
		party_setting 07D7
		send_equip 0998
		pet_capture 08B5
		char_delete2_accept 098F
		char_create 0A39
	);
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self->{send_buy_bulk_pack} = "v V";
	$self->{char_create_version} = 0x0A39;
	$self->{send_sell_buy_complete} = 1;

	return $self;
}
1;