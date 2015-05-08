-- Slayer blink, global version of human blink
function SlayerBlink( keys )
  local caster = keys.caster
  local point = keys.target_points[1]

  FindClearSpaceForUnit(caster, point, false)
end


-- Slayer tracker, for finding invis units
function SlayerSummonTracker( keys )
  local caster = keys.caster
  local pID = caster:GetMainControllingPlayer()

  local tracker = CreateUnitByName("slayer_tracker", caster:GetAbsOrigin(), true, nil, nil,caster:GetTeam() )
  tracker:SetControllableByPlayer(pID, true)
end


-- Tracker death
function SlayerRemoveTracker( keys )
  local caster = keys.caster
  caster:RemoveSelf()
end

-- Slayer building invuln start
function SlayerBuildingProtection( keys )
  local caster = keys.caster
  local radius = keys.InvulRadius
  local pID = caster:GetMainControllingPlayer()
  local ability = keys.ability

  local nearby_units = FindUnitsInRadius(caster:GetTeam(), caster:GetAbsOrigin() , nil, radius, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false) 

  for i, nearby in ipairs(nearby_units) do
    if nearby:GetMainControllingPlayer() == pID then
      if nearby:FindAbilityByName("is_a_building") ~= nil then
        ability:ApplyDataDrivenModifier(caster, nearby, "modifier_building_invulnerable", nil)
      end
    end
  end
end

-- Slayer building invuln end
function SlayerBuildingProtectionEnd( keys )
  local caster = keys.caster
  local radius = keys.InvulRadius
  local pID = caster:GetMainControllingPlayer()

  local nearby_units = FindUnitsInRadius(caster:GetTeam(), caster:GetAbsOrigin() , nil, radius, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false) 

  for i, nearby in ipairs(nearby_units) do
    if nearby:GetMainControllingPlayer() == pID then
      if nearby:HasModifier("modifier_building_invulnerable") == true then
        nearby:RemoveModifierByName("modifier_building_invulnerable")
      end
    end
  end
end

-- Slayer Avatar
function SlayerAvatarStart( keys )
  local caster = keys.caster
  local modelscale = keys.Modelscale
  local scalefinish = 1.0 + modelscale * 1.0 / 100.0
  local scale = 1.0

  Timers:CreateTimer(0.3, function ()
    if scale < scalefinish then
      caster:SetModelScale(scale)
      scale = scale + 0.01
      return 0.03
    else
      return nil
    end
  end)
end

-- Slayer Avatar end
function SlayerAvatarEnd( keys )
  local caster = keys.caster
  local modelscale = keys.Modelscale
  local scalestart = 1.0 + modelscale * 1.0 / 100.0
  local scalefinish = 1.0

  Timers:CreateTimer(0.3, function ()
    if scalestart > scalefinish then
      caster:SetModelScale(scalestart)
      scalestart = scalestart - 0.01
      return 0.03
    else
      return nil
    end
  end)
end

-- Check that the player can summon a slayer, otherwise stop.
function SummonSlayer( keys )
  local caster = keys.caster
  local ability = keys.ability
  local pID = caster:GetMainControllingPlayer()
  local lumberCost = ABILITY_KV[ability:GetAbilityName()].AbilityLumberCost
  local goldCost = ABILITY_KV[ability:GetAbilityName()].AbilityGoldCost

  if SLAYERS[pID] ~= nil then
    FireGameEvent( 'custom_error_show', { player_ID = caster:GetMainControllingPlayer() , _error = "Only one slayer per player." } )
    caster:Stop()
    return
  end

  if lumberCost == nil then
    lumberCost = 0
  end
  if goldCost == nil then
    goldCost = 0
  end

  -- Check that the player can afford the slayer, if not break out of the function
  if WOOD[pID] < lumberCost then
    caster:Stop()
    FireGameEvent( 'custom_error_show', { player_ID = pID, _error = "You need more wood" } )
    return
  end
  if PlayerResource:GetGold(pID) < goldCost then
    caster:Stop()
    FireGameEvent( 'custom_error_show', { player_ID = pID, _error = "You need more gold" } )
    return
  end

  -- Checks passed, deduct the resources and start channeling
  WOOD[pID] = WOOD[pID] - lumberCost
  FireGameEvent('vamp_wood_changed', { player_ID = pID, wood_total = WOOD[pID]})

  PlayerResource:ModifyGold(pID, -1 * goldCost, true, 9)
  FireGameEvent('vamp_gold_changed', { player_ID = pID, gold_total = PlayerResource:GetGold(pID)})  
end

function Refund( keys )
  local caster = keys.caster
  local pID = caster:GetMainControllingPlayer()
  local ability = keys.ability
  
  local refundWood = ABILITY_KV[ability:GetAbilityName()].AbilityLumberCost
  local refundGold = ABILITY_KV[ability:GetAbilityName()].AbilityGoldCost

  if refundWood == nil then
    refundWood = 0
  end
  if refundGold == nil then
    refundGold = 0
  end

  if HAS_SLAYER[pID] == nil then
    WOOD[pID] = WOOD[pID] + refundWood
    FireGameEvent('vamp_wood_changed', { player_ID = pID, wood_total = WOOD[pID]})

    PlayerResource:ModifyGold(pID, refundGold, true, 9)
    FireGameEvent('vamp_gold_changed', { player_ID = pID, gold_total = caster:GetGold()}) 
  end
end


-- Function that spawns the slayer on channel success
function SpawnSlayer( keys )
  local caster = keys.caster
  local pID = caster:GetMainControllingPlayer()

  SLAYERS[pID] = {["state"] = "alive"}

  local slayer = CreateUnitByName("npc_dota_hero_invoker", caster:GetAbsOrigin(), true, nil, nil, caster:GetTeam())
  slayer:SetControllableByPlayer(pID, true)
  slayer:SetOwner(EntIndexToHScript(pID))
  slayer:FindAbilityByName("slayer_blink"):SetLevel(1)

  SLAYERS[pID].handle = slayer
  FireGameEvent("vamp_slayer_state_update", {player_ID = playerID, slayer_state = "Alive"})

  GameMode:ModifyStatBonuses(slayer)
end

-- Revive Slayer
function SlayerRespawnStart( keys )
  local caster = keys.caster
  local pID = caster:GetMainControllingPlayer()

  if SLAYERS[pID].state == "alive" then
    FireGameEvent( 'custom_error_show', { player_ID = pID, _error = "Slayer is currently alive" } )
    caster:Stop()
    return nil
  end

  if SLAYERS[pID].state == "reviving" then
    FireGameEvent( 'custom_error_show', { player_ID = pID, _error = "Slayer is currently reviving" } )
    caster:Stop()
    return nil
  end
  SLAYERS[pID].state = "reviving"
  FireGameEvent("vamp_slayer_state_update", {player_ID = playerID, slayer_state = "Reviving"})
end

function SlayerRespawnInterrupted( keys )
  local caster = keys.caster
  local pID = caster:GetMainControllingPlayer()

  if SLAYERS[pID].state == "reviving" then
   SLAYERS[pID].state = "dead" 
   FireGameEvent("vamp_slayer_state_update", {player_ID = playerID, slayer_state = "Dead"})
  end
end

function SlayerRespawn( keys )
  local caster = keys.caster
  local pID = caster:GetMainControllingPlayer()

  SLAYERS[pID].handle:RespawnUnit()
  GameMode:ModifyStatBonuses(SLAYERS[pID].handle)
end