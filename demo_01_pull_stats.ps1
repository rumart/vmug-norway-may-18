##########################
## Demo #1 - Pull stats ##
##########################

#region Connect
    Connect-VIServer -Server "ip-or-name-to-vcenter"
#end region

#region Verify connection
    Get-VM -OutVariable vms
#end region

#region Check out Get-Stat
    Get-Stat $vms[0]
#end region

#region What kind of metrics are available?
    Get-StatType -Entity $vms[0]
#end region

#region Realtime stats
    Get-StatType -Entity $vms[0] -Realtime | sort
#end region

#region Common metrics / specific
    Get-Stat -Entity $vms[0] -Realtime -Common
    Get-Stat -Entity $vms[0] -Realtime -Cpu -Memory -Disk -Network
    Get-Stat -Entity $vms[0] -Realtime -Stat cpu.usage.average
#end region

#region Specify start/stop
    Get-Stat -Entity $vms[0] -Realtime -Stat cpu.usage.average,mem.usage.average -Start (Get-Date).AddMinutes(-5)
#end region
