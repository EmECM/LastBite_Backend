<#
    .SYNOPSIS
    Emite un JWT firmado con la clave de desarrollo, sin pasar por login.

    M0 (identidad) todavia no existe, asi que para probar los endpoints con
    [Authorize] hay que fabricar el token a mano. Usa la misma clave y los
    mismos nombres de claim (los URI largos de ClaimTypes, no "sub"/"role")
    que TokenService.cs, para que el resultado sea indistinguible de uno real.

    .EXAMPLE
    ./scripts/mint-jwt-dev.ps1 -UsuarioId 3 -Correo kevin.zelaya@correo.hn -Roles CLIENTE
    ./scripts/mint-jwt-dev.ps1 -UsuarioId 7 -Correo rosa.mejia@eltrigal.hn -Roles COMERCIO
#>
param(
    [Parameter(Mandatory = $true)][long]$UsuarioId,
    [string]$Correo = "dev@lastbite.hn",
    [string[]]$Roles = @("CLIENTE"),
    [int]$Horas = 12,
    [string]$Clave = "clave-solo-para-desarrollo-de-al-menos-32-caracteres",
    [string]$Issuer = "LastBite",
    [string]$Audience = "LastBiteApp"
)

function ConvertTo-Base64Url([byte[]]$Bytes) {
    [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

$header = @{ alg = "HS256"; typ = "JWT" } | ConvertTo-Json -Compress

$exp = [DateTimeOffset]::UtcNow.AddHours($Horas).ToUnixTimeSeconds()

$claims = [ordered]@{
    "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier" = "$UsuarioId"
    "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"   = $Correo
    jti = [guid]::NewGuid().ToString()
    exp = $exp
    iss = $Issuer
    aud = $Audience
}

$rolClaim = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role"
if ($Roles.Count -eq 1) { $claims[$rolClaim] = $Roles[0] }
elseif ($Roles.Count -gt 1) { $claims[$rolClaim] = $Roles }

$payload = $claims | ConvertTo-Json -Compress

$headerB64  = ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($header))
$payloadB64 = ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($payload))
$sinFirmar  = "$headerB64.$payloadB64"

$hmac = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($Clave))
$firma = ConvertTo-Base64Url $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($sinFirmar))

"$sinFirmar.$firma"
