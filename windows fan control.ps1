#######################################################################################R330FanControl.ps1###

# First and foremost, I cannot recommend using this or any script to alter system cooling or kill processes as it can cause damage or break stuff!
# I accept no liability for anything, USE AT YOUR OWN RISK!
# CAUTION this sctipt could possibly damage things especially data but if your server is already cooking itself it should help lower the temperatures but know if it kills something as it’s writing data consider it lost!
# READ AND UNDERSTAND WHAT IT IS DOING SO YOU CAN MODIFY AS NEEDED

# REQUIRES ipmitools “OM-BMC-Dell-Web-WIN-9.1.0-2757_A00.exe” is what I downloaded from Dell at: https://www.dell.com/support/home/en-us/drivers/driversdetails?driverid=9ngfj
# Add to the system variable path the installation folder which might be different from “C:\Program Files (x86)\Dell\SysMgt\bmc” where the ipmitool.exe is located.

# Setup
# create a scheduled task to run on startup that calls powershell.exe with the following parameter(remove the # before the -file part):
# -file “C:\Scripts\PS\R330FanControl\R330FanControl.ps1″
# Set to run with highest privledges and without being logged in, be sure it’s enabled and reboot. Then verify it’s running in the background.

#Variables###################################

# Set iDRAC IP
$iDRAC=”XXX.XXX.XXX.XXX”
# Set iDRAC Credentials
$usr=”root”
$pw=”calvin”

#Reset counter
$i=0

# Enables fan control via ipmitool
$FanControlEnable = “ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x01 0x00”

# DISABLE FAN CONTROL if you ever want to do so.
# ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x01 0x01

# Sets fan speed to % defined in $FanControl variable
# hex conversion tables http://cactus.io/resources/toolbox/decimal-binary-octal-hexadecimal-conversion
$FanControl20 = (“ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x14”)
$FanControl30 = (“ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x1e”)
$FanControl40 = (“ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x28”)
$FanControl50 = (“ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x32”)
$FanControl60 = (“ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x3c”)
$FanControl70 = (“ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x46”)
$FanControl80 = (“ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x50”)
$FanControl90 = (“ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x5a”)
$FanControl100 = (“ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x64”)

#######################
$KillHighCPU = “C:\Scripts\PS\R330FanControl\Kill_CPU_hog.ps1”
#######################
# Retrieves temperatures:
# ipmitool -H $iDRAC -U $usr -P $pw -I lanplus sdr elist | findstr “Temp” | findstr “0Eh”

#############################################

Invoke-Expression -Command $FanControlEnable

While($true)
{
$i++
$cpuTemp = (ipmitool -H $iDRAC -U $usr -P $pw -I lanplus sdr elist | findstr “Temp” | findstr “0Eh” | %{$_.split(‘|’)[4]})

# Extract the digits of the temperature
$cpuTempDigits=$cpuTemp.Substring(0,3)

# Displays the temerature as the script is running
$cpuTempDigits

# Switch logic to change the fan based on operating temperature reported via ipmi. (I noticed this displays different temperatures thatn Speccy, not sure which is more accurate)
# My processor is a e3-1220 V6 which from what I could find has a maximum temperature of ~70°C
# The last temperature from 67-999C will invoke another script tha twill find and kill the process usign the most CPU resources, THIS COULD POTENTIALLY BE DANGEROUS!
switch ($cpuTempDigits) {
{1..49 -contains $_}{write-host “Fan set to 20%” ; Invoke-Expression -Command $FanControl20}
{50..52 -contains $_}{write-host “Fan set to 30%” ;Invoke-Expression -Command $FanControl30}
{53..54 -contains $_}{write-host “Fan set to 40%” ;Invoke-Expression -Command $FanControl40}
{55..56 -contains $_}{write-host “Fan set to 50%” ;Invoke-Expression -Command $FanControl50}
{57..58 -contains $_}{write-host “Fan set to 60%” ;Invoke-Expression -Command $FanControl60}
{59..60 -contains $_}{write-host “Fan set to 70%” ;Invoke-Expression -Command $FanControl70}
{61..62 -contains $_}{write-host “Fan set to 80%” ;Invoke-Expression -Command $FanControl80}
{63..64 -contains $_}{write-host “Fan set to 90%” ;Invoke-Expression -Command $FanControl90}
{65..66 -contains $_}{write-host “Fan set to 100%” ;Invoke-Expression -Command $FanControl100}
{67..999 -contains $_}{write-host “Killing processes to cool down!” ;Invoke-Expression -Command $KillHighCPU}

}
# IF YOU ARE MANUALLY RUNNING THIS SCRIPT you can uncomment out the line below to watch it display the number of times it’s checking temps and setting the fan speeds.
#Write-Host “Action has run $i times at” (date)
}

#################################################################################

Now here’s the  script that kills the task using the most amount of CPU:

#################################################################################

### Kill_CPU_Hog.ps1 ###
# First and foremost, I cannot recommend using this or any script to alter system cooling or kill processes as it can cause damage or break stuff!
# I accept no liability for anything, USE AT YOUR OWN RISK!
# CAUTION this sctipt could possibly damage things especially data but if your server is already cooking itself it should help lower the temperatures but know if it kills something as it’s writing data consider it lost!
# This is the second script that finds what is taking the most CPU usage and kills that process. This script should not be run on it’s own.
# This script is invoked by the R330FanControl script that only calls it if the CPU temperature is running too hot and the fans are spinning as fast as they can to keep it cool and it’s still not enough.
# Then this script is invoked to kill whatever is potentially causing the server to overheat.
# https://www.youtube.com/c/ShinyTechThings

#Get all cores, which includes virtual cores from hyperthreading
$cores = (Get-WmiObject Win32_ComputerSystem).NumberOfLogicalProcessors
#Get all process with there ID’s, excluding processes you can’t stop.
$processes = ((Get-Counter “\Process(*)\ID Process”).CounterSamples).where({$_.InstanceName -notin “idle”,”_total”,”system”})
#Get cpu time for all processes
$cputime = $processes.Path.Replace(“id process”, “% Processor Time”) | get-counter | select -ExpandProperty CounterSamples
#Get the processes with above 14% utilisation.
$highUsage = $cputime.where({[Math]::round($_.CookedValue / $cores,2) -gt 14})
# For each high usage process, grab it’s process ID from the processes list, by matching on the relevant part of the path
$highUsage |%{
$path = $_.Path
$id = $processes.where({$_.Path -like “*$($path.Split(‘(‘)[1].Split(‘)’)[0])*”}) | select -ExpandProperty CookedValue
Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
}

#################################################################################
