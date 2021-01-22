#login-azaccount
Connect-AzAccount
Set-AzContext cf5bfdc9-de10-4f8e-af12-5d7352167561
New-AzResourceGroupDeployment -TemplateFile ./Deploy-WVD-Foundation.json
