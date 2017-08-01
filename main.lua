local BlinkTears = RegisterMod("Blink Tears", 1)
local blinkTearsItem = Isaac.GetItemIdByName("Blink Tears");
--local excecutioner = Isaac.GetItemIdByName("Executioner");

local alphaMod
local ENTITY_FLAGS
local ENTITIES = {}
local ITEMS = {
	ACTIVE = {},
	PASSIVE = {},
	TRINKET = {}
}
local CONFIG
local game = Game()
local sfxManager = SFXManager();

local blueTearColor = Color(0.01, 0.1, 0.58,1,0,0,0)
local blueFartColor = Color(0.01,0.1,1,0.75,0,0,0)
--local blueLaserColor = Color(0.01,0.1,1,0.75,0,0,0)
local blueLaserColor = Color(0,0,0,0.75,0,0,1)

local possible_door_slots = {DoorSlot.LEFT0, DoorSlot.UP0, DoorSlot.RIGHT0, DoorSlot.DOWN0,
						DoorSlot.LEFT1, DoorSlot.UP1, DoorSlot.RIGHT1, DoorSlot.DOWN1}

local function start()
    alphaMod = AlphaAPI.registerMod(BlinkTears)
	local player = AlphaAPI.GAME_STATE.PLAYERS[1]

	--Blink tears init
	------------------
	ENTITIES.BLINK_TEAR = alphaMod:getEntityConfig("Blink Tear", 0)
	ITEMS.PASSIVE.BLINK_TEARS = alphaMod:registerItem("Blink Tears", "gfx/characters/animation_costume_blinktears.anm2")
	alphaMod:addCallback(AlphaAPI.Callbacks.ENTITY_APPEAR, BlinkTears.tearAppear, EntityType.ENTITY_TEAR)
    ENTITY_FLAGS = {
        BLINK_TEAR = AlphaAPI.createFlag()
    }
	BlinkTears:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, BlinkTears.cacheUpdate)
	alphaMod:addCallback(AlphaAPI.Callbacks.ENTITY_DAMAGE, BlinkTears.triggerBlink)
	BlinkTears:AddCallback(ModCallbacks.MC_POST_UPDATE, BlinkTears.captureKeys)

	--Executioner init
	------------------
	--ITEMS.ACTIVE.EXECUTIONER = alphaMod:registerItem("Executioner")
	--ITEMS.ACTIVE.EXECUTIONER:addCallback(AlphaAPI.Callbacks.ITEM_USE, BlinkTears.triggerExecutioner)
end	


---------------------------------------
-- Some common functions and inits
---------------------------------------

function BlinkTears:cacheUpdate(player, cacheFlag)
	if player:HasCollectible(blinkTearsItem) then
		if (cacheFlag == CacheFlag.CACHE_SHOTSPEED) then
			player.ShotSpeed = player.ShotSpeed + 0.6;
		end
		if (cacheFlag == CacheFlag.CACHE_FIREDELAY) then
			player.MaxFireDelay = player.MaxFireDelay + 5;
		end
	end
	--if player:HasCollectible(executionerItem) then
	--
	--end
end

function BlinkTears:captureKeys()
	if (Input.IsButtonTriggered(Keyboard.KEY_R , 0)) then
		local room = AlphaAPI.GAME_STATE.ROOM
		if room:GetAliveEnemiesCount() == 0 then
			sfxManager:Play(SoundEffect.SOUND_HELL_PORTAL2 , 1.0, 0, false, 1.0);
			local player = AlphaAPI.GAME_STATE.PLAYERS[1]
			previousPosition = Vector(player.Position.X, player.Position.Y)
			newPosition = BlinkTears.getEntranceTile(room)
			laser = BlinkTears.fireLaserFromTo(newPosition, player.Position, player)
			player.Position = newPosition
			Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CRACK_THE_SKY, 0, player.Position, Vector(0,0), player)
		end
	end
end


function BlinkTears.getEntranceTile(room)
	local level = AlphaAPI.GAME_STATE.LEVEL
	entrance = room:GetDoor(level.EnterDoor).Position
	center = room:GetCenterPos()
	entranceToCenter = (center - entrance):Normalized()*40
	newPosition = entrance + entranceToCenter
	return newPosition
end

function BlinkTears.findNearestEnemy(player)
	for radius=10,1000 do
		possibleEnemy = Isaac.FindInRadius(player.Position, radius, EntityPartition.ENEMY)
		if possibleEnemy ~= nil then -- el  ~= nil posiblemente no sea necesario
			return possibleEnemy
		end
	end
end


local rng = RNG()
rng:SetSeed(Random(), 1)

local function random(min, max) -- Re-implements math.random()
	if min ~= nil and max ~= nil then -- Min and max passed, integer [min,max]
		return math.floor(rng:RandomFloat() * (max - min + 1) + min)
	elseif min ~= nil then -- Only min passed, integer [0,min]
		return math.floor(rng:RandomFloat() * (min + 1))
	end
	return rng:RandomFloat() -- float [0,1)
end


---------------------------------------
--Blink Logic
---------------------------------------
function BlinkTears.triggerBlink(enemy, damage_amount, damage_flag, damage_source_ref, invincible_frames)
	local player = AlphaAPI.GAME_STATE.PLAYERS[1]
	damage_source_ref_entity = AlphaAPI.getEntityFromRef(damage_source_ref)
	if AlphaAPI.hasFlag(damage_source_ref_entity, ENTITY_FLAGS.BLINK_TEAR) then
		local damaged_npc = enemy:ToNPC()
		if damaged_npc then
			if enemy:IsActiveEnemy(false) and enemy:IsVulnerableEnemy() then
				fart = game:ButterBeanFart(enemy.Position, 160, player, false)
				BlinkTears.SwitchPositions(enemy, player)
				blueFart = game:Spawn(EntityType.ENTITY_EFFECT, EffectVariant.FART,
				player.Position, player.Velocity, player, 0, 0)
				blueFart :SetColor(blueFartColor, 1000, 1, false, false)
				game:BombDamage(player.Position, 0, 70, true, player, 0, 0, false)
				game:BombExplosionEffects(player.Position, 0, 1, blueFartColor, player, 0, true, false)
				Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CRACK_THE_SKY, 0,
				player.Position, player.Velocity * 0.5, player)
				laser = BlinkTears.fireLaserFromTo(player.Position, enemy.Position, player)
				sfxManager:Play(SoundEffect.SOUND_HELL_PORTAL2 , 1.0, 0, false, 1.0);
				player:SetMinDamageCooldown(60)
			end
		end
	end
end

function BlinkTears.fireLaserFromTo(from, to, player)
	ToFromVector = to - from
	laser = player:FireTechLaser(to, LaserOffset.LASER_TECH1_OFFSET , ToFromVector:Normalized(), false, false)
	laser:SetMaxDistance(ToFromVector:Length())
	laser:SetColor(blueLaserColor, 1000, 1, false, false)
	laser.Timeout = 8
	return laser
end

function BlinkTears.SwitchPositions(entity1, entity2)
	pos = entity1.Position
	entity1.Position = entity2.Position
	entity2.Position = pos
end

BlinkTears.tearsShot = 0
BlinkTears.tearsFamiliarsShot = 0
function BlinkTears.tearAppear(entity, data)
	local tear = entity:ToTear()
	if tear.SpawnerType and tear.SpawnerType == EntityType.ENTITY_PLAYER
	and tear.Variant ~= TearVariant.CHAOS_CARD then
		BlinkTears.tearsShot = BlinkTears.tearsShot + 1
		local player = AlphaAPI.GAME_STATE.PLAYERS[1]
		if player:HasCollectible(ITEMS.PASSIVE.BLINK_TEARS.id) then
			if player.Luck > 10 and (BlinkTears.tearsShot % 2 == 0) then
				BlinkTears.giveBlinkEffect(tear)
			elseif 10 >= player.Luck and player.Luck > 7 and (BlinkTears.tearsShot % 3 == 0) then
				BlinkTears.giveBlinkEffect(tear)
			elseif 7 >= player.Luck and player.Luck > 5 and (BlinkTears.tearsShot % 4 == 0) then
				BlinkTears.giveBlinkEffect(tear)
			elseif 5 >= player.Luck and player.Luck > 3 and (BlinkTears.tearsShot % 5 == 0) then
				BlinkTears.giveBlinkEffect(tear)
			elseif 3 >= player.Luck and player.Luck > 1 and (BlinkTears.tearsShot % 6 == 0) then
				BlinkTears.giveBlinkEffect(tear)
			elseif player.Luck <= 1 and (BlinkTears.tearsShot % 7 == 0) then
				BlinkTears.giveBlinkEffect(tear)
			end
		end
	end

	if tear.SpawnerType and tear.SpawnerType == EntityType.ENTITY_FAMILIAR
		and tear.Variant ~= TearVariant.CHAOS_CARD then
			BlinkTears.tearsFamiliarsShot = BlinkTears.tearsFamiliarsShot + 1
			local player = AlphaAPI.GAME_STATE.PLAYERS[1]
			if player:HasCollectible(ITEMS.PASSIVE.BLINK_TEARS.id) then
				if player.Luck > 10 and (BlinkTears.tearsFamiliarsShot % 2 == 0) then
					BlinkTears.giveBlinkEffect(tear)
				elseif 10 >= player.Luck and player.Luck > 7 and (BlinkTears.tearsFamiliarsShot % 3 == 0) then
					BlinkTears.giveBlinkEffect(tear)
				elseif 7 >= player.Luck and player.Luck > 5 and (BlinkTears.tearsFamiliarsShot % 4 == 0) then
					BlinkTears.giveBlinkEffect(tear)
				elseif 5 >= player.Luck and player.Luck > 3 and (BlinkTears.tearsFamiliarsShot % 5 == 0) then
					BlinkTears.giveBlinkEffect(tear)
				elseif 3 >= player.Luck and player.Luck > 1 and (BlinkTears.tearsFamiliarsShot % 6 == 0) then
					BlinkTears.giveBlinkEffect(tear)
				elseif player.Luck <= 1 and (BlinkTears.tearsFamiliarsShot % 7 == 0) then
					BlinkTears.giveBlinkEffect(tear)
				end
			end
		end

end

function BlinkTears.giveBlinkEffect(tear)
	tear.Color = blueTearColor
	AlphaAPI.addFlag(tear, ENTITY_FLAGS.BLINK_TEAR)
	tear:ChangeVariant(TearVariant.CUPID_BLUE)
end



-------------------
--Executioner logic
-------------------

--function BlinkTears.triggerExecutioner()
--	local player = AlphaAPI.GAME_STATE.PLAYERS[1]
--	local nearest_enemy = BlinkTears.findNearestEnemy(player)
--	player.Position = nearest_enemy.Position
--	Isaac.DebugString("triggerExecutioner")
--	return false  --TODO: no esta andando
--end


local START_FUNC = start
--------------------------------------
if AlphaAPI then START_FUNC()
else if not __alphaInit then
	__alphaInit={} end __alphaInit
[#__alphaInit+1]=START_FUNC end
--------------------------------------
