#include "Hitters.as";
#include "HittersTC.as";
#include "CommonGun.as";

void onInit(CBlob@ this)
{
	GunInitRaycast(
		this,
		true,				//If true, gun will be fully automatic and players will be able to just hold the fire button
		4.0f,				//Weapon damage / projectile blob name
		950.0f,				//Weapon raycast range
		40,					//Weapon fire delay, in ticks
		8,					//Weapon clip size
		1.00f,				//Ammo usage factor, completely ignore for now
		80,					//Weapon reload time
		false,				//If true, gun will be reloaded like a shotgun
		0,					//For shotguns: Additional delay to reload end
		1,					//Bullet count - for shotguns
		1.0f,				//Bullet Jitter
		"mat_lasbattery",	//Ammo item blob name
		true,				//If true, firing sound will be looped until player stops firing
		SoundInfo("Lasgun_Shoot",0,1.0f,1.0f),	//Sound to play when firing
		SoundInfo("Lasgun_Shoot",1,1.0f,0.8f),	//Sound to play when reloading
		SoundInfo(),						//Sound to play some time after firing
		0,					//Delay for the delayed sound, in ticks
		Vec2f(-7.0f,1.0f)	//Visual offset for raycast bullets
	);
	
	this.set_u8("gun_hitter", HittersTC::plasma);
}

void onTick(CBlob@ this)
{
	GunTick(this);
}