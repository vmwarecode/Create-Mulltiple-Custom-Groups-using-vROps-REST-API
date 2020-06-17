  #################################################################
 # First Part : Get tags from vCenter changing variable $category #
 #################################################################
 # Note : Get-Tags part are from https://code.vmware.com/samples/2808/automated-custom-group-creation-in-vrops-as-per-vcenter-tags#
 # However creating custom group part is not working as expected. So I wrote new powershell script.
  $Server = Connect-VIServer -Server "vCenterServer" -User "user" -Password "Pass"

  #Change Tag Category according to your needs.
  $category = "Environment"

  # Retrieve all tags of the category
   if($category){
        $tagList = Get-Tag -Server $Server -Category $category | Select Name, Category
    }
    else{
        $tagList = Get-Tag -Server $Server | Select Name, Category
    }
   
    $tags = @()

    Foreach($item in $tagList){

    $tag = New-Object PSObject

    #This one is important. We'll use tag name while creating custom groups.
    $tag | add-member -type NoteProperty -Name tagName -Value $item.Name
    #Below part can be uncommented if you want. It just gets tag category.
    #$tag | add-member -type NoteProperty -Name categoryName -Value $item.Category.Name

    $tags += $tag
    }

#################################################################
# Second Part : Get Authorization token from vROps API
#################################################################

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json; utf-8")
$headers.Add("Accept", "application/json")

#Enter your username and password. I just tried with local user.
$body = "{
`n  `"username`" : `"Yourusername`",
`n  `"password`" : `"Yourpassword!`",
`n  `"others`" : [ ],
`n  `"otherAttributes`" : { }
`n}"

#Enter your vROps IP or FQDN
$response = Invoke-RestMethod 'https://yourvropsiporfqdn/suite-api/api/auth/token/acquire' -Method 'POST' -Headers $headers -Body $body
$response | ConvertTo-Json

#We get the token.
$token = $response.token

#################################################################
# Third Part : Create custom groups using vROps API
#################################################################

# $key is the Tag Category again. 
$key = "Environment"

#Below for loop will create custom group for each tag name in tag category. For our example, it "Environment"
for($i=0; $i -le $tags.Length; $i++){

#Check 70th line. This will get tags step by step. And we'll use them in request body.
#Check 80th line. Tag Name will be group Name.
#Check 81st line. This is Container for custom groups. Do not change it!
#Check 82nd line. This is the group type. Change it according to your needs!
$val = $tags[$i].tagName

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json; utf-8")
$headers.Add("Accept", "application/json")
$headers.Add("Authorization", "vRealizeOpsToken $token")

$body = "{
`n    `"id`": null,
`n    `"resourceKey`": {
`n        `"name`": `"$val`",
`n        `"adapterKindKey`": `"Container`",
`n        `"resourceKindKey`": `"Environment`",
`n        `"others`": [],
`n        `"otherAttributes`": {}
`n    },
`n    `"autoResolveMembership`": false,
`n    `"membershipDefinition`": {
`n        `"includedResources`": [],
`n        `"excludedResources`": [],
`n        `"custom-group-properties`": [],
`n        `"rules`": [
`n            {
`n                `"resourceKindKey`": {
`n                    `"resourceKind`": `"VirtualMachine`",
`n                    `"adapterKind`": `"VMWARE`"
`n                },
`n                `"statConditionRules`": [],
`n                `"propertyConditionRules`": [
`n                    {
`n                        `"key`": `"summary|tag`",
`n                        `"stringValue`": `"[<$key-$val>]`",
`n                        `"compareOperator`": `"CONTAINS`"
`n                    }],
`n                `"resourceNameConditionRules`": [],
`n                `"relationshipConditionRules`": [],
`n                `"others`": [],
`n                `"otherAttributes`": {}
`n            }
`n        ],
`n        `"others`": [],
`n        `"otherAttributes`": {}
`n    },
`n    `"others`": [],
`n    `"otherAttributes`": {}
`n}"

$response = Invoke-RestMethod 'https://vrops.mhclabs.com/suite-api/api/resources/groups' -Method 'POST' -Headers $headers -Body $body
}

 
