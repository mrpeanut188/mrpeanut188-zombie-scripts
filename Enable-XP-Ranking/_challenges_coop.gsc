//|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
//|||| Name			: _challenges_coop.gsc
//|||| Info			: Enables XP ranking for zombies.
//|||| Site			: aviacreations.com
//|||| Author		: Mrpeanut188
//|||| Notes		: v3 (Solo ranking)
//|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
/*
	Use getRank() and getRankXP() to retrieve rank. Solo has seperate ranking progress that is stored in DVARS instead of the stats.
	This means DVARS are NOT saved specific to mod, any maps using this script will share solo XP.
	
	Installation:
		Place in mods/MAPNAME/maps and replace if necessary.
		
		mapname.gsc:
			players = getPlayers();
			for (i = 0; i < players.size; i++)
				players[i] thread maps\_challenges_coop::xpWatcher();
		
		_zombiemode_spawner.gsc:
		Add:
			maps\_challenges_coop::setXPReward( zombie.attacker, zombie.damageloc, zombie.damagemod );
		
		Before: 
			zombie.attacker notify("zom_kill");
		
		After:
			maps\_challenges_coop::setXPReward( zombie.attacker, zombie.damageloc, zombie.damagemod );
			zombie.attacker notify("zom_kill");		
*/

#include maps\_utility;
#include maps\_zombiemode_utility;

init()
{

	// ================================= SETTINGS =================================
	level.zombie_vars[ "xp_base" ] 			= 5; 		// XP awarded per kill
	level.zombie_vars[ "xp_headshot" ] 		= 8; 		// XP awarded per headshot kill
	level.zombie_vars[ "xp_knife" ] 		= 12; 		// XP awarded per melee kill
	// ================================= SETTINGS =================================

	rank_init();
	
	level.xpScale = getDvarInt( "scr_xpscale" );
	if (level.xpScale == 0)
		level.xpScale = 1;
		
	level thread onPlayerConnect();
}

setXPReward( player, damageloc, damagemod )
{
	if ( damagemod == "MOD_HEAD_SHOT" )
		player.xpReward = level.zombie_vars[ "xp_headshot" ];
	if ( damagemod == "MOD_MELEE" )
		player.xpReward = level.zombie_vars[ "xp_knife" ];
}

xpWatcher()
{
	self endon( "disconnect" );

	while (1)
	{
		self waittill( "zom_kill" );
		if (isCoopEPD())
			giveRankXP( self.xpReward );
		else
			giveSoloRankXP( self.xpReward );
		self.xpReward = level.zombie_vars[ "xp_base" ];
	}
}

mayGenerateAfterActionReport()
{	
	if ( isCoopEPD() )
		return false;
}

onPlayerConnect()
{
	for(;;)
	{
		level waittill( "connected", player );
		if (isCoopEPD())
			player.rankxp = player statGet( "rankxp" );
		else
			player.rankxp = getDvarInt( "rank_xp_solo" );
		rankId = player getRankForXp( player getRankXP() );
		player.rank = rankId;
	
		prestige = player getPrestigeLevel();
		player setRank( rankId, prestige );
		player.prestige = prestige;

		// Setting Summary Variables to Zero
		player.summary_xp = 0;
		player.summary_challenge = 0;
		
		// resetting game summary dvars
		player setClientDvars( 	"psn", player.playername,
								"psx", "0",
								"pss", "0",
								"psc", "0",
								"psk", "0",
								"psd", "0",
								"psr", "0",
								"psh", "0", 
								"psa", "0",								
								"ui_lobbypopup", "summary");
	}
}

onSaveRestored()
{
	players = get_players();
	for( i = 0; i < players.size; i++)
	{
		if (isCoopEPD())	
			players[i].rankxp = players[i] statGet( "rankxp" );
		else
			players[i].rankxp = getDvarInt( "rank_xp_solo" );
			
		rankId = players[i] getRankForXp( players[i] getRankXP() );
		players[i].rank = rankId;

		prestige = players[i] getPrestigeLevel();
		players[i] setRank( rankId, prestige );
		players[i].prestige = prestige;		
	}
}

createCacheSummary()
{
	self.cached_summary_xp = 0;
	self.cached_score = 0;
	self.cached_summary_challenge = 0;
	self.cached_kills =  0;
	self.cached_downs = 0;
	self.cached_assists = 0;
	self.cached_headshots = 0;
	self.cached_revives = 0;
	
	self.summary_cache_created = true;
}

buildSummaryArray()
{
	summaryArray = [];

	if(self.cached_summary_xp != self.summary_xp)
	{
		summaryArray[summaryArray.size] = "psx";
		summaryArray[summaryArray.size] = self.summary_xp;
		self.cached_summary_xp = self.summary_xp;
	}	

	if(self.cached_score != self.score)
	{
		summaryArray[summaryArray.size] = "pss";
		summaryArray[summaryArray.size] = self.score;
		self.cached_score = self.score;
	}
	
	if(self.cached_downs != self.downs)
	{
		summaryArray[summaryArray.size] = "psd";
		summaryArray[summaryArray.size] = self.downs;
		self.cached_downs = self.downs;
	}

	if(self.cached_headshots != self.headshots)
	{
		summaryArray[summaryArray.size] = "psh";
		summaryArray[summaryArray.size] = self.headshots;
		self.cached_headshots = self.headshots;
	}

	if(self.cached_kills != self.kills - self.headshots)
	{
		summaryArray[summaryArray.size] = "psk";
		summaryArray[summaryArray.size] = self.kills - self.headshots;
		self.cached_kills = self.kills - self.headshots;
	}
	
	if(self.cached_revives != self.revives)
	{
		summaryArray[summaryArray.size] = "psr";
		summaryArray[summaryArray.size] = self.revives;
		self.cached_revives = self.revives;
	}
	
	if(self.cached_assists != self.assists)
	{
		summaryArray[summaryArray.size] = "psa";
		summaryArray[summaryArray.size] = self.assists;
		self.cached_assists = self.assists;
	}	
		
	return summaryArray;
}

updateMatchSummary( callback )
{
	forceUpdate = ( IsDefined(callback) && (callback == "levelEnd" || callback == "checkpointLoaded") );

	if( OkToSpawn() || forceUpdate )
	{
		if( !isdefined(self.summary_cache_created) || callback == "checkpointLoaded" )
		{
			self createCacheSummary();
		}
	
		summary = self buildSummaryArray();
		
		if(summary.size > 0)
		{
			switch(summary.size)	// Vile.
			{
				case 2:
					self setClientDvars(summary[0], summary[1]);
					break;
				case 4:
					self setClientDvars(summary[0], summary[1], summary[2], summary[3]);
					break;
				case 6:
					self setClientDvars(summary[0], summary[1], summary[2], summary[3], summary[4], summary[5]);
					break;
				case 8:
					self setClientDvars(summary[0], summary[1], summary[2], summary[3], summary[4], summary[5], summary[6], summary[7]);
					break;
				case 10:
					self setClientDvars(summary[0], summary[1], summary[2], summary[3], summary[4], summary[5], summary[6], summary[7], summary[8], summary[9]);
					break;
				case 12:
					self setClientDvars(summary[0], summary[1], summary[2], summary[3], summary[4], summary[5], summary[6], summary[7], summary[8], summary[9], summary[10], summary[11]);
					break;
				case 14:
					self setClientDvars(summary[0], summary[1], summary[2], summary[3], summary[4], summary[5], summary[6], summary[7], summary[8], summary[9], summary[10], summary[11], summary[12], summary[13]);
					break;
				case 16:
					self setClientDvars(summary[0], summary[1], summary[2], summary[3], summary[4], summary[5], summary[6], summary[7], summary[8], summary[9], summary[10], summary[11], summary[12], summary[13], summary[14], summary[15]);
					break;
				case 18:
					self setClientDvars(summary[0], summary[1], summary[2], summary[3], summary[4], summary[5], summary[6], summary[7], summary[8], summary[9], summary[10], summary[11], summary[12], summary[13], summary[14], summary[15], summary[16], summary[17]);
					break;
				default:
					assertex("Unexpected number of elements in summary array.");
			}
			
			println("*** Summary sent " + (summary.size / 2) + " elements.");
		}
		
	}
}

registerMissionCallback(callback, func)
{
	return;
}

rank_init()
{
	// Set up the lookup tables for fetching rank data
	level.rankTable = [];

	level.maxRank = int(tableLookup( "mp/rankTable.csv", 0, "maxrank", 1 ));
	level.maxPrestige = int(tableLookup( "mp/rankIconTable.csv", 0, "maxprestige", 1 ));

	pId = 0;
	rId = 0;
	// Precaching the rank icons
	for ( pId = 0; pId <= level.maxPrestige; pId++ )
	{
		for ( rId = 0; rId <= level.maxRank; rId++ )
			precacheShader( tableLookup( "mp/rankIconTable.csv", 0, rId, pId+1 ) );
	}

	rankId = 0;
	rankName = tableLookup( "mp/ranktable.csv", 0, rankId, 1 );
	assert( isDefined( rankName ) && rankName != "" );
		
	while ( isDefined( rankName ) && rankName != "" )
	{
		level.rankTable[rankId][1] = tableLookup( "mp/ranktable.csv", 0, rankId, 1 );
		level.rankTable[rankId][2] = tableLookup( "mp/ranktable.csv", 0, rankId, 2 );
		level.rankTable[rankId][3] = tableLookup( "mp/ranktable.csv", 0, rankId, 3 );
		level.rankTable[rankId][7] = tableLookup( "mp/ranktable.csv", 0, rankId, 7 );

		rankId++;
		rankName = tableLookup( "mp/ranktable.csv", 0, rankId, 1 );		
	}

	level.numChallengeTiers	= 4;
	level.numChallengeTiersMP = 12;

	// Precaching the strings
	precacheString( &"RANK_PLAYER_WAS_PROMOTED_N" );
	precacheString( &"RANK_PLAYER_WAS_PROMOTED" );
	precacheString( &"RANK_PROMOTED" );
	precacheString( &"MP_PLUS" );
	precacheString( &"RANK_ROMANI" );
	precacheString( &"RANK_ROMANII" );
	precacheString( &"RANK_ROMANIII" );
}

giveRankXP( value, levelEnd )
{
	self endon("disconnect");

	if(	!isDefined( levelEnd ) )
	{
		levelEnd = false;
	}	
	
	value = int( value * level.xpScale );

	self incRankXP( value );

	if ( updateRank() && false == levelEnd )
		self thread updateRankAnnounceHUD();

	// Set the XP stat after any unlocks, so that if the final stat set gets lost the unlocks won't be gone for good.
	self syncXPStat();
}

giveSoloRankXP( value, levelEnd )
{
	self endon("disconnect");

	if(	!isDefined( levelEnd ) )
	{
		levelEnd = false;
	}	
	
	value = (getDvarInt("rank_xp_solo") + int( value * level.xpScale ));
	setDvar( "rank_xp_solo", value );

	if ( updateRank() && levelEnd == false )
		self thread updateRankAnnounceHUD();
}

updateRankAnnounceHUD()
{
	self endon("disconnect");

	self notify("update_rank");
	self endon("update_rank");
	
	self notify("reset_outcome");
	newRankName = self getRankInfoFull( self.rank );
	
	notifyData = spawnStruct();

	notifyData.titleText = &"RANK_PROMOTED";
	notifyData.iconName = self getRankInfoIcon( self.rank, self.prestige );
	notifyData.sound = "mp_level_up";
	notifyData.duration = 4.0;
	
	rank_char = level.rankTable[self.rank][1];
	subRank = int(rank_char[rank_char.size-1]);
	
	if ( subRank == 2 )
	{
		notifyData.textLabel = newRankName;
		notifyData.notifyText = &"RANK_ROMANI";
		notifyData.textIsString = true;
	}
	else if ( subRank == 3 )
	{
		notifyData.textLabel = newRankName;
		notifyData.notifyText = &"RANK_ROMANII";
		notifyData.textIsString = true;
	}
	else if ( subRank == 4 )
	{
		notifyData.textLabel = newRankName;
		notifyData.notifyText = &"RANK_ROMANIII";
		notifyData.textIsString = true;
	}
	else
	{
		notifyData.notifyText = newRankName;
	}

	self thread maps\_hud_message::notifyMessage( notifyData );
}

updateRank()
{
	newRankId = self getRank();
	if ( newRankId == self.rank )
		return false;

	oldRank = self.rank;
	rankId = self.rank;
	self.rank = newRankId;

	while ( rankId <= newRankId )
	{	
		self statSet( "rank", rankId );
		self statSet( "minxp", int(level.rankTable[rankId][2]) );
		self statSet( "maxxp", int(level.rankTable[rankId][7]) );
	
		// set current new rank index to stat#252
		if (isCoopEPD())
			self setStat( 252, rankId );
		else
			setDvar( "rank_solo", rankId );

		rankId++;
	}

	if (isCoopEPD())
		self setRank( newRankId );
	else
		setDvar( "rank_solo", newRankId );
	
	return true;
}

getPrestigeLevel()
{
	if (isCoopEPD())
		return self statGet( "plevel" );
	else
		return getDvarInt( "rank_prestige_solo" );
}

getRank()
{	
	if (isCoopEPD())
	{
		rankXp = self.rankxp;
		rankId = self.rank;
	}
	else
	{
		rankXp = getDvarInt( "rank_xp_solo" );
		rankId = getDvarInt( "rank_solo" );
	}
	


	if ( rankXp < (getRankInfoMinXP( rankId ) + getRankInfoXPAmt( rankId )) )
		return rankId;
	else
		return self getRankForXp( rankXp );
}

getRankXP()
{
	if (isCoopEPD())
		return self.rankxp;
	else
		return getDvarInt("rank_xp_solo");
}

getRankForXp( xpVal )
{
	rankId = 0;
	rankName = level.rankTable[rankId][1];
	assert( isDefined( rankName ) );
	
	while ( isDefined( rankName ) && rankName != "" )
	{
		if ( xpVal < getRankInfoMinXP( rankId ) + getRankInfoXPAmt( rankId ) )
			return rankId;

		rankId++;
		if ( isDefined( level.rankTable[rankId] ) )
			rankName = level.rankTable[rankId][1];
		else
			rankName = undefined;
	}
	
	rankId--;
	return rankId;
}

getRankInfoMinXP( rankId )
{
	return int(level.rankTable[rankId][2]);
}

getRankInfoXPAmt( rankId )
{
	return int(level.rankTable[rankId][3]);
}

getRankInfoMaxXp( rankId )
{
	return int(level.rankTable[rankId][7]);
}

getRankInfoFull( rankId )
{
	return tableLookupIString( "mp/ranktable.csv", 0, rankId, 16 );
}

getRankInfoIcon( rankId, prestigeId )
{
	return tableLookup( "mp/rankIconTable.csv", 0, rankId, prestigeId+1 );
}

incRankXP( amount )
{
	xp = self getRankXP();
	newXp = (xp + amount);

	if ( self.rank == level.maxRank && newXp >= getRankInfoMaxXP( level.maxRank ) )
		newXp = getRankInfoMaxXP( level.maxRank );

	self.rankxp = newXp;
}

syncXPStat()
{
	xp = self getRankXP();
	if (isCoopEPD())
		self statSet( "rankxp", xp );
	else 
		setDvar( "rank_xp_solo", xp );
}

doMissionCallback( callback, data )
{
	return;
}

statSet( dataName, value )
{
	self setStat( int(tableLookup( "mp/playerStatsTable.csv", 1, dataName, 0 )), value );	
}

statGet( dataName )
{	
	return self getStat( int(tableLookup( "mp/playerStatsTable.csv", 1, dataName, 0 )) );
}

statAdd( dataName, value )
{	
	curValue = self getStat( int(tableLookup( "mp/playerStatsTable.csv", 1, dataName, 0 )) );
	self setStat( int(tableLookup( "mp/playerStatsTable.csv", 1, dataName, 0 )), value + curValue );
}