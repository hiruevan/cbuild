function Display-cbuildAPI() {
    Show-Markdown "./shim/API.md"
}


function Show-Markdown {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    # Resolve the Markdown file
    $Path = (Resolve-Path $Path -ErrorAction Stop).Path

    if ([IO.Path]::GetExtension($Path) -ne ".md") {
        throw "File must be a Markdown (.md) file."
    }

    # Read Markdown content
    $Markdown = Get-Content -Path $Path -Raw

    # Encode Markdown as Base64 to safely embed it in HTML
    $Bytes = [Text.Encoding]::UTF8.GetBytes($Markdown)
    $Base64 = [Convert]::ToBase64String($Bytes)

    # Create HTML page
    $Html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$( [IO.Path]::GetFileNameWithoutExtension($Path) )</title>

    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>

    <style>
        body {
            font-family: Arial, sans-serif;
            background: #0f1117;
            color: #e6e6e6;
            margin: 0;
            padding: 40px 20px;
            line-height: 1.7;
        }

        main {
            max-width: 900px;
            margin: auto;
            background: #181b23;
            padding: 40px;
            border-radius: 12px;
        }

        h1, h2, h3 {
            color: #ffffff;
        }

        a {
            color: #9b8cff;
        }

        code {
            background: #292d38;
            padding: 3px 6px;
            border-radius: 4px;
        }

        pre {
            background: #101219;
            padding: 18px;
            border-radius: 8px;
            overflow-x: auto;
        }

        pre code {
            padding: 0;
            background: none;
        }

        blockquote {
            border-left: 4px solid #7c6cf0;
            margin-left: 0;
            padding-left: 16px;
            color: #aaa;
        }

        img {
            max-width: 100%;
        }

        table {
            border-collapse: collapse;
            width: 100%;
        }

        th, td {
            border: 1px solid #383d49;
            padding: 10px;
        }

        th {
            background: #292d38;
        }

        hr {
            border: 0;
            border-top: 1px solid #383d49;
        }
    </style>
</head>
<body>
    <main id="content">Loading...</main>

    <script>
        const markdown = new TextDecoder().decode(
            Uint8Array.from(atob("$Base64"), c => c.charCodeAt(0))
        );

        document.getElementById("content").innerHTML =
            marked.parse(markdown);
    </script>
</body>
</html>
"@

    # Save to temporary HTML file
    $TempFile = Join-Path $env:TEMP (
        [IO.Path]::GetRandomFileName() + ".html"
    )

    Set-Content -Path $TempFile -Value $Html -Encoding UTF8

    # Open in default browser
    Start-Process $TempFile
}
