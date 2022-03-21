package telesearchV3fix;

use strict;
use Globals;
use Log qw(message warning error debug);
use Plugins;
use Skill qw(getHandle getIDN);
use Translation qw(T);
use Utils qw(timeOut);
use Data::Dumper;


Plugins::register('Tele-Search V3.5', 'tele-search V3.5 04_21_2021.', \&unload, \&unload);

my $hooks = Plugins::addHooks(
	['AI_post',\&search, undef],
	['packet/map_loaded', \&MapLoaded, undef],
	['Network::Receive::map_changed', \&SuspendClientManager, undef],
	['packet/map_change', \&MapLoaded, undef],
	['packet_message_string', \&onMsgstring, undef],
	['packet_skillfail', \&onMsgstring, undef]
);

#allow manage Queue
my $allowSortQueue = 0;
my ($maploaded,$allow_tele,$allow_sort_ai_v);
our @teleport_item1_index;
our @teleport_item2_index;

# Set $maploaded to 1, this incase we reload the plugin for whatever reason...
if ($net && $net->getState() == Network::IN_GAME) {
	$maploaded = 1;
}

sub unload {
	Plugins::delHooks($hooks);
	undef $maploaded;
	undef $allow_tele;
	undef $allow_sort_ai_v;
	message "Tele-Search V3.5 plugin unloading or reloading\n", 'success';
}

sub MapLoaded {
	my (undef, $args) = @_;
	$maploaded = 1;
	if (AI::inQueue("teleport")) {
		AI::clear('teleport');
	}	
	if (AI::inQueue("skill_use")) {
		AI::clear('skill_use');
	}	
}

sub checkIdle {	
	if (AI::action eq "move" && AI::action(1) eq "route" || AI::action eq "route" && !AI::inQueue("attack","skill_use", "buyAuto", "sellAuto", "storageAuto")) {
		return 1;
	} else {
		return 0;
	}
}

sub SuspendClientManager {
	my (undef, $args) = @_;		
	if($config{clear_ClientSuspend_inLockOnly} eq 1 && $field->name eq $args->{oldMap} && $field->name eq $config{lockMap} ) {
		AI::clear('clientSuspend');
	} elsif ($config{clear_ClientSuspend_inLockOnly} eq 2) {
		if (AI::inQueue("clientSuspend")) {
			AI::clear('clientSuspend');
		}
	}
}

sub minSPCondition {
	$config{teleport_search_minSp} = 15 if (!$config{teleport_search_minSp});
	if ($config{teleport_search_minSp} <= $char->{sp}) {
		return 1;
	} else {
		return 0;
	}
}

sub SellBeforeBuy{
	#manage Queue
	if (AI::inQueue("buyAuto") == 1 && $config{sellAuto} == 1 && $allowSortQueue == 0) {		
		AI::queue("sellAuto", {forcedByBuy => 2});
		$allowSortQueue = 1;
	}elsif(AI::inQueue("buyAuto") == 0 && AI::inQueue("sellAuto") == 0){
		$allowSortQueue = 0;
	}
}

sub OrderTeleportItem {
	if ($net->getState() eq Network::IN_GAME()) {
		#-------------------------------- Default item order here -----------------------
		my $default_Item1_order = "Unlimited Wing Of Fly,[Not For Sale] Novice Fly Wing,Novice Fly Wing,Beginner Fly Wing,Fly Wing";
		my $default_Item2_order = "Novice Butterfly Wing,Butterfly Wing";
		#--------------------------------------------------------------------------------
		
		#item1
		my $teleport_item1_order = !$config{teleport_item1_order} ? $default_Item1_order : $config{teleport_item1_order};
		@teleport_item1_index = $char->inventory->getMultiple($teleport_item1_order);
		#item2
		my $teleport_item2_order = !$config{teleport_item2_order} ? $default_Item2_order : $config{teleport_item2_order};
		@teleport_item2_index = $char->inventory->getMultiple($teleport_item2_order);
		
		
		my $item1 = @teleport_item1_index->[0]{name};
		#Except Beginner Fly Wing if base level >= 99
		if($char->{lv} >= 99){
			if($item1 eq "Beginner Fly Wing"){
				if(scalar(@teleport_item1_index) >= 2){
					$item1 = @teleport_item1_index->[1]{name};
				}else{
					$item1 = "";
				}
			}
		}
		#set teleportAuto_item1
		if($item1 ne "" && $config{teleportAuto_item1} ne $item1){
			message "Updated teleportAuto_item1 $item1\n";
			main::configModify('teleportAuto_item1', $item1, 1);	
		}
		
		my $item2 = @teleport_item2_index->[0]{name};
		#set teleportAuto_item2
		if($item2 ne "" && $config{teleportAuto_item2} ne $item2){
			message "Updated teleportAuto_item2 $item2\n";
			main::configModify('teleportAuto_item2', $item2, 1);	
		}
	}	
}

sub search {
	#Find teleport item order
	OrderTeleportItem();
			
	#ChangeQueue
	#SellBeforeBuy();
	
	#Tele-Search Section
	if ($config{teleport_search} && Misc::inLockMap() && $timeout{'ai_teleport_search'}{'timeout'}) {
		if ($maploaded && !$allow_tele) {
			$timeout{'ai_teleport_search'}{'time'} = time;
			$allow_tele = 1;
			
		# Check if we're allowed to teleport, if map is loaded, timeout has passed and we're just looking for targets.
		} elsif ($maploaded && $allow_tele && timeOut($timeout{'ai_teleport_search'}) && checkIdle() && minSPCondition()) {
			message "Attemping to tele-search.\n";
			$allow_tele = 0;
			$maploaded = 0;
			# Attempt to teleport, give error and unload plugin if we cant.
			if (!Misc::useTeleport(1)) {
				error ("Unable to tele-search cause we can't teleport!\n");
				return;
			}

		# We're doing something else besides looking for monsters, reset the timeout.
		} elsif (!checkIdle()) {
			$timeout{'ai_teleport_search'}{'time'} = time;
		}

		# Oops! timeouts.txt is missing a crucial value, lets use the default value ;)
	} elsif (!$timeout{'ai_teleport_search'}{'timeout'}) {
		error ("timeouts.txt missing setting! Using default timeout of 5 seconds.\n");
		$timeout{'ai_teleport_search'}{'timeout'} = 5;
		return;
	}
}
sub onMsgstring {
	my (undef, $args) = @_;
	return if ($field->isCity);
	#1924  Call Spirits	=> if stuck into loop call just go teleport By Poring
	if (AI::inQueue("skill_use") || $args->{failType} == 1 && $config{XKore} eq 1) {		
		if($args->{skillID} == 261){
			AI::clear('skill_use');
			warning ("skill_use in Queue : Cleared skillID ".$args->{skillID}."\n");
			if (!Misc::useTeleport(1)) {
				error ("Unable to teleport :: in Clear Method !\n");
				return;
			}
		}
	}
	if ($args->{index} == 1 || $args->{index} == 1924 && $config{XKore} eq 1) {
		warning ("Stuck in Teleport Window - Cleared Teleport\n");
		Commands::run('warp cancel');
		AI::clear('teleport');
		#Force Teleport 
		if (!Misc::useTeleport(1)) {
			error ("Unable to tele-search cause we can't teleport!\n");
			return;
		}
	}
}

1;