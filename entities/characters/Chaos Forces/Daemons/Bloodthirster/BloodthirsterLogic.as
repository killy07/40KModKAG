// Bloodthirster logic

#include "ThrowCommon.as"
#include "BloodthirsterCommon.as";
#include "KnightCommon.as";
#include "RunnerCommon.as";
#include "HittersTC.as";
#include "Hitters.as";
#include "ShieldCommon.as";
#include "Help.as";
#include "Requirements.as";
#include "SplashWater.as"
#include "ParticleSparks.as";
#include "FireCommon.as";



//attacks limited to the one time per-actor before reset.

void bloodthirster_actorlimit_setup(CBlob@ this)
{
	u16[] networkIDs;
	this.set("LimitedActors",networkIDs);
}

bool bloodthirster_has_hit_actor(CBlob@ this,CBlob@ actor)
{
	u16[]@ networkIDs;
	this.get("LimitedActors",@networkIDs);
	return networkIDs.find(actor.getNetworkID()) >= 0;
}

u32 bloodthirster_hit_actor_count(CBlob@ this)
{
	u16[]@ networkIDs;
	this.get("LimitedActors",@networkIDs);
	return networkIDs.length;
}

void bloodthirster_add_actor_limit(CBlob@ this,CBlob@ actor)
{
	this.push("LimitedActors",actor.getNetworkID());
}

void bloodthirster_clear_actor_limits(CBlob@ this)
{
	this.clear("LimitedActors");
}

void onInit(CBlob@ this)
{
	this.Tag("bloodthirster");
	
	BloodthirsterInfo bloodthirster;

	bloodthirster.state=		BloodthirsterStates::normal;
	bloodthirster.prevState=	BloodthirsterStates::normal;
	bloodthirster.actionTimer=	0;
	bloodthirster.attackDelay=	0;
	bloodthirster.goFatality=	false;
	bloodthirster.normalSprite=true;
	bloodthirster.tileDestructionLimiter=0;
	bloodthirster.dontHitMore=false;

	this.set("BloodthirsterInfo",@bloodthirster);
	
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
		
	this.set_f32("gib health",0.0f);
	this.set_s16(burn_duration,360);
	addShieldVars(this,SHIELD_BLOCK_ANGLE,2.0f,5.0f);
	bloodthirster_actorlimit_setup(this);
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().net_threshold_multiplier=	0.5f;
	this.Tag("player");
	this.Tag("flesh");

	this.set_Vec2f("inventory offset",Vec2f(0.0f,0.0f));

	SetHelp(this,"help self action","bloodthirster","$Slash$ Slash!    $KEY_HOLD$$LMB$","",13);
	SetHelp(this,"help self action2","bloodthirster","$Shield$Shield    $KEY_HOLD$$RMB$","",13);

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag=	"dead";
		
	this.addCommandID("grabbedSomeone");
	this.addCommandID("throw");
	this.addCommandID("goFatality");
	this.addCommandID("goFatalityReal");
		
	this.set_string("grabbedEnemy","knight");

int playerCount=getPlayerCount();
	for(int i=0;i<playerCount;i++) {
		CPlayer@ player=	getPlayer(i);
		}
	if (isClient()){
		CSprite@ sprite = this.getSprite();
		sprite.SetEmitSound("BloodthirsterTheme.ogg");
		sprite.SetEmitSoundVolume(2.5f);
		sprite.SetEmitSoundPaused(false);
	}
}


f32 Lerp(f32 a,f32 b,f32 time)
{
	return a+(b-a)*Maths::Min(1.0,Maths::Max(0.0,time));
}

void onSetPlayer(CBlob@ this,CPlayer@ player)
{
	if(player !is null)
	{
		player.SetScoreboardVars("ScoreboardIcons.png",3,Vec2f(16,16));
	}
}


void onTick(CBlob@ this)
{
	RunnerMoveVars@ moveVars;
	if(!this.get("moveVars",@moveVars)) {
		return;
	}
	BloodthirsterInfo@ bloodthirster;
	if(!this.get("BloodthirsterInfo",@bloodthirster)) {
		return;
	}
	bloodthirster.prevState=	bloodthirster.state;
	
	Vec2f vec;
	Vec2f aimPos=		this.getAimPos();
	const int direction=this.getAimDirection(vec);
	const f32 side=		(this.isFacingLeft() ? 1.0f : -1.0f);
	
	Vec2f pos=			this.getPosition();
	Vec2f vel=			this.getVelocity();
	bool isInAir=		(!this.isOnGround() && !this.isOnLadder());
	const bool isMyPlayer=	this.isMyPlayer();
	
	bool pressed_lmb=	this.isKeyPressed(key_action1) && !this.hasTag("noLMB");
	bool pressed_rmb=	this.isKeyPressed(key_action2) && !this.hasTag("noLMB");
	
	float attackJumpFactor=	0.375f;
	float attackWalkFactor=	0.4f;
	bool extraSync=	false;
	
	if(isMyPlayer) {
		getHUD().SetCursorFrame(0);
	}
	
	if(bloodthirster.state==BloodthirsterStates::stun)
	{
		moveVars.jumpFactor=		0.0f;
		moveVars.walkFactor=		0.0f;
		bloodthirster.actionTimer=		0;
		bloodthirster.actionTimer=		0;
		bloodthirster.goFatality=		false;
		bloodthirster.forceFatality=	false;
		bloodthirster.dontHitMore=		false;
		bloodthirster.stun--;
		if(bloodthirster.stun<=0){
			bloodthirster.state=BloodthirsterStates::normal;
		}
	}
	else if(bloodthirster.state==BloodthirsterStates::normal)
	{
		//Normal
		if(bloodthirster.attackDelay>0){
			bloodthirster.attackDelay--;
		}else if(pressed_lmb){
			bloodthirster.state=			BloodthirsterStates::charging;
			bloodthirster.actionTimer=		0;
			bloodthirster.goFatality=		false;
			bloodthirster.forceFatality=	false;
			bloodthirster.dontHitMore=		false;
		}
		if(pressed_rmb){
			f32 angle=	   -((this.getAimPos()-pos).getAngleDegrees());
			if(angle<0.0f)	{angle+=360.0f;}
			Vec2f dir=		Vec2f(1.0f,0.0f).RotateBy(angle);
			bloodthirster.attackDirection=	dir;
			bloodthirster.attackAimPos=	this.getAimPos();
			bloodthirster.attackRot=		angle;
			angle=			(this.getAimPos()-pos).Angle();
			bloodthirster.attackTrueRot=	angle;
			
			bloodthirster.wasFacingLeft=	this.isFacingLeft();
			bloodthirster.state=			BloodthirsterStates::grabbing;
			bloodthirster.actionTimer=		0;
			bloodthirster.goFatality=		false;
			bloodthirster.forceFatality=	false;
			bloodthirster.dontHitMore=		false;
			
			if(getNet().isClient()){
				Sound::Play("/ArgLong",this.getPosition());
			}
		}
	}
	else if(bloodthirster.state==BloodthirsterStates::charging)
	{
		//Charging hammer attack
		moveVars.jumpFactor*=	attackJumpFactor;
		moveVars.walkFactor*=	attackWalkFactor;
		bloodthirster.actionTimer+=1;
		
		f32 angle=	   -((this.getAimPos()-pos).getAngleDegrees());
		if(angle<0.0f)	{angle+=360.0f;}
		Vec2f dir=		Vec2f(1.0f,0.0f).RotateBy(angle);
		bloodthirster.attackDirection=	dir;
		bloodthirster.attackAimPos=	this.getAimPos();
		bloodthirster.attackRot=		angle;
		angle=						(this.getAimPos()-pos).Angle();
		bloodthirster.attackTrueRot=	angle;
		
		bloodthirster.wasFacingLeft=	this.isFacingLeft();
		
		if(bloodthirster.actionTimer>=BloodthirsterVars::chargeTime){
			bloodthirster.state=			BloodthirsterStates::chargedAttack;
			bloodthirster.actionTimer=		0;
			bloodthirster.goFatality=		false;
			bloodthirster.forceFatality=	false;
			bloodthirster.dontHitMore=		false;
			
			if(getNet().isClient()){
				Sound::Play("/ArgLong",this.getPosition());
				PlaySoundRanged(this,"SwingHeavy",4,1.0f,1.0f);
			}
			Vec2f force=bloodthirster.attackDirection*this.getMass()*3.0f;
			this.AddForce(force);
		}
	}
	else if(bloodthirster.state==BloodthirsterStates::chargedAttack)
	{
		//Attacking with the hammer
		moveVars.jumpFactor*=	attackJumpFactor;
		moveVars.walkFactor*=	attackWalkFactor;
		this.SetFacingLeft(bloodthirster.wasFacingLeft);
		
		if(bloodthirster.actionTimer>=BloodthirsterVars::attackTime){
			bloodthirster.state=			BloodthirsterStates::normal;
			bloodthirster.actionTimer=		0;
			bloodthirster.goFatality=		false;
			bloodthirster.forceFatality=	false;
			bloodthirster.dontHitMore=		false;
			bloodthirster.attackDelay=BloodthirsterVars::attackDelay;
		}else{
			if(bloodthirster.actionTimer<12){
				DoAttack(this,2.0f,bloodthirster,120.0f,HittersTC::hammer,bloodthirster.actionTimer);
			}
		}
		bloodthirster.actionTimer+=1;
	}
	else if(bloodthirster.state==BloodthirsterStates::grabbing)
	{
		//Trying to grab a stunned enemy
		moveVars.jumpFactor*=	attackJumpFactor;
		moveVars.walkFactor*=	attackWalkFactor;
		this.SetFacingLeft(bloodthirster.wasFacingLeft);
		
		if(bloodthirster.actionTimer>=BloodthirsterVars::grabTime){
			bloodthirster.state=			BloodthirsterStates::normal;
			bloodthirster.actionTimer=		0;
			bloodthirster.goFatality=		false;
			bloodthirster.forceFatality=	false;
			bloodthirster.dontHitMore=		false;
			bloodthirster.attackDelay=		BloodthirsterVars::attackDelay*2;
		}else{
			if(getNet().isServer() && bloodthirster.actionTimer<=(BloodthirsterVars::grabTime/4)*3 && bloodthirster.dontHitMore==false){
				//Grab
				const float range=	26.0f; //36.0f originally
				f32 angle=	bloodthirster.attackRot;
				Vec2f dir=	bloodthirster.attackDirection;
				
				Vec2f startPos=	this.getPosition()+Vec2f(0.0f,5.0f);
				Vec2f endPos=	startPos+(dir*range);
			
				HitInfo@[] hitInfos;
				Vec2f hitPos;
				bool mapHit=getMap().rayCastSolid(startPos,endPos,hitPos);
				f32 length=	(hitPos-startPos).Length();
				
				bool blobHit=	getMap().getHitInfosFromRay(startPos,angle,length,this,@hitInfos);
				
				if(blobHit) {
					for(u32 i=0;i<hitInfos.length;i++) {
						if(hitInfos[i].blob !is null) {	
							CBlob@ blob=	hitInfos[i].blob;
							if((blob.getConfig()=="knight" || blob.getConfig()=="crossbowman" || blob.getConfig()=="trader") && blob.getTeamNum()!=this.getTeamNum() && !blob.hasTag("dead")) {
								if(blob.getConfig()=="knight"){
									if(blockAttack(blob,dir,0.0f)){
										Sound::Play("Entities/Characters/Knight/ShieldHit.ogg",pos);
										sparks(pos,-dir.Angle(),Maths::Max(10.0f*0.05f,1.0f));
										bloodthirster.dontHitMore=true;
										break;
									}else{
										KnightInfo@ knight;
										if(this.get("KnightInfo",@knight)) {
											if(inMiddleOfAttack(knight.state)){
												bloodthirster.dontHitMore=true;
												break;
											}
										}
									}
								}
								if(blob.getHealth()<=0.5f || IsKnocked(blob) || blob.getConfig()=="crossbowman" || blob.getConfig()=="trader"){
									CPlayer@ player=blob.getPlayer();
									if(player !is null){
										CBlob@ newBlob=	server_CreateBlob("playercontainer",0,this.getPosition());
										if(newBlob !is null){
											newBlob.server_SetPlayer(player);
											AttachmentPoint@ point=	this.getAttachments().getAttachmentPointByName("PICKUP");
											this.server_AttachTo(newBlob,point);
											newBlob.server_setTeamNum(blob.getTeamNum());
											player.server_setTeamNum(blob.getTeamNum());
										}
									}
									blob.server_Die();
									
									CBitStream stream;
										stream.write_string(blob.getConfig());
									this.SendCommand(this.getCommandID("grabbedSomeone"),stream);
									bloodthirster.state=BloodthirsterStates::grabbed;
								}else{
									this.server_Hit(blob,this.getPosition(),dir,1.0f,Hitters::flying,false);
								}
								bloodthirster.dontHitMore=true;
								break;
							}
						}
					}
				}
				bloodthirster.goFatality=		false;
				bloodthirster.forceFatality=	false;
			}
		}
		bloodthirster.actionTimer+=1;
	}else if(bloodthirster.state==BloodthirsterStates::grabbed) {
		//Holding someone by the neck
		if(bloodthirster.attackDelay>0){
			bloodthirster.attackDelay--;
		}else if(pressed_lmb && !bloodthirster.goFatality && !bloodthirster.forceFatality){
			f32 angle=					(this.getAimPos()-pos).Angle();
			bloodthirster.attackTrueRot=	angle;
			
			bloodthirster.state=		BloodthirsterStates::throwing;
			bloodthirster.actionTimer=	0;
			bloodthirster.dontHitMore=	false;
			if(getNet().isClient()){
				Sound::Play("/ArgLong",this.getPosition());
			}
			if(getNet().isServer()){
				f32 angle=	-((this.getAimPos()-pos).getAngleDegrees());
				if(angle<0.0f){
					angle+=360.0f;
				}
				string config=	this.get_string("grabbedEnemy");
				Vec2f dir=Vec2f(1.0f,0.0f).RotateBy(angle);
				CBlob@ blob=server_CreateBlob(config=="crossbowman" ? "corpsecrossbowman" : (config=="trader" ? "corpsetrader" : "corpseknight"),this.getTeamNum(),pos);
				
				AttachmentPoint@ point=	this.getAttachments().getAttachmentPointByName("PICKUP");
				CBlob@ attachedBlob=	point.getOccupied();
				if(attachedBlob !is null){
					CPlayer@ attachedPlayer=	attachedBlob.getPlayer();
					if(attachedPlayer !is null){
						blob.server_SetPlayer(attachedPlayer);
					}
					attachedBlob.server_Die();
				}
				if(blob !is null){
					blob.setVelocity(dir*12.0f);
					if(this.getPlayer() !is null){
						blob.SetDamageOwnerPlayer(this.getPlayer());
					}
				}
				extraSync=	true;
				//this.SendCommand(this.getCommandID("throw"));
			}
		}else if(pressed_rmb && this.isKeyJustPressed(key_action2) && !bloodthirster.goFatality && this.get_string("grabbedEnemy")!="trader"){
			/*if(getNet().isClient() && isMyPlayer){
				CBitStream stream;
				this.SendCommandOnlyServer(this.getCommandID("goFatality"),stream);
			}*/
			bloodthirster.goFatality=true;
		}
		if(bloodthirster.goFatality || bloodthirster.forceFatality){
			bloodthirster.state=			BloodthirsterStates::fatality;
			bloodthirster.actionTimer=		0;
			bloodthirster.goFatality=		false;
			bloodthirster.forceFatality=	false;
			bloodthirster.wasFacingLeft=	this.isFacingLeft();
			if(getNet().isServer()) {
				this.SendCommand(this.getCommandID("goFatalityReal"));
			}
		}
	}
	else if(bloodthirster.state==BloodthirsterStates::throwing)
	{
		if(bloodthirster.actionTimer>=BloodthirsterVars::throwTime){
			bloodthirster.state=			BloodthirsterStates::normal;
			bloodthirster.actionTimer=		0;
			bloodthirster.dontHitMore=		false;
			bloodthirster.goFatality=		false;
			bloodthirster.forceFatality=	false;
			bloodthirster.attackDelay=		BloodthirsterVars::attackDelay;
		}
		bloodthirster.actionTimer+=1;
	}
	else if(bloodthirster.state==BloodthirsterStates::fatality)
	{
		moveVars.jumpFactor=	0.0f;
		moveVars.walkFactor=	0.0f;
		this.getShape().SetVelocity(Vec2f());
		if(!this.hasTag("invincible")){
			this.Tag("invincible");
		}
		this.SetFacingLeft(bloodthirster.wasFacingLeft);
		if(bloodthirster.actionTimer==46){ //62
			this.server_SetHealth(Maths::Min(this.getHealth()+3.75f,this.get_f32("realInitialHealth")));
			
			if(getNet().isServer()){
				AttachmentPoint@ point=	this.getAttachments().getAttachmentPointByName("PICKUP");
				if(point !is null){
					CBlob@ attachedBlob=	point.getOccupied();
					if(attachedBlob !is null){
						CPlayer@ attachedPlayer=attachedBlob.getPlayer();
						if(attachedPlayer !is null){
							CPlayer@ player=this.getPlayer();
							if(player !is null){
								getRules().server_PlayerDie(attachedPlayer,player,HittersTC::stomp);
							}else{
								attachedBlob.server_Die();
							}
						}else{
							attachedBlob.server_Die();
						}
					}
				}
			}
		}
		if(getNet().isClient()) {
			if(bloodthirster.actionTimer==3){ //4
				Sound::Play("ArgShort.ogg",pos,1.0f);
			}else if(bloodthirster.actionTimer==20){ //27
				Sound::Play("ArgLong.ogg",pos,1.0f);
			}else if(bloodthirster.actionTimer==29){ //39
				ShakeScreen(6.0f,5,this.getPosition());
				Sound::Play("FallOnGround.ogg",pos,0.4f);
			}else if(bloodthirster.actionTimer==45){ //60
				ShakeScreen(25.0f,6,this.getPosition());
			}else if(bloodthirster.actionTimer==46){ //62
				Vec2f posOffset=pos+Vec2f(this.isFacingLeft() ? -8 : 8,3);
				ParticleBloodSplat(posOffset,true);
				for(int i=0;i<12;i++) {
					Vec2f vel=getRandomVelocity(float(XORRandom(360)),1.0f+float(XORRandom(2)),60.0f);
					makeGibParticle("mini_gibs.png",posOffset,vel,0,4+XORRandom(4),Vec2f(8,8),2.0f,20,"/BodyGibFall",0);
				}
			}else if(bloodthirster.actionTimer==48){	 //64
				Sound::Play("Gore.ogg",pos,1.0f);
				Vec2f offset=Vec2f(0,0);
			}
		}
		if(bloodthirster.actionTimer>=BloodthirsterVars::fatalityTime){
			bloodthirster.state=			BloodthirsterStates::normal;
			bloodthirster.actionTimer=		0;
			bloodthirster.goFatality=		false;
			bloodthirster.forceFatality=	false;
			this.Untag("invincible");
			if(getNet().isServer()){
				CBlob@ blob=	server_CreateBlob(this.get_string("grabbedEnemy")=="crossbowman" ? "corpsestillcrossbowman" : "corpsestill",0,this.getPosition());
				blob.getSprite().SetFacingLeft(this.isFacingLeft());
			}
		}
		bloodthirster.actionTimer+=1;
	}

	if(bloodthirster.state!=BloodthirsterStates::charging && bloodthirster.state!=BloodthirsterStates::chargedAttack && getNet().isServer()) {
		bloodthirster_clear_actor_limits(this);
	}
	if(extraSync) {
		this.Sync("extraSync",false);
	}
}
bool IsKnocked(CBlob@ blob)
{
	if(!blob.exists("knocked")){
		return false;
	}
	return blob.get_u8("knocked")>0;
}
/*void DrawLine(CSprite@ this, u8 index, Vec2f startPos, f32 length, f32 angleOffset, bool flip)
{
	CSpriteLayer@ tracer=this.getSpriteLayer("tracer");
	
	tracer.SetVisible(true);
	
	tracer.ResetTransform();
	tracer.ScaleBy(Vec2f(length,1.0f));
	tracer.TranslateBy(Vec2f(length*16.0f,0.0f));
	tracer.RotateBy(angleOffset + (flip ? 180 : 0),Vec2f());
}*/
void PlaySoundRanged(CBlob@ this,string sound,int range,float volume,float pitch)
{
	this.getSprite().PlaySound(sound+(range>1 ? formatInt(XORRandom(range-1)+1,"")+".ogg" : ".ogg"),volume,pitch);
}
void onCommand(CBlob@ this,u8 cmd,CBitStream @stream)
{
	BloodthirsterInfo@ bloodthirster;
	if(!this.get("BloodthirsterInfo",@bloodthirster)) {
		return;
	}
	if(cmd==this.getCommandID("throw")){
		if(getNet().isServer() || bloodthirster.state==BloodthirsterStates::throwing){
			return;
		}
		bloodthirster.state=		BloodthirsterStates::throwing;
		bloodthirster.actionTimer=	0;
		bloodthirster.dontHitMore=	false;
	}else if(cmd==this.getCommandID("goFatality")){
		bloodthirster.goFatality=true;
	}else if(cmd==this.getCommandID("goFatalityReal")){
		bloodthirster.forceFatality=true;
	}else if(cmd==this.getCommandID("grabbedSomeone")){
		this.set_string("grabbedEnemy",stream.read_string());
		bloodthirster.state=BloodthirsterStates::grabbed;
		bloodthirster.attackDelay=15;
		bloodthirster.forceFatality=false;
		bloodthirster.goFatality=false;
		if(getNet().isClient()){
			this.getSprite().PlaySound("Gasp.ogg");
			CSpriteLayer@ victim=this.getSprite().getSpriteLayer("victim");
			if(victim !is null){
				if(this.get_string("grabbedEnemy")=="crossbowman"){
					victim.ReloadSprite("CrossbowmanVictim.png",64,64,0,0);
				}else if(this.get_string("grabbedEnemy")=="trader"){
					victim.ReloadSprite("TraderVictim.png",64,64,0,0);
				}else{
					victim.ReloadSprite("KnightVictim.png",64,64,0,0);
				}
			}
		}
	}
}


f32 onHit(CBlob@ this,Vec2f worldPoint,Vec2f velocity,f32 damage,CBlob@ hitterBlob,u8 customData)
{
	if(this.hasTag("invincible")){
		return 0.0f;
	}
	//if(customData==HittersNew::arrow) {
	//	return damage*1.5f;
	//}
	return damage;
}
void onDie(CBlob@ this)
{
	if(!getNet().isServer()){
		return;
	}
	BloodthirsterInfo@ bloodthirster;
	if(!this.get("BloodthirsterInfo",@bloodthirster)) {
		return;
	}
	if(bloodthirster.state==BloodthirsterStates::grabbed){
		CBlob@ blob=			server_CreateBlob(this.get_string("grabbedEnemy"),0,this.getPosition());
		if(blob !is null){
			AttachmentPoint@ point=	this.getAttachments().getAttachmentPointByName("PICKUP");
			if(point !is null){
				CBlob@ attachedBlob=	point.getOccupied();
				if(attachedBlob !is null){
					CPlayer@ attachedPlayer=attachedBlob.getPlayer();
					if(attachedPlayer !is null){
						blob.server_SetPlayer(attachedPlayer);
						
						CBitStream params;
						params.write_u16(2);
						params.write_string(attachedPlayer.getUsername()+" was saved by the heroes!");
						params.write_string("Good fuckin' job! Don't forget to attach a screenshot of this to your wall.");
						getRules().SendCommand(getRules().getCommandID("broadcastMessage"),params);
					}else{
						CBitStream params;
						params.write_u16(2);
						params.write_string(this.get_string("grabbedEnemy")+" was saved by the heroes!");
						params.write_string("Good fuckin' job! Don't forget to attach a screenshot of this to your wall.");
						getRules().SendCommand(getRules().getCommandID("broadcastMessage"),params);
					}
				}
			}
		}
	}
}

/////////////////////////////////////////////////

void DoAttack(CBlob@ this,f32 damage,BloodthirsterInfo@ info,f32 arcDegrees,u8 type,int deltaInt)
{
	f32 aimangle=-(info.attackDirection.Angle());
	if(aimangle<0.0f) {
		aimangle+=360.0f;
	}
	f32 exact_aimangle=	info.attackTrueRot;
	Vec2f aimPos=		info.attackAimPos;
	//get the actual aim angle

	Vec2f blobPos=	this.getPosition();
	Vec2f vel=	this.getVelocity();
	Vec2f thinghy(1,0);
	thinghy.RotateBy(aimangle);
	Vec2f pos=	blobPos - thinghy * 6.0f + vel + Vec2f(0,-2);
	vel.Normalize();

	f32 attack_distance=	Maths::Min(DEFAULT_ATTACK_DISTANCE + Maths::Max(0.0f,1.75f * this.getShape().vellen *(vel * thinghy)),MAX_ATTACK_DISTANCE);

	f32 radius=	this.getRadius();
	CMap@ map=	this.getMap();
	bool dontHitMore=	false;
	bool dontHitMoreMap=false;
	bool hasHitBlob=	false;
	bool hasHitMap=		false;
	
	if(getNet().isServer() && (blobPos-aimPos).Length()<=attack_distance*1.5f){
		DamageWall(this,map,aimPos);
	}

	// this gathers HitInfo objects which contain blob or tile hit information
	HitInfo@[] hitInfos;
	if(map.getHitInfosFromArc(pos,aimangle,arcDegrees,radius + attack_distance,this,@hitInfos))
	{
		//HitInfo objects are sorted,first come closest hits
		for(uint i=	0; i < hitInfos.length; i++) {
			HitInfo@ hi=hitInfos[i];
			CBlob@ b=	hi.blob;
			if(b !is null && !dontHitMore && deltaInt<=BloodthirsterVars::attackTime-9) // blob
			{
				//big things block attacks
				const bool large=	b.hasTag("blocks sword") && !b.isAttached() && b.isCollidable();

				if(!canHit(this,b)) {
					// no TK
					if(large){
						dontHitMore=	true;
					}
					continue;
				}

				if(bloodthirster_has_hit_actor(this,b))
				{
					if(large){
						dontHitMore=	true;
					}
					continue;
				}

				bloodthirster_add_actor_limit(this,b);
				if(!dontHitMore)
				{
					if(getNet().isServer()) {
						Vec2f velocity=	b.getPosition() - pos;
						this.server_Hit(b,hi.hitpos,velocity,damage,type,true);  // server_Hit() is server-side only
					}

					// end hitting if we hit something solid,don't if its flesh
					if(large)
					{
						dontHitMore=	true;
					}
				hasHitBlob=	true;
			}
			else if(!dontHitMoreMap &&(deltaInt == DELTA_BEGIN_ATTACK + 1)) { // hitmap
				Vec2f tpos=	map.getTileWorldPosition(hi.tileOffset) + Vec2f(4,4);
				Vec2f offset=	(tpos - blobPos);
				f32 tileangle=	offset.Angle();
				f32 dif=	Maths::Abs(exact_aimangle - tileangle);
				if(dif > 180){
					dif -= 360;
				}
				if(dif < -180){
					dif += 360;
				}

				dif=	Maths::Abs(dif);
				//print("dif: "+dif);

				if(dif < 30.0f) {
					hasHitMap=	true;
					if(!getNet().isServer()) {
						continue;
					}
					if(map.getSectorAtPosition(tpos,"no build") !is null){
						continue;
					}
					TileType tile=map.getTile(hi.hitpos).type;
					if(!map.isTileBedrock(tile)){
						map.server_DestroyTile(hi.hitpos,1000.0f,this);
					}
					
					DamageWall(this,map,hi.hitpos+Vec2f(-8, 0));
					DamageWall(this,map,hi.hitpos+Vec2f( 8, 0));
					DamageWall(this,map,hi.hitpos+Vec2f( 0,-8));
					DamageWall(this,map,hi.hitpos+Vec2f( 0, 8));
					
					
					//this.server_HitMap(hi.hitpos,offset,1.0f,HittersNew::builder);
				}
		if(hasHitBlob || hasHitMap) {
			//if(hasHitBlob) {
				//ShakeScreen(30.0f,30,this.getPosition());
			//}
			if(!hasHitBlob) {
				PlaySoundRanged(this,"HammerHit",3,1.0f,1.0f);
			}

	// destroy grass

	if(((aimangle >= 0.0f && aimangle <= 180.0f) || damage > 1.0f) &&    // aiming down or slash
	(deltaInt == DELTA_BEGIN_ATTACK + 1)) // hit only once
	{
		f32 tilesize=	map.tilesize;
		int steps=	Maths::Ceil(2 * radius / tilesize);
		int sign=	this.isFacingLeft() ? -1 : 1;

		for(int y=	0; y < steps; y++)
			for(int x=	0; x < steps; x++)
			{
				Vec2f tilepos=	blobPos + Vec2f(x * tilesize * sign,y * tilesize);
				TileType tile=	map.getTile(tilepos).type;

				if(map.isTileGrass(tile))
				{
					map.server_DestroyTile(tilepos,damage,this);

					if(damage <= 1.0f)
					{
						return;
					}
				}
			}
void DamageWall(CBlob@ this,CMap@ map,Vec2f pos)
{
	if(pos.x<0.0f || pos.x>=map.tilemapwidth*8.0f || pos.y<0.0f || pos.y>=map.tilemapheight*8.0f){
		print("returned from "+pos.x+","+pos.y);
		return;
	}
	Tile tile=map.getTile(pos);
	if(map.isTileBackground(tile) && !map.isTileGroundBack(tile.type)){
		tile.type=CMap::TileEnum::tile_empty;
		map.server_SetTile(pos,tile);
		//map.server_DestroyTile(pos,1000.0f,this);
	}
}
void DoGrab(CBlob@ this,f32 aimangle,f32 arcDegrees,BloodthirsterInfo@ info)
{
	if(!getNet().isServer()) {
		return;
	}
	if(aimangle<0.0f) {
		aimangle+=360.0f;
	}
	Vec2f blobPos=	this.getPosition();
	Vec2f vel=		this.getVelocity();
	Vec2f thinghy(1,0);
	thinghy.RotateBy(aimangle);
	Vec2f pos=	blobPos-thinghy*6.0f+vel+Vec2f(0,-2);
	vel.Normalize();

	f32 attack_distance=Maths::Min(DEFAULT_ATTACK_DISTANCE+Maths::Max(0.0f,1.75f*this.getShape().vellen*(vel*thinghy)),MAX_ATTACK_DISTANCE);

	f32 radius=			this.getRadius();
	CMap@ map=			this.getMap();

	f32 exact_aimangle=	(this.getAimPos()-blobPos).Angle(); //get the actual aim angle

	HitInfo@[] hitInfos; // this gathers HitInfo objects which contain blob or tile hit information
	if(map.getHitInfosFromArc(pos,aimangle,arcDegrees,radius+attack_distance,this,@hitInfos))
	{
		for(uint i=0;i<hitInfos.length;i++) { //HitInfo objects are sorted,first come closest hits
			HitInfo@ hi=	hitInfos[i];
			CBlob@ b=	hi.blob;
			if(b !is null) { //blob 
				if(b.getName()!="knight" || b.hasTag("ignore sword") || !canHit(this,b) || bloodthirster_has_hit_actor(this,b)){
					continue;
				}
				bloodthirster_add_actor_limit(this,b);
				Vec2f velocity=	b.getPosition()-pos;
				//this.server_Hit(b,hi.hitpos,velocity,damage,type,true);  // server_Hit() is server-side only
				CBitStream stream;
				stream.write_u16(b.getNetworkID()); //victim's blob id
				stream.write_u8(0); //fatality id
				stream.write_bool(this.isFacingLeft());
				//stream.write_f32(100.0f); fatality length
				uint8 commandId=this.getCommandID("fatality");
				/*int playerCount=getPlayerCount();
				for(uint j=0;j<playerCount;j++){
					CPlayer@ player=getPlayer(j);
					this.server_SendCommandToPlayer(commandId,stream,player);
				}*/
				this.SendCommand(commandId,stream);
				//b.Damage(b.getInitialHealth()*2,this);
				this.server_Hit(b,hi.hitpos,velocity,b.getInitialHealth()*2,Hitters::suicide,false);
				break;
			}
		}
	}
}

//a little push forward

void pushForward(CBlob@ this,f32 normalForce,f32 pushingForce,f32 verticalForce)
{
	f32 facing_sign=	this.isFacingLeft() ? -1.0f : 1.0f ;
	bool pushing_in_facing_direction =
	(facing_sign < 0.0f && this.isKeyPressed(key_left)) ||
	(facing_sign > 0.0f && this.isKeyPressed(key_right));
	f32 force=	normalForce;

		if(pushing_in_facing_direction){
		force=	pushingForce;
		this.AddForce(Vec2f(force * facing_sign ,verticalForce));
		}
}