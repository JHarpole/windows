﻿<#
.Synopsis
   Test a CSV from FakeNameGenerator.com for required fields.
.DESCRIPTION
  Test a CSV from FakeNameGenerator.com for required fields. Original by Carlos Perez (@darkoperator) via http://www.darkoperator.com/blog/2016/7/30/creating-real-looking-user-accounts-in-ad-lab. Patched for 2008 R2 and changed the username format to lowercase GivenName.Surname. This may likely cause collisions in large datasets.
.EXAMPLE
   Test-LabADUserList -Path .\FakeNameGenerator.com_b58aa6a5.csv
#>
function Test-LabADUserList
{
    [CmdletBinding()]
    [OutputType([Bool])]
    Param
    (
        [Parameter(Mandatory=$true,
                   Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Path to CSV generated from fakenamegenerator.com.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    Begin {}
    Process
    {
        # Test if the file exists.
        if (Test-Path -Path $Path -PathType Leaf) 
        {
            Write-Verbose -Message "Testing file $($Path)"
        } 
        else 
        {
            Write-Error -Message "File $($Path) was not found or not a file." 
            $false
            return
        }

        # Get CSV header info.
        $fileinfo = Import-Csv -Path $Path | Get-Member | Select-Object -ExpandProperty Name
        $valid = $true
        
            
        if ($fileinfo -NotContains 'City') {
            Write-Warning -Message 'City field is missing'
            $valid =  $false
        }

        if ($fileinfo -NotContains 'Country') {
            Write-Warning -Message 'Country field is missing'
            $valid =  $false
        }


        if ($fileinfo -NotContains 'GivenName') {
            Write-Warning -Message 'GivenName field is missing'
            $valid =  $false
        }

        if ($fileinfo -NotContains 'Occupation') {
            Write-Warning -Message 'Occupation field is missing'
            $valid =  $false
        }

        if ($fileinfo -NotContains 'Password') {
            Write-Warning -Message 'Password field is missing'
            $valid =  $false
        }

        if ($fileinfo -NotContains 'StreetAddress') {
            Write-Warning -Message 'StreetAddress field is missing'
            $valid =  $false
        }

        if ($fileinfo -NotContains 'Surname') {
            Write-Warning -Message 'Surname field is missing'
            $valid =  $false
        }

        if ($fileinfo -NotContains 'TelephoneNumber') {
            Write-Warning -Message 'TelephoneNumber field is missing'
            $valid =  $false
        }

        if ($fileinfo -NotContains 'Username') {
            Write-Warning -Message 'Username field is missing'
            $valid =  $false
        } 

        $valid
    }
    End {}
}

<#
.SYNOPSIS
    Generates a semi random string.
.DESCRIPTION
    Generates a semi random string.
.EXAMPLE
    C:\PS> Get-RandomString

#>
function Get-RandomString {
    [CmdletBinding()]
    param(
        # Size of string
        [Parameter(Mandatory=$false,
                   HelpMessage='Length of random string,')]
        [int]
        $Length = 5
    )
    
    begin {
    }
    
    process {
        -join ((65..90) + (97..122) | Get-Random -Count $Length | % {[char]$_})
    }
    
    end {
    }
}


<#
.Synopsis
   Removes duplicate username entries from Fake Name Generator generated accounts.
.DESCRIPTION
   Removes duplicate username entries from Fake Name Generator generated accounts. Bulk
   generated accounts from fakenamegenerator.com must have as fields:
   * GivenName
   * Surname
   * StreetAddress
   * City
   * Title
   * Username
   * Password
   * Country
   * TelephoneNumber
   * Occupation
.EXAMPLE
    Remove-LabADUserDuplicate -Path .\FakeNameGenerator.com_b58aa6a5.csv -OutPath .\unique_users.csv
#>
function Remove-LabADUserDuplicate
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   Position=0,
                   ParameterSetName="Path",
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Path to CSV to remove duplicates from.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory=$true,
                   Position=1,
                   ParameterSetName="Path",
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Path to CSV to remove duplicates from.")]
        [ValidateNotNullOrEmpty()]
        [string]
        $OutPath
    )

    Begin {}
    Process
    {
        Write-Verbose -Message "Processing $($Path)"
        if (Test-LabADUserList -Path $Path) {
            Import-Csv -Path $Path | Group-Object GivenName, Surname | Foreach-Object {
                $_.group | Select-Object -Last 1} | Export-Csv -Path $OutPath -Encoding UTF8
        } else {
            Write-Error -Message "File $($Path) is not valid."
        }
        
    }
    End {}
}

<#
.SYNOPSIS
    Imports a CSV from Fake Name Generator to create test AD User accounts.
.DESCRIPTION
    Imports a CSV from Fake Name Generator to create test AD User accounts. 
    It will create OUs per country under the OU specified. Bulk
   generated accounts from fakenamegenerator.com must have as fields:
   * GivenName
   * Surname
   * StreetAddress
   * City
   * Title
   * Username
   * Password
   * Country
   * TelephoneNumber
   * Occupation
.EXAMPLE
    C:\PS> Import-LabADUser -Path .\unique.csv -OU DemoUsers
#>
function Import-LabADUser
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,
                   Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Path to one or more locations.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Path,

        [Parameter(Mandatory=$true,
                   position=1,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Organizational Unit to save users.")]
        [String]
        [Alias('OU')]
        $OrganizationalUnit
    )
    
    begin {
<#
        if (-not (Get-Module -Name 'ActiveDirectory')) {
            Write-Error -Message 'ActiveDirectory module is not present'
            return
        }
#>
    }
    
    process {
        Import-Module ActiveDirectory
        $DomDN = (Get-ADDomain).DistinguishedName
        $forest = (Get-ADDomain).Forest
        $ou = Get-ADOrganizationalUnit -Filter "name -eq '$($OrganizationalUnit)'"
        if($ou -eq $null) {
            New-ADOrganizationalUnit -Name "$($OrganizationalUnit)" -Path $DomDN
            $ou = Get-ADOrganizationalUnit -Filter "name -eq '$($OrganizationalUnit)'"
        }
        $data = 

        Import-Csv -Path $Path | select  @{Name="Name";Expression={$_.Surname + ", " + $_.GivenName}},
                @{Name="SamAccountName"; Expression={$_.GivenName.ToLower() + "." + $_.Surname.ToLower()}},
                @{Name="UserPrincipalName"; Expression={$_.GivenName.ToLower() + "." + $_.Surname.ToLower() +"@" + $forest}},
                @{Name="GivenName"; Expression={$_.GivenName}},
                @{Name="Surname"; Expression={$_.Surname}},
                @{Name="DisplayName"; Expression={$_.Surname + ", " + $_.GivenName}},
                @{Name="City"; Expression={$_.City}},
                @{Name="StreetAddress"; Expression={$_.StreetAddress}},
                @{Name="State"; Expression={$_.State}},
                @{Name="Country"; Expression={$_.Country}},
                @{Name="PostalCode"; Expression={$_.ZipCode}},
                @{Name="EmailAddress"; Expression={$_.GivenName.ToLower() + "." + $_.Surname.ToLower() +"@" + $forest}},
                @{Name="AccountPassword"; Expression={ (Convertto-SecureString -Force -AsPlainText $_.password)}},
                @{Name="OfficePhone"; Expression={$_.TelephoneNumber}},
                @{Name="Title"; Expression={$_.Occupation}},
                @{Name="Enabled"; Expression={$true}},
                @{Name="PasswordNeverExpires"; Expression={$true}} | ForEach-Object -Process {
             
                    $subou = Get-ADOrganizationalUnit -Filter "name -eq ""$($_.Country)""" -SearchBase $ou.DistinguishedName        
                    if($subou -eq $null) {
                        New-ADOrganizationalUnit -Name $_.Country -Path $ou.DistinguishedName
                        $subou = Get-ADOrganizationalUnit -Filter "name -eq ""$($_.Country)""" -SearchBase $ou.DistinguishedName        
                    }
                    $_ | Select @{Name="Path"; Expression={$subou.DistinguishedName}},* | New-ADUser  
                }
    }    
    end {}
}
