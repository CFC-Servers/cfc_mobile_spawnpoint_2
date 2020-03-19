local HOOK_CANTOOL = "CFC_Spawnpoint2_BannedTools"
local bannedTools = {
    ["nocollideeverything"] = true,
    ["nocollide"] = true,
}
hook.Remove( "CanTool" , HOOK_CANTOOL )
hook.Add( "CanTool" , HOOK_CANTOOL, function( ply, tr, tool )
    if not tr.Entity or tr.Entity:GetClass() ~= "sent_spawnpoint" then return end
    
    if bannedTools[tool] then
        ply:ChatPrint( string.format( "You cant use '%s' on a spawnpoint", tool) )
        return false
    end
    
end)
