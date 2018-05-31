###############################
## Demo #4                   ##
## Pulling things together   ##
## Change details for        ##
## -vcenter connection       ##
## -influxdb connection & db ##
###############################

function Get-DBTimestamp($timestamp = (get-date)){
    if($timestamp -is [system.string]){
        $timestamp = [datetime]::ParseExact($timestamp,'dd.MM.yyyy HH:mm:ss',$null)
    }
    return $([long][double]::Parse((get-date $($timestamp).ToUniversalTime() -UFormat %s)) * 1000 * 1000 * 1000)
}

$vcenterServer = "name-or-ip-to-your-vcenter"
$vcUser = "vcenter-user"
$vcPass = "vcenter-pass"

$influxDBServer = "name-or-ip-to-your-influxdb"
$influxDBName = "performance"

$metrics = "cpu.ready.summation","cpu.costop.summation","cpu.latency.average","cpu.usagemhz.average","cpu.usage.average","mem.active.average","mem.usage.average","net.received.average","net.transmitted.average","disk.maxtotallatency.latest","disk.read.average","disk.write.average","net.usage.average","disk.usage.average"
$cpuRdyInt = 200
$run = 1
while($true){
    $lapstart = Get-Date
    #region Connect
        Connect-VIServer -Server $vcenterServer -User $vcUser -Password $vcPass | Out-Null
    #end region

    $vms = Get-VM
    $tbl = @()

    foreach($vm in $vms){
        
        #Build variables for vm "metadata"    
        $vid = $vm.Id
        $vname = $vm.name
        $vproc = $vm.NumCpu
        $cname = $vm.VMHost.Parent.Name
        $hname = $vm.VMHost.Name
        $vname = $vname.toUpper()

        #Get the stats
        $stats = Get-Stat -Entity $vm -Realtime -MaxSamples 2 -Stat $metrics
        
        foreach($stat in $stats){
            $instance = $stat.Instance

            if($instance -or $instance -ne ""){
                continue
            }
                
            $unit = $stat.Unit
            $value = $stat.Value
            $statTimestamp = Get-DBTimestamp $stat.Timestamp

            if($unit -eq "%"){
                $unit = "perc"
            }

            switch ($stat.MetricId) {
                "cpu.ready.summation" { $measurement = "cpu_ready";$value = $(($Value / $cpuRdyInt)/$vproc); $unit = "perc" }
                "cpu.costop.summation" { $measurement = "cpu_costop";$value = $(($Value / $cpuRdyInt)/$vproc); $unit = "perc" }
                "cpu.latency.average" {$measurement = "cpu_latency" }
                "cpu.usagemhz.average" {$measurement = "cpu_usagemhz" }
                "cpu.usage.average" {$measurement = "cpu_usage" }
                "mem.active.average" {$measurement = "mem_usagekb" }
                "mem.usage.average" {$measurement = "mem_usage" }
                "net.received.average"  {$measurement = "net_through_receive"}
                "net.transmitted.average"  {$measurement = "net_through_transmit"}
                "net.usage.average"  {$measurement = "net_through_total"}
                "disk.maxtotallatency.latest" {$measurement = "storage_latency";if($value -ge $latThreshold){$value = 0}}
                "disk.read.average" {$measurement = "disk_through_read"}
                "disk.write.average" {$measurement = "disk_through_write"}
                "disk.usage.average" {$measurement = "disk_through_total"}
                Default { $measurement = $null }
            }

            if($measurement -ne $null){
                $tbl += "$measurement,type=vm,vm=$vname,vmid=$vid,host=$hname,cluster=$cname,unit=$unit value=$Value $stattimestamp"
            }

        }
        
    }

    Disconnect-VIServer -Server $vcenterServer -Confirm:$false

    $baseUri = "http://$influxDBServer" + ":8086/"
    $postUri = $baseUri + "write?db=" + $influxDBName

    Invoke-RestMethod -Method Post -Uri $postUri -Body ($tbl -join "`n")
    
    $lapstop = Get-Date
    $lapspan = New-TimeSpan -Start $lapstart -End $lapstop
    Write-Output "Run #$run took $($lapspan.totalseconds) seconds"
    $run++
    Start-Sleep -Seconds 20
}

