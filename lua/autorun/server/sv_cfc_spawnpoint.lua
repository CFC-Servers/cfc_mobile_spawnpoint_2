resource.AddWorkshop( "3114959065" )

local HOOK_CANTOOL = "CFC_Spawnpoint2_BannedTools"
local bannedTools = {
    ["nocollideeverything"] = true,
    ["nocollide"] = true,
}
hook.Remove( "CanTool" , HOOK_CANTOOL )
hook.Add( "CanTool" , HOOK_CANTOOL, function( ply, tr, tool )
    if not tr.Hit then return end
    if not IsValid( tr.Entity ) then return end
    if tr.Entity:GetClass() ~= "sent_spawnpoint" then return end

    if bannedTools[tool] then
        ply:ChatPrint( string.format( "You cant use '%s' on a spawnpoint", tool) )
        return false
    end
end)
