
net.Receive( "CFC_SpawnPoints_CreationDenied", function()
    local reason = net.ReadString()

    notification.AddLegacy( reason, NOTIFY_ERROR, 5 )
    surface.PlaySound( "buttons/button10.wav" )
end )
