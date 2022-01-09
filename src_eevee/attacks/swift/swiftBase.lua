local swiftBase = {}

function swiftBase:SpawnPos(player, degreeOfTearSpawns, offset)
	local dataPlayer = player:GetData()
	local anglePos = Vector.FromAngle((degreeOfTearSpawns * dataPlayer.Swift.NumWeaponsSpawned)):Resized(swiftBase:SwiftTearDistanceFromPlayer(player)):Rotated(offset)

	return anglePos
end

function swiftBase:SpawnPosMulti(player, degreeOfTearSpawns, offset, multiOffset, orbit, i)
	local dataPlayer = player:GetData()
	local degrees = 360/dataPlayer.Swift.MultiShots
	local anglePos = Vector.FromAngle(((degrees * i) * dataPlayer.Swift.NumWeaponsSpawned)):Resized(orbit):Rotated(multiOffset)
	return anglePos
end

function swiftBase:SwiftFireDelay(player)
	local nextTearTime = player.MaxFireDelay
	local dataPlayer = player:GetData()
	if player:HasWeaponType(WeaponType.WEAPON_BRIMSTONE)
	or player:HasWeaponType(WeaponType.WEAPON_TECH_X)
	or player:HasWeaponType(WeaponType.WEAPON_KNIFE) then
		nextTearTime = nextTearTime * 1.5
	end
	if dataPlayer.Swift then
		if (not dataPlayer.Swift.Constant and player.MaxFireDelay <= 0.5)
		or (player:GetData().Swift.KidneyTimer and dataPlayer.Swift.AttackDuration ~= 0) then
			nextTearTime = 0.5
		end
	end
	return nextTearTime
end

function swiftBase:SwiftShotVelocity(direction, player, useMovement)
	local newDirection = direction:Resized(10 * player.ShotSpeed)
	if useMovement then
		return newDirection + player:GetMovementInput():Resized(3)
	else
		return newDirection
	end
end

function swiftBase:TryFireToEnemy(player, weapon, fireDir)
	local newFireDir = fireDir
	local radius = player.TearRange / 2
	local closestEnemy = EEVEEMOD.API.DetectNearestEnemy(weapon, radius)
	local dirToEnemy = nil
	local angleLimit = 30
	
	if not player:HasCollectible(CollectibleType.COLLECTIBLE_MARKED)
	and not player:HasCollectible(CollectibleType.COLLECTIBLE_TRACTOR_BEAM)
	and not player:HasCollectible(CollectibleType.COLLECTIBLE_EYE_OF_THE_OCCULT)
	and not swiftBase:IsSwiftLaserEffect(weapon)
	then
		if closestEnemy ~= nil then
			dirToEnemy = (closestEnemy.Position - weapon.Position):Normalized()
			
			if math.abs(math.abs(dirToEnemy:GetAngleDegrees()) - math.abs(fireDir:GetAngleDegrees())) <= angleLimit then
				newFireDir = swiftBase:SwiftShotVelocity(dirToEnemy, player, true)
			end
		end
	end
	return newFireDir
end

function swiftBase:SwiftShotDelay(weapon, player)
	local dataPlayer = player:GetData()
	local dataWeapon = weapon:GetData()
	local delay = swiftBase:SwiftFireDelay(player) / (5 / dataPlayer.Swift.NumWeaponsSpawned)

	if not dataPlayer.Swift.Constant then
		if swiftBase:SwiftFireDelay(player) < 5
		or weapon.Type == EntityType.ENTITY_EFFECT
		or (weapon.Type == EntityType.ENTITY_TEAR
		and dataWeapon.Swift.IsFakeKnife)
		then
			delay = 0
		end
	else
		if dataPlayer.Swift.RespawnNewRoom then
			delay = swiftBase:SwiftFireDelay(player) + math.abs(swiftBase:SwiftFireDelay(player) * dataPlayer.Swift.NumWeaponsSpawned)
		else
			delay = swiftBase:SwiftFireDelay(player) + math.abs(swiftBase:SwiftFireDelay(player) * 5)
		end
	end
	return delay
end

function swiftBase:SwiftTearFlags(weapon, addPiercing, addHoming)
	if not weapon:HasTearFlags(TearFlags.TEAR_SPECTRAL) then
		weapon:AddTearFlags(TearFlags.TEAR_SPECTRAL)
	end
	if addPiercing and not weapon:HasTearFlags(TearFlags.TEAR_PIERCING) then
		weapon:AddTearFlags(TearFlags.TEAR_PIERCING)
	end
	if addHoming and not weapon:HasTearFlags(TearFlags.TEAR_HOMING) then
		weapon:AddTearFlags(TearFlags.TEAR_HOMING)
	end
end

function swiftBase:AddSwiftTrail(weapon, player)
	if weapon.SpawnerType == EntityType.ENTITY_PLAYER then
		local player = weapon.SpawnerEntity:ToPlayer() or weapon.SpawnerEntity:ToFamiliar().Player
		local dataPlayer = player:GetData()
		local dataWeapon = weapon:GetData()
		
		if dataWeapon.Swift ~= nil then

			if (not dataPlayer.Swift.Constant) or (dataPlayer.Swift.Constant and dataWeapon.Swift.ConstantOrbit) then
				
				local trail = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.SPRITE_TRAIL, 0, weapon.Position, Vector.Zero, nil):ToEffect()
				local wC = weapon:GetSprite().Color
				local tC = Color(wC.R, wC.G, wC.B, 1, wC.RO, wC.GO, wC.BO)
				
				if not player:HasCollectible(CollectibleType.COLLECTIBLE_PLAYDOUGH_COOKIE) then	
					if weapon.Type == EntityType.ENTITY_TEAR then
						if not swiftBase:AreColorsDifferent(wC, Color.Default) and not dataWeapon.Swift.IsFakeKnife then
							if weapon:GetSprite():GetFilename() == "gfx/tear_swift_blood.anm2" then
								tC = EEVEEMOD.TrailColor.Blood
							elseif EEVEEMOD.TrailColor[weapon.Variant] ~= nil then
								tC = EEVEEMOD.TrailColor[weapon.Variant]
							else
								tC = EEVEEMOD.TrailColor.Normal
							end
						end
					end
				else
					if weapon.Type ~= EntityType.ENTITY_EFFECT and weapon.Type ~= EntityType.ENTITY_LASER then
						swiftBase:PlaydoughRandomColor(trail)
					else
						trail:GetData().EeveeRGB = true
					end
				end
				trail.Parent = weapon
				trail:GetData().SwiftTrail = true
				trail:GetData().TrailColor = tC
				trail.Color = tC
				trail:SetColor(Color(tC.R, tC.G, tC.B, 0, tC.RO, tC.GO, tC.BO), 15, 1, true, false)
				dataWeapon.Swift.Trail = trail
				trail.MinRadius = 0.2
				trail.RenderZOffset = -10
				trail:Update()
			end
		end
	end
end

function swiftBase:SwiftTearDistanceFromPlayer(player)
	local distFromPlayer = 50
	if player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_MEGA_MUSH) then
		distFromPlayer = 100
	elseif player:HasCollectible(CollectibleType.COLLECTIBLE_ANGELIC_PRISM) then
		distFromPlayer = 40
	elseif player:HasCollectible(CollectibleType.COLLECTIBLE_IPECAC)
	or player:HasCollectible(CollectibleType.COLLECTIBLE_FIRE_MIND)
	then
		distFromPlayer = 70
	elseif player:HasCollectible(CollectibleType.COLLECTIBLE_LOST_CONTACT) then
		distFromPlayer = 30
	end
	return distFromPlayer
end

function swiftBase:MultiSwiftTearDistanceFromTear(player)
	local distFromTear = 15
	if player:HasWeaponType(WeaponType.WEAPON_MONSTROS_LUNGS) then
		distFromTear = EEVEEMOD.RandomNum(10, 50)
	end
	return distFromTear
end

function swiftBase:AssignSwiftSounds(weapon)
	local dataWeapon = weapon:GetData()
	
	if weapon.Type == EntityType.ENTITY_TEAR then
		if dataWeapon.Swift.IsFakeKnife then
			--EEVEEMOD.sfx:Play(SoundEffect.SOUND_1UP, 1, 0, false, 1)
		else
			--EEVEEMOD.sfx:Play(SoundEffect.SOUND_1UP, 1, 0, false, 1)
		end
	elseif weapon.Type == EntityType.ENTITY_EFFECT then
		if weapon.Variant == EffectVariant.EVIL_EYE then
			--EEVEEMOD.sfx:Play(SoundEffect.SOUND_1UP, 1, 0, false, 1)
		elseif swiftBase:IsSwiftLaserEffect(weapon) == "brim" then
			--EEVEEMOD.sfx:Play(SoundEffect.SOUND_1UP, 1, 0, false, 1)
		elseif swiftBase:IsSwiftLaserEffect(weapon) == "tech" then
			EEVEEMOD.sfx:Stop(SoundEffect.SOUND_TEARS_FIRE)
			EEVEEMOD.sfx:Play(SoundEffect.SOUND_LASERRING_WEAK, 0.7, 0, false, 3, 0)
		end
	elseif weapon.Type == EntityType.ENTITY_BOMBDROP then
		EEVEEMOD.sfx:Play(SoundEffect.SOUND_FETUS_LAND, 1, 0, false, 1)
	end
end

function swiftBase:AssignSwiftBasicData(weapon, player, anglePos)
	local dataWeapon = weapon:GetData()
	local dataPlayer = player:GetData()
	
	dataWeapon.Swift = {}
	
	if weapon.Type == EntityType.ENTITY_TEAR then
		if player:HasCollectible(CollectibleType.COLLECTIBLE_KIDNEY_STONE) then
			weapon.Height = weapon.Height - 16
		elseif player:HasCollectible(CollectibleType.COLLECTIBLE_NUMBER_ONE)  then
			weapon.Height = weapon.Height - 8
		end
		dataWeapon.Swift.HoldTearHeight = weapon.Height
	end

	dataWeapon.Swift.ShotDelay = swiftBase:SwiftShotDelay(weapon, player)
	dataWeapon.Swift.PosToFollow = anglePos:Rotated(180)
	dataWeapon.Swift.ShotDir = EEVEEMOD.API.GetIsaacShootingDirection(player, weapon)
	dataWeapon.Swift.DistFromPlayer = swiftBase:SwiftTearDistanceFromPlayer(player)
	
	if not dataWeapon.MultiSwiftTear then
		if not dataPlayer.Swift.ExistingShots then
			dataPlayer.Swift.ExistingShots = {}
		end
		dataPlayer.Swift.ExistingShots[dataPlayer.Swift.NumWeaponsSpawned] = weapon
	end
	
	if dataPlayer.Swift.Constant then
		dataWeapon.Swift.ConstantOrbit = true
	end
	
	dataWeapon.Swift.IsSwiftWeapon = true
end

local playdoughColor = {
	{0.9, 0, 0, 1}, --red
	{0, 0.7, 0, 0.9}, --green
	{0, 0, 1, 1}, --blue
	{0.8, 0.8, 0, 1}, --yellow
	{0, 0.5, 1, 0.9}, --light blue
	{0.6, 0.4, 0, 1}, --light brown
	{2, 0.1, 0.5, 1}, --pink
	{1.1, 0, 1.1, 0.9}, --purple
	{1, 0.1, 0, 1} --dark orange
}

function swiftBase:PlaydoughRandomColor(entity)
	local dC = Color.Default
	local color = playdoughColor[EEVEEMOD.RandomNum(9)]
	dC:SetColorize(color[1], color[2], color[3], color[4])
	entity.Color = dC
end

function swiftBase:AreColorsDifferent(c1, c2)
	local isDifferent = false
	if c1 ~= nil and c2 ~= nil then
		--print(c1.R, c1.G, c1.B, c1.RO, c1.GO, c1.BO)
		--print(c2.R, c2.G, c2.B, c2.RO, c2.GO, c2.BO)	
		if c1.R ~= c2.R or c1.G ~= c2.G or c1.B ~= c2.B or c1.RO ~= c2.RO or c1.GO ~= c2.GO or c1.BO ~= c2.BO then
			isDifferent = true
		end
	end
	return isDifferent
end

function swiftBase:IsSwiftLaserEffect(effect)
	local variant = nil
	if effect.Variant == EEVEEMOD.EffectVariant.CUSTOM_TECH_DOT then
		variant = "tech"
	elseif effect.Variant == EEVEEMOD.EffectVariant.CUSTOM_BRIMSTONE_SWIRL then
		variant = "brim"
	end
	return variant
end

function swiftBase:SwiftShouldBeConstant(player)
	local playerEffects = player:GetEffects()
	if player:HasCollectible(CollectibleType.COLLECTIBLE_SOY_MILK)
	or player:HasCollectible(CollectibleType.COLLECTIBLE_ALMOND_MILK)
	or player:HasCollectible(CollectibleType.COLLECTIBLE_TINY_PLANET)
	or swiftBase:SwiftFireDelay(player) <= 1
	then
		return true
	else
		return false
	end
end

function swiftBase:RestoreArcShot(player, tear)
	local dataTear = tear:GetData()
	local range = player.TearRange / 10
	
	if not dataTear.Swift
	or (
	not tear:HasTearFlags(TearFlags.TEAR_EXPLOSIVE)
	and not tear:HasTearFlags(TearFlags.TEAR_BURSTSPLIT)
	and not player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_MEGA_MUSH)
	)
	then
		return
	end
	
	if not dataTear.Swift.PeakReached then
		if not dataTear.Swift.HeightToAdd
		and not dataTear.Swift.HeighToReach
		and not dataTear.Swift.OriginalHeight then
			dataTear.Swift.OriginalHeight = tear.Height
			dataTear.Swift.HeightToAdd = range / 2
			dataTear.Swift.HeightToReach = dataTear.Swift.OriginalHeight - range 
		elseif dataTear.Swift.HeightToAdd > 0 then
			dataTear.Swift.HeightToAdd = dataTear.Swift.HeightToAdd / 2
			if dataTear.Swift.HeightToAdd < 5 then
				dataTear.Swift.HeightToAdd = 5
			end
		end

		tear.Height = tear.Height - dataTear.Swift.HeightToAdd

		if tear.Height <= dataTear.Swift.HeightToReach then
			dataTear.Swift.PeakReached = true
			if tear.FallingAcceleration ~= dataTear.Swift.StoredFallingAccel then
				tear.FallingAcceleration = dataTear.Swift.StoredFallingAccel
			end
		end
	end
end

function swiftBase:DelayFallingAcceleration(player, tear)
	local dataTear = tear:GetData()
	
	if tear.Type == EntityType.ENTITY_TEAR then
		if tear.FallingAcceleration ~= 0 and not dataTear.Swift.StoredFallingAccel then
			dataTear.Swift.StoredFallingAccel = tear.FallingAcceleration
		elseif dataTear.Swift.StoredFallingAccel then
			if not dataTear.Swift.HasFired then
				tear.FallingAcceleration = 0
			elseif dataTear.Swift.HasFired then
				if tear.FallingAcceleration ~= dataTear.Swift.StoredFallingAccel then
					tear.FallingAcceleration = dataTear.Swift.StoredFallingAccel
				end
				--swiftBase:RestoreArcShot(player, tear)
			end
		end
	end
end

return swiftBase