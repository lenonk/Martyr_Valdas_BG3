-- Server: each Martyr spell's effective level, cost and inherited RequirementConditions; and the host.
for _, name in ipairs(Ext.Stats.GetStats("SpellData")) do
  local s = Ext.Stats.Get(name)
  local uc = s and s.UseCosts or ""
  if type(uc) ~= "string" then uc = Ext.Json.Stringify(uc) end
  if s and tostring(uc):find("MartyrSpellUses") then
    print("MDS", name, s.Level, s.PowerLevel, "RC=[" .. tostring(s.RequirementConditions) .. "]", "parent=" .. tostring(s.Using))
  end
end
local host = Osi.GetHostCharacter()
local e = Ext.Entity.Get(host)
print("MDH", host, e.Health.Hp, e.Health.MaxHp, "temp", e.Health.TemporaryHp)
for _, c in ipairs(e.Classes.Classes) do print("MDH class", tostring(c.ClassUUID), c.Level) end
print("MDS done")
