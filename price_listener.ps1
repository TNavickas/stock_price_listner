function CreateJsonRequest {
    [cmdletbinding()]
    param (
        $symbols
    )
    $symbol_string = [string]::Join(",",$symbols)
    return @{"action"="subscribe"; "params" = @{"symbols" = $symbol_string}} | ConvertTo-Json
}
function RequestSubscription {
    [cmdletbinding()]
    param (
        $WS,
        $CT,
        $json_string
    )

    # Convert json into byte array to send
    $array = @()
    $json_string.ToCharArray() | ForEach-Object { $array += [byte]$_ }          
    $json_string = New-Object System.ArraySegment[byte]  -ArgumentList @(,$array)

    # Send json through socket
    $Conn = $WS.SendAsync($json_string, [System.Net.WebSockets.WebSocketMessageType]::Text, [System.Boolean]::TrueString, $CT)
    While (!$Conn.IsCompleted) { Start-Sleep -Milliseconds 100 }
}
function GetResponse {
    [cmdletbinding()]
    param ($WS,$CT)

    $size = 1024
    $array = [byte[]] @(,0) * $size
    $recv = New-Object System.ArraySegment[byte] -ArgumentList @(,$array)
    $response = ""

    Do {
        $Conn = $WS.ReceiveAsync($recv, $CT)
        While (!$Conn.IsCompleted) { Start-Sleep -Milliseconds 100 }

        $recv.Array[0..($Conn.Result.Count - 1)] | ForEach-Object { $response += [char]$_ }

    } Until ($Conn.Result.Count -lt $size)

    Return $response
}
function ParseResponse {
    [cmdletbinding()]
    param (
        $WS,
        $response
    )
    $json_response = $response | ConvertFrom-Json
    if (($json_response.event -eq 'subscribe-status') -and ($null -eq $json_response.success)) {
        Write-Host "Subscription Failed"
        return 1
    }
    elseif ($json_response.event -eq 'subscribe-status') {
        Write-Host "Subscription Succeeded"
        return 0
    }
    elseif ($json_response.event -eq 'price') {
        #Create DateTime object from timestamp
        [datetime]$origin = '1970-01-01 00:00:00'
        $time = $origin.AddSeconds($json_response.timestamp)

        $symbol = $json_response.symbol
        $price = $json_response.price

        Write-Host "$time $symbol price: $price"
        return 0
    }
    else{
        Write-Host "Unrecognized response"
        Write-Host $response
        return 1
    }
}


Try{
    # Set up url to api
    $uri = "wss://ws.twelvedata.com/v1/quotes/price?apikey="
    $api_key = Get-Content .\api_key.txt -First 1
    $uri = $uri+$api_key

    # Set Symbols to subscribe to
    $symbols = @("BTC/USD")
    if ($args.count -gt  0) {
        $symbols = $args
    }

    $WS = New-Object System.Net.WebSockets.ClientWebSocket                                                
    $CT = New-Object System.Threading.CancellationToken 

    # Connect to api
    Write-Host "Attempting to connect to $uri"
    $Conn = $WS.ConnectAsync($uri, $CT)
    While (!$Conn.IsCompleted) { Start-Sleep -Milliseconds 100 }
    Write-Host "Connected to $uri"

    # Create Json string to subscribe to given symbols
    $json_string = CreateJsonRequest -symbols $symbols

    # Send json through websocket
    Write-Host "Sending subscribe request to the api"
    RequestSubscription -WS $WS -CT $CT -json_string $json_string
    Write-Host "Finished subscribe request to the api"

    # Receive response from server
    Write-Host "Attempting to receive reponse from server"
    $response = GetResponse -WS $WS -CT $CT
    Write-Host "Received reponse from server"
    $status = ParseResponse -WS $WS -response $response

    if ($status -eq 1) {return}

    # Receive price updates from server
    Write-Host "Awaiting stock price updates from server:"
    While ($WS.State -eq 'Open') {
        $response = GetResponse -WS $WS -CT $CT
        $status = ParseResponse -response $response
        if ($status -eq 1) {return}
    }
    
} Finally {
    If ($WS) {
        Write-Host "Closing websocket"
        $WS.Dispose()
    }
}
