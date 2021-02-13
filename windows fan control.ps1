$ServerNames = @(
    'idrac-r710-01',
    'idrac-r610-01',
    'idrac-r710-02',
    'idrac-r510-01'
)

$SleepTimer = 5 <# Default 30: Seconds between loops. #>
$InitialSpeed = 5 <# Default 20: Speed to start at and ramp up or down as it needs to. #>
$Step = 2 <# Default 2: How fast to go up and down as temps change. #>

$DracUser = 'root'
$DracPass = 'root'
$IpmiPath = 'C:\Program Files (x86)\Dell\SysMgt\bmc'
$IpmiTool = Get-ChildItem -Path $ipmiPath 'ipmitool.exe'

Function Get-SystemType () {
    param( $Foo )
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $ipmiTool.FullName
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $Foo.getSystemType
    $pinfo.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stdout = $stdout -replace "`n", ""
    $stdout = $stdout -replace " ", ""
    Switch ( $stdout ) {
        "1100000f506f776572456467652052373130" { Return "PowerEdge R710" }
        "1100000f506f776572456467652052363130" { Return "PowerEdge R610" }
        "1100000f506f776572456467652052353130" { Return "PowerEdge R510" }
        default { Return "Unknown system type" }
    }
}

Function Get-PowerState (){
    param( $Foo )
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $ipmiTool.FullName
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $Foo.GetPowerState
    $pinfo.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    If ( $stdout -like "Chassis Power is on*" ) { Return $true }
    Else { Return $false }
}

Function Get-RPM (){
    param( $Foo )
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $ipmiTool.FullName
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $Foo.GetRPM
    $pinfo.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    Return [int]$stdout.Substring( $stdout.IndexOf( "|" ) +1 )
}

Function Get-Temp (){
    param( $Foo )
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $ipmiTool.FullName
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $Foo.GetTemp
    $pinfo.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    Return [int]$stdout.Substring( $stdout.IndexOf( "|" ) +1 )
}  

Function Set-Control (){
    param( $Foo, $Type )
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $ipmiTool.FullName
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false   
    If ( $Type -eq "A" ) { $pinfo.Arguments = $Foo.SetAuto }
    If ( $Type -eq "M" ) { $pinfo.Arguments = $Foo.SetManual }
    $pinfo.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
}

Function Set-Speed () {
    param( $Foo )
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $ipmiTool.FullName
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = "$( $Foo.SetSpeed )$( "{0:x2}" -f $Foo.Speed )"
    $pinfo.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
}


[System.Collections.ArrayList]$Servers = @()

<#
This is a terribly inefficient way to do this, but it works and is easy to debug, so too bad.
Also, I could have checked if servers are online and skipped them entirely during the initialization, but I didn't on purpose.
I wanted this to be flexible enough to work with servers that go on and off.
#>

"Initializing everything. This will take a few seconds per server."

ForEach ( $Server in $ServerNames ){
    $TempServer = New-Object -TypeName psobject
    $TempServer | Add-Member -NotePropertyName ServerName -NotePropertyValue $Server
    $TempServer | Add-Member -NotePropertyName BaseArgs -NotePropertyValue "-I lanplus -H $( $TempServer.ServerName ) -U $dracUser -P $dracPass"
    
    $TempServer | Add-Member -NotePropertyName SetAuto -NotePropertyValue "$( $TempServer.BaseArgs ) raw 0x30 0x30 0x01 0x01"
    $TempServer | Add-Member -NotePropertyName SetManual -NotePropertyValue "$( $TempServer.BaseArgs ) raw 0x30 0x30 0x01 0x00"
    $TempServer | Add-Member -NotePropertyName Speed -NotePropertyValue $InitialSpeed
    $TempServer | Add-Member -NotePropertyName SetSpeed -NotePropertyValue "$( $TempServer.BaseArgs ) raw 0x30 0x30 0x02 0xff 0x"
    
    $TempServer | Add-Member -NotePropertyName GetTemp   -NotePropertyValue "$( $TempServer.BaseArgs ) sensor reading `"Ambient Temp`""
    $TempServer | Add-Member -NotePropertyName CurrentTemp -NotePropertyValue ( Get-Temp $TempServer )
    $TempServer | Add-Member -NotePropertyName LastTemp -NotePropertyValue $TempServer.CurrentTemp

    $TempServer | Add-Member -NotePropertyName GetSystemType -NotePropertyValue "$( $TempServer.BaseArgs ) raw 0x06 0x59 0x00 0xd1 0x00 0x00"
    $TempServer | Add-Member -NotePropertyName SystemType -NotePropertyValue ( Get-SystemType $TempServer )
    
    $TempServer | Add-Member -NotePropertyName DracOnline -NotePropertyValue ( Test-Connection $TempServer.ServerName -Count 1 -Quiet )
    $TempServer | Add-Member -NotePropertyName GetPowerState -NotePropertyValue "$( $TempServer.BaseArgs ) chassis power status"
    $TempServer | Add-Member -NotePropertyName PoweredOn -NotePropertyValue ( Get-PowerState $TempServer )
    
    <# Adjust for various model servers as needed. #>
    Switch ( $TempServer.SystemType ) {
        "PowerEdge R510" {
            $TempServer | Add-Member -NotePropertyName GetRPM -NotePropertyValue "$( $TempServer.BaseArgs ) sensor reading `"FAN MOD 3A RPM`""
            $TempServer | Add-Member -NotePropertyName MinRPM -NotePropertyValue 1500
            $TempServer | Add-Member -NotePropertyName MinSpeed -NotePropertyValue 10
            $TempServer | Add-Member -NotePropertyName MaxTemp -NotePropertyValue 40
        }
        "PowerEdge R610" {
            $TempServer | Add-Member -NotePropertyName GetRPM -NotePropertyValue "$( $TempServer.BaseArgs ) sensor reading `"FAN MOD 3A RPM`""
            $TempServer | Add-Member -NotePropertyName MinRPM -NotePropertyValue 1500
            $TempServer | Add-Member -NotePropertyName MinSpeed -NotePropertyValue 10
            $TempServer | Add-Member -NotePropertyName MaxTemp -NotePropertyValue 40
        }
        "PowerEdge R710" {
            $TempServer | Add-Member -NotePropertyName GetRPM -NotePropertyValue "$( $TempServer.BaseArgs ) sensor reading `"FAN 3 RPM`""
            $TempServer | Add-Member -NotePropertyName MinRPM -NotePropertyValue 1000
            $TempServer | Add-Member -NotePropertyName MinSpeed -NotePropertyValue 10
            $TempServer | Add-Member -NotePropertyName MaxTemp -NotePropertyValue 40
        }
        default {  }
    }
    
    $TempServer | Add-Member -NotePropertyName CurrentRPM -NotePropertyValue ( Get-RPM $TempServer )
    $Servers.Add( $TempServer ) | Out-Null
}

$Servers | ForEach-Object { Set-Control $_ "M" }
$Servers | ForEach-Object { Set-Speed $Server.Speed }

Start-Sleep -Seconds $SleepTimer

Do {
    ForEach ( $Server in $Servers ) {
        $Server.DracOnline = Test-Connection $Server.ServerName -Count 1 -Quiet
        $Server.PoweredOn = Get-PowerState $Server
        If ( $Server.DracOnline -and $Server.PoweredOn ) {
            $Server.CurrentTemp = Get-Temp $Server
            Switch ( $Server ) {
                { $Server.CurrentTemp -ge $Server.MaxTemp } {
                    Set-Control $Server "A"
                    For ( $i = 1 ; $i -le 5 ; $i ++ ) {
                        [console]::Beep( 3000, 100 )
                        [console]::Beep( 2000, 100 )
                        }
                }
                
                { $Server.CurrentTemp -le $Server.LastTemp } {
                    If ( ( $Server.Speed - $Step ) -ge $Server.MinSpeed ) { $Server.Speed = $Server.Speed - $Step }
                }
                
                { $Server.CurrentTemp -gt $Server.LastTemp } {
                    $Server.Speed = $Server.Speed + ( $Step * 2 )
                }
            }
        Set-Speed $Server
        $Server.CurrentRPM = Get-RPM $Server    
        $Server.LastTemp = $Server.CurrentTemp    
        }
    }
    $Servers | Where-Object { $_.PoweredOn } | Select-Object `
        @{ Name = "Server Name" ; Expression = { $_.ServerName } } , `
        @{ Name = "Temperature" ; Expression = { $_.CurrentTemp } } , `
        @{ Name = "Fan RPM"; Expression = { $_.CurrentRPM } }, `
        Speed
    Start-Sleep -Seconds $SleepTimer
} While ( $true )
