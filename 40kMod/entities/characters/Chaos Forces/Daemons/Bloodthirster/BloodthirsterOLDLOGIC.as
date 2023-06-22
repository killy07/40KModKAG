// Knight logic

#include "ThrowCommon.as"
#include "KnightCommon.as";
#include "RunnerCommon.as";
#include "Hitters.as";
#include "ShieldCommon.as";
#include "Knocked.as"
#include "Help.as";
#include "Requirements.as"

//attacks limited to the one time per-actor before reset.

void knight_actorlimit_setup(CBlob@ this)
{
	u16[] networkIDs;
	this.set("LimitedActors", networkIDs);
}

bool knight_has_hit_actor(CBlob@ this, CBlob@ actor)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.find(actor.getNetworkID()) >= 0;
}

u32 knight_hit_actor_count(CBlob@ this)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.length;
}

void knight_add_actor_limit(CBlob@ this, CBlob@ actor)
{
	this.push("LimitedActors", actor.getNetworkID());
}

void knight_clear_actor_limits(CBlob@ this)
{
	this.clear("LimitedActors");
}

void onInit(CBlob@ this)
{
	this.Tag("no drown");

	KnightInfo knight;
	knight.state = KnightStates::normal;
	knight.swordTimer = 0;
	knight.slideTime = 0;
	knight.doubleslash = false;
	knight.tileDestructionLimiter = 0;
	this.set("knightInfo", @knight);

	CSprite@ sprite = this.getSprite();

	CSpriteLayer@ wings = this.getSprite().addSpriteLayer("bloodthirsterwings", "BloodthirsterWings.png", 133, 100);
	if (wings !is null)
	{
		Animation@ anim = wings.addAnimation("flap", 2, false);		
		anim.AddFrame(4);
		anim.AddFrame(4);		
		anim.AddFrame(5);
		anim.AddFrame(5);		
		anim.AddFrame(6);
		anim.AddFrame(6);		
		anim.AddFrame(7);
		anim.AddFrame(7);		
		anim.AddFrame(8);
		anim.AddFrame(8);		
		anim.AddFrame(0);
		anim.AddFrame(1);
		anim.AddFrame(1);
		anim.AddFrame(2);
		anim.AddFrame(2);		
		anim.AddFrame(3);
		anim.AddFrame(3);
		
		wings.SetOffset(Vec2f(20, -25));
		wings.SetRelativeZ(-10);
	}
		
	this.set_f32("gib health", -3.0f);
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;
	this.Tag("player");
	this.Tag("flesh");

	this.set_u8("override head", 102);
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));

	this.getCurrentScript().runFlags |= Script::tick_not_attached;

	this.SetLight(true);
	this.SetLightRadius(64.0f);
	this.SetLightColor(SColor(255, 0, 0, 0));
	
	if (isClient())
	{
		CSprite@ sprite = this.getSprite();
		sprite.SetEmitSound("BloodthirsterTheme.ogg");
		sprite.SetEmitSoundVolume(2.5f);
		sprite.SetEmitSoundPaused(false);
	}
}

void onInit(CSprite@ this)
{

}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null) player.SetScoreboardVars("ScoreboardIcons.png", 12, Vec2f(16, 16));
}

void onTick(CSprite@ this)
{

}

void onTick(CBlob@ this)
{
	u8 knocked = getKnocked(this);
	
	if (this.isInInventory())
		return;

	RunnerMoveVars@ moveVars;
	if (!this.get("moveVars", @moveVars))
	{
		return;
	}

	Vec2f pos = this.getPosition();
	Vec2f aimpos = this.getAimPos();
	const bool inair = (!this.isOnGround() && !this.isOnLadder());

	CMap@ map = getMap();

	bool pressed_a1 = this.isKeyPressed(key_action1) && !this.hasTag("noLMB");
	bool pressed_a2 = this.isKeyPressed(key_action2);
	bool walking = (this.isKeyPressed(key_left) || this.isKeyPressed(key_right));

	const bool myplayer = this.isMyPlayer();

	if (myplayer)
	{
		if (this.isKeyJustPressed(key_action3))
		{
			client_SendThrowOrActivateCommand(this);
		}
	}

	moveVars.walkFactor *= 1.20f;
	moveVars.jumpFactor *= 0.90f;
	if (getGameTime() >= this.get_u32("nextWingsJump"))
	{
		if (this.isKeyJustPressed(key_action2) && !this.isOnGround())
		{
			Vec2f vel = this.getAimPos() - this.getPosition();
			vel.Normalize();
			vel.x *= 2.00f;
			vel.y = -12.00f;
			
			this.setVelocity((this.getVelocity() * 0.25f) + vel);
			this.set_u32("nextWingsJump", getGameTime() + 15);
				
			CSpriteLayer@ wings = this.getSprite().getSpriteLayer("bloodthirsterwings");
			if (wings !is null)
			{
				wings.SetAnimation("flap");
					
				Animation@ animation = wings.getAnimation("flap");
				if (animation !is null)
				{
					animation.SetFrameIndex(0);
				}
			}
		}
	}
	if (knocked > 0)
	{
		pressed_a1 = false;
		pressed_a2 = false;
		walking = false;
		
		return;
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	CPlayer@ player = this.getPlayer();

	if (this.hasTag("invincible") || (player !is null && player.freeze)) 
	{
		return 0;
	}

	switch (customData)
	{
		case Hitters::suicide:
			damage *= 10.0f;
			break;

		case Hitters::explosion:
		case Hitters::keg:
		case Hitters::mine:
		case Hitters::mine_special:
		case Hitters::bomb:
		case Hitters::arrow:
		case Hitters::stab:
		case Hitters::sword:
			damage *= 0.50f;
			break;

		case Hitters::fall:
			damage *= 0.00f;
			break;
			
		case Hitters::burn:
		case Hitters::fire:
		case Hitters::drown:
		case Hitters::water:
		case Hitters::water_stun:
		case Hitters::water_stun_force:
			damage = 0.00f;
			break;
			
		default:
			damage *= 0.80f;
			break;
	}

	return damage;
}

