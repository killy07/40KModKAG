#include "CustomBlocks.as";
#include "MapType.as";
#include "TexturePackCommonRules.as";

void onInit(CBlob@ this)
{
	if (getNet().isClient())
		Sound::Play("hivecity.ogg");
	this.getShape().SetGravityScale(0.0f);
	this.getShape().SetStatic(true);
	
	getRules().set_u8("map_type", MapType::hivecity);

	this.Tag("infos");
	if (isServer())
	{
		CBlob@[] infos;
		getBlobsByTag("infos", @infos);
		for (u8 i = 0; i < infos.length; i++)
		{
			CBlob@ b = infos[i];
			if (b is null) continue;
			if (b is this) continue;
			b.server_Die();
		}
	}
	
	if (isServer())
	{
		CBlob@[] nature;
		//getBlobsByName("bush", @nature);
		//getBlobsByName("ivy", @nature);
		getBlobsByName("chicken", @nature);
		getBlobsByName("bison", @nature);
		getBlobsByName("flower", @nature);
		getBlobsByName("badgerden", @nature);
		getBlobsByName("grain_plant", @nature);
		getBlobsByName("pumpkin_plant", @nature);
		getBlobsByName("grain", @nature);
		getBlobsByName("seed", @nature);
		
		for (int i = 0; i < nature.length; i++)
		{
			CBlob@ b = nature[i];
			// Disabled to reduce lag
			// if (XORRandom(8) == 0)
			// {
			// 	switch (XORRandom(3))
			// 	{
			// 		case 0:
			// 			server_CreateBlob("mithrilman", b.getTeamNum(), b.getPosition());
			// 		case 1:
			// 			server_CreateBlob("bagel", b.getTeamNum(), b.getPosition());
			// 		case 3:
			// 			if (XORRandom(1) == 0) server_CreateBlob("cowo", b.getTeamNum(), b.getPosition());
			// 	}
			// }
			
			b.Tag("no drop");
			b.server_Die();
		}
	}

	if (isClient())
	{
		//SetScreenFlash(255, 255, 255, 255);
	
		CMap@ map = this.getMap();
		map.CreateTileMap(0, 0, 8.0f, "Hivecity_world.png");
		
		map.CreateSky(color_white, Vec2f(1.0f, 1.0f), 200, "Sprites/Back/cloud", 0);
		map.CreateSkyGradient("Hivecity_skygradient.png"); // override sky color with gradient

		map.AddBackground("Hivecity3.png", Vec2f(0.0f, -27.0f), Vec2f(0.3f, 0.3f), color_white);
		map.AddBackground("Hivecity2.png", Vec2f(0.0f, -18.0f), Vec2f(0.3f, 0.3f), color_white);
		map.AddBackground("Hivecity1.png", Vec2f(0.0f,  -5.0f), Vec2f(0.4f, 0.4f), color_white);
	}
}