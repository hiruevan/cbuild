function Get-CBuildPython {
    # Prefer the Python launcher because it can select a specific version.
    $launcher = Get-Command py.exe -ErrorAction SilentlyContinue

    if ($launcher) {
        & $launcher.Source -3.11 -c "import sys; print(sys.executable)" 2>$null |
            Out-Null

        if ($LASTEXITCODE -eq 0) {
            return @{
                Path = $launcher.Source
                Args = @("-3.11")
            }
        }
    }

    # Fall back to a regular Python executable.
    $python = Get-Command python.exe -ErrorAction SilentlyContinue

    if ($python) {
        & $python.Source -c "import sys; print(sys.executable)" 2>$null |
            Out-Null

        if ($LASTEXITCODE -eq 0) {
            return @{
                Path = $python.Source
                Args = @()
            }
        }
    }

    return $null
}


function Install-CBuildPython {
    Write-Host "`n>>> Checking Python installation..."

    $python = Get-CBuildPython

    if (-not $python) {
        Write-Host "[Notice] Python 3.11 was not detected."

        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
            throw @"
Python is required, but neither Python nor winget was found.

Install Python 3.11 manually:
https://www.python.org/downloads/

Make sure to enable Python PATH integration during installation.
Restart PowerShell afterward and run cbuild install again.
"@
        }

        Write-Host ">>> Installing Python 3.11..."

        & winget install Python.Python.3.11 `
            --accept-package-agreements `
            --accept-source-agreements

        if ($LASTEXITCODE -ne 0) {
            throw "Python installation failed. Install Python manually and retry."
        }

        # Check again because winget may not refresh the current PATH.
        $python = Get-CBuildPython
    }

    if (-not $python) {
        throw @"
Python installation completed, but Python could not be located.

Restart PowerShell to refresh PATH, then run:

    cbuild install

If Python is installed but still unavailable, verify that
the Python launcher or python.exe is accessible from PATH.
"@
    }

    Write-Host "Using Python: $($python.Path)" `
        -ForegroundColor Green

    # Update pip.
    Write-Host ">>> Updating pip..."

    & $python.Path @($python.Args) -m pip install --upgrade pip

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to update pip."
    }

    # Install Pillow.
    Write-Host ">>> Installing Pillow..."

    & $python.Path @($python.Args) -m pip install --quiet pillow

    if ($LASTEXITCODE -ne 0) {
        throw "Pillow installation failed. Check your Python/pip installation."
    }

    # Verify Pillow actually works.
    & $python.Path @($python.Args) -c "from PIL import Image"

    if ($LASTEXITCODE -ne 0) {
        throw "Pillow was installed but could not be imported."
    }

    Write-Host "Python and Pillow are ready." `
        -ForegroundColor Green

    return $python
}