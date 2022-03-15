############################################################
# koreShield plugin by Revok/iMikeLance
# Este 頵m merge dos plugins:
# * detectGM
# * pingGMpp
# * broadcastAnalyst
# * playerRecorder
# r2 ~ 04/10/2012 ~ fixed unloading/reloading, added a function similiar to playerRecorder plugin, added chatLog detection logs.
# r1 ~ 02/10/2012 ~ added ping_notWhileQueued config key
# r0 ~ 25/09/2012 ~ merge plugins
#
# TODO:
# * adicionar blacklist de monsters
# * salvar provᶥis ID de GMs num arquivo de log.
# * armazenar detec絥s em uma lista. 
# * No koreShield_ping, checar se o ID detectado estᠮa blacklist, se estiver 頲esultado do check de pings.
# * Checar se existe um objeto na tela com este ID, se existir NAO ɠRESULTADO DE koreSHield_ping e devemos kitar imediatamente.
# * [DONE] Caso entre em um mapa onde recentemente foi detectado um GM, desconecte
#
# Copyright (c) 2012-2060 bROShop Development Team
############################################################
{
package justCounting;
use Log qw( warning message error debug );
use Globals qw(%timeout);
use Utils qw(timeOut);
use AI;
use Encode;
sub new {
   my $class = shift;
   my $count = shift;
   # Print all the values just for clarification.
   #print "First Name is $self->{_firstName}\n";
   #print "Last Name is $self->{_lastName}\n";
   #print "SSN is $self->{_ssn}\n";
   #bless $self, $class;
  
   	my $couter = 10;
	
	while($couter > 0){
		warning decode("UTF-8","เจอ GM หยุดบอท จะทำงานอีกภายใน .....").$couter." \n";
		

		$couter--;
	}
	
}
sub on_AI {
	debug "Clear Ai clientSuspend\n";

	warning "......".timeOut(1.0)."........ \n";
    
}
}

{

package koreShield;

use strict;
use Plugins;
use lib $Plugins::current_plugin_folder;
use Utils qw( existsInList getFormattedDate timeOut makeIP compactArray calcPosition distance);
use Time::HiRes qw(time);
use Log qw( warning message error debug );
use Misc;
use AI;
use Globals;
use I18N qw(bytesToString);
use Commands;
use ActorList;
use RevokUtils::Parsers;
use Utils qw(existsInList);
use Encode;
use Data::Dumper;

my $dealCount = 0;

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
my $pushover_timeout = 0;
my $allowAfterRespawn = 0;
my $ReportCount = 0;
my $LastReport_time;
my $LastReport_id;
my $LastReport_map;
my $RestingTimeout = time + 0;
my $AfterRespawnTimeout = undef; #= time + 0;
my $BotSleepCouter = 0;
my $BotinCity;
my $StopWaitingCommand = Commands::register(
	['bot','cancel bot resting', \&commandHandler]
);



#teswhile();

sub teswhile{
	my $object = new justCounting();

}
sub commandHandler {
		### if no parameter just show info
		my ($miss_msg, @params) = split(/\s+/, $_[1]);
		
		
		
	if (!defined $_[1] || $miss_msg != 'go') {
		warning decode("UTF-8","คำสั่งนี้ให้บอท ยกเลิกการจำศีล \n").
		decode("UTF-8","ไม่มีคำสั่งอะไรอื่นเลย  ต้องพิมพ์   bot go  จัดทำโดย Poring\n");
		return
	}
	my ($arg, @params) = split(/\s+/, $_[1]);
	### parameter: Stop command
	if ($arg eq 'go') {
		if ($net->getState() eq Network::IN_GAME()) {
			warning decode("UTF-8","############## Let IT GO! เริ่มกระบวนการ บอทอัตโนมัติ โดยทันที  ขอให้โชคดี  ###########\n");
			if($BotSleepCouter > 5){
				$BotSleepCouter = 5;
			}
		}else {
			warning decode("UTF-8",">>>> ท่านต้อง Login game ก่อนดิ  <<<<\n");
		}
	}
	if ($arg eq 'RestTesting') {
		if ($net->getState() eq Network::IN_GAME() && $field->name eq $config{lockMap}) {
			warning decode("UTF-8","############## Bot Resting ทดสอบการ จำศีล  ###########\n");
			$ReportCount = 9;
			&core_eventsReaction('direct_call');
		}else {
			warning decode("UTF-8",">>>> ต้องอยู่ในเกม และ ใน lockMap ของ config.txt <<<<\n");
		}
	}
	if ($arg eq 'ks-disable'){
		if($config{koreShield} eq 0){
			main::configModify('koreShield',1, 2);
			message (decode("UTF-8"," เปิดระบบ ป้องกัน GM \n"));
			message (decode("UTF-8"," เปิดระบบ ป้องกัน GM \n"));
		}else {
			main::configModify('koreShield',0, 2);
			error (decode("UTF-8"," ระวัง คุณได้ปิดระบบ ป้องกัน GM \n"));
			error (decode("UTF-8"," ระวัง คุณได้ปิดระบบ ป้องกัน GM \n"));				
		}
		
	}
}
sub pushover {
	my ($reason, $message, $priority) = @_;
	return if !timeOut($pushover_timeout, 15);
	my @sound = ('gamelan', 'mechanical', 'alien');
	$pushover_timeout = time;
	my $final_message = $message."\n";
	my $server = $config{master};
	$final_message .= $server." - ".$config{username};
	require LWP::UserAgent;
	LWP::UserAgent->new()->post(
	  'https://api.#pushover.net/1/messages.json' , [
	  "token" => 'YOUR_#pushover_TOKEN',
	  "user" => 'YOUR_#pushover_USERNAME',
	  "message" => $final_message,
	  "title" => $reason,
	  "priority" => 0,
	  "sound" => $priority == -1 ? 'none' : $sound[$priority],
	  "timestamp" => int(time)
	]);
	return;
}

sub cmdTestNotification {
	my $name = '[GM]bRO'.int(rand(20));
	my $push_title;
	$push_title .= sprintf("%s detectado.", $name) if $name;

	# my $push_msg
	#pushover($push_title, sprintf("Mapa %s", 'gef_fild10'), 0);
}


use constant {
	PLUGINNAME				=>	"koreShield",
	BUS_KORESHIELD_MID 			=> 	"koreShield",
	BUS_KORESHIELD_MID_PING 	=> 	"koreShield_ping",
};


# Plugin
Plugins::register(PLUGINNAME, "", \&core_Unload, \&core_Reload);

my $commands_hooks = Commands::register(
	['ks_r', 'change material',			\&cmdKSr],
	['ks_r_on', 'change material',		\&cmdKSr_on],
	['ks_r_off', 'change material',		\&cmdKSr_off],
	['ks_n', 'change material',			\&cmdTestNotification],
);

my $myHooks = Plugins::addHooks(
	
	['start3',	\&core_start3],
	['initialized',\&initialized_config],
	#['AI_post', 								\&IngameDangerous],
	# core
	['packet/received_character_ID_and_Map',	\&core_mapServerInfo],
	['packet/actor_info',						\&core_actorInfo], #changed from pre_
	#all of these were packet_pre
	['packet/actor_action',						\&core_actorInfo],
	['packet/actor_exists',						\&core_actorInfo],
	['packet/actor_connected',					\&core_actorInfo],
	['packet/actor_spawned',					\&core_actorInfo],
	['packet/actor_died_or_disappeared',		\&core_actorInfo],
	['packet/actor_display',					\&core_actorInfo],
	['packet/actor_movement_interrupted',		\&core_actorInfo],
	['packet/actor_look_at',					\&core_actorInfo],
	['packet/actor_moved',						\&core_actorInfo],
	['packet/item_used',						\&item_used],
	['packet/actor_status_active',				\&core_actorInfo],
	['packet/unit_levelup',						\&core_actorInfo],
	['packet/stat_info',						\&core_actorInfo],
	['packet/player_equipment',					\&core_actorInfo],
	['packet/GM_req_acc_name',					\&core_actorInfo],
	['packet/deal_request',						\&core_actorInfo],
	['packet/party_invite',						\&core_actorInfo],
	['packet/friend_request',					\&core_actorInfo],	
	['charNameUpdate',							\&core_actorInfo],
	
	['packet_pre/map_loaded',					\&core_mapLogin],
	['packet_pre/map_change',					\&core_mapChange_pre],
	['packet_pre/map_changed',					\&core_mapChange_pre],
	['packet/map_change',						\&core_mapChange_post],
	['packet/map_changed',						\&core_mapChange_post], # used by detectGM and by buscheck to save map:ip
	['Network::Receive::map_changed',			\&AfterRespawnMaploaded],
	['postloadfiles',							\&core_overrideConfigKeys],
	['configModify',							\&core_overrideModifiedKey],
	# ping
	['mainLoop_pre',							\&ping_checkIds],
	['mainLoop_post',							\&Alarm_me],

	# detectgm
	['packet_pre/item_skill',					\&detectGM_flyOrButterflyWing_tpflag],
	['packet/manner_message',					\&detectGM_manner],
	['packet/GM_silence',						\&detectGM_manner],
	['packet/actor_muted',						\&detectGM_someonesMuted],
	['perfect_hidden_player',       			\&detectGM_perfectHide],
	['packet_skilluse',							\&detectGM_analyseSkillCaster],
	['is_casting',								\&detectGM_analyseSkillCaster],
	['teleport_sent',							\&detectGM_tpFlag_on],
	['Task::MapRoute::iterate::route_portal_near', \&detectGM_tpFlag_on],

	#['packet/public_chat',					\&detectGM_tpFlag_on],
	['packet/warp_portal_list',					\&detectGM_tpFlag_on], # new!
	['packet/npc_talk',							\&detectGM_addNPCtalkTolerance],
	['packet/npc_talk_continue',				\&detectGM_addNPCtalkTolerance],
	['packet/npc_talk_close',					\&detectGM_addNPCtalkTolerance],
	['packet/npc_talk_responses',				\&detectGM_addNPCtalkTolerance],
	['packet/npc_talk_number',					\&detectGM_addNPCtalkTolerance],
	['packet/npc_talk_text',					\&detectGM_addNPCtalkTolerance],
	['packet/chat_user_leave',					\&detectGM_addNPCtalkTolerance],
	['self_died',								\&detectGM_tpFlag_on],
	['packet/login_error',						\&detectGM_handleLogin],
	['packet/errors',							\&detectGM_handleLogin],
	
	#TODO: ADD SUPPORT FOR packet/actor_status_active, check lullaby deep sleep status
	['packet/character_status',					\&detectGM_forced_status],
	
	
	['packet_pubMsg',							\&detectGM_msg],
	['packet_privMsg',							\&detectGM_msg],
	
	['player_added_to_cache',					\&recorder_cache],
	
	# broadcast
	['packet_pre/local_broadcast',				\&broadcast],
	['packet_pre/system_chat',					\&broadcast],
	#['packet_sysMsg',					\&broadcast],
	['Commands::run/pre',						\&cmdReload],
	['Actor::route::map',						\&foresee_route_danger]
);

my $networkHook = Plugins::addHook('Network::stateChanged',\&bus_isStarted);

my $core_workingFolder = $Plugins::current_plugin_folder;	
my $bus_server;
my ($core_map, $core_mapIP, $core_mapPort);
my %core_databases;
my %core_config;
# pingGMpp variables
my $ping_testMap;
my $ping_idArrayPosition; # should start as 0.
my $ping_nextCheck = time + 0;
my $ping_loopTimeStart;
my $portal_testNextTime = time;
my $needCheckportal = 0;
my @ping_notWhileQueued = split(/\s+/, $core_config{ping_notWhileQueued}); 
my $detectGM_safeTeleport;
my %detectGM_actorTpInfo;

my %ping_dangerousMaps;

my $ignorePasswd = 1;

my @sc_bomb_id_list;
my $AfterRespawn_i = 0;

if ($::net) {
 core_start3();
}
sub initialized_config {
	############ create koreshield in config.txt ############
	if($config{koreShield} eq ""){
		main::configModify('koreShield',1, 2);
		message "Created koreShield enable status \n";
		message "Default koreShield enable is  ".$config{koreShield}." \n";
	}else {
		message "Default koreShield enable is  ".$config{koreShield}." \n";
	}
	############ create koreshield alarm_disable in config.txt ############
	if($config{alarm_disable} eq ""){
		main::configModify('alarm_disable',0, 2);
		Log::message "Created alarm_disable enable status \n";
		Log::message "Default alarm_disable enable is  ".$config{fast_take_item}." \n";
	}else {
		Log::message "Default alarm_disable enable is  ".$config{fast_take_item}." \n";
	}
	
	############ create koreshield alarm_time in config.txt ############
	if($config{alarm_time} eq ""){
		main::configModify('alarm_time',"", 2);
		Log::message "Created alarm_time enable status \n";
		Log::message "Default alarm_time enable is  ".$config{fast_take_item}." \n";
	}else {
		Log::message "Default alarm_time enable is  ".$config{fast_take_item}." \n";
	}
	############ create koreshield maintenance_date in config.txt ############
	if($config{maintenance_date} eq ""){
		main::configModify('maintenance_date',"", 2);
		Log::message "Created maintenance_date enable status \n";
		Log::message "Default maintenance_date enable is  ".$config{fast_take_item}." \n";
	}else {
		Log::message "Default maintenance_date enable is  ".$config{fast_take_item}." \n";
	}
	
	############ create koreshield maintenance_date in config.txt ############
	if($config{alarm_opk_quit} eq ""){
		main::configModify('alarm_opk_quit',1, 2);
		Log::message "Created alarm_opk_quit enable status \n";
		Log::message "Default alarm_opk_quit enable is  ".$config{fast_take_item}." \n";
	}else {
		Log::message "Default alarm_opk_quit enable is  ".$config{fast_take_item}." \n";
	}
}
my $alarm_time = time;
my @command_alarm_task = ("tele", "tele", "tele", "charselect", "charselect", "charselect", "charselect", "charselect", "charselect", "charselect","quit");
sub Alarm_me {
	return if (!main::timeOut($alarm_time, 3));
	$alarm_time = time;
	return if ($config{alarm_disable});
	return if (!$config{alarm_time} && !$config{maintenance_date});
	################### Alarm Method #######################
	my @stops = split(' ', $config{alarm_time});	
	for my $stop (@stops){
		my @maintenance_date = split(' ', $config{maintenance_date});
		my $maintenant_time = @maintenance_date[0];
		my $maintenant_day = @maintenance_date[1];	
		my $now = sprintf("%02d:%02d", $hour,$min);
		#message "Now $now !!!! Stop $stop \n";
		if($now eq $stop || ($now eq $maintenant_time && $maintenant_day eq $wday)){
			#Action after alarm
			warning decode("UTF-8"," >>>>>>>>>>>>>>>> คำเตือน เวลาปลุกทำงาน <<<<<<<<<<<<<<<<  \n");
			error decode("UTF-8"," >>>>>>>>>>>>>>>> ขณะนี้เวลา  $now <<<<<<<<<<<<<<<<  \n");
			alarm_task();
		}
	}
	#update
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
}
sub alarm_task {
	my $command = shift(@command_alarm_task);
	warning decode("UTF-8"," ||||||||||||||||||||||||||||| พยายาม ใช้คำสั่ง $command |||||||||||||||||||||||||||||  \n");
	if(!$config{alarm_opk_quit} && $command eq "quit") {
		return;
	}
	Commands::run($command);
}
sub cmdKSr_on {
	$ignorePasswd = 0;
	message "Password reset WILL TRIGGER \n";
}

sub cmdKSr_off {
	$ignorePasswd = 1;
	message "Password reset wont trigger... \n";
}

sub cmdKSr {
	if ($ignorePasswd == 1) {
		$ignorePasswd = 0;
		message "Turning ignore password off \n";
	} else {
		$ignorePasswd = 1;
		message "Turning ignore password on \n";
	}
}
			
sub core_start3 {
	my $reload = shift;
	if ($reload) {
		undef %core_databases;
		undef %core_config;
	}
	$ping_idArrayPosition = 0;
	my $master = $masterServer = $masterServers{$config{master}};
	message sprintf("Loading %s... \n", 'control-koreshield/koreShield.txt');
	&RevokUtils::Parsers::parseSectionedFile('control-koreshield/koreShield.txt', \%core_databases);
	%core_config = &RevokUtils::Parsers::parseConfigArray(\@{$core_databases{CONFIG}});
	message sprintf("GM DB size: %s \n", scalar @{$core_databases{GMIDS}});	
	
}
sub cmdReload {
	my (undef, $args) = @_;
	if ($args->{switch} eq 'reload' && $args->{args} =~ /koreshield|ks|^all$/i) {
		core_start3(1);
	}
}

# BUS handle plugin loaded manually (plugin load/reload inside kore)
# this is used just in case the user reloads the plugin
# this code will be skipped during automatic plugin loading
# if ($::net) {
	# if ($::net->getState() > 1) {
		# $bus_server = $bus->onMessageReceived->add(undef, \&bus_parseMsg);
		# Plugins::delHook($networkHook);
		# undef $networkHook;
	# }
# }

sub foresee_route_danger {
	my ($self, $args) = @_;
	foresee_map_danger($args->{map});
}


sub foresee_map_danger {
	my ($map) = @_;
	if ($ping_dangerousMaps{$map}) {
		my $relog_time = $core_config{ping_relogTime} || 10;# minutes
		my $time = $ping_dangerousMaps{$map} + ($relog_time * 10);
		if ($time > time) {
			error "...This map was Dangerous \n";
			my $seed = $core_config{ping_relogTimeSeed} || 10;# minutes
			$seed  = $seed * 5;
			my $relog_time = ($time - time) + int(rand $seed);		
			return;
		} else {
			message "...expired, removing. \n", 'message';
			delete $ping_dangerousMaps{$map};
		}
	}
	message "...safe! \n", 'success';
	
}

sub detectGM_someonesMuted {
	if (defined $field && $field && !$field->isCity()) {
		error sprintf("Someone was silenced out of town! \n"), "koreShield_detect";
		&core_eventsReaction('player_muted');
	}
}

sub detectGM_msg {
	my ($self, $args) = @_;
	if ($args->{pubID} && isIn_Array(unpack("V",$args->{pubID}), \@{$core_databases{GMIDS}}) eq 1) {
		error sprintf("Player with ID blacklisted %s talked in $self! \n", unpack("V",$args->{pubID})), "koreShield_detect";
		&core_eventsReaction($self);
	} elsif ($args->{MsgUser} && (isIn_Array_Regex($args->{MsgUser}, \@{$core_databases{NAMES}}))) {
		error sprintf("Player with name blacklisted %s talked in em $self! \n", $args->{pubMsgUser}), "koreShield_detect";
		&core_eventsReaction($self);
	}
}

sub detectGM_forced_status {
		
	my (undef, $args) = @_;
	return; # TODO: fix this
	if (($args->{opt1} == 4) && ($args->{ID} eq $accountID)) {
		error sprintf("Status Sono for硤o! \n"), "koreShield_detect";
		&core_eventsReaction('forced_status');
	}
}


# we're checking if our client is set to connect to a bus server. if not, warn the user.
# caller: Network::stateChange hook
# params: none
sub bus_isStarted {
	#return if ($::net->getState() == 1);
	if (!$bus) {
		die("You MUST start bus server and configure all bots to use it. Open the following file control/sys.txt and set bus 0 to bus 1. \n\n");
	} elsif (!$bus_server) {
		$bus_server = $bus->onMessageReceived->add(undef, \&bus_parseMsg);
		Plugins::delHook($networkHook);
		undef $networkHook;
	}
}

# receives message from another kore instance and check if we should react
# caller: $bus_server = $bus_server->onMessageReceived->add(undef, \&bus_parseMsg);
# params: undef, undef, bus message (array of vars)
sub bus_parseMsg {
	return if ($core_config{disable} || $core_config{disable_core});
	my (undef, undef, $msg) = @_;
	return if (!$core_map);
	#warning $core_mapIP.' <==Core mapIP \n';
	#warning $core_mapPort.' <==core_mapPort \n';
	#warning Dumper($msg).' <==Dumper($msg) \n';
	#warning BUS_KORESHIELD_MID_PING.' <==Core mapIP \n';
	
	if ($core_mapIP && $core_mapPort && ($msg->{messageID} eq BUS_KORESHIELD_MID_PING)) {
		return;
	} elsif ($msg->{messageID} eq BUS_KORESHIELD_MID) {
		&core_eventsReaction($msg->{args}{danger}, $msg->{args});
	}
}

sub detectGM_analyseSkillCaster {
	return if ($core_config{disable} || $core_config{disable_detect} || !$core_config{detectGM_avoidStrangeSkillsBehaviour});
	my ($caller, $args) = @_;
	
	# 70 = santuario
	# 73 = kyrie
	# 12 = escudo magico
	# 29 = agi
	# 34 = ben硯
	# 361 = assumptio
	# 476 = Remo磯 Total
	# 2304 = Copia explosiva
	my $castername = Actor::get($args->{sourceID});
	debug sprintf("%s %s %s casted a skill \n",
				unpack("V1", $args->{sourceID}),
				$castername->{name},
				$castername->{jobID}
			), "koreShield_detect";
			
	
	
	return if ($core_config{detectGM_notInTown} && $field->isCity());
	return if (unpack("V1", $args->{sourceID}) eq unpack("L1", $accountID)); # won't check if it's our own ID
	
	if ($args->{skillID} == 2304) { # handle sc bomb
		push (@sc_bomb_id_list, unpack("V", $args->{sourceID}));
		debug (sprintf("SC Bomb: adding %s to \@sc_bomb_id_list \n",unpack("V", $args->{sourceID})), "koreShield_detect");
	}
	
	return unless ($castername->{jobID} == 4057); # unsafe
	return if ($castername->{jobID} == 17);
	
	
	my $skillname = $args->{skillID}?sprintf("%s (%s)", (new Skill(idn => $args->{skillID}))->getName, $args->{skillID}):sprintf("Desconhecida (%s)", $args->{skillID});
	
	return if unpack("V", $args->{sourceID}) < 100000;
	
	$messageSender->sendGetPlayerInfo(pack("V", unpack("V1", $args->{sourceID}))); # to be used with pingGMpp [OK]
	
	if ($caller eq 'is_casting') {
		if (isIn_Array(unpack("V1", $args->{sourceID}), \@{$core_databases{GMIDS}})) {
			error sprintf("Player with ID %s from blacklist is casting %s! Running default reaction... \n", unpack("V1", $args->{sourceID}), $skillname), "koreShield_detect";
			&core_eventsReaction('blacklisted_used_skill');
			return;
		} elsif (($args->{skillID} == 73) && (unpack("V1", $args->{targetID}) eq unpack("L1", $accountID))) { # kyrie eleison
			if ($castername->{name} =~ /^Unknown \#\d+/ || !$castername->{name}) {
				error sprintf("Unknown Player %s (%s) buffed You with %s! Running default reaction...\n", $castername->{name}, unpack("V", $args->{sourceID}), $skillname), "koreShield_detect";
				&core_eventsReaction('unknown_buffed_me');
				return;
			}
		} elsif ((unpack("V1", $args->{targetID}) eq unpack("L1", $accountID)) && ($castername->{name} =~ /^Unknown \#\d+/ || !$castername->{name}))  {
			error sprintf("Unknown Player %s (%s) is casting %s em You ! Running default reaction...\n", $castername->{name}, unpack("V", $args->{sourceID}), $skillname), "koreShield_detect";
			&core_eventsReaction('unknown_used_skill_me');
			return;
		
		}
		
		if (AI::action eq "attack") {
			my $monsterID = AI::args->{ID};
			if (($monsterID eq $args->{targetID}) && AI::args->{dmgFromYou_last} && $args->{sourceID}) {
			#warning "lol ".$monstersList->getByID($args->{sourceID})."\n" if $monstersList->getByID($args->{sourceID});
				if ((grep {$_ eq $args->{skillID}} (73, 2051)) && !($monstersList->getByID($args->{sourceID}))) { # do not detect 28 (Heal) here
					error sprintf("Player %s (%s) is casting %s no seu monster! Running default reaction...\n", $castername->{name}, unpack("V", $args->{sourceID}), $skillname), "koreShield_detect";
					&core_eventsReaction('slaving_monster');
				}
			}
		}
	} elsif ($caller eq 'packet_skilluse') {
		if (($args->{sourceID} eq $accountID) && ($args->{skillID} == 27)) {
			$detectGM_safeTeleport = 1;
		} elsif ($args->{sourceID} && (isIn_Array(unpack("V1", $args->{sourceID}), \@{$core_databases{GMIDS}}))) {
			error sprintf("Player de ID %s da blacklist used %s! Running default reaction... \n", unpack("V1", $args->{sourceID}), $skillname), "koreShield_detect";
			&core_eventsReaction('blacklisted_used_skill');
			return;
		} elsif ($castername =~ /^(NPC|Player)? ?\[?GM\]?.*/) {
			error sprintf("%s with [GM] in nickname used %s! Running default reaction... \n", $castername->{name}, $skillname), "koreShield_detect";
			&core_eventsReaction('gm_used_skill');
			return;
		} elsif ($castername =~ /^(NPC|Player)? ?\[?EXE\]?.*/) {
			error sprintf("%s with [EXE] in nickname used %s! Running default reaction... \n", $castername->{name}, $skillname), "koreShield_detect";
			&core_eventsReaction('gm_used_skill');
			return;
		}
		
		if (unpack("V1", $args->{targetID}) eq unpack("L1", $accountID)) { # target skills
			if ($args->{skillID} == 29 || $args->{skillID} == 34 || $args->{skillID} == 361) { # alguns buffs menos kyrie
				if ($castername =~ /^Unknown \#\d+/ || !$castername->{name}) {
					error sprintf("Unknown Player %s (%s) buffou You with %s! Running default reaction...\n", $castername->{name}, unpack("V", $args->{sourceID}), $skillname), "koreShield_detect";
					&core_eventsReaction('unknown_buffed_me');
					return;
				}
			} elsif ($args->{skillID} == 476) { # remo磯 total
					error sprintf("Unknown Player %s (%s) give you %s! Running default reaction...\n", $castername->{name}, unpack("V", $args->{sourceID}), $skillname), "koreShield_detect";
					&core_eventsReaction('fullstripped');
					return; 
			} elsif (($castername->{name} =~ /^Unknown \#\d{6,16}/ || !$castername->{name}) && (unpack("V", $args->{sourceID}) >= 100000)) {
				error sprintf("Unknown Player %s (%s) used %s em You ! Running default reaction...\n", $castername->{name}, unpack("V", $args->{sourceID}), $skillname), "koreShield_detect";
				&core_eventsReaction('unknown_used_skill_me');
				return;
			}
		} else { # ground skills
			if ($args->{skillID} == 70) { # santuᲩo
				my %skill_cast_pos;
				($skill_cast_pos{x}, $skill_cast_pos{y}) = ($args->{x}, $args->{y});
				if (&detectGM_analyseSkillCaster_isInsideSanctuary(\%skill_cast_pos)) {
					&core_eventsReaction('monster_sanctuary');
				}
			} elsif ($args->{skillID} == 12) { # escudo m᧩co
				my %skill_cast_pos;
				($skill_cast_pos{x}, $skill_cast_pos{y}) = ($args->{x}, $args->{y});
				if (&detectGM_analyseSkillCaster_isInsideSW(\%skill_cast_pos)) {
					&core_eventsReaction('monster_sw');
				}
			} elsif ($args->{skillID} == 27) { # warp portal
				if ($config{master} =~ /(Thor|Revok)/) {
					error sprintf("Player %s (%s) used a portal in a not allowed server ! Running default reaction...\n", $castername->{name}, unpack("V", $args->{sourceID})), "koreShield_detect";
					&core_eventsReaction('alien_skill');
				}
			}
		
		}
		
		if (AI::action eq "attack") {
			my $monsterID = AI::args->{ID};
			if (($monsterID eq $args->{targetID}) && AI::args->{dmgFromYou_last} && $args->{sourceID}) {
				my $lol;
				grep { $lol .= unpack("V", $_)." " } ($monsterID, $args->{targetID});
				warning "$lol\n";
				if (
						((grep {$_ eq $args->{skillID}} (73, 2051)) || (($args->{skillID} eq 28) && !$args->{damage}))
						&& !($monstersList->getByID($args->{sourceID}))
					) {
					error sprintf("Player %s (%s) used %s in your monster! Running default reaction...\n", $castername->{name}, unpack("V", $args->{sourceID}), $skillname), "koreShield_detect";
					&core_eventsReaction('slaving_monster');
				}
			}
		}
	}
}

sub detectGM_analyseSkillCaster_isInsideSW {
	return if ($core_config{disable} || $core_config{disable_detect});
	my $skill_cast_pos = shift;
	foreach my $monster (@{$monstersList->getItems()}) {
		my $mx = $monster->{pos_to}{x};
		my $my = $monster->{pos_to}{y};
		if (($skill_cast_pos->{x} == $mx) && ($skill_cast_pos->{y} == $my) && (Actor::distance($monster) <= $core_config{detectGM_monsterMaxDist})) {
			error sprintf("SW casted inside monster (%s blocks away)\n", Actor::distance($monster)), "koreShield_detect";
			return 1;
		}
	}
}


sub detectGM_analyseSkillCaster_isInsideSanctuary {
	return if ($core_config{disable} || $core_config{disable_detect});
	my $skill_cast_pos = shift;
	foreach my $monster (@{$monstersList->getItems()}) {
		my $mx = $monster->{pos_to}{x};
		my $my = $monster->{pos_to}{y};
		if ( ($skill_cast_pos->{x} >= ($mx - 3) && $skill_cast_pos->{x} <= ($mx + 3)) && ($skill_cast_pos->{y} >= ($my - 3) && $skill_cast_pos->{y} <= ($my + 3)) && (Actor::distance($monster) <= $core_config{detectGM_monsterMaxDist}) ) {
			error sprintf("Sanctuary casted inside monster (%s blocks away) \n", Actor::distance($monster)), "koreShield_detect";
			return 1;
		}
	}
}

sub detectGM_addNPCtalkTolerance {
	return if ($core_config{disable} || $core_config{disable_detect});
	$detectGM_safeTeleport = 1;
	$detectGM_actorTpInfo{npctalk} = time + $core_config{detectGM_toleranceAfterNPCtalk};
	debug (sprintf("Waiting time added (%s s)after talk with NPC. \n", $core_config{detectGM_toleranceAfterNPCtalk}), "koreShield_detect");
}

sub detectGM_flyOrButterflyWing_tpflag {
	return if ($core_config{disable} || $core_config{disable_detect});
	my ($caller, $args) = @_;
	if ($args->{skillID} == 26) {
		$detectGM_safeTeleport = 1;
		debug (sprintf("\$detectGM_safeTeleport changed to %s \n", $detectGM_safeTeleport), "koreShield_detect");
	}
}

sub detectGM_manner {
	error("Chat bloqueado, gm is banning us, Running default reaction...\n"), "koreShield_detect";
	&core_eventsReaction('chat_blocked');
	#pushover('Chat bloqueado', 'Chat bloqueado, estamos sendo banidos, Running default reaction...', 1);
}

sub detectGM_perfectHide {
	return if ($core_config{disable} || $core_config{disable_detect} || !$core_config{detectGM_avoidPerfectHidden});
	my ($caller, $args) = @_;
	
	# check sc_bomb_id_list
	for (my $i = $#sc_bomb_id_list; $i > -1; $i--) {
		if (unpack("V", $args->{actor}->{ID}) eq $sc_bomb_id_list[$i]) {
			debug (sprintf("Removing %s from \@sc_bomb_id_list and ignoring perfecthide \n", unpack("V", $args->{actor}->{ID})), 'koreShield_detect');
			splice (@sc_bomb_id_list, $i, 1);
			return;
		}
	}
	
	my $player = Actor::get($args->{actor}->{ID});	
	return if ($player && $player->{jobID} == 4079); # 4079 => 'Shadow Chaser',
	
	my $msg;
	$msg .= sprintf("Um GM em perfect hide (%s) foi detectado! Running default reaction...\n", $args->{actor}->{name});
	$msg .= "=================== UM GM FOI DETECTADO ==================\n";
	$msg .= sprintf("Called by hook %s\n", $caller);
	$msg .= sprintf("Time: %s\n", getFormattedDate(time));
	$msg .= sprintf("Map: %s\n", $field?$field->baseName:"Unknown");
	$msg .= sprintf("ID: %s\n", unpack("V", $args->{actor}->{ID})) if $args->{actor}->{ID};
	$msg .= sprintf("Level: %s\n", unpack("V", $args->{actor}->{level})) if $args->{actor}->{level};
	$msg .= sprintf("Name: %s\n", unpack("Z24", $args->{actor}->{name})) if $args->{actor}->{name};
	$msg .= sprintf("Party Name: %s\n", unpack("Z24", $args->{actor}->{partyName})) if $args->{actor}->{partyName};
	$msg .= sprintf("Guild Name: %s\n", unpack("Z24", $args->{actor}->{guildName})) if $args->{actor}->{guildName};
	$msg .= sprintf("Guild Title: %s\n", unpack("Z24", $args->{actor}->{guildTitle})) if $args->{actor}->{guildTitle};
	$msg .= "==========================================================\n";
	error ($msg, "koreShield_detect");
	##########Check Duplicate by Time
	
	
	&core_eventsReaction('perfect_hidden');
}

sub broadcast {
	return if ($core_config{disable} || $core_config{disable_broadcast});
	my ($caller, $args) = @_;
	# received msg in bytes
	my $message = bytesToString($args->{message});
	chomp($message); # remove newline
	$message =~ s/\000//g; # remove null charachters
	#$message =~ s/^(tool[0-9a-fA-F]{6})//g; # remove those annoying toolDDDDDD from bRO (and maybe some other server?)
	#$message =~ s/^ssss//g; # remove those annoying ssss from bRO (and maybe some other server?)
	#$message =~ s/^ +//g; $message =~ s/ +$//g; # remove whitespace in the beginning and the end of $message
	if ($message =~ /\Q$char->{'name'}/i ) {
		error sprintf("Received a broadcast with our nickname !\n".
						"Broadcast: %s \n", $message), "koreShield_broadcast";
		chatLog("koreShield.broadcast", "$message\n");
		kLog($message."\n", 'broadcast_nickname.log');
		&core_eventsReaction('broadcast_nickname');
		#pushover('Broadcast - Nickname', $message, 1);
	} elsif (isIn_Array_Regex($message, \@{$core_databases{BROADCASTWHITELIST}}, 1)) {
		debug (sprintf("Allowed broadcast: %s\n", $message), "koreShield_broadcast");
		kLog($message."\n", 'broadcast_whitelist.log');
	} elsif (isIn_Array_Regex($message, \@{$core_databases{BROADCASTBLACKLIST}}, 1)) {
		error sprintf("Match: %s \n", isIn_Array_Regex($message, \@{$core_databases{BROADCASTBLACKLIST}}, 1)), "koreShield_broadcast";
		error sprintf("Received a blacklisted broadcast.\nForbidden broadcast: %s \n", $message), "koreShield_broadcast";
		chatLog("koreShield.broadcast", "$message\n");
		kLog($message."\n", 'broadcast_blacklist.log');
		&core_eventsReaction('broadcast_blacklisted');
		#pushover('Broadcast - Blacklist', $message, 1);
	} else {
		error sprintf("Received a broadcast thats not inside whitelist or blacklist.\nForbidden broadcast: %s \n", $message), "koreShield_broadcast";
		chatLog("koreShield.broadcast", "$message\n");
		kLog($message."\n", 'broadcast_unknown.log');
		&core_eventsReaction('broadcast_unknown');
		#pushover('Broadcast - Unknown', $message, 0);
	}
}

sub detectGM_checkAllowedMap {
	my $map = shift;
	if (
		existsInList($core_config{detectGM_forbiddenMaps}, $map)
	)
	{
		error sprintf("The current map (%s) is not on the list of allowed maps or is forbidden.\n", $map), "koreShield_detect";
		&core_eventsReaction('forbidden_map');
	}
}

sub detectGM_isPortalNear {
    for (my $i = 0; $i <= $portalsList->size(); $i++) {
        my $portal = $portalsList->get($i);
        message sprintf("I'm at %s %s Portal at %s %s Distance(%s) \n",
                            $char->{pos_to}{x},
                            $char->{pos_to}{y},
                            $portal->{pos}{x},
                            $portal->{pos}{y},
                            &distance(calcPosition($char), calcPosition($portal))
                        ), "koreShield_detect";
                           
        return 1 if (distance(calcPosition($char), calcPosition($portal)) <= 15);
    }
    return 0;
}

sub core_calcDist {
	# calculate distance between char and provided coordinates
	my ($a, $b) = @_;
	return sqrt(($char->{pos_to}{x} - $a)**2 + ($char->{pos_to}{y} - $b)**2); # pythagorean
}

sub item_used {
	return if ($core_config{disable} || $core_config{disable_detect});
	return if $detectGM_safeTeleport;

	my ( $self, $args ) = @_;

	if ($args->{ID}	eq $accountID) {
		my $teleport_items_ids = "602";

		if( existsInList($teleport_items_ids, $args->{itemID}) ) {
			$detectGM_safeTeleport = 1;
			debug (sprintf("\$detectGM_safeTeleport (buttlerfly or fly wing) changed to %s \n", $detectGM_safeTeleport), "koreShield_detect");
		}
	}
}

sub detectGM_tpFlag_on {
	return if ($core_config{disable} || $core_config{disable_detect});
	return if $detectGM_safeTeleport;
	my ($self, $args) = @_;
	$detectGM_safeTeleport = 1;
	debug (sprintf("\$detectGM_safeTeleport changed to %s \n", $detectGM_safeTeleport), "koreShield_detect");
}

sub detectGM_tpFlag_off {
	return if ($core_config{disable} || $core_config{disable_detect});
	return unless $detectGM_safeTeleport;
	$detectGM_safeTeleport = 0;
	debug (sprintf("\$detectGM_safeTeleport changed to %s \n", $detectGM_safeTeleport), "koreShield_detect");
}

sub detectGM_handleLogin {
	 # 4		conta bloqueada - mais comum em privates
	 # 6		banida por tempo - mais comum em oficiais, bRO
	 # 15	GM te deu kick
	 # 101	geralmente banida por muitas conexões
	 # 102	o mesmo de 101, por魠incomum em oficiais
	my (undef, $args) = @_;
	if ($args->{date} && $args->{type} == 6) {
		my ($date, $hour) = split(' ', $args->{date});
	}
	#$args->{type} == 4 bug do bRO
	if ($args->{type} == 6 || $args->{type} == 15 || $args->{type} == 101 || $args->{type} == 102) {
		error("Conta bloqueada ou GM nos derrubou, Running default reaction... \n"), "koreShield_detect";
		#return;
		&core_eventsReaction('banned');
		#pushover("Sendo banido", '', 2);
	#} elsif ($args->{type} == Network::Receive::REFUSE_INVALID_PASSWD) {
		$config{ignoreInvalidLogin} = 1;
		&core_eventsReaction('passwd_reset') unless $ignorePasswd;
		#pushover("Reset de senha", '', 1) unless $ignorePasswd;
	}	
}

sub ping_checkIds {
	######################### Taking rest ###############
	if(time > $RestingTimeout && $BotSleepCouter > 0 && $ReportCount > 0){		
		$RestingTimeout = time + 1;
		warning decode("UTF-8","Bot กำลังจำศีล หลบ GM อยู่ จะออกไปทำงานอีกครั้ง ภายในเวลา....  ").$BotSleepCouter.decode("UTF-8"," วินาที \n");
		Commands::run("ai off");
		$BotSleepCouter--;
		
		
		
		#####Adding Counting left #######
		if($BotSleepCouter <= 5){			
			Utils::Win32::playSound ('C:\Windows\Media\Windows Battery Low.wav');			
		}
		### make sure AI is on ###
		if($BotSleepCouter <= 2){			
			Commands::run("ai auto");			
		}
		### End hidden ###
		if($BotSleepCouter <= 0){
			Commands::run("ai auto");
			if($config{XKore} eq 0){
				Commands::run("relog 1");
			}
			
			$BotSleepCouter = 0;
			$ReportCount = 0;
		}
	}
	
	##### Allow AfterRespawn Action part ! #######
	if($AfterRespawnTimeout ne undef){
		if(time > $AfterRespawnTimeout && $allowAfterRespawn eq 1){
			$AfterRespawnTimeout = time + 3;
			AfterRespawn();	
		}
	}
	
	return if ($core_config{disable} || $core_config{disable_ping});
	return if (time < $ping_nextCheck || !@{$core_databases{GMIDS}} || $::net->getState() != 5);
	

	
	if ($core_config{ping_inLockOnly} && ($core_map ne $::config{lockMap})) {
		$ping_nextCheck = time + 5;
		#message("I'm not in my lockMap, next check in ".int($ping_nextCheck - time)." seconds. \n", "ping", 0);
		$ping_idArrayPosition = 0;
		return;
	}

	if ($core_config{ping_notInExcludeMap} && isIn_StringList(\@{$core_databases{EXCLUDEMAPS}}, $core_map)) {
		$ping_nextCheck = time + 10;
		#message("I'm in a city or excluded map, next check in ".
		int($ping_nextCheck - time);
		$ping_idArrayPosition = 0;
		return;
	}
	
	$messageSender->sendGetPlayerInfo(pack("V", $core_databases{GMIDS}[$ping_idArrayPosition]));
	#debug (sprintf("Testing ID %s (%s) \n", $core_databases{GMIDS}[$ping_idArrayPosition], $ping_idArrayPosition), "koreShield_ping");
	
	if ($ping_idArrayPosition >= (@{$core_databases{GMIDS}} - 1) ) { # (@{$core_databases{GMIDS}} - 1) is former $gmListSize
		warning("I took ".int(time - $ping_loopTimeStart)." seconds to check the entire GM ID List. \n", "ping", 0);
		$ping_idArrayPosition = 0;
		$ping_nextCheck = time + 5;
	} else {
		if ($ping_idArrayPosition == 0) {
			$ping_testMap = $core_map;
			if ($ping_idArrayPosition == 0) {
				$ping_loopTimeStart = time;
				warning("Starting GM ID list check ! \n", "ping", 0);
			}
		}
		$ping_nextCheck = time + $core_config{ping_checkDelay};
		$ping_idArrayPosition++;
		
		# se mudarmos de mapa...
		if ($ping_testMap ne $core_map) {
			message("Changed our maps, reseting GM ID list position... \n", "ping", 0);
			$ping_idArrayPosition = 0;
		}
	}
}

sub core_overrideConfigKeys {
	foreach (keys %core_config) {
		next if !exists($config{'koreShield_'.$_});
		message sprintf("Overriding %s with %s\n", $_, "koreShield_".$_), "koreShield";
		$core_config{$_} = $config{'koreShield_'.$_};
	}
	
}

sub core_overrideModifiedKey {
	my (undef, $args) = @_;
	if ($args->{key} =~ /^koreShield_/) {
		my $modified_key = $args->{key};
		$modified_key =~ s/^koreShield_//;
		warning sprintf("Overriding %s with %s \n", $args->{key}, $modified_key), "koreShield";
		$core_config{$modified_key} = $args->{value};
	}
}

sub recorder_cache {
	return; # desativa isso :D
	my ($caller, $args) = @_;
	return if $field->isCity();
	# TODO: make unique entries
	my $targetName = $args->{name};
	#my $selfName = $char->name(); # my own name
	my $file = "$Settings::logs_folder/players_$servers[$config{'server'}]{'name'}_$config{username}.txt";
	debug (sprintf("Player Exists: %s (%s) \n", $targetName, unpack("V1", $args->{ID})), "koreShield_recorder");
	open FILE, ">>:utf8", $file;
	my $time=localtime time;
	print FILE swrite("[$time] " . $field->baseName . " ".unpack("V1", $args->{ID})." \@<<<<<<<<<<<<<<<<<<<<<<<< \@<<< \@<<<<<<<<<< \@<<<<<<<<<<<<<<<<", [$args->{name},$args->{lv}, $jobs_lut{$args->{jobID}}, $args->{guild}]);
	#print FILE $args->{name}\t$args->{lv}\t".$jobs_lut{$args->{jobID}}."\t$args->{guild}\n";
	close FILE;

}

sub core_actorInfo {
	
	return if ($core_config{disable} || $core_config{disable_core});
	my ($caller, $args) = @_;
	
	return unless $packetParser->changeToInGameState();
	
	# check monster fake name
	# my $monster = $monstersList->getByID($args->{ID}) if ($monstersList && ($caller eq "packet/actor_info"));
	# if ($monster) {
		# my $name = bytesToString($args->{name});
		# $name =~ s/^\s+|\s+$//g;
		# if (defined $monsters_lut{$monster->{nameID}} && ($monsters_lut{$monster->{nameID}} ne $name) && !$core_config{disable_detectDisguised}) {
			# warning "Detected Disguised Actor $name (should be \n";
			# error sprintf("Detected a probably disguised actor, name %s disguised as %s \n", $name, $monsters_lut{$monster->{nameID}} ), "koreShield_detect";
			# &core_eventsReaction('actor_disguised');
		# }
		# #return;
	# }
	
	#'a4 v8 V v6 a4 a2 v2 C2 a6 C2 v'
	#[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead tick shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords unknown1 unknown2 lv)]], #walking
	my $ID;
	$ID = unpack("V1", $args->{ID}) if $args->{ID};
	$ID = unpack("V1", $args->{sourceID}) if $args->{sourceID};
	$ID = $args->{player}{nameID} if $args->{player}{nameID};
	
	return if !$ID;	
	return if ($ID < 100000);
	return if ($ID eq unpack("L1", $accountID)); # won't check if it's our own ID	
	
	my $player;
	# get stored actor info
	if ($ID) {
		$player = $playersList->getByID(pack("V1", $ID)) if $playersList;
	}	
	if (isIn_Array($ID, \@{$core_databases{WHITELISTIDS}}) eq 1) {
		warning "Ignoring whitelisted ID $ID \n";
		return;
	}
	# set name 
	my $name = $player?$player->name:unpack("Z24", $args->{name});
	my $detect_reason;
	if (isIn_Array($ID, \@{$core_databases{GMIDS}}) eq 1) {
		$detect_reason = 'ID na blacklist';
	} elsif ($name && (isIn_Array_Regex(unpack("Z24", $name), \@{$core_databases{NAMES}}))) {
		$detect_reason = 'Nome na blacklist';
	} elsif (defined $player && $player->{guild} && (isIn_Array_Regex($player->{guild}{name}, \@{$core_databases{GUILD}}))) {
		$detect_reason = 'Guild na blacklist';
	} elsif (defined $player && defined $player->{headgear}{top} && $player->{headgear}{top} && (isIn_Array($player->{headgear}{top}, \@{$core_databases{EQUIPS}}))) {
		$detect_reason = sprintf("Hat top (%s) na blacklist", $player->{headgear}{top});
	} elsif (defined $player && defined $player->{headgear}{mid} && $player->{headgear}{mid} && (isIn_Array($player->{headgear}{mid}, \@{$core_databases{EQUIPS}}))) {
		$detect_reason = 'Hat mid na blacklist';
	} elsif (defined $player && defined $player->{headgear}{low} && $player->{headgear}{low} && (isIn_Array($player->{headgear}{low}, \@{$core_databases{EQUIPS}}))) {
		$detect_reason = 'Hat low na blacklist';
	} elsif (defined $player && defined $player->{weapon} && $player->{weapon} && (isIn_Array($player->{weapon}, \@{$core_databases{EQUIPS}}))) {
		$detect_reason = 'Arma na blacklist';
	} elsif (defined $player && defined $player->{shield} && $player->{shield} && (isIn_Array($player->{shield}, \@{$core_databases{EQUIPS}}))) {
		$detect_reason = sprintf("Escudo (%s) na blacklist", $player->{shield});
	} elsif (defined $player && defined $player->{party} && (isIn_Array_Regex($player->{party}{name}, \@{$core_databases{PARTY}}))) {
		$detect_reason = 'Party na blacklist';
	} elsif (defined $player && defined $player->{guild} && (isIn_Array_Regex($player->{guild}{title}, \@{$core_databases{GUILDTITLE}}))) {
		$detect_reason = 'Guild title na blacklist';
	}
	if ($detect_reason) {
		$ping_idArrayPosition = 0;
		
		my $timeStamp = time;
		my $map = $field?$field->baseName:"Unknown", ($core_mapIP && $core_mapPort)?$core_mapIP.':'.$core_mapPort:"Unknown";
		my $msg;
		$msg .= "==================== WOW GM HAS BEEN DETECTED ======================\n";
		$msg .= sprintf("Called by hook %s\n", $caller);
		$msg .= sprintf("Reason: %s\n", $detect_reason);
		$msg .= sprintf("Time: %s\n", getFormattedDate($timeStamp));
		$msg .= sprintf("Map: %s Zone: %s\n", $map);
		$msg .= sprintf("ID: %s\n", $ID);
		$msg .= sprintf("Level: %s\n", unpack("V", $args->{level})) if $args->{level};
		$msg .= sprintf("Name: %s\n", $name) if $name;
		$msg .= sprintf("Party Name: %s\n", unpack("Z24", $args->{partyName})) if defined $args->{partyName};
		$msg .= sprintf("Guild Name: %s\n", unpack("Z24", $args->{guildName})) if defined $args->{guildName};
		$msg .= sprintf("Weapon: %s\n", itemName({nameID => $player->{weapon}})) if defined $player->{weapon};
		if (defined $player->{headgear}) {
			$msg .= sprintf("Hat top: %s (%s)\n", headgearName($player->{headgear}{top}), $player->{headgear}{top});
			$msg .= sprintf("Hat mid: %s (%s)\n", headgearName($player->{headgear}{mid}), $player->{headgear}{mid});
			$msg .= sprintf("Hat low: %s (%s)\n", headgearName($player->{headgear}{low}), $player->{headgear}{low});
		}
		$msg .= sprintf("Guild Title: %s\n", unpack("Z24", $args->{guildTitle})) if $args->{guildTitle};
		$msg .= "==========================================================\n";
		
		$ReportCount++;
		#&core_eventsReaction('direct_call');
		if($LastReport_map != $map && $LastReport_id != $ID){
			#Adding info
			$LastReport_map = $map;
			$LastReport_id = $ID;
			$LastReport_time = $timeStamp;
		}
		
		
		error ($msg, "koreShield_detect");
		
		kLog($msg, 'detect_log.log');
		
		chatLog("koreShield.ping", "GM Detectado! ID: $ID Nome: ".unpack("Z24", $args->{name})." \n");
		
		foreach my $action_item (@ping_notWhileQueued) {
			if (existsInList($action_item, AI::action())) {
				error sprintf("We won't disconnect because of action: %s \n", $action_item), "koreShield_detect";
				return;
			}
		}
		#warning Data::Dumper::Dumper($player);
		if (($caller eq "packet/actor_info") && !$player->{actorType}) {
			return if ($field && $field->baseName eq 'prontera'); # workaround
			&core_eventsReaction('actor_found_normal', undef, 1);

			my $push_title;
			$push_title .= sprintf("%s detectado.", $name) if $name;

			# my $push_msg
			#pushover($push_title, sprintf("Mapa %s", ($field?$field->baseName:"Unknown")), -1);
		} else {
			&core_eventsReaction('actor_found');
			my $push_msg;
			$push_msg .= sprintf("Map: %s\n", $field?$field->baseName:"Unknown", ($core_mapIP && $core_mapPort)?$core_mapIP.':'.$core_mapPort:"Unknown");
			$push_msg .= sprintf("Nome: %s\n", $name) if $name;
			#pushover("GM - $detect_reason", $push_msg, 0);
		}
		
			
	} else {
		my $msg;
		$msg .= "=================== INFO DE DEBUG ==================\n";
		$msg .= sprintf("Called by hook %s\n", $caller);
		$msg .= sprintf("Time: %s\n", getFormattedDate(time));
		$msg .= sprintf("ID: %s\n", $ID);
		$msg .= sprintf("Level: %s\n", unpack("V", $args->{level})) if $args->{level};
		$msg .= sprintf("Nome: %s\n", $name) if $name;
		$msg .= sprintf("Nome da party: %s\n", unpack("Z24", $args->{partyName})) if defined $args->{partyName};
		$msg .= sprintf("Nome da guild: %s\n", unpack("Z24", $args->{guildName})) if defined $args->{guildName};
		$msg .= sprintf("Arma: %s\n", itemName({nameID => $player->{weapon}})) if defined $player->{weapon};
		$msg .= sprintf("Escudo: %s\n", itemName({nameID => $player->{shield}})) if defined $player->{shield};
		if (defined $player->{headgear}) {
			$msg .= sprintf("Hat top: %s (%s)\n", headgearName($player->{headgear}{top}), $player->{headgear}{top});
			$msg .= sprintf("Hat mid: %s (%s)\n", headgearName($player->{headgear}{mid}), $player->{headgear}{mid});
			$msg .= sprintf("Hat low: %s (%s)\n", headgearName($player->{headgear}{low}), $player->{headgear}{low});
		}
		$msg .= sprintf("T񝑬o na guild: %s\n", unpack("Z24", $args->{guildTitle})) if $args->{guildTitle};
		$msg .= sprintf("Vel. de Movimento: %s\n", $player->{walk_speed}) if defined $player->{walk_speed};
		$msg .= "==========================================================\n";
		debug ($msg, "koreShield_detect");
	}
}


sub kLog {
	my ($msg, $file) = @_;
	my $filename = $file;
	$filename = $servers[$config{'server'}]{'name'}.'_'.$file;
	if (open (my $log_file_fh, '>>', 'logs-koreshield/'.$filename)) {
		print $log_file_fh $msg;
		close $log_file_fh;
	} else {
	#error 'Cant open : logs-koreshield/'.$filename."\n";
	}
}

##
# updatePlayerNameCache(player)
# player: a player actor object.
*Network::Receive::updatePlayerNameCache =
*Misc::updatePlayerNameCache = sub {
	my ($player) = @_;
	
	return if (!$config{cachePlayerNames});

	# First, cleanup the cache. Remove entries that are too old.
	# Default life time: 15 minutes
	my $changed = 1;
	for (my $i = 0; $i < @playerNameCacheIDs; $i++) {
		my $ID = $playerNameCacheIDs[$i];
		if (timeOut($playerNameCache{$ID}{time}, $config{cachePlayerNames_duration})) {
			delete $playerNameCacheIDs[$i];
			delete $playerNameCache{$ID};
			$changed = 1;
		}
	}
	compactArray(\@playerNameCacheIDs) if ($changed);

	# Resize the cache if it's still too large.
	# Default cache size: 100
	while (@playerNameCacheIDs > $config{cachePlayerNames_maxSize}) {
		my $ID = shift @playerNameCacheIDs;
		delete $playerNameCache{$ID};
	}

	# Add this player name to the cache.
	my $ID = $player->{ID};
	if (!$playerNameCache{$ID}) {
	# We'll only get here if this players is new
	
		push @playerNameCacheIDs, $ID;
		my %entry = (
			ID => $player->{ID},
			name => $player->{name},
			guild => $player->{guild},
			time => time,
			lv => $player->{lv},
			jobID => $player->{jobID},
			object_type => Scalar::Util::blessed($player)
		);
		$playerNameCache{$ID} = \%entry;
		Plugins::callHook("player_added_to_cache", \%entry);
	}
};

sub core_mapLogin {	
	my ($caller, $args) = @_;
	return if ($core_config{disable} || $core_config{disable_detect});
}


sub core_mapChange_pre {
	my ($caller, $args) = @_;
	return if ($core_config{disable} || $core_config{disable_detect});
	($detectGM_actorTpInfo{map}, $detectGM_actorTpInfo{pos}{x}, $detectGM_actorTpInfo{pos}{y}) =
			($core_map, $char->{pos_to}{x}, $char->{pos_to}{y});
	
	debug (sprintf("Before TP: %s and %s and %s \n", $detectGM_actorTpInfo{map}, $detectGM_actorTpInfo{pos}{x}, $detectGM_actorTpInfo{pos}{y}), "koreShield_detect");
	
	($core_map) = unpack("Z16", $args->{map}) =~ /([\s\S]*)\./; # cut off .gat
}

sub core_mapChange_post {

	
	my ($caller, $args) = @_;
	($core_map) = unpack("Z16", $args->{map}) =~ /([\s\S]*)\./; # cut off .gat
	
	debug ("Saved core_map\n", "koreShield_detect");
	$core_mapIP = makeIP($args->{IP}) if $args->{IP};
	$core_mapPort = $args->{port} if $args->{port};
	
	return if ($core_config{disable} || $core_config{disable_detect});
	
	debug (sprintf("Before TP: %s and %s and %s \n",
					$core_map,
					$char->{pos_to}{x},
					$char->{pos_to}{y}), "koreShield_detect");
					
	if ( !$detectGM_safeTeleport && ($core_map eq $detectGM_actorTpInfo{map}) && ( $char->{pos_to}{x} eq $detectGM_actorTpInfo{pos}{x}) && ( $char->{pos_to}{y} eq $detectGM_actorTpInfo{pos}{y} ) ) {
		error("forced_teleport_same_cell, Running default reaction...\n", "koreShield_detect");
		&core_eventsReaction('forced_teleport_same_cell');
	} elsif (!$detectGM_safeTeleport) {
		error("forced_teleport, Running default reaction...\n", "koreShield_detect");
		&core_eventsReaction('forced_teleport');
	}

	&detectGM_tpFlag_off(); # safe to teleport
	foresee_map_danger($core_map);
	detectGM_checkAllowedMap($core_map);

}

sub core_mapServerInfo {
	my (undef, $args) = @_;
	($core_map) = unpack("Z16", $args->{mapName}) =~ /([\s\S]*)\./; # cut off .gat
	debug ("Saved core_map\n", "koreShield_detect");
	$core_mapIP = makeIP($args->{mapIP});
	$core_mapPort = $args->{mapPort};
	foresee_map_danger($core_map);
	detectGM_checkAllowedMap($core_map);
}

sub core_Unload {
	error("Unloading plugin...", "koreShield");
	$bus->onMessageReceived->remove($bus_server) if $bus_server;
	core_SafeUnload();
	undef $bus_server;
	undef $core_map;
	undef $core_mapIP;
	undef $core_mapPort;
	
}

sub core_Reload {
	warning("Reloading plugin...", "koreShield");
	core_SafeUnload();
}

sub core_SafeUnload {
	Plugins::delHooks($myHooks);
	Plugins::delHook($networkHook) if $networkHook;
	Commands::unregister($commands_hooks);
	undef $commands_hooks;
	undef $myHooks;
	undef $networkHook;
	undef $core_workingFolder;
	#undef $bus_server;
	#undef $core_map;
	#undef $core_mapIP;
	#undef $core_mapPort;
	undef %core_databases;
	undef %core_config;
	undef $ping_testMap;
	undef $ping_idArrayPosition;
	undef $ping_nextCheck;
	undef $ping_loopTimeStart;
	undef @ping_notWhileQueued;
	undef $detectGM_safeTeleport;
	undef %detectGM_actorTpInfo;;
	undef %ping_dangerousMaps;
}

sub core_eventsReaction {
	my ($danger, $bus_args, $ifound,$lastDanger) = @_;
	if ($bus_args) {
		debug (sprintf("From BUS:\n %s \n %s \n %s \n %s \n %s \n",
						$bus_args->{mapserver},
						$bus_args->{map},
						$bus_args->{player},
						$bus_args->{global},
						$bus_args->{danger}), "koreShield");

						
						
		return if ($config{master} ne $bus_args->{server});

		#message "someone was harmed - koreShield";
		if ($bus_args->{map}) {
			warning "adding map ".$bus_args->{map}." to dangerous list \n";
			$ping_dangerousMaps{$bus_args->{map}} = time;
		}

		if ($bus_args->{mapserver}) {
			return if ($core_config{ignore_detected_ping} || (($core_mapIP.$core_mapPort ne $bus_args->{mapserver}) && !$core_config{promiscuous_mode} && !$core_config{ping_global_halftime}));
			warning sprintf("%s detected an GM in this mapserver !\n", $bus_args->{player}), "koreShield";
		} elsif ($bus_args->{map}) {
			return if ((!$core_map || ($core_map ne $bus_args->{map})) && !$core_config{promiscuous_mode});
			warning sprintf("%s BINGO was harmed in this map!\n", $bus_args->{player}), "koreShield";
		} elsif ($bus_args->{global}) {
			warning sprintf("%s has been banned or teleported !\n", $bus_args->{player}), "koreShield";
		}
		
		#warning sprintf("BINGO Reason: %s !\n", $bus_args->{danger}), "koreShield";
	} else {
		my %args;
		$args{player} = $char->name if $char;
		if ($danger eq 'actor_found_normal') {
			$args{mapserver} = $core_mapIP.$core_mapPort;
		} elsif ($danger eq 'banned' || $danger eq 'forbidden_map') {
			$args{global} = 1
		} else {
			$args{map} = $core_map;
		}
		
		#warning "adding map ".$core_map."to dangerous list \n";
		$ping_dangerousMaps{$core_map} = time;
		
		$args{server} = $config{master};
		$args{map} = $core_map;
		$args{danger} = $danger;
		$bus->send(BUS_KORESHIELD_MID, \%args);
		#error("Sent notification to other bots.", "koreShield");
		#error sprintf("Reason: %s !\n", $danger), "koreShield";
	}
	error decode("UTF-8","================  ประเภทเหตุ เตือนภัย ".$danger."  ================\n");
	
	######### Enable Alert the whole world ###############
	my $same_map = 0;	
	if ($danger eq 'actor_found_normal' && $bus_args->{map} eq $field->baseName && $same_map eq 1) {
		warning decode("UTF-8",">>>>>  บอท ตัวอื่นได้ แจ้งงเตือน  <<<<<\n");
		warning decode("UTF-8",">>>>>  พบ GM ในแผนที่เดียวกัน  <<<<<\n");
		$ReportCount++;
	}elsif($danger eq 'actor_found_normal' && $same_map ne 1) {
		$ReportCount++;
	}
	######### Enable Alert whole world ###############
	
	if ($danger eq 'actor_found_normal' || grep {$_ eq $danger} ('direct_call','actor_found','actor_found_normal','gm_used_skill','perfect_hidden','player_muted', 'blacklisted_used_skill', 'chat_blocked')){
		## Main Action of bot ##
		if ($config{koreShield} eq 1 && $ReportCount > 0) {			
			if($field->isCity != 1 || $field->isCity == ""){
				#adding Random Time
				$BotSleepCouter = 0;	#Reset Time
				my $InstanceBotSleepCouter = $core_config{koreShieldSleep} || 1440;
				$BotSleepCouter = $InstanceBotSleepCouter + int(rand(200));
				#Utils::Win32::playSound ('C:\Windows\Media\Alarm01.wav');
				if($config{XKore} eq 1){
					Commands::run("respawn");
				}else{
					Commands::run("relog 99999");
				}
				#Enable AfterRespawn Action
				if($allowAfterRespawn eq 0){
					$allowAfterRespawn = 1;
				#$AfterRespawnTimeout = time + 5;
				}				
			}
			
		}
		##End Bot Action ####
	}
	elsif(grep {$_ eq $danger} ('banned', 'alien_skill', 'broadcast_blacklisted',
		'broadcast_nickname', 'fullstripped', 'actor_disguised',
		'monster_sanctuary', 'monster_sw', 'packet_pubMsg', 'packet_privMsg',
		'slaving_monster', 'unknown_buffed_me', 'unknown_used_skill_me',
		'passwd_reset'
		)) {	
		warning decode("UTF-8","มีสิ่งผิดปรกติ กับ ตัวละคร ด้าน..").$danger." \n";
		#Utils::Win32::playSound ('C:\Windows\Media\Alarm04.wav');
	} elsif(grep {$_ eq $danger} ('forced_status', 'gm_used_skill', 
		'forbidden_map', 'perfect_hidden', 'player_muted', 'blacklisted_used_skill', 'chat_blocked')) {
				
		#Commands::run("ai manual");
		#Commands::run("do quit");
		
	} elsif (grep {$_ eq $danger} ( 'forced_teleport_false', 'forced_teleport_same_cell')){
		my $lockMap = $config{lockMap};
		if($lockMap ne ""){
			#Utils::Win32::playSound ('C:\Windows\Media\Alarm04.wav');
			warning decode("UTF-8","หลุดออกจาก แผนที่  $lockMap \n");		
		}	
	}

}
sub AfterRespawnMaploaded{
	#Check maploaded will this active
	if($field->isCity eq 1 && $ReportCount > 0){
		$AfterRespawnTimeout = time + 5;		
	}
}
sub AfterRespawn{
	return if ($core_config{disable_after_respawn_action});
	########## stop time ########
	if($AfterRespawn_i <= 3) {
		warning "After respawn : >>>>> Action <<<<< \n" ;
		warning ">>>>> Now Teleport <<<<< \n" ;
		warning "Action count $AfterRespawn_i \n";
		
		############ do action here ############
		if (!Misc::useTeleport(1)) {
			error ("Unable to tele-search cause we can't teleport!\n");
		}
		############ End Action ###############
		
	} elsif ($AfterRespawn_i <= 15) {
		warning "After respawn : >>>>> Action <<<<< \n" ;
		warning ">>>>> Now charselect <<<<< \n" ;
		warning "Action count $AfterRespawn_i \n";
		
		############ do action here ############
		#Commands::run("charselect");
		############ End Action ###############
		
	} elsif ($AfterRespawn_i <= 30){
		warning "After respawn : >>>>> Action <<<<< \n" ;
		warning ">>>>> Now Quit <<<<< \n" ;
		warning "Action count $AfterRespawn_i \n";
		
		############ do action here ############
		#Commands::run('quit');
		############ do action here ############
		
	} elsif ($AfterRespawn_i >= 31) {
		#release allow & time
		$allowAfterRespawn = 0;
		undef $AfterRespawnTimeout;
		$AfterRespawn_i = 0;
	}
	#counting
	$AfterRespawn_i++;
}
sub T {
	return sprintf @_;
}

1;

}
