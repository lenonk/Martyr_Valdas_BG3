local MOD = "[Martyr]"
local spellCost = { [1]=5, [2]=10, [3]=20, [4]=30, [5]=45 }
-- Sacrosanct Spell: no HP for a spell whose sole effect is restoring hit points, at any level.
local healing = { Martyr_CureWounds_1=true, Martyr_CureWounds_2=true, Martyr_CureWounds_3=true, Martyr_HealingWord=true, Martyr_HealingWord_1=true, Martyr_HealingWord_2=true, Martyr_HealingWord_3=true }

local function ent(id) local ok,e=pcall(Ext.Entity.Get,id); if ok then return e end end
local function hasStatus(id,s) return Osi.HasActiveStatus(id,s)==1 end
-- Indemnify: caster -> creatures that take 1d8 Radiant whenever the caster loses HP.
local indemnified={}
local function key(id) return string.sub(tostring(id),-36) end
local MARTYR_CLASS="7f0673f5-7f42-5864-85dd-48a922911857"
local function martyrLevel(id)
    local e=ent(id); local cl=e and e.Classes and e.Classes.Classes
    for _,c in ipairs(cl or {}) do if tostring(c.ClassUUID)==MARTYR_CLASS then return c.Level end end
    return 0
end
-- Torment's price: 5 HP for +10, or 10 for +20 from 11th level. Taken off Health directly, so no concentration save.
local function tormentCost(id) return martyrLevel(id)>=11 and 10 or 5 end
local function indemnify(id)
    for target,guid in pairs(indemnified[key(id)] or {}) do
        if hasStatus(guid,"MARTYR_INDEMNIFY") then pcall(Osi.ApplyDamage,guid,math.random(1,8),"Radiant",id)
        else indemnified[key(id)][target]=nil end
    end
end

-- The hotbar re-checks spell requirements (the HP price) when an action resource changes, not when HP does:
-- flipping the hidden MartyrHotbarTick (from Ordained Death) makes it re-check.
local SPELL_USES="3148272e-c001-52f9-9017-db78ce5a9f91"
local HIT_DICE_RES="fe784912-4541-5222-9e60-04be2e079bbc"
local HOTBAR_TICK="b0fdcf37-fb3c-5101-85e0-36a7c7607934"
local function refreshHotbar(id)
    local e=ent(id); local all=e and e.ActionResources and e.ActionResources.Resources
    local res=all and all[HOTBAR_TICK]
    local r=res and res[1]; if not r then return end
    r.Amount=(r.Amount>=0.5) and 0 or 1
    pcall(function() e:Replicate("ActionResources") end)
end
-- An earlier build nudged the visible Spell Uses and Hit Dice by a millionth instead: round them back.
local function repairNudgedResources(id)
    local e=ent(id); local all=e and e.ActionResources and e.ActionResources.Resources
    local changed=false
    for _,g in ipairs({SPELL_USES,HIT_DICE_RES}) do
        local r=all and all[g] and all[g][1]
        if r and math.abs(r.Amount-math.floor(r.Amount+0.5))>1e-9 then r.Amount=math.floor(r.Amount+0.5); changed=true end
    end
    if changed then pcall(function() e:Replicate("ActionResources") end) end
end

-- The engine downs a character only when it sets her HP to 0 itself, and not in the middle of her own cast:
-- a price that takes her last HP holds her at 1 until the cast is over.
local pendingDown={}
local function downNow(id)
    if not pendingDown[key(id)] then return end
    pendingDown[key(id)]=nil
    Ext.Timer.WaitFor(50,function() Osi.SetHitpoints(id,0) end)
end
local function loseHP(id, amount)
    local e=ent(id); if not e or not e.Health then return end
    local hp=e.Health.Hp or 0
    e.Health.Hp=math.max(1,hp-amount)
    pcall(function() e:Replicate("Health") end)
    if hp-amount<=0 then
        pendingDown[key(id)]=true
        Ext.Timer.WaitFor(6000,function() downNow(id) end)  -- a cast that never reports back
    end
    Ext.Timer.WaitFor(100,function() refreshHotbar(id) end)
    indemnify(id)
end
local function isSacrosanct(id)
    -- Sacrosanct is granted as a passive; HasPassive is an Osiris query in BG3.
    local ok,v=pcall(Osi.HasPassive,id,"Martyr_SacrosanctSpell")
    return ok and v==1
end

-- Hit Dice: half back on a long rest (at least one), all of them with Respite. The game refills them fully (they
-- replenish on Rest; "Never" made spending lower the maximum), so the count at the rest's start is noted and restored.
local HIT_DICE="fe784912-4541-5222-9e60-04be2e079bbc"
local diceBeforeRest={}
-- A long rest ends the day's statuses; Transient Bulwark must not read that as a spent stage and chain.
local resting=false
local function hitDiceRow(id)
    local e=ent(id); local res=e and e.ActionResources and e.ActionResources.Resources[HIT_DICE]
    return e,res and res[1]
end
local function longRestStarted()
    resting=true
    for _,row in ipairs(Osi.DB_Players:Get(nil) or {}) do
        local _,r=hitDiceRow(row[1])
        if r then diceBeforeRest[key(row[1])]=r.Amount end
    end
end
local function longRestFinished()
    Ext.Timer.WaitFor(3000,function() resting=false end)
    Ext.Timer.WaitFor(500,function()
        for _,row in ipairs(Osi.DB_Players:Get(nil) or {}) do
            local e,r=hitDiceRow(row[1]); local before=diceBeforeRest[key(row[1])]
            if r and before then
                local ok,respite=pcall(Osi.HasPassive,row[1],"Martyr_Respite")
                local back=(ok and respite==1) and r.MaxAmount or math.max(1,math.floor(r.MaxAmount/2))
                r.Amount=math.min(r.MaxAmount,before+back)
                pcall(function() e:Replicate("ActionResources") end)
            end
        end
        diceBeforeRest={}
    end)
end

-- Self-Sacrifice (would-hit version): the ally's ward soaks the hit; each damage it took goes to the Martyr instead,
-- with its type (so the Martyr's resistances apply), and the ward comes off.
local wards={}
local function wardUp(ally,martyr)
    if not martyr then return end
    local k=key(ally)
    wards[k]={martyr=martyr,ally=ally}
    Ext.Timer.WaitFor(3000,function() if wards[k] then wards[k]=nil; pcall(Osi.RemoveStatus,ally,"MARTYR_SACRIFICE_WARD") end end)
end
local function wardHit(defender,attacker,damageType,amount)
    local w=wards[key(defender)]
    if not w or (tonumber(amount) or 0)<=0 then return end
    pcall(Osi.ApplyDamage,w.martyr,tonumber(amount),damageType,attacker)
    if not w.closing then
        w.closing=true
        Ext.Timer.WaitFor(200,function() wards[key(defender)]=nil; pcall(Osi.RemoveStatus,w.ally,"MARTYR_SACRIFICE_WARD") end)
    end
end
-- Allies near a Martyr carry MARTYR_SS_D<k>, k = Martyr AC - their AC, for the reaction's margin test.
local SS_MAX=15
local ssMarked={}
local function acOf(e) return e and e.Resistances and e.Resistances.AC end
local function refreshSacrificeMarks()
    local martyrs={}
    for _,row in ipairs(Osi.DB_Players:Get(nil) or {}) do
        if Osi.HasPassive(row[1],"Martyr_SelfSacrifice")==1 then martyrs[#martyrs+1]={id=row[1],e=ent(row[1])} end
    end
    local want={}
    if #martyrs>0 then
        for _,e in ipairs(Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")) do
            local id=e.Uuid and e.Uuid.EntityUuid
            if id then
                for _,m in ipairs(martyrs) do
                    if key(m.id)~=id and Osi.IsAlly(m.id,id)==1 and (Osi.GetDistanceTo(m.id,id) or 99)<4 then
                        local d=(acOf(m.e) or 0)-(acOf(e) or 0)
                        if d>0 then want[id]=math.min(d,SS_MAX) end
                        break
                    end
                end
            end
        end
    end
    for id,k in pairs(want) do
        if ssMarked[id]~=k then Osi.ApplyStatus(id,"MARTYR_SS_D"..k,-1,1); ssMarked[id]=k end
    end
    for id,k in pairs(ssMarked) do
        if not want[id] then pcall(Osi.RemoveStatus,id,"MARTYR_SS_D"..k); ssMarked[id]=nil end
    end
end
local ssLooping=false
local function sacrificeTick() pcall(refreshSacrificeMarks); Ext.Timer.WaitFor(500,sacrificeTick) end
local function sacrificeLoop() if not ssLooping then ssLooping=true; sacrificeTick() end end

local function onUsingSpell(character, spell, spellType, spellElement, storyActionID)
    if type(spell)~="string" or not spell:find("^Martyr_") then return end
    if spell=="Martyr_Counterspell" then return end  -- a reaction: paid through MARTYR_COUNTERSPELL_PAID
    -- Boomering's advantage is for the first target only; a new cast starts without the mark.
    if spell:find("^Martyr_Boomering") then pcall(Osi.RemoveStatus,character,"MARTYR_BOOMERING_FIRST") end
    local st=Ext.Stats.Get(spell); if not st then return end
    local level=tonumber(st.Level or 0) or 0
    if level<=0 then return end
    if isSacrosanct(character) and healing[spell] then return end
    local cost=spell:find("^Martyr_BloodPrint") and 5*level or spellCost[level]
    if cost then loseHP(character,cost) end
end

-- Burnt Offering: Wisdom instead of Dexterity for AC. The worn armour's AC ability is switched to Wisdom, so its
-- cap still applies and the tooltip says "from Wisdom"; with no body armour, 10 + Wisdom (ACOverrideFormula).
-- PersistentVars keeps what was changed (a number is an older build's flat AC boost) so it can be undone after a reload.
local function burnt()
    PersistentVars=PersistentVars or {}
    PersistentVars.BurntOffering=PersistentVars.BurntOffering or {}
    return PersistentVars.BurntOffering
end
local BURNT_FORMULA="ACOverrideFormula(10,true,Wisdom)"
local function recalcAC(object)  -- a boost change makes the game recompute AC from the armour
    Osi.AddBoosts(object,"AC(0)","MARTYR_BURNT_OFFERING",object)
    Osi.RemoveBoosts(object,"AC(0)",0,"MARTYR_BURNT_OFFERING",object)
end
local function setArmorAbility(item,from,to)
    local ie=item and ent(item); local a=ie and ie.Armor
    if a and a.ArmorClassAbility==from then a.ArmorClassAbility=to; pcall(function() ie:Replicate("Armor") end) end
end
local function burntOfferingOn(object)
    local item=Osi.GetEquippedItem(object,"Breast")
    local ie=item and ent(item); local a=ie and ie.Armor
    if a then
        if a.ArmorClassAbility==2 then  -- Dexterity; heavy armour adds none, so there is nothing to swap
            setArmorAbility(item,2,5); burnt()[key(object)]={item=key(item)}
        end
    else
        Osi.AddBoosts(object,BURNT_FORMULA,"MARTYR_BURNT_OFFERING",object); burnt()[key(object)]={formula=true}
    end
    recalcAC(object)
end
local function burntOfferingOff(object)
    local v=burnt()[key(object)]
    if type(v)=="number" then Osi.RemoveBoosts(object,"AC("..v..")",0,"MARTYR_BURNT_OFFERING",object)
    elseif type(v)=="table" then
        if v.item then setArmorAbility(v.item,5,2) end
        if v.formula then Osi.RemoveBoosts(object,BURNT_FORMULA,0,"MARTYR_BURNT_OFFERING",object) end
    end
    burnt()[key(object)]=nil
    recalcAC(object)
end

-- Transient Bulwark wards 3 attacks: each one removes a stage, and the next is applied.
local bulwarkNext={MARTYR_TRANSIENT_BULWARK="MARTYR_TRANSIENT_BULWARK_2",MARTYR_TRANSIENT_BULWARK_2="MARTYR_TRANSIENT_BULWARK_1"}
local function bulwarkSpent(object,status)
    -- A stage replaced by a recast leaves another stage on: nothing to do.
    for s in pairs({MARTYR_TRANSIENT_BULWARK=1,MARTYR_TRANSIENT_BULWARK_2=1,MARTYR_TRANSIENT_BULWARK_1=1}) do
        if hasStatus(object,s) then return end
    end
    if resting or Osi.IsDead(object)==1 then return end
    Osi.ApplyStatus(object,bulwarkNext[status],-1,1,object)
end

-- Snakestaff's Constrict: victim -> {snake, dist}. The grapple ends the moment the snake dies, goes, or moves off
-- (more than half a metre further away than where it settled after wrapping).
local constricted,constrictWatching={},false
local function release(victim)
    local hold=constricted[victim]; constricted[victim]=nil
    if hold then pcall(Osi.RemoveStatus,hold.snake,"MARTYR_CONSTRICTING") end
    pcall(Osi.RemoveStatus,victim,"MARTYR_CONSTRICTED")
    -- Removed off the victim's turn, the restrained pose stays until the victim acts: turning to the snake ends it.
    if hold and ent(hold.snake) then pcall(Osi.SteerTo,victim,hold.snake,0) end
end
local function distance(a,b) local ok,d=pcall(Osi.GetDistanceTo,a,b); return ok and d or nil end
local function holding(hold,victim)
    local snake=hold.snake
    if not ent(snake) or Osi.IsDead(snake)==1 or not hasStatus(snake,"MARTYR_CONSTRICTING") then return false end
    if not hold.dist then return true end   -- not settled round the victim yet
    local d=distance(snake,victim)
    return not d or d<=hold.dist+0.5
end
local function constrictWatch()
    local any=false
    for victim,hold in pairs(constricted) do
        if hasStatus(victim,"MARTYR_CONSTRICTED") and Osi.IsDead(victim)~=1 and holding(hold,victim) then any=true else release(victim) end
    end
    if any then Ext.Timer.WaitFor(200,constrictWatch) else constrictWatching=false end
end
-- The coil animation wraps round a point 1.72 m ahead: as close as collision lets the snake stand to a medium creature.
local COIL_REACH=1.72
local function placeCoil(victim,snake)
    local ok,sx,sy,sz=pcall(Osi.GetPosition,snake); local ok2,vx,vy,vz=pcall(Osi.GetPosition,victim)
    if not ok or not ok2 or not sx or not vx then return end
    local dx,dz=sx-vx,sz-vz; local d=math.sqrt(dx*dx+dz*dz)
    if d<0.01 then dx,dz,d=1,0,1 end
    pcall(Osi.TeleportToPosition,snake,vx+dx/d*COIL_REACH,vy,vz+dz/d*COIL_REACH,"",0,0,0,0,1)
    pcall(Osi.SteerTo,snake,victim,1)
end
local function constrictStart(victim,snake)
    local hold={snake=snake}
    constricted[key(victim)]=hold
    Ext.Timer.WaitFor(900,function()
        if constricted[key(victim)]~=hold then return end
        placeCoil(victim,snake)
        Ext.Timer.WaitFor(300,function() if constricted[key(victim)]==hold then hold.dist=distance(snake,victim) end end)
    end)
    if not constrictWatching then constrictWatching=true; Ext.Timer.WaitFor(200,constrictWatch) end
end

-- Havoc! (Discord): a melee weapon hit on an enemy marks it and readies the Havoc! button for the turn; casting it
-- rolls a d10 on the book's table, with 1 (Shield on the target), 3 (Indemnify on it) and 9 (Fireball at a random
-- spot) changed for BG3. Durations are in seconds, 6 to a turn.
local havocTarget={}
local HAVOC_TEXT={
    "Havoc! Your foe is shielded.", "Havoc! Lightning strikes you both.", "Havoc! Your foe is Indemnified.",
    "Havoc! Darkness falls.", "Havoc! You vanish.", "Havoc! Your foe bursts into flames.",
    "Havoc! Your foe's skin turns to brittle glass.", "Havoc! Your foe falls over.", "Havoc! Something explodes.",
    "Havoc! Chaos, twice over."}
local function dice(n,sides) local t=0; for _=1,n do t=t+math.random(1,sides) end; return t end
local function explodeSomewhere(caster)
    local ok,x,y,z=pcall(Osi.GetPosition,caster); if not ok or not x then return end
    local a,r=math.random()*2*math.pi,6+math.random()*9
    local px,py,pz=x+math.cos(a)*r,y,z+math.sin(a)*r
    local ok2,vx,vy,vz=pcall(Osi.FindValidPosition,px,py,pz,5,caster,0)
    if ok2 and vx then px,py,pz=vx,vy,vz end
    Osi.CreateExplosionAtPosition(px,py,pz,"Projectile_Fireball",3,caster)
end
local function havocEffect(caster,target,roll)
    if roll==1 then
        -- The bubble doesn't scale with the creature: Large and up get a scaled copy (ObjectSize 3, 4, 5).
        local e=ent(target); local size=e and e.ObjectSize and e.ObjectSize.Size or 2
        local status=({[3]="MARTYR_HAVOC_SHIELD_LARGE",[4]="MARTYR_HAVOC_SHIELD_HUGE",[5]="MARTYR_HAVOC_SHIELD_GARGANTUAN"})[size]
        Osi.ApplyStatus(target,status or "MARTYR_HAVOC_SHIELD",6,1,caster)
    elseif roll==2 then
        -- Call Lightning's bolt on each of them; the damage lands as it strikes.
        for _,who in ipairs({caster,target}) do
            local ok,x,y,z=pcall(Osi.GetPosition,who)
            if ok and x then pcall(Osi.PlayEffectAtPosition,"8c464fe2-3fa6-d6ef-4a1b-6b9a4301159d",x,y,z) end
        end
        local d=dice(3,6)
        Ext.Timer.WaitFor(500,function() Osi.ApplyDamage(caster,d,"Lightning",caster); Osi.ApplyDamage(target,d,"Lightning",caster) end)
    elseif roll==3 then Osi.ApplyStatus(target,"MARTYR_INDEMNIFY",60,1,caster)
    elseif roll==4 then Osi.CreateSurface(target,"SurfaceDarknessCloud",5,60)
    elseif roll==5 then Osi.ApplyStatus(caster,"INVISIBILITY",12,1,caster)
    elseif roll==6 then Osi.ApplyStatus(target,"BURNING",60,1,caster)
    elseif roll==7 then Osi.ApplyStatus(target,"MARTYR_HAVOC_GLASS",6,1,caster)
    elseif roll==8 then Osi.ApplyStatus(target,"PRONE",6,1,caster)
    elseif roll==9 then explodeSomewhere(caster) end
end
local function havoc(caster)
    local target=havocTarget[key(caster)]; havocTarget[key(caster)]=nil
    pcall(Osi.RemoveStatus,caster,"MARTYR_HAVOC_READY")
    if not target then return end
    pcall(Osi.RemoveStatus,target,"MARTYR_HAVOC_MARK")
    -- The roll's own status names it in the combat log ("received Condition: Havoc! 5: You vanish").
    local function announce(r)
        print(MOD.." Havoc! rolled "..r)
        pcall(Osi.ApplyStatus,caster,"MARTYR_HAVOC_ROLL_"..r,6,1,caster)
        pcall(Osi.ShowNotification,caster,HAVOC_TEXT[r])
    end
    local roll=math.random(1,10)
    announce(roll)
    if roll<10 then havocEffect(caster,target,roll); return end
    -- 10: roll twice and apply both; a 10 on either is ignored.
    for _=1,2 do local r=math.random(1,10); if r<10 then announce(r); havocEffect(caster,target,r) end end
end

local function statusRemoved(object,status,causee,storyActionID)
    if status=="MARTYR_HAVOC_READY" then refreshHotbar(object); return end
    if status=="MARTYR_CONSTRICTED" then release(key(object))
    elseif status=="MARTYR_CONSTRICTING" then
        for victim,hold in pairs(constricted) do if key(hold.snake)==key(object) then release(victim) end end
    elseif status=="MARTYR_INDEMNIFY" then
        for _,targets in pairs(indemnified) do targets[key(object)]=nil end
    elseif status=="MARTYR_BURNT_OFFERING" then burntOfferingOff(object)
    elseif bulwarkNext[status] then bulwarkSpent(object,status) end
end

local function hurt(defender, attackerOwner, attacker, damageType, damageAmount, damageCause, storyActionID)
    if (tonumber(damageAmount) or 0)>0 and indemnified[key(defender)] then indemnify(defender) end
end

local function statusApplied(object,status,causee,storyActionID)
    if status=="MARTYR_SACRIFICE_WARD" then wardUp(object,causee); return end
    if status=="MARTYR_HAVOC_MARK" and causee then havocTarget[key(causee)]=object; return end
    if status=="MARTYR_HAVOC_READY" then Ext.Timer.WaitFor(100,function() refreshHotbar(object) end); return end
    if status=="MARTYR_CONSTRICTED" and causee then constrictStart(object,causee); return end
    if status=="MARTYR_TORMENT_SPENT" then loseHP(object,tormentCost(object)); return end
    -- Counterspell's price as a 3rd-level Martyr spell, whether or not the counter succeeded.
    if status=="MARTYR_COUNTERSPELL_PAID" then loseHP(object,spellCost[3]); return end
    if status=="MARTYR_TORMENTED" and causee then
        -- Blooded Reprieve: no HP lost if the hit killed a hostile creature.
        Ext.Timer.WaitFor(300,function()
            local ok,has=pcall(Osi.HasPassive,causee,"Martyr_BloodedReprieve")
            if ok and has==1 and Osi.IsDead(object)==1 and Osi.IsEnemy(causee,object)==1 then
                local e=ent(causee); if e and e.Health then e.Health.Hp=math.min(e.Health.MaxHp,e.Health.Hp+tormentCost(causee)); pcall(function() e:Replicate("Health") end) end
            end
        end)
        return
    end
    if status=="MARTYR_INDEMNIFY" and causee then
        indemnified[key(causee)]=indemnified[key(causee)] or {}
        indemnified[key(causee)][key(object)]=object
        return
    end
    if status=="MARTYR_BURNT_OFFERING" then burntOfferingOff(object); burntOfferingOn(object); return end
end

-- Passives that come with Martyr levels (menu unlocks, Extra Attack), for Martyrs who passed those levels on an older build.
local UNLOCKS={{2,"Martyr_Unlock_BloodPrint1"},{3,"Martyr_Unlock_DivineHealing12"},{5,"Martyr_Unlock_Level5"},{9,"Martyr_Unlock_Level9"},{13,"Martyr_Unlock_Level13"},{17,"Martyr_Unlock_Level17"},{5,"ExtraAttack"}}
local function subclassIs(id,uuid)
    local e=ent(id); local cl=e and e.Classes and e.Classes.Classes
    for _,c in ipairs(cl or {}) do if tostring(c.SubClassUUID)==uuid then return true end end
    return false
end
-- An earlier build zeroed the Hit Dice maximum in some saves, and the game doesn't recompute it: one die per Martyr level.
local function repairHitDice(id)
    local e=ent(id); local res=e and e.ActionResources and e.ActionResources.Resources[HIT_DICE]
    local r=res and res[1]; local lv=martyrLevel(id)
    if r and lv>0 and r.MaxAmount<lv then
        r.MaxAmount=lv; r.Amount=math.min(r.Amount,lv)
        pcall(function() e:Replicate("ActionResources") end)
    end
end
local function grantUnlocks(id)
    local lv=martyrLevel(id)
    for _,u in ipairs(UNLOCKS) do
        if lv>=u[1] and Osi.HasPassive(id,u[2])~=1 then Osi.AddPassive(id,u[2]) end
    end
end
-- Martyr_BoomeringArc came with level 2 after some Martyrs had passed it.
local function grantMissingPassives()
    for _,row in ipairs(Osi.DB_Players:Get(nil) or {}) do
        local id=row[1]
        local ok,isMartyr=pcall(Osi.HasPassive,id,"Martyr_SaintedReprisal")
        local ok2,has=pcall(Osi.HasPassive,id,"Martyr_BoomeringArc")
        if ok and isMartyr==1 and ok2 and has~=1 then Osi.AddPassive(id,"Martyr_BoomeringArc") end
        -- The Torment feature brings its two toggles (a passive can't grant passives, so the Lua does).
        local ok3,torment=pcall(Osi.HasPassive,id,"Martyr_Torment")
        if ok3 and torment==1 and Osi.HasPassive(id,"Martyr_TormentRadiant")~=1 then
            Osi.AddPassive(id,"Martyr_TormentRadiant"); Osi.AddPassive(id,"Martyr_TormentNecrotic")
        end
        -- Healing Magic is a rule of the class, not a feature: an earlier build added it as a passive.
        if Osi.HasPassive(id,"Martyr_HealingMagic")==1 then Osi.RemovePassive(id,"Martyr_HealingMagic") end
        grantUnlocks(id)
        repairHitDice(id)
        repairNudgedResources(id)
        -- Undying Conviction's ready status comes on OnCreate and OnLongRest; a Martyr from an older build has neither.
        if Osi.HasPassive(id,"Martyr_Undying")==1 and not hasStatus(id,"MARTYR_UNDYING") and not hasStatus(id,"MARTYR_UNDYING_SPENT") then
            Osi.ApplyStatus(id,"MARTYR_UNDYING",-1,1,id)
        end
        if subclassIs(id,"1e8e90a0-1af3-5368-9bae-079f53e922dc") and Osi.HasPassive(id,"Martyr_SelfSacrifice")~=1 then Osi.AddPassive(id,"Martyr_SelfSacrifice") end
        if subclassIs(id,"e9818795-9a1e-52f9-bad8-c14d70778a47") and Osi.HasPassive(id,"Martyr_HeraldOfTheEnd")~=1 then  -- End
            Osi.AddPassive(id,"Martyr_HeraldOfTheEnd")
        end
        if subclassIs(id,"db06ac5b-a5a1-5419-9847-bd9396636b1b") and Osi.HasPassive(id,"Martyr_MoralErudition")~=1 then  -- Truth: Moral Erudition came late
            Osi.AddPassive(id,"Martyr_MoralErudition")
        end
        if subclassIs(id,"cb975b92-5eb7-578d-aafb-0f26bfdab549") then  -- Discord: Havoc! came after some had passed 1st level
            for _,p in ipairs({"Martyr_Havoc","Martyr_HavocTrigger"}) do if Osi.HasPassive(id,p)~=1 then Osi.AddPassive(id,p) end end
        end
    end
end


local function tryRegister(name,arity,when,fn)
    local ok,err=pcall(Ext.Osiris.RegisterListener,name,arity,when,fn)
    if not ok then print(MOD.." listener "..name.." unavailable: "..tostring(err)) end
end

tryRegister("UsingSpell",5,"before",onUsingSpell)
tryRegister("CastedSpell",5,"after",function(caster,spell)
    downNow(caster)
    if spell=="Shout_Martyr_Havoc" then havoc(caster) end
    if type(spell)=="string" and spell:find("^Martyr_Boomering") then pcall(Osi.RemoveStatus,caster,"MARTYR_BOOMERING_FIRST") end
end)
-- Burnt Offering follows the armour: redo the swap when body armour changes, and after a load
-- (a reload rebuilds the armour from its stats); a leftover change without the status is undone.
do
    local function redo(char)
        if burnt()[key(char)]~=nil then burntOfferingOff(char) end
        if hasStatus(char,"MARTYR_BURNT_OFFERING") then burntOfferingOn(char) end
    end
    local function onEquipChange(item,char)
        if char and (hasStatus(char,"MARTYR_BURNT_OFFERING") or burnt()[key(char)]~=nil) then
            Ext.Timer.WaitFor(200,function() redo(char) end)
        end
    end
    tryRegister("Equipped",2,"after",onEquipChange)
    tryRegister("Unequipped",2,"after",onEquipChange)
    tryRegister("LevelGameplayStarted",2,"after",function()
        for _,row in ipairs(Osi.DB_Players:Get(nil) or {}) do pcall(redo,row[1]) end
    end)
end
-- Diabolic Ultimatum: the book lets the target choose charm or fear; the AI can't, so a failed save flips a coin.
tryRegister("StatusApplied",4,"after",function(object,status,causee)
    if status~="MARTYR_ULTIMATUM_FAILED" then return end
    local choice=math.random(1,2)==1 and "MARTYR_ULTIMATUM_CHARMED" or "MARTYR_ULTIMATUM_FRIGHTENED"
    Osi.ApplyStatus(object,choice,60,1,causee or object)  -- 10 turns
end)
-- Maxim of Truth: an Exposed creature also loses invisibility statuses outside SG_Invisible (any INVISIBLE type).
do
    local function invisible(s) local ok,st=pcall(Ext.Stats.Get,s); return ok and st and st.StatusType=="INVISIBLE" end
    tryRegister("StatusApplied",4,"after",function(object,status)
        if status=="MARTYR_MAXIM_EXPOSED" then
            local e=ent(object)
            for _,s in pairs(e and e.StatusContainer and e.StatusContainer.Statuses or {}) do
                if invisible(tostring(s)) then pcall(Osi.RemoveStatus,object,tostring(s)) end
            end
        elseif invisible(status) and hasStatus(object,"MARTYR_MAXIM_EXPOSED") then pcall(Osi.RemoveStatus,object,status) end
    end)
end
-- Bulwark of Rebellion: 1d10 + level temporary HP, or what Bulwark has left if that is more; the duration always refreshes.
do
    local MAX=22
    local function bulwarkCast(id)
        local e=ent(id); if not e or not e.Health then return end
        local level=(e.EocLevel and e.EocLevel.Level) or martyrLevel(id)
        local roll=math.random(1,10)+level
        local current=e.Health.TemporaryHp or 0
        local own=hasStatus(id,"MARTYR_BULWARK")
        for n=1,MAX do if hasStatus(id,"MARTYR_BULWARK_"..n) then own=true end end
        if not own and current>=roll then return end  -- another source's higher temporary HP stays
        local amount=math.min(MAX,own and math.max(roll,current) or roll)
        pcall(Osi.RemoveStatus,id,"MARTYR_BULWARK")
        for n=1,MAX do if hasStatus(id,"MARTYR_BULWARK_"..n) then pcall(Osi.RemoveStatus,id,"MARTYR_BULWARK_"..n) end end
        Osi.ApplyStatus(id,"MARTYR_BULWARK_"..amount,3600,1,id)
    end
    tryRegister("CastedSpell",5,"after",function(caster,spell) if spell=="Shout_Martyr_Bulwark" then bulwarkCast(caster) end end)
end
tryRegister("HitpointsChanged",2,"after",function(id) Ext.Timer.WaitFor(100,function() refreshHotbar(id) end) end)
tryRegister("CastSpellFailed",5,"after",function(caster) downNow(caster) end)
tryRegister("StatusApplied",4,"after",statusApplied)
tryRegister("AttackedBy",7,"after",hurt)
tryRegister("AttackedBy",7,"after",function(d,o,a,t,amount) wardHit(d,a,t,amount) end)
tryRegister("StatusRemoved",4,"after",statusRemoved)
-- A dead victim keeps Constricted, so the snake would keep holding it.
tryRegister("Died",1,"after",function(dead) if constricted[key(dead)] then release(key(dead)) end end)
tryRegister("LongRestStarted",0,"after",longRestStarted)
tryRegister("LongRestFinished",0,"after",longRestFinished)
-- TEMPORARY test hook: Mods.MartyrValdas.DebugLongRest() runs the long-rest Hit Dice refill without resting.
function DebugLongRest() longRestStarted(); longRestFinished(); print(MOD.." DebugLongRest: ran the Hit Dice long-rest refill") end
tryRegister("LevelGameplayStarted",2,"after",function() grantMissingPassives(); sacrificeLoop() end)
tryRegister("LeveledUp",1,"after",function() Ext.Timer.WaitFor(500,grantMissingPassives) end)

print(MOD.." loaded")
